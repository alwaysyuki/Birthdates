//
//  FriendRepository.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation
import SwiftData

/// Protocol defining operations on friends, archival lifecycles, and associated children.
protocol FriendRepositoryProtocol: Sendable {
    func createFriend(
        firstName: String,
        lastName: String,
        nickname: String?,
        birthMonth: Int,
        birthDay: Int,
        birthYear: Int?,
        hasBirthday: Bool,
        isFavorite: Bool,
        photoData: Data?,
        notes: String?,
        avatarColorHex: String,
        tags: [String],
        categories: [Category],
        reminderLeadDays: [Int],
        in context: ModelContext
    ) throws -> Friend

    func updateFriend(_ friend: Friend, in context: ModelContext) throws
    func toggleFavorite(_ friend: Friend, in context: ModelContext) throws
    func archive(_ friend: Friend, in context: ModelContext) throws
    func unarchive(_ friend: Friend, in context: ModelContext) throws
    func deletePermanently(_ friend: Friend, in context: ModelContext) throws

    func addMemory(
        title: String,
        notes: String?,
        date: Date,
        photoData: Data?,
        to friend: Friend,
        in context: ModelContext
    ) throws -> Memory

    func deleteMemory(_ memory: Memory, from friend: Friend, in context: ModelContext) throws

    func addGiftIdea(
        title: String,
        notes: String?,
        url: String?,
        price: Double?,
        to friend: Friend,
        in context: ModelContext
    ) throws -> GiftIdea

    func deleteGiftIdea(_ giftIdea: GiftIdea, from friend: Friend, in context: ModelContext) throws
}

/// Offline persistent repository managing friends and their associated life cycle.
final class FriendRepository: FriendRepositoryProtocol {
    static let shared = FriendRepository()

    init() {}

    /// Validates birthday components and persists a new friend with initial reminder settings.
    @discardableResult
    func createFriend(
        firstName: String,
        lastName: String = "",
        nickname: String? = nil,
        birthMonth: Int = 1,
        birthDay: Int = 1,
        birthYear: Int? = nil,
        hasBirthday: Bool = true,
        isFavorite: Bool = false,
        photoData: Data? = nil,
        notes: String? = nil,
        avatarColorHex: String = "#0A84FF",
        tags: [String] = [],
        categories: [Category] = [],
        reminderLeadDays: [Int] = [0, 1, 3],
        in context: ModelContext
    ) throws -> Friend {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFirst.isEmpty else {
            throw DataError.validationFailed("First name cannot be empty.")
        }

        if hasBirthday {
            do {
                try BirthdayValidator.validate(month: birthMonth, day: birthDay, year: birthYear)
            } catch {
                throw DataError.validationFailed(error.localizedDescription)
            }
        }

        let friend = Friend(
            firstName: trimmedFirst,
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            nickname: nickname?.trimmingCharacters(in: .whitespacesAndNewlines),
            birthMonth: birthMonth,
            birthDay: birthDay,
            birthYear: birthYear,
            hasBirthday: hasBirthday,
            isFavorite: isFavorite,
            photoData: photoData,
            notes: notes,
            avatarColorHex: avatarColorHex,
            tags: tags,
            categories: categories
        )

        let reminders = ReminderSettings(
            isEnabled: true,
            leadTimeDays: reminderLeadDays,
            friend: friend
        )
        friend.reminderSettings = reminders

        context.insert(friend)

        for category in categories {
            if !(category.friends?.contains(where: { $0.id == friend.id }) ?? false) {
                category.friends?.append(friend)
            }
        }

        try save(context: context)
        return friend
    }

    /// Updates existing friend properties and persists changes.
    func updateFriend(_ friend: Friend, in context: ModelContext) throws {
        let trimmedFirst = friend.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFirst.isEmpty else {
            throw DataError.validationFailed("First name cannot be empty.")
        }

        if friend.hasBirthday {
            do {
                try BirthdayValidator.validate(
                    month: friend.birthMonth,
                    day: friend.birthDay,
                    year: friend.birthYear
                )
            } catch {
                throw DataError.validationFailed(error.localizedDescription)
            }
        }

        friend.updatedAt = Date()
        try save(context: context)
    }

    /// Toggles favorite status and immediately persists.
    func toggleFavorite(_ friend: Friend, in context: ModelContext) throws {
        friend.toggleFavorite()
        try save(context: context)
    }

    /// Soft-archives a friend, keeping all associated memories and gift ideas intact.
    func archive(_ friend: Friend, in context: ModelContext) throws {
        friend.archive()
        try save(context: context)
    }

    /// Restores a previously archived friend back into active status.
    func unarchive(_ friend: Friend, in context: ModelContext) throws {
        friend.unarchive()
        try save(context: context)
    }

    /// Permanently deletes a friend and cascades deletion to memories, gift ideas, and reminder settings.
    /// Safely severs relations with categories without modifying category objects.
    func deletePermanently(_ friend: Friend, in context: ModelContext) throws {
        // Disassociate categories first
        for category in friend.categories {
            category.friends?.removeAll(where: { $0.id == friend.id })
        }
        friend.categories.removeAll()

        // Delete root friend; SwiftData cascades deletion to memories, giftIdeas, and reminderSettings
        context.delete(friend)

        try save(context: context)
    }

    // MARK: - Associated Memories
    @discardableResult
    func addMemory(
        title: String,
        notes: String? = nil,
        date: Date = Date(),
        photoData: Data? = nil,
        to friend: Friend,
        in context: ModelContext
    ) throws -> Memory {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw DataError.validationFailed("Memory title cannot be empty.")
        }

        let memory = Memory(
            title: trimmedTitle,
            notes: notes,
            date: date,
            photoData: photoData,
            friend: friend
        )
        friend.memories.append(memory)
        friend.updatedAt = Date()

        try save(context: context)
        return memory
    }

    func deleteMemory(_ memory: Memory, from friend: Friend, in context: ModelContext) throws {
        friend.memories.removeAll(where: { $0.id == memory.id })
        context.delete(memory)
        friend.updatedAt = Date()

        try save(context: context)
    }

    // MARK: - Associated Gift Ideas
    @discardableResult
    func addGiftIdea(
        title: String,
        notes: String? = nil,
        url: String? = nil,
        price: Double? = nil,
        to friend: Friend,
        in context: ModelContext
    ) throws -> GiftIdea {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw DataError.validationFailed("Gift idea title cannot be empty.")
        }

        let gift = GiftIdea(
            title: trimmedTitle,
            notes: notes,
            url: url,
            price: price,
            friend: friend
        )
        friend.giftIdeas.append(gift)
        friend.updatedAt = Date()

        try save(context: context)
        return gift
    }

    func deleteGiftIdea(_ giftIdea: GiftIdea, from friend: Friend, in context: ModelContext) throws {
        friend.giftIdeas.removeAll(where: { $0.id == giftIdea.id })
        context.delete(giftIdea)
        friend.updatedAt = Date()

        try save(context: context)
    }

    // MARK: - Save Helper
    private func save(context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            throw DataError.saveFailed(error.localizedDescription)
        }
    }
}
