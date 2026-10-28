//
//  Friend.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation
import SwiftData

/// Represents a friend whose birthday, circles, memories, and gift ideas are managed entirely offline.
@Model
final class Friend {
    // MARK: - Identity & Basic Info
    var id: UUID = UUID()
    var firstName: String = ""
    var lastName: String = ""
    var nickname: String?
    var notes: String?
    var avatarColorHex: String = "#0A84FF"
    var tags: [String] = []
    var isFavorite: Bool = false
    var photoData: Data? = nil

    // MARK: - Validated Birthday Components
    var birthMonth: Int = 1
    var birthDay: Int = 1
    var birthYear: Int?
    var isBirthYearKnown: Bool = true
    var hasBirthday: Bool = true

    // MARK: - Lifecycle & Archival
    var isArchived: Bool = false
    var archivedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationships
    /// Friends can belong to multiple categories. Deleting a category nullifies this relationship.
    @Relationship(deleteRule: .nullify, inverse: \Category.friends)
    var categories: [Category] = []

    /// Memories tied to this friend. Cascade deleted when friend is permanently deleted.
    @Relationship(deleteRule: .cascade, inverse: \Memory.friend)
    var memories: [Memory] = []

    /// Gift ideas tied to this friend. Cascade deleted when friend is permanently deleted.
    @Relationship(deleteRule: .cascade, inverse: \GiftIdea.friend)
    var giftIdeas: [GiftIdea] = []

    /// Reminder configuration for this friend. Cascade deleted when friend is permanently deleted.
    @Relationship(deleteRule: .cascade, inverse: \ReminderSettings.friend)
    var reminderSettings: ReminderSettings?

    // MARK: - Initializer with Date Components
    init(
        id: UUID = UUID(),
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
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.nickname = nickname
        self.birthMonth = birthMonth
        self.birthDay = birthDay
        self.birthYear = birthYear
        self.isBirthYearKnown = (birthYear != nil)
        self.hasBirthday = hasBirthday
        self.isFavorite = isFavorite
        self.photoData = photoData
        self.notes = notes
        self.avatarColorHex = avatarColorHex
        self.tags = tags
        self.categories = categories
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.memories = []
        self.giftIdeas = []
        self.reminderSettings = nil
    }

    // MARK: - Convenience Initializer with Date
    convenience init(
        id: UUID = UUID(),
        firstName: String,
        lastName: String = "",
        nickname: String? = nil,
        birthdate: Date = Date(),
        isBirthYearKnown: Bool = true,
        hasBirthday: Bool = true,
        isFavorite: Bool = false,
        photoData: Data? = nil,
        notes: String? = nil,
        avatarColorHex: String = "#0A84FF",
        tags: [String] = [],
        categories: [Category] = [],
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: birthdate)
        let day = calendar.component(.day, from: birthdate)
        let year = isBirthYearKnown ? calendar.component(.year, from: birthdate) : nil

        self.init(
            id: id,
            firstName: firstName,
            lastName: lastName,
            nickname: nickname,
            birthMonth: month,
            birthDay: day,
            birthYear: year,
            hasBirthday: hasBirthday,
            isFavorite: isFavorite,
            photoData: photoData,
            notes: notes,
            avatarColorHex: avatarColorHex,
            tags: tags,
            categories: categories,
            isArchived: isArchived,
            archivedAt: archivedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Computed Properties
    /// Convenience accessor treating tags as interests
    var interests: [String] {
        get { tags }
        set { tags = newValue }
    }

    /// Synthesizes a Date from the stored birth components for display or calculations.
    var birthdate: Date {
        var components = DateComponents()
        components.year = birthYear ?? 2000
        components.month = birthMonth
        components.day = birthDay
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Primary category helper for single-category display contexts.
    var category: Category? {
        get { categories.first }
        set {
            if let newValue {
                if !categories.contains(where: { $0.id == newValue.id }) {
                    categories.append(newValue)
                }
            } else {
                categories.removeAll()
            }
        }
    }

    /// Full formatted name.
    var fullName: String {
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLast.isEmpty {
            return firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "\(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) \(trimmedLast)"
    }

    /// User-friendly display name favoring nickname when present.
    var displayName: String {
        if let nick = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nick.isEmpty {
            return "\(fullName) (\(nick))"
        }
        return fullName
    }

    /// Two-letter monogram for avatar presentation.
    var initials: String {
        let firstLetter = firstName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)
        let lastLetter = lastName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)
        if lastLetter.isEmpty {
            return firstLetter.uppercased()
        }
        return "\(firstLetter)\(lastLetter)".uppercased()
    }

    // MARK: - Actions
    func toggleFavorite() {
        self.isFavorite.toggle()
        self.updatedAt = Date()
    }

    func archive() {
        self.isArchived = true
        self.archivedAt = Date()
        self.updatedAt = Date()
    }

    func unarchive() {
        self.isArchived = false
        self.archivedAt = nil
        self.updatedAt = Date()
    }
}
