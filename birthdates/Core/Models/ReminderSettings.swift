//
//  ReminderSettings.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation
import SwiftData

/// Configures notification preferences and advance alert intervals for a friend.
@Model
final class ReminderSettings {
    var id: UUID = UUID()
    var isEnabled: Bool = true
    var leadTimeDays: [Int] = [0, 1, 3]
    var notificationHour: Int = 9
    var notificationMinute: Int = 0
    var customMessage: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify)
    var friend: Friend?

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        leadTimeDays: [Int] = [0, 1, 3],
        notificationHour: Int = 9,
        notificationMinute: Int = 0,
        customMessage: String? = nil,
        friend: Friend? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.leadTimeDays = leadTimeDays
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
        self.customMessage = customMessage
        self.friend = friend
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
