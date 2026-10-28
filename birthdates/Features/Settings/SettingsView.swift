//
//  SettingsView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import SwiftData
import UserNotifications

/// Settings and preferences view for native macOS offline configuration
/// styled with liquid-glass card containers and accessible controls.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var friends: [Friend]
    @Query private var categories: [Category]

    @AppStorage("showZodiacSigns") private var showZodiacSigns: Bool = true
    @AppStorage("showTurningAge") private var showTurningAge: Bool = true

    @State private var notificationManager = NotificationManager.shared
    @State private var preferences: NotificationPreferences = NotificationPreferences.load()
    @State private var selectedLeadTimes: Set<Int> = Set(NotificationPreferences.load().leadTimeDays)
    @State private var deliveryDate: Date = {
        let prefs = NotificationPreferences.load()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = prefs.notificationHour
        comps.minute = prefs.notificationMinute
        return Calendar.current.date(from: comps) ?? Date()
    }()

    private let availableLeadTimes: [(days: Int, label: String)] = [
        (0, "On the day (0 days)"),
        (1, "1 day before"),
        (3, "3 days before"),
        (7, "1 week before (7 days)"),
        (14, "2 weeks before (14 days)")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                // Header
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                    Text("Settings & Preferences")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Manage your offline birthday tracking preferences, local notifications, and storage.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Notification Authorization Status Card
                notificationPermissionCard

                // Default Reminder Rules
                notificationPreferencesCard

                // Rolling Window & System Limit Info Card
                notificationSystemLimitCard

                // General Preferences
                displayPreferencesCard

                // Privacy & Storage
                storageCard
            }
            .padding(AppTheme.Spacing.large)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle("Settings")
        .task {
            await notificationManager.refreshAuthorizationStatus()
        }
    }

    // MARK: - Subviews: Notification Authorization
    private var notificationPermissionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                    ZStack {
                        Circle()
                            .fill(permissionColor.opacity(0.15))
                            .frame(width: 38, height: 38)

                        Image(systemName: permissionIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(permissionColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("macOS Notification Permission")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(permissionBadgeTitle)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(permissionColor.opacity(0.12))
                                .foregroundStyle(permissionColor)
                                .clipShape(Capsule())
                        }

                        Text(permissionDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if notificationManager.authorizationStatus == .denied {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                                Text("⚠️ Notifications are disabled. Birthday reminders cannot be delivered.")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)

                                Text("To enable alerts: Open System Settings → Notifications → birthdates and toggle 'Allow Notifications'.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button("Open System Settings") {
                                    notificationManager.openSystemNotificationSettings()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .padding(.top, 4)
                            }
                            .padding(.top, 4)
                        } else if notificationManager.authorizationStatus == .notDetermined {
                            Button("Enable Notifications…") {
                                Task {
                                    _ = await notificationManager.requestAuthorization()
                                    await notificationManager.reconcileAll(in: modelContext)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }

    private var permissionColor: Color {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .blue
        @unknown default:
            return .secondary
        }
    }

    private var permissionIcon: String {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional:
            return "bell.badge.fill"
        case .denied:
            return "bell.slash.fill"
        case .notDetermined:
            return "bell.fill"
        @unknown default:
            return "bell"
        }
    }

    private var permissionBadgeTitle: String {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional:
            return "Allowed"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Configured"
        @unknown default:
            return "Unknown"
        }
    }

    private var permissionDescription: String {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional:
            return "Birthdates is authorized to show birthday alerts and sounds on your Mac."
        case .denied:
            return "Permission was denied. To receive reminders, you must grant permission in macOS System Settings."
        case .notDetermined:
            return "Allow Birthdates to alert you of upcoming birthdays so you never miss a friend's milestone."
        @unknown default:
            return "Check notification settings in System Settings."
        }
    }

    // MARK: - Subviews: Default Reminder Rules
    private var notificationPreferencesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("Default Notification Rules")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Toggle(isOn: $preferences.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Birthday Reminders")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text("Schedule offline local alerts for friends who have reminders enabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .onChange(of: preferences.isEnabled) { _, _ in
                    persistPreferencesAndSync()
                }

                if preferences.isEnabled {
                    Divider()

                    // Delivery Time
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delivery Time")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)

                            Text("Time of day reminder notifications will be delivered.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        DatePicker(
                            "",
                            selection: $deliveryDate,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                        .onChange(of: deliveryDate) { _, newDate in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                            preferences.notificationHour = comps.hour ?? 9
                            preferences.notificationMinute = comps.minute ?? 0
                            persistPreferencesAndSync()
                        }
                    }

                    Divider()

                    // Default Lead Times
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                        Text("Default Lead Times")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text("Select which advance alerts new friends receive by default:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(availableLeadTimes, id: \.days) { item in
                                Toggle(isOn: Binding(
                                    get: { selectedLeadTimes.contains(item.days) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedLeadTimes.insert(item.days)
                                        } else {
                                            selectedLeadTimes.remove(item.days)
                                        }
                                        preferences.leadTimeDays = Array(selectedLeadTimes).sorted()
                                        persistPreferencesAndSync()
                                    }
                                )) {
                                    Text(item.label)
                                        .font(.subheadline)
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews: System Limits & Rolling Window
    private var notificationSystemLimitCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rolling Scheduling Window & macOS Limits")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("macOS caps pending notifications at 64 requests per application.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(notificationManager.pendingRequestsCount) / \(NotificationManager.maxPendingNotifications)")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.primary)

                        Text("Scheduled")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("• The nearest upcoming eligible birthdays are always scheduled first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("• Offline Limit Notice: While macOS delivers queued notifications reliably when the app is closed, new notifications cannot be scheduled while completely terminated. Launching Birthdates automatically refreshes and extends the rolling 64-notification window.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if let lastSync = notificationManager.lastReconciledAt {
                        Text("Last synced: \(lastSync.formatted(date: .omitted, time: .standard))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        Task {
                            await notificationManager.reconcileAll(in: modelContext)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if notificationManager.isReconciling {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("Sync Reminders Now")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(notificationManager.isReconciling)
                }
            }
        }
    }

    // MARK: - Subviews: Celebration Display Preferences
    private var displayPreferencesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("Celebration Display")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Toggle(isOn: $showTurningAge) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Display Turning Age")
                            .font(.body)
                            .foregroundStyle(.primary)

                        Text("Shows the age your friend will be turning on their next birthday.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)

                Divider()

                Toggle(isOn: $showZodiacSigns) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Display Zodiac Signs")
                            .font(.body)
                            .foregroundStyle(.primary)

                        Text("Shows Western zodiac constellations alongside birthday dates.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    // MARK: - Subviews: Privacy & Storage
    private var storageCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack(spacing: AppTheme.Spacing.small) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Offline-First Privacy Guarantee")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("All birthday dates, names, notes, and circles are strictly kept on your Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                HStack(spacing: AppTheme.Spacing.xxLarge) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stored Friends")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(friends.count)")
                            .font(.title3.bold().monospacedDigit())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stored Categories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(categories.count)")
                            .font(.title3.bold().monospacedDigit())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Storage Engine")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("SwiftData Local")
                            .font(.body.weight(.medium))
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private func persistPreferencesAndSync() {
        preferences.save()
        Task {
            await notificationManager.reconcileAll(in: modelContext)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(SampleData.createSampleContainer())
}
