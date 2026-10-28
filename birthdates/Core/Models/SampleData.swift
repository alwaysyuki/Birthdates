//
//  SampleData.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation
import SwiftData

/// Helper to generate sample models for SwiftData previews and tests without relying on network or external data.
enum SampleData {
    @MainActor
    static func createSampleContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: AppSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            populateSampleData(context: container.mainContext)
            return container
        } catch {
            fatalError("Failed to instantiate sample in-memory ModelContainer: \(error.localizedDescription)")
        }
    }

    @MainActor
    static func populateSampleData(context: ModelContext) {
        let family = Category(name: "Family", iconName: "heart.fill", colorHex: "#FF2D55", sortOrder: 0)
        let closeFriends = Category(name: "Close Friends", iconName: "star.fill", colorHex: "#FF9500", sortOrder: 1)
        let colleagues = Category(name: "Colleagues", iconName: "briefcase.fill", colorHex: "#007AFF", sortOrder: 2)

        context.insert(family)
        context.insert(closeFriends)
        context.insert(colleagues)

        let calendar = Calendar.current
        let today = Date()

        let emmaBirthday = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        let emmaMonth = calendar.component(.month, from: emmaBirthday)
        let emmaDay = calendar.component(.day, from: emmaBirthday)
        let emmaYear = 1995

        let friend1 = Friend(
            firstName: "Emma",
            lastName: "Watson",
            nickname: "Em",
            birthMonth: emmaMonth,
            birthDay: emmaDay,
            birthYear: emmaYear,
            notes: "Loves science fiction novels and artisan tea.",
            avatarColorHex: "#AF52DE",
            tags: ["High School", "London"],
            categories: [closeFriends]
        )
        friend1.reminderSettings = ReminderSettings(
            isEnabled: true,
            leadTimeDays: [0, 1, 3],
            friend: friend1
        )
        friend1.memories.append(Memory(
            title: "30th Birthday Surprise",
            notes: "Surprise picnic at Regents Park with friends.",
            date: calendar.date(byAdding: .year, value: -1, to: today) ?? today,
            friend: friend1
        ))
        friend1.giftIdeas.append(GiftIdea(
            title: "Vintage First Edition Novel",
            notes: "Check local antique book shop",
            price: 45.0,
            friend: friend1
        ))

        let liamBirthday = calendar.date(byAdding: .day, value: 14, to: today) ?? today
        let liamMonth = calendar.component(.month, from: liamBirthday)
        let liamDay = calendar.component(.day, from: liamBirthday)

        let friend2 = Friend(
            firstName: "Liam",
            lastName: "Chen",
            nickname: nil,
            birthMonth: liamMonth,
            birthDay: liamDay,
            birthYear: nil, // Unknown birth year
            notes: "Enjoys bouldering and specialty coffee.",
            avatarColorHex: "#34C759",
            tags: ["Colleague", "Gym"],
            categories: [closeFriends, colleagues] // Belongs to multiple categories
        )
        friend2.reminderSettings = ReminderSettings(
            isEnabled: true,
            leadTimeDays: [0, 1],
            friend: friend2
        )

        let sophiaBirthday = calendar.date(byAdding: .day, value: 30, to: today) ?? today
        let sophiaMonth = calendar.component(.month, from: sophiaBirthday)
        let sophiaDay = calendar.component(.day, from: sophiaBirthday)
        let sophiaYear = 1998

        let friend3 = Friend(
            firstName: "Sophia",
            lastName: "Miller",
            nickname: "Soph",
            birthMonth: sophiaMonth,
            birthDay: sophiaDay,
            birthYear: sophiaYear,
            notes: "Cousin on mother's side.",
            avatarColorHex: "#FF3B30",
            tags: ["Family"],
            categories: [family]
        )
        friend3.reminderSettings = ReminderSettings(
            isEnabled: true,
            leadTimeDays: [0, 7],
            friend: friend3
        )

        context.insert(friend1)
        context.insert(friend2)
        context.insert(friend3)

        closeFriends.friends?.append(friend1)
        closeFriends.friends?.append(friend2)
        colleagues.friends?.append(friend2)
        family.friends?.append(friend3)
    }
}
