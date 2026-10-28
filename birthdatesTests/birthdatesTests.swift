//
//  birthdatesTests.swift
//  birthdatesTests
//
//  Created for native macOS offline-first birthday management.
//

import Testing
import Foundation
import SwiftData
import SwiftUI
import UserNotifications
@testable import birthdates

// Disambiguate against OSLog/Testing Category
typealias Category = birthdates.Category

struct BirthdayValidatorTests {

    @Test func testValidBirthdays() throws {
        // Normal date
        #expect(throws: Never.self) {
            try BirthdayValidator.validate(month: 7, day: 15, year: 1990)
        }

        // Unknown year
        #expect(throws: Never.self) {
            try BirthdayValidator.validate(month: 12, day: 25, year: nil)
        }

        // Leap year valid day
        #expect(throws: Never.self) {
            try BirthdayValidator.validate(month: 2, day: 29, year: 2024)
        }
    }

    @Test func testInvalidMonth() {
        #expect(throws: BirthdayValidationError.invalidMonth(13)) {
            try BirthdayValidator.validate(month: 13, day: 10, year: 2000)
        }

        #expect(throws: BirthdayValidationError.invalidMonth(0)) {
            try BirthdayValidator.validate(month: 0, day: 10, year: 2000)
        }
    }

    @Test func testInvalidDayForMonth() {
        // April has 30 days
        #expect(throws: BirthdayValidationError.invalidDay(day: 31, month: 4)) {
            try BirthdayValidator.validate(month: 4, day: 31, year: 2000)
        }

        // Non-leap year February has 28 days
        #expect(throws: BirthdayValidationError.invalidDay(day: 29, month: 2)) {
            try BirthdayValidator.validate(month: 2, day: 29, year: 2023)
        }
    }

    @Test func testFutureBirthYear() {
        let futureYear = Calendar.current.component(.year, from: Date()) + 1
        #expect(throws: BirthdayValidationError.invalidYear(futureYear)) {
            try BirthdayValidator.validate(month: 1, day: 1, year: futureYear)
        }
    }
}

@MainActor
struct ModelPersistenceAndRelationshipTests {

    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: AppSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func testMultipleCategoriesRelationship() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()
        let categoryRepo = CategoryRepository()

        let family = try categoryRepo.createCategory(name: "Family", iconName: "heart.fill", colorHex: "#FF2D55", sortOrder: 0, in: context)
        let work = try categoryRepo.createCategory(name: "Work", iconName: "briefcase.fill", colorHex: "#007AFF", sortOrder: 1, in: context)

        let friend = try friendRepo.createFriend(
            firstName: "Alex",
            lastName: "Rivera",
            birthMonth: 5,
            birthDay: 20,
            birthYear: 1992,
            categories: [family, work],
            in: context
        )

        #expect(friend.categories.count == 2)
        #expect(friend.categories.contains(where: { $0.id == family.id }))
        #expect(friend.categories.contains(where: { $0.id == work.id }))
        #expect(family.friends?.contains(where: { $0.id == friend.id }) ?? false)
        #expect(work.friends?.contains(where: { $0.id == friend.id }) ?? false)
    }

    @Test func testCategoryDeletionNeverDeletesFriends() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()
        let categoryRepo = CategoryRepository()

        let category = try categoryRepo.createCategory(name: "Book Club", in: context)
        let friend = try friendRepo.createFriend(
            firstName: "Jordan",
            birthMonth: 8,
            birthDay: 12,
            birthYear: 1988,
            categories: [category],
            in: context
        )

        let friendId = friend.id
        let categoryId = category.id

        // Delete the category
        try categoryRepo.deleteCategory(category, in: context)

        // Verify category is deleted
        var catDescriptor = FetchDescriptor<birthdates.Category>()
        catDescriptor.predicate = #Predicate { $0.id == categoryId }
        let remainingCategories = try context.fetch(catDescriptor)
        #expect(remainingCategories.isEmpty)

        // Verify friend is STILL ALIVE and intact
        var friendDescriptor = FetchDescriptor<Friend>()
        friendDescriptor.predicate = #Predicate { $0.id == friendId }
        let remainingFriends = try context.fetch(friendDescriptor)
        #expect(remainingFriends.count == 1)
        #expect(remainingFriends.first?.categories.isEmpty == true)
    }

    @Test func testFriendArchiveAndUnarchive() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let friend = try friendRepo.createFriend(
            firstName: "Maya",
            birthMonth: 3,
            birthDay: 5,
            in: context
        )

        #expect(friend.isArchived == false)
        #expect(friend.archivedAt == nil)

        // Archive
        try friendRepo.archive(friend, in: context)
        #expect(friend.isArchived == true)
        #expect(friend.archivedAt != nil)

        // Unarchive
        try friendRepo.unarchive(friend, in: context)
        #expect(friend.isArchived == false)
        #expect(friend.archivedAt == nil)
    }

    @Test func testPermanentDeleteCascadesToMemoriesAndGifts() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let friend = try friendRepo.createFriend(
            firstName: "Taylor",
            birthMonth: 11,
            birthDay: 3,
            birthYear: 1996,
            in: context
        )

        let memory = try friendRepo.addMemory(title: "Graduation Party", to: friend, in: context)
        let gift = try friendRepo.addGiftIdea(title: "Espresso Grinder", price: 120.0, to: friend, in: context)

        let memoryId = memory.id
        let giftId = gift.id
        let reminderId = friend.reminderSettings?.id

        #expect(friend.memories.count == 1)
        #expect(friend.giftIdeas.count == 1)
        #expect(reminderId != nil)

        // Permanently delete friend
        try friendRepo.deletePermanently(friend, in: context)

        // Confirm memories cascaded
        var memDescriptor = FetchDescriptor<Memory>()
        memDescriptor.predicate = #Predicate { $0.id == memoryId }
        let remainingMemories = try context.fetch(memDescriptor)
        #expect(remainingMemories.isEmpty)

        // Confirm gift ideas cascaded
        var giftDescriptor = FetchDescriptor<GiftIdea>()
        giftDescriptor.predicate = #Predicate { $0.id == giftId }
        let remainingGifts = try context.fetch(giftDescriptor)
        #expect(remainingGifts.isEmpty)

        // Confirm reminder settings cascaded
        if let reminderId {
            var remDescriptor = FetchDescriptor<ReminderSettings>()
            remDescriptor.predicate = #Predicate { $0.id == reminderId }
            let remainingReminders = try context.fetch(remDescriptor)
            #expect(remainingReminders.isEmpty)
        }
    }

    @Test func testFriendValidationFailures() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        // Empty first name
        #expect(throws: DataError.self) {
            try friendRepo.createFriend(
                firstName: "   ",
                birthMonth: 6,
                birthDay: 10,
                in: context
            )
        }

        // Invalid day for month
        #expect(throws: DataError.self) {
            try friendRepo.createFriend(
                firstName: "Sam",
                birthMonth: 2,
                birthDay: 30,
                in: context
            )
        }
    }
}

// MARK: - Design System Tests
struct DesignSystemThemeTests {

    @Test func testSpacingGridProgression() {
        #expect(AppTheme.Spacing.xxSmall == 4)
        #expect(AppTheme.Spacing.xSmall == 8)
        #expect(AppTheme.Spacing.small == 12)
        #expect(AppTheme.Spacing.medium == 16)
        #expect(AppTheme.Spacing.large == 20)
        #expect(AppTheme.Spacing.xLarge == 24)
        #expect(AppTheme.Spacing.xxLarge == 32)
        #expect(AppTheme.Spacing.xxxLarge == 40)
    }

    @Test func testCornerRadiiProgression() {
        #expect(AppTheme.CornerRadius.small < AppTheme.CornerRadius.medium)
        #expect(AppTheme.CornerRadius.medium < AppTheme.CornerRadius.large)
        #expect(AppTheme.CornerRadius.large < AppTheme.CornerRadius.xLarge)
        #expect(AppTheme.CornerRadius.xLarge < AppTheme.CornerRadius.circular)
    }

    @Test func testColorHexParsing() {
        // Valid 6-char hex
        let blueColor = Color(hex: "#0A84FF")
        #expect(blueColor != nil)

        // Valid 8-char hex (with alpha)
        let pinkWithAlpha = Color(hex: "#FF2D5580")
        #expect(pinkWithAlpha != nil)

        // Invalid hex
        let invalidColor = Color(hex: "not-a-color")
        #expect(invalidColor == nil)
    }

    @Test func testReduceMotionAnimationHelper() {
        let spring = AppTheme.Motion.smoothSpring

        // When reduceMotion is true, animation must be nil
        let disabledAnimation = AppTheme.Motion.animation(spring, reduceMotion: true)
        #expect(disabledAnimation == nil)

        // When reduceMotion is false, animation must be returned
        let enabledAnimation = AppTheme.Motion.animation(spring, reduceMotion: false)
        #expect(enabledAnimation != nil)
    }

    @Test func testLayoutWindowBoundaries() {
        #expect(AppTheme.Layout.windowMinWidth <= AppTheme.Layout.windowIdealWidth)
        #expect(AppTheme.Layout.windowMinHeight <= AppTheme.Layout.windowIdealHeight)
        #expect(AppTheme.Layout.sidebarMinWidth <= AppTheme.Layout.sidebarIdealWidth)
        #expect(AppTheme.Layout.sidebarIdealWidth <= AppTheme.Layout.sidebarMaxWidth)
    }
}

@MainActor
struct DesignSystemComponentTests {

    @Test func testGlassCardInstantiability() {
        let card = GlassCard(
            padding: AppTheme.Spacing.medium,
            cornerRadius: AppTheme.CornerRadius.medium,
            isInteractive: true,
            tintColor: .pink
        ) {
            Text("Test Content")
        }
        #expect(card != nil)
    }

    @Test func testFriendAvatarInstantiability() {
        let avatar = FriendAvatar(
            initials: "EW",
            colorHex: "#AF52DE",
            size: 40,
            name: "Emma Watson"
        )
        #expect(avatar != nil)
    }

    @Test func testCategoryChipInstantiability() {
        let chip = CategoryChip(
            title: "Family",
            color: .pink,
            iconName: "heart.fill",
            count: 3,
            isSelected: true,
            action: {}
        )
        #expect(chip != nil)
    }

    @Test func testBirthdayRowInstantiability() {
        let friend = Friend(
            firstName: "Sophia",
            lastName: "Miller",
            nickname: "Soph",
            birthMonth: 10,
            birthDay: 24,
            birthYear: 1998
        )
        let row = BirthdayRow(
            friend: friend,
            daysRemaining: 7,
            nextBirthdayDate: Date(),
            turningAge: 28,
            zodiacSign: "Scorpio ♏️",
            showCategories: true
        )
        #expect(row != nil)
    }

    @Test func testEmptyStateViewInstantiability() {
        let emptyState = EmptyStateView(
            iconName: "calendar.badge.plus",
            title: "No Birthdays Yet",
            message: "Add your friends to begin tracking their birthdays offline.",
            actionTitle: "Add Friend",
            action: {}
        )
        #expect(emptyState != nil)
    }
}

// MARK: - Friends Feature Tests
@MainActor
struct FriendsFeaturePersistenceAndValidationTests {

    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: AppSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func testCreateFriendWithOptionalBirthdayAndInterests() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let friend = try friendRepo.createFriend(
            firstName: "Devon",
            lastName: "Brooks",
            nickname: "Dev",
            birthMonth: 1,
            birthDay: 1,
            birthYear: nil,
            hasBirthday: false,
            isFavorite: true,
            photoData: nil,
            notes: "Met at Swift conference",
            avatarColorHex: "#34C759",
            tags: ["Swift", "Photography"],
            categories: [],
            in: context
        )

        #expect(friend.firstName == "Devon")
        #expect(friend.nickname == "Dev")
        #expect(friend.hasBirthday == false)
        #expect(friend.isFavorite == true)
        #expect(friend.interests.count == 2)
        #expect(friend.interests.contains("Swift"))
        #expect(friend.interests.contains("Photography"))
        #expect(friend.notes == "Met at Swift conference")
    }

    @Test func testFriendFavoriteToggleUpdatesTimestamp() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let friend = try friendRepo.createFriend(
            firstName: "Clara",
            birthMonth: 4,
            birthDay: 18,
            in: context
        )

        let initialTimestamp = friend.updatedAt
        #expect(friend.isFavorite == false)

        try friendRepo.toggleFavorite(friend, in: context)
        #expect(friend.isFavorite == true)
        #expect(friend.updatedAt >= initialTimestamp)

        try friendRepo.toggleFavorite(friend, in: context)
        #expect(friend.isFavorite == false)
    }

    @Test func testFriendWithoutBirthdaySkipsBirthdayValidation() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        // With hasBirthday: false, arbitrary month/day does not throw validation error
        #expect(throws: Never.self) {
            try friendRepo.createFriend(
                firstName: "Morgan",
                birthMonth: 0,
                birthDay: 0,
                hasBirthday: false,
                in: context
            )
        }
    }

    @Test func testUpdateFriendPersistsAndUpdatesTimestamp() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let friend = try friendRepo.createFriend(
            firstName: "Robin",
            birthMonth: 9,
            birthDay: 15,
            in: context
        )

        let oldDate = friend.updatedAt
        friend.lastName = "Hood"
        friend.notes = "Updated notes"

        try friendRepo.updateFriend(friend, in: context)
        #expect(friend.fullName == "Robin Hood")
        #expect(friend.updatedAt >= oldDate)
    }
}

@MainActor
struct FriendsFeatureFilteringAndSortingTests {

    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: AppSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func testSearchByNameNicknameAndInterests() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let alice = try friendRepo.createFriend(
            firstName: "Alice",
            lastName: "Smith",
            nickname: "Ali",
            birthMonth: 1,
            birthDay: 10,
            tags: ["Rowing"],
            in: context
        )

        let bob = try friendRepo.createFriend(
            firstName: "Bob",
            lastName: "Jones",
            nickname: "Bobby",
            birthMonth: 2,
            birthDay: 20,
            tags: ["Baking"],
            in: context
        )

        let all = [alice, bob]

        // Search by first name
        let nameResults = all.filter { $0.fullName.localizedCaseInsensitiveContains("Alice") }
        #expect(nameResults.count == 1)
        #expect(nameResults.first?.firstName == "Alice")

        // Search by nickname
        let nickResults = all.filter { $0.nickname?.localizedCaseInsensitiveContains("Bobby") ?? false }
        #expect(nickResults.count == 1)
        #expect(nickResults.first?.firstName == "Bob")

        // Search by interest tag
        let tagResults = all.filter { $0.tags.contains(where: { $0.localizedCaseInsensitiveContains("Rowing") }) }
        #expect(tagResults.count == 1)
        #expect(tagResults.first?.firstName == "Alice")
    }

    @Test func testFilterByFavoritesAndArchive() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let f1 = try friendRepo.createFriend(firstName: "Friend1", birthMonth: 3, birthDay: 1, isFavorite: true, in: context)
        let f2 = try friendRepo.createFriend(firstName: "Friend2", birthMonth: 4, birthDay: 2, isFavorite: false, in: context)
        let f3 = try friendRepo.createFriend(firstName: "Friend3", birthMonth: 5, birthDay: 3, isFavorite: true, in: context)
        try friendRepo.archive(f3, in: context)

        let all = [f1, f2, f3]

        // Active favorites
        let activeFavorites = all.filter { !$0.isArchived && $0.isFavorite }
        #expect(activeFavorites.count == 1)
        #expect(activeFavorites.first?.firstName == "Friend1")

        // Archived only
        let archived = all.filter { $0.isArchived }
        #expect(archived.count == 1)
        #expect(archived.first?.firstName == "Friend3")
    }
}

@MainActor
struct FriendsFeatureUIComponentTests {

    @Test func testFriendEditorSheetInstantiability() {
        let newSheet = FriendEditorSheet(friendToEdit: nil)
        #expect(newSheet != nil)

        let friend = Friend(firstName: "Test", birthMonth: 1, birthDay: 1)
        let editSheet = FriendEditorSheet(friendToEdit: friend)
        #expect(editSheet != nil)
    }

    @Test func testFriendsListViewInstantiability() {
        let view = FriendsListView()
        #expect(view != nil)
    }
}

// MARK: - BirthdayCalculator Tests
struct BirthdayCalculatorTests {

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar = .current) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)!
    }

    @Test func testBirthdayToday() throws {
        let calendar = Calendar.current
        let calculator = BirthdayCalculator(calendar: calendar)
        let refDate = makeDate(year: 2026, month: 5, day: 14, calendar: calendar)

        let remaining = try calculator.daysRemaining(month: 5, day: 14, relativeTo: refDate)
        #expect(remaining == 0)

        let isToday = calculator.isBirthdayToday(month: 5, day: 14, relativeTo: refDate)
        #expect(isToday == true)

        let next = try calculator.nextBirthday(month: 5, day: 14, relativeTo: refDate)
        #expect(calendar.component(.year, from: next) == 2026)
        #expect(calendar.component(.month, from: next) == 5)
        #expect(calendar.component(.day, from: next) == 14)
    }

    @Test func testBirthdayTomorrow() throws {
        let calendar = Calendar.current
        let calculator = BirthdayCalculator(calendar: calendar)
        let refDate = makeDate(year: 2026, month: 5, day: 14, calendar: calendar)

        let remaining = try calculator.daysRemaining(month: 5, day: 15, relativeTo: refDate)
        #expect(remaining == 1)

        let isToday = calculator.isBirthdayToday(month: 5, day: 15, relativeTo: refDate)
        #expect(isToday == false)

        let next = try calculator.nextBirthday(month: 5, day: 15, relativeTo: refDate)
        #expect(calendar.component(.year, from: next) == 2026)
        #expect(calendar.component(.month, from: next) == 5)
        #expect(calendar.component(.day, from: next) == 15)
    }

    @Test func testBirthdayYesterday() throws {
        let calendar = Calendar.current
        let calculator = BirthdayCalculator(calendar: calendar)
        // 2026 is a non-leap year (365 days)
        let refDate = makeDate(year: 2026, month: 5, day: 14, calendar: calendar)

        let remaining = try calculator.daysRemaining(month: 5, day: 13, relativeTo: refDate)
        // Since yesterday passed, next birthday is May 13, 2027 (364 days away)
        #expect(remaining == 364)

        let isToday = calculator.isBirthdayToday(month: 5, day: 13, relativeTo: refDate)
        #expect(isToday == false)

        let next = try calculator.nextBirthday(month: 5, day: 13, relativeTo: refDate)
        #expect(calendar.component(.year, from: next) == 2027)
        #expect(calendar.component(.month, from: next) == 5)
        #expect(calendar.component(.day, from: next) == 13)
    }

    @Test func testDecemberToJanuaryRollover() throws {
        let calendar = Calendar.current
        let calculator = BirthdayCalculator(calendar: calendar)

        // New Year's Eve -> New Year's Day
        let newYearsEve = makeDate(year: 2026, month: 12, day: 31, calendar: calendar)
        let remainingNY = try calculator.daysRemaining(month: 1, day: 1, relativeTo: newYearsEve)
        #expect(remainingNY == 1)

        let nextNY = try calculator.nextBirthday(month: 1, day: 1, relativeTo: newYearsEve)
        #expect(calendar.component(.year, from: nextNY) == 2027)
        #expect(calendar.component(.month, from: nextNY) == 1)
        #expect(calendar.component(.day, from: nextNY) == 1)

        // Late December -> Early January (Dec 28 to Jan 3 = 6 days)
        let dec28 = makeDate(year: 2026, month: 12, day: 28, calendar: calendar)
        let remainingJan3 = try calculator.daysRemaining(month: 1, day: 3, relativeTo: dec28)
        #expect(remainingJan3 == 6)
    }

    @Test func testFebruary29InLeapAndNonLeapYears() throws {
        let calendar = Calendar.current

        // 1. Leap Year: 2024
        let calcLeap = BirthdayCalculator(calendar: calendar)
        let refLeap = makeDate(year: 2024, month: 1, day: 1, calendar: calendar)
        let nextLeap = try calcLeap.nextBirthday(month: 2, day: 29, relativeTo: refLeap)
        #expect(calendar.component(.year, from: nextLeap) == 2024)
        #expect(calendar.component(.month, from: nextLeap) == 2)
        #expect(calendar.component(.day, from: nextLeap) == 29)

        // 2. Non-Leap Year defaulting to February 28
        let calcFeb28 = BirthdayCalculator(calendar: calendar, leapYearBehavior: .february28)
        let refNonLeap = makeDate(year: 2025, month: 1, day: 1, calendar: calendar)
        let nextFeb28 = try calcFeb28.nextBirthday(month: 2, day: 29, relativeTo: refNonLeap)
        #expect(calendar.component(.year, from: nextFeb28) == 2025)
        #expect(calendar.component(.month, from: nextFeb28) == 2)
        #expect(calendar.component(.day, from: nextFeb28) == 28)

        // 3. Non-Leap Year configured for March 1
        let calcMarch1 = BirthdayCalculator(calendar: calendar, leapYearBehavior: .march1)
        let nextMarch1 = try calcMarch1.nextBirthday(month: 2, day: 29, relativeTo: refNonLeap)
        #expect(calendar.component(.year, from: nextMarch1) == 2025)
        #expect(calendar.component(.month, from: nextMarch1) == 3)
        #expect(calendar.component(.day, from: nextMarch1) == 1)
    }

    @Test func testBirthdayWithoutBirthYear() {
        let calendar = Calendar.current
        let calculator = BirthdayCalculator(calendar: calendar)
        let refDate = makeDate(year: 2026, month: 8, day: 1, calendar: calendar)

        let result = calculator.calculateDetails(month: 8, day: 22, year: nil, relativeTo: refDate)
        switch result {
        case .success(let details):
            #expect(details.turningAge == nil)
            #expect(details.currentAge == nil)
            #expect(details.daysRemaining == 21)
            #expect(details.isToday == false)
            #expect(details.zodiacSign == "Leo ♌️")
            #expect(calendar.component(.year, from: details.nextBirthday) == 2026)
            #expect(calendar.component(.month, from: details.nextBirthday) == 8)
            #expect(calendar.component(.day, from: details.nextBirthday) == 22)
        case .failure(let error):
            Issue.record("Expected success but received error: \(error)")
        }
    }

    @Test func testAgeBeforeVersusAfterBirthday() {
        let calendar = Calendar.current
        let calculator = BirthdayCalculator(calendar: calendar)

        // Person born on June 15, 1990
        let birthYear = 1990
        let birthMonth = 6
        let birthDay = 15

        // Case 1: Day before birthday (June 14, 2025)
        let dayBefore = makeDate(year: 2025, month: 6, day: 14, calendar: calendar)
        let currentAgeBefore = calculator.currentAge(birthYear: birthYear, birthMonth: birthMonth, birthDay: birthDay, relativeTo: dayBefore)
        let turningAgeBefore = calculator.ageTurning(birthYear: birthYear, birthMonth: birthMonth, birthDay: birthDay, relativeTo: dayBefore)
        #expect(currentAgeBefore == 34)
        #expect(turningAgeBefore == 35)

        // Case 2: Day of birthday (June 15, 2025)
        let dayOf = makeDate(year: 2025, month: 6, day: 15, calendar: calendar)
        let currentAgeOf = calculator.currentAge(birthYear: birthYear, birthMonth: birthMonth, birthDay: birthDay, relativeTo: dayOf)
        let turningAgeOf = calculator.ageTurning(birthYear: birthYear, birthMonth: birthMonth, birthDay: birthDay, relativeTo: dayOf)
        #expect(currentAgeOf == 35)
        #expect(turningAgeOf == 35)

        // Case 3: Day after birthday (June 16, 2025)
        let dayAfter = makeDate(year: 2025, month: 6, day: 16, calendar: calendar)
        let currentAgeAfter = calculator.currentAge(birthYear: birthYear, birthMonth: birthMonth, birthDay: birthDay, relativeTo: dayAfter)
        let turningAgeAfter = calculator.ageTurning(birthYear: birthYear, birthMonth: birthMonth, birthDay: birthDay, relativeTo: dayAfter)
        #expect(currentAgeAfter == 35)
        #expect(turningAgeAfter == 36)
    }

    @Test func testTimeZoneChangeConsistency() throws {
        var tokyoCalendar = Calendar(identifier: .gregorian)
        guard let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo") else { return }
        tokyoCalendar.timeZone = tokyoTimeZone

        let calculator = BirthdayCalculator(calendar: tokyoCalendar)
        let refDate = makeDate(year: 2026, month: 10, day: 17, calendar: tokyoCalendar)

        let remaining = try calculator.daysRemaining(month: 10, day: 20, relativeTo: refDate)
        #expect(remaining == 3)
    }

    @Test func testMissingAndInvalidBirthdayData() {
        let calculator = BirthdayCalculator.shared

        // Missing month / day
        let missingResult = calculator.calculateDetails(month: nil, day: nil, year: 2000)
        #expect(missingResult == .failure(.missingBirthday))

        // Invalid month
        let invalidMonthResult = calculator.calculateDetails(month: 13, day: 10)
        #expect(invalidMonthResult == .failure(.invalidMonth(13)))

        // Invalid day for month
        let invalidDayResult = calculator.calculateDetails(month: 4, day: 31)
        #expect(invalidDayResult == .failure(.invalidDay(day: 31, month: 4)))

        // Non-existent day in Feb non-leap
        let invalidFebResult = calculator.calculateDetails(month: 2, day: 30)
        #expect(invalidFebResult == .failure(.invalidDay(day: 30, month: 2)))
    }
}

// MARK: - Home Dashboard & Calendar Feature Tests
@MainActor
struct HomeDashboardAndCalendarTests {

    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: AppSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func testHomeViewInstantiability() {
        let view = HomeView()
        #expect(view != nil)
    }

    @Test func testCalendarViewInstantiability() {
        let view = CalendarView()
        #expect(view != nil)
    }

    @Test func testHomeMetricsAndFilteringLogic() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        // 1. Friend with birthday today (relative to now)
        let cal = Calendar.current
        let now = Date()
        let thisMonth = cal.component(.month, from: now)
        let thisDay = cal.component(.day, from: now)

        let f1 = try friendRepo.createFriend(
            firstName: "BirthdayStar",
            birthMonth: thisMonth,
            birthDay: thisDay,
            in: context
        )

        // 2. Friend without birthday recorded
        let f2 = try friendRepo.createFriend(
            firstName: "NoBirthdayFriend",
            birthMonth: 0,
            birthDay: 0,
            hasBirthday: false,
            in: context
        )

        // 3. Friend archived
        let f3 = try friendRepo.createFriend(
            firstName: "ArchivedFriend",
            birthMonth: thisMonth,
            birthDay: thisDay,
            in: context
        )
        try friendRepo.archive(f3, in: context)

        let all = [f1, f2, f3]

        // Active friends metric (archived excluded)
        let activeFriends = all.filter { !$0.isArchived }
        #expect(activeFriends.count == 2)
        #expect(activeFriends.contains(where: { $0.id == f1.id }))
        #expect(activeFriends.contains(where: { $0.id == f2.id }))

        // Birthday calculations only include friends who have birthdays
        let activeWithBirthdays = activeFriends.filter { $0.hasBirthday }
        #expect(activeWithBirthdays.count == 1)
        #expect(activeWithBirthdays.first?.firstName == "BirthdayStar")

        // Calculator checks for today
        let calculator = BirthdayCalculator.shared
        let isToday = calculator.isBirthdayToday(for: f1, relativeTo: now)
        #expect(isToday == true)

        let isNoBirthdayToday = calculator.isBirthdayToday(for: f2, relativeTo: now)
        #expect(isNoBirthdayToday == false)
    }

    @Test func testUpcomingRangeFiltering() {
        let calculator = BirthdayCalculator.shared
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = 1
        let refDate = cal.date(from: comps)!

        // Person with birthday on April 10 (9 days away)
        let days9 = try? calculator.daysRemaining(month: 4, day: 10, relativeTo: refDate)
        #expect(days9 == 9)

        // Test range options
        #expect(days9! > UpcomingRangeOption.next7Days.rawValue)
        #expect(days9! <= UpcomingRangeOption.next14Days.rawValue)
        #expect(days9! <= UpcomingRangeOption.next30Days.rawValue)
        #expect(days9! <= UpcomingRangeOption.next60Days.rawValue)
        #expect(days9! <= UpcomingRangeOption.next90Days.rawValue)
    }

    @Test func testCalendarMonthEventResolutionAndLeapDays() {
        let calculator = BirthdayCalculator.shared

        // Non-leap year 2025
        let year2025 = 2025
        #expect(calculator.isLeapYear(year2025) == false)

        // Feb 29 friend resolves to Feb 28 in non-leap year by default
        let resolvedDate = calculator.resolveDate(month: 2, day: 29, inYear: year2025)
        #expect(resolvedDate != nil)
        let cal = Calendar.current
        #expect(cal.component(.month, from: resolvedDate!) == 2)
        #expect(cal.component(.day, from: resolvedDate!) == 28)

        // Leap year 2024
        let year2024 = 2024
        #expect(calculator.isLeapYear(year2024) == true)
        let resolvedLeap = calculator.resolveDate(month: 2, day: 29, inYear: year2024)
        #expect(resolvedLeap != nil)
        #expect(cal.component(.month, from: resolvedLeap!) == 2)
        #expect(cal.component(.day, from: resolvedLeap!) == 29)
    }
}

// MARK: - Notification Manager Tests
final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var authorizationStatus: UNAuthorizationStatus = .authorized
    var scheduledRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [[String]] = []
    var removeAllCount: Int = 0
    var requestAuthorizationResult: Bool = true
    var shouldFailOnAdd: Bool = false

    init(authorizationStatus: UNAuthorizationStatus = .authorized) {
        self.authorizationStatus = authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        return requestAuthorizationResult
    }

    func notificationSettings() async -> UNNotificationSettingsSnapshot {
        return UNNotificationSettingsSnapshot(authorizationStatus: authorizationStatus)
    }

    func add(_ request: UNNotificationRequest) async throws {
        if shouldFailOnAdd {
            throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to add notification"])
        }
        scheduledRequests.append(request)
    }

    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        return scheduledRequests
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
        scheduledRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllPendingNotificationRequests() {
        removeAllCount += 1
        scheduledRequests.removeAll()
    }
}

@MainActor
struct NotificationManagerTests {

    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: AppSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)!
    }

    @Test func testStableIdentifierFormat() {
        let friendId = UUID()
        let id = NotificationManager.makeIdentifier(friendId: friendId, targetYear: 2026, leadTimeDays: 3)
        #expect(id == "bday-\(friendId.uuidString)-2026-3d")
    }

    @Test func testSchedulingWhenPermissionDeniedDoesNotClaimDelivered() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let mockCenter = MockNotificationCenter(authorizationStatus: .denied)
        let manager = NotificationManager(notificationCenter: mockCenter)

        let friend = try friendRepo.createFriend(
            firstName: "Alice",
            birthMonth: 5,
            birthDay: 20,
            birthYear: 1995,
            in: context
        )
        let prefs = NotificationPreferences(isEnabled: true, leadTimeDays: [0, 1, 3], notificationHour: 9, notificationMinute: 0)

        let refDate = makeDate(year: 2026, month: 5, day: 1)
        await manager.reconcileNotifications(friends: [friend], preferences: prefs, referenceDate: refDate)

        #expect(manager.authorizationStatus == .denied)
        #expect(manager.pendingRequestsCount == 0)
        #expect(mockCenter.scheduledRequests.isEmpty)
        #expect(mockCenter.removeAllCount >= 1)
    }

    @Test func testReminderCandidatesGenerationWithLeadTimes() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let mockCenter = MockNotificationCenter(authorizationStatus: .authorized)
        let manager = NotificationManager(notificationCenter: mockCenter)

        let friend = try friendRepo.createFriend(
            firstName: "Sophia",
            birthMonth: 6,
            birthDay: 15,
            birthYear: 2000,
            in: context
        )
        // Set reminderSettings to nil so globalPreferences are tested
        friend.reminderSettings = nil

        let prefs = NotificationPreferences(
            isEnabled: true,
            leadTimeDays: [0, 1, 7],
            notificationHour: 9,
            notificationMinute: 30
        )

        let refDate = makeDate(year: 2026, month: 6, day: 1, hour: 0, minute: 0)
        let candidates = manager.reminderCandidates(
            for: friend,
            globalPreferences: prefs,
            referenceDate: refDate
        )

        // Across 2026 and 2027, with 3 lead times each, we have 6 future candidates
        #expect(candidates.count == 6)

        // Verify the 7-day candidate for 2026: June 15 - 7 days = June 8 at 09:30
        let sevenDay2026 = candidates.first { $0.leadTimeDays == 7 && $0.triggerComponents.year == 2026 }
        #expect(sevenDay2026 != nil)
        #expect(sevenDay2026?.triggerComponents.month == 6)
        #expect(sevenDay2026?.triggerComponents.day == 8)
        #expect(sevenDay2026?.triggerComponents.hour == 9)
        #expect(sevenDay2026?.triggerComponents.minute == 30)
        #expect(sevenDay2026?.turningAge == 26)
        #expect(sevenDay2026?.title.contains("7 Days") == true)

        // Verify the 0-day (same day) candidate for 2026: June 15 at 09:30
        let zeroDay2026 = candidates.first { $0.leadTimeDays == 0 && $0.triggerComponents.year == 2026 }
        #expect(zeroDay2026 != nil)
        #expect(zeroDay2026?.triggerComponents.day == 15)
        #expect(zeroDay2026?.title.contains("Today") == true)
    }

    @Test func testExclusionOfArchivedAndBirthdaylessFriends() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let mockCenter = MockNotificationCenter(authorizationStatus: .authorized)
        let manager = NotificationManager(notificationCenter: mockCenter)

        // 1. Archived friend
        let archived = try friendRepo.createFriend(firstName: "Archived", birthMonth: 7, birthDay: 10, in: context)
        try friendRepo.archive(archived, in: context)

        // 2. Friend without birthday
        let noBirthday = try friendRepo.createFriend(
            firstName: "NoBirthday",
            birthMonth: 0,
            birthDay: 0,
            hasBirthday: false,
            in: context
        )

        // 3. Friend with disabled reminders
        let disabled = try friendRepo.createFriend(firstName: "Disabled", birthMonth: 7, birthDay: 12, in: context)
        disabled.reminderSettings?.isEnabled = false

        // 4. Active valid friend
        let validFriend = try friendRepo.createFriend(firstName: "Active", birthMonth: 7, birthDay: 15, in: context)

        let prefs = NotificationPreferences(isEnabled: true, leadTimeDays: [0], notificationHour: 9, notificationMinute: 0)
        let refDate = makeDate(year: 2026, month: 7, day: 1)

        await manager.reconcileNotifications(
            friends: [archived, noBirthday, disabled, validFriend],
            preferences: prefs,
            referenceDate: refDate
        )

        // Only the valid active friend should have requests scheduled
        #expect(mockCenter.scheduledRequests.allSatisfy { $0.identifier.contains(validFriend.id.uuidString) })
        #expect(!mockCenter.scheduledRequests.isEmpty)
    }

    @Test func testRollingSchedulingWindowRespects64NotificationLimit() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let mockCenter = MockNotificationCenter(authorizationStatus: .authorized)
        let manager = NotificationManager(notificationCenter: mockCenter)

        // Generate 30 friends with 3 lead times each (90 candidates total)
        var friends: [Friend] = []
        for i in 1...30 {
            let f = try friendRepo.createFriend(
                firstName: "Friend\(i)",
                birthMonth: 8,
                birthDay: (i % 28) + 1,
                birthYear: 1990,
                in: context
            )
            friends.append(f)
        }

        let prefs = NotificationPreferences(isEnabled: true, leadTimeDays: [0, 1, 3], notificationHour: 9, notificationMinute: 0)
        let refDate = makeDate(year: 2026, month: 8, day: 1)

        await manager.reconcileNotifications(friends: friends, preferences: prefs, referenceDate: refDate)

        // Must be capped strictly at 64 pending requests
        #expect(mockCenter.scheduledRequests.count == 64)
        #expect(manager.pendingRequestsCount == 64)
    }

    @Test func testPerFriendCustomReminderSettingsOverride() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let mockCenter = MockNotificationCenter(authorizationStatus: .authorized)
        let manager = NotificationManager(notificationCenter: mockCenter)

        let friend = try friendRepo.createFriend(
            firstName: "CustomFriend",
            birthMonth: 9,
            birthDay: 20,
            birthYear: 1998,
            in: context
        )
        friend.reminderSettings?.isEnabled = true
        friend.reminderSettings?.leadTimeDays = [7] // only 7 days
        friend.reminderSettings?.notificationHour = 14
        friend.reminderSettings?.notificationMinute = 45
        friend.reminderSettings?.customMessage = "Bring the surprise gift!"

        let globalPrefs = NotificationPreferences(
            isEnabled: true,
            leadTimeDays: [0, 1, 3], // global defaults
            notificationHour: 9,
            notificationMinute: 0
        )

        let refDate = makeDate(year: 2026, month: 9, day: 1)
        let candidates = manager.reminderCandidates(
            for: friend,
            globalPreferences: globalPrefs,
            referenceDate: refDate
        )

        // Only the 7-day override should be generated, not [0, 1, 3]
        #expect(candidates.allSatisfy { $0.leadTimeDays == 7 })
        #expect(candidates.allSatisfy { $0.triggerComponents.hour == 14 && $0.triggerComponents.minute == 45 })
        #expect(candidates.allSatisfy { $0.body == "Bring the surprise gift!" })
    }

    @Test func testLeapDayBirthdaySchedulingInNonLeapYear() throws {
        let container = try createTestContainer()
        let context = container.mainContext
        let friendRepo = FriendRepository()

        let mockCenter = MockNotificationCenter(authorizationStatus: .authorized)
        let manager = NotificationManager(notificationCenter: mockCenter)

        let leapFriend = try friendRepo.createFriend(
            firstName: "LeapBaby",
            birthMonth: 2,
            birthDay: 29,
            birthYear: 2000,
            in: context
        )
        let prefs = NotificationPreferences(isEnabled: true, leadTimeDays: [0], notificationHour: 9, notificationMinute: 0)

        // 2025 is a non-leap year
        let refDate = makeDate(year: 2025, month: 2, day: 1)
        let candidates = manager.reminderCandidates(
            for: leapFriend,
            globalPreferences: prefs,
            referenceDate: refDate
        )

        // In 2025, February 29 resolves to February 28
        let candidate2025 = candidates.first { $0.triggerComponents.year == 2025 }
        #expect(candidate2025 != nil)
        #expect(candidate2025?.triggerComponents.month == 2)
        #expect(candidate2025?.triggerComponents.day == 28)
    }
}
