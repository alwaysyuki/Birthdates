//
//  NotificationManager.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation
import UserNotifications
import SwiftData
import SwiftUI

/// Abstract protocol for UserNotifications scheduling to allow complete unit testing without system daemons.
protocol NotificationCenterProtocol: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func notificationSettings() async -> UNNotificationSettingsSnapshot
    func add(_ request: UNNotificationRequest) async throws
    func getPendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeAllPendingNotificationRequests()
}

/// Decoupled snapshot of UNNotificationSettings for testability.
struct UNNotificationSettingsSnapshot: Sendable, Equatable {
    let authorizationStatus: UNAuthorizationStatus

    init(authorizationStatus: UNAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }
}

/// Default system wrapper bridging UNUserNotificationCenter.
final class SystemNotificationCenterWrapper: NotificationCenterProtocol, @unchecked Sendable {
    private var isTestingEnvironment: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil ||
        NSClassFromString("XCTestCase") != nil
    }

    private var center: UNUserNotificationCenter? {
        guard !isTestingEnvironment else { return nil }
        return UNUserNotificationCenter.current()
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        guard let center else { return false }
        return try await center.requestAuthorization(options: options)
    }

    func notificationSettings() async -> UNNotificationSettingsSnapshot {
        guard let center else {
            return UNNotificationSettingsSnapshot(authorizationStatus: .notDetermined)
        }
        let settings = await center.notificationSettings()
        return UNNotificationSettingsSnapshot(authorizationStatus: settings.authorizationStatus)
    }

    func add(_ request: UNNotificationRequest) async throws {
        guard let center else { return }
        try await center.add(request)
    }

    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        guard let center else { return [] }
        return await center.pendingNotificationRequests()
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        guard let center else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeAllPendingNotificationRequests() {
        guard let center else { return }
        center.removeAllPendingNotificationRequests()
    }
}

/// Global user preferences for default birthday notifications.
struct NotificationPreferences: Codable, Equatable, Sendable {
    var isEnabled: Bool = true
    var leadTimeDays: [Int] = [0, 1, 3]
    var notificationHour: Int = 9
    var notificationMinute: Int = 0

    static let defaultsKey = "birthdates.notificationPreferences"

    static func load() -> NotificationPreferences {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            return prefs
        }
        return NotificationPreferences()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: NotificationPreferences.defaultsKey)
        }
    }
}

/// Scheduled reminder candidate awaiting system queueing.
struct ScheduledReminderCandidate: Sendable, Equatable {
    let identifier: String
    let friendId: UUID
    let friendName: String
    let triggerDate: Date
    let triggerComponents: DateComponents
    let leadTimeDays: Int
    let turningAge: Int?
    let title: String
    let body: String
}

/// Observable service coordinating macOS UserNotifications, rolling windows, and permission states.
@MainActor
@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    /// Maximum pending notifications allowed by macOS UserNotifications
    static let maxPendingNotifications = 64

    let notificationCenter: NotificationCenterProtocol
    private let calculator = BirthdayCalculator.shared

    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var pendingRequestsCount: Int = 0
    var lastReconciledAt: Date? = nil
    var lastSyncError: String? = nil
    var isReconciling: Bool = false

    init(notificationCenter: NotificationCenterProtocol? = nil) {
        self.notificationCenter = notificationCenter ?? SystemNotificationCenterWrapper()
        setupLifecycleObservers()
    }

    // MARK: - Lifecycle & Timezone Observers
    private func setupLifecycleObservers() {
        // Observe system time zone adjustments and calendar day changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name.NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshAuthorizationStatus()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name.NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshAuthorizationStatus()
            }
        }
    }

    // MARK: - Permission Management
    /// Checks and updates the live authorization status.
    func refreshAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
        let pending = await notificationCenter.getPendingNotificationRequests()
        self.pendingRequestsCount = pending.count
    }

    /// Requests user authorization for alerts, badges, and sounds.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            self.lastSyncError = error.localizedDescription
            await refreshAuthorizationStatus()
            return false
        }
    }

    /// Opens macOS System Settings directly to the notifications preference pane.
    func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Notification Reconciliation & Scheduling
    /// Generates stable identifier for a notification.
    nonisolated static func makeIdentifier(friendId: UUID, targetYear: Int, leadTimeDays: Int) -> String {
        "bday-\(friendId.uuidString)-\(targetYear)-\(leadTimeDays)d"
    }

    /// Generates all eligible candidates for a given friend across a rolling scheduling window.
    func reminderCandidates(
        for friend: Friend,
        globalPreferences: NotificationPreferences,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [ScheduledReminderCandidate] {
        // Validation checks
        guard !friend.isArchived, friend.hasBirthday else { return [] }

        // Determine if reminders are enabled for this friend
        let friendReminderSettings = friend.reminderSettings
        let isEnabled = friendReminderSettings?.isEnabled ?? globalPreferences.isEnabled
        guard isEnabled else { return [] }

        let leadDays = friendReminderSettings?.leadTimeDays ?? globalPreferences.leadTimeDays
        let hour = friendReminderSettings?.notificationHour ?? globalPreferences.notificationHour
        let minute = friendReminderSettings?.notificationMinute ?? globalPreferences.notificationMinute

        var candidates: [ScheduledReminderCandidate] = []
        let currentYear = calendar.component(.year, from: referenceDate)

        // Evaluate milestones for the current calendar year and the next calendar year
        for targetYear in [currentYear, currentYear + 1] {
            guard let birthdayDate = calculator.resolveDate(
                month: friend.birthMonth,
                day: friend.birthDay,
                inYear: targetYear
            ) else {
                continue
            }

            for leadDaysCount in leadDays {
                // Determine target trigger date: birthday minus leadDaysCount
                guard let triggerDayDate = calendar.date(byAdding: .day, value: -leadDaysCount, to: birthdayDate) else {
                    continue
                }

                // Apply delivery hour and minute
                var triggerComponents = calendar.dateComponents([.year, .month, .day], from: triggerDayDate)
                triggerComponents.hour = hour
                triggerComponents.minute = minute
                triggerComponents.second = 0

                guard let fullTriggerDate = calendar.date(from: triggerComponents) else {
                    continue
                }

                // Must be strictly in the future relative to the reference date
                guard fullTriggerDate > referenceDate else {
                    continue
                }

                // Turning age calculation
                let turningAge: Int?
                if friend.isBirthYearKnown, let birthYear = friend.birthYear {
                    let age = targetYear - birthYear
                    turningAge = age > 0 ? age : nil
                } else {
                    turningAge = nil
                }

                // Title & Body
                let title: String
                if leadDaysCount == 0 {
                    title = "🎉 \(friend.displayName)'s Birthday Today!"
                } else if leadDaysCount == 1 {
                    title = "🎂 \(friend.displayName)'s Birthday Tomorrow"
                } else {
                    title = "🗓️ \(friend.displayName)'s Birthday in \(leadDaysCount) Days"
                }

                let body: String
                if let custom = friendReminderSettings?.customMessage, !custom.isEmpty {
                    body = custom
                } else if let turningAge {
                    if leadDaysCount == 0 {
                        body = "\(friend.firstName) turns \(turningAge) today! Don't forget to wish them a wonderful celebration."
                    } else {
                        body = "\(friend.firstName) will be turning \(turningAge) on \(birthdayDate.formatted(date: .abbreviated, time: .omitted))."
                    }
                } else {
                    body = "Don't forget to celebrate \(friend.displayName) on \(birthdayDate.formatted(date: .abbreviated, time: .omitted))!"
                }

                let identifier = Self.makeIdentifier(
                    friendId: friend.id,
                    targetYear: targetYear,
                    leadTimeDays: leadDaysCount
                )

                candidates.append(
                    ScheduledReminderCandidate(
                        identifier: identifier,
                        friendId: friend.id,
                        friendName: friend.displayName,
                        triggerDate: fullTriggerDate,
                        triggerComponents: triggerComponents,
                        leadTimeDays: leadDaysCount,
                        turningAge: turningAge,
                        title: title,
                        body: body
                    )
                )
            }
        }

        return candidates
    }

    /// Reconciles all pending local notifications for active friends.
    /// Orders by earliest date first and respects the 64-notification system threshold.
    func reconcileNotifications(
        friends: [Friend],
        preferences: NotificationPreferences = NotificationPreferences.load(),
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) async {
        isReconciling = true
        defer { isReconciling = false }

        await refreshAuthorizationStatus()

        // If authorization is denied or not authorized, clear pending requests and exit
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            notificationCenter.removeAllPendingNotificationRequests()
            self.pendingRequestsCount = 0
            self.lastReconciledAt = Date()
            return
        }

        // If global reminders disabled, clear all
        guard preferences.isEnabled else {
            notificationCenter.removeAllPendingNotificationRequests()
            self.pendingRequestsCount = 0
            self.lastReconciledAt = Date()
            return
        }

        // Collect all candidates across all friends
        var allCandidates: [ScheduledReminderCandidate] = []
        for friend in friends {
            let candidates = reminderCandidates(
                for: friend,
                globalPreferences: preferences,
                referenceDate: referenceDate,
                calendar: calendar
            )
            allCandidates.append(contentsOf: candidates)
        }

        // Deduplicate by identifier and sort chronologically (earliest first)
        var uniqueCandidatesById: [String: ScheduledReminderCandidate] = [:]
        for candidate in allCandidates {
            uniqueCandidatesById[candidate.identifier] = candidate
        }

        let sortedCandidates = uniqueCandidatesById.values.sorted {
            $0.triggerDate < $1.triggerDate
        }

        // Cap at the maximum allowed pending notifications (64)
        let scheduledBatch = Array(sortedCandidates.prefix(Self.maxPendingNotifications))

        // Reset existing pending notifications and reschedule the prioritized batch
        notificationCenter.removeAllPendingNotificationRequests()

        var successfullyScheduled = 0
        for candidate in scheduledBatch {
            let content = UNMutableNotificationContent()
            content.title = candidate.title
            content.body = candidate.body
            content.sound = .default
            content.userInfo = [
                "friendId": candidate.friendId.uuidString,
                "leadTimeDays": candidate.leadTimeDays
            ]

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: candidate.triggerComponents,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: candidate.identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
                successfullyScheduled += 1
            } catch {
                self.lastSyncError = "Failed to schedule notification: \(error.localizedDescription)"
            }
        }

        let pending = await notificationCenter.getPendingNotificationRequests()
        self.pendingRequestsCount = pending.count
        self.lastReconciledAt = Date()
    }

    /// Fetches all friends from the given SwiftData context and reconciles pending notifications.
    func reconcileAll(in context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<Friend>()
            let friends = try context.fetch(descriptor)
            await reconcileNotifications(friends: friends)
        } catch {
            self.lastSyncError = "Failed to fetch friends for notifications: \(error.localizedDescription)"
        }
    }
}
