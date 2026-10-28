//
//  FriendEditorSheet.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

/// Compact sheet for creating and editing friend records with input validation,
/// photo picking, category multi-selection, reminder overrides, and dirty-state tracking.
struct FriendEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Category.sortOrder) private var availableCategories: [Category]

    let friendToEdit: Friend?
    var onSaveSuccess: ((Friend) -> Void)? = nil

    // Form fields
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var nickname: String = ""
    @State private var isFavorite: Bool = false
    @State private var hasBirthday: Bool = true
    @State private var birthMonth: Int = 1
    @State private var birthDay: Int = 1
    @State private var includeBirthYear: Bool = false
    @State private var birthYear: Int = 1995
    @State private var photoData: Data? = nil
    @State private var avatarColorHex: String = "#0A84FF"
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var interests: [String] = []
    @State private var newInterestText: String = ""
    @State private var notes: String = ""
    @State private var isShowingNewCategorySheet: Bool = false

    // Per-friend reminder preferences
    @State private var remindersEnabled: Bool = true
    @State private var useCustomReminders: Bool = false
    @State private var customLeadTimes: Set<Int> = [0, 1, 3]
    @State private var customDeliveryDate: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var customReminderMessage: String = ""

    // Initial values for unsaved changes detection
    @State private var initialSnapshot: FormSnapshot? = nil
    @State private var showDiscardAlert: Bool = false
    @State private var errorMessage: String? = nil

    private let calendar = Calendar.current
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let friendRepo = FriendRepository.shared

    private let availableLeadTimes: [(days: Int, label: String)] = [
        (0, "On birthday (0 days)"),
        (1, "1 day before"),
        (3, "3 days before"),
        (7, "1 week before"),
        (14, "2 weeks before")
    ]

    private struct FormSnapshot: Equatable {
        let firstName: String
        let lastName: String
        let nickname: String
        let isFavorite: Bool
        let hasBirthday: Bool
        let birthMonth: Int
        let birthDay: Int
        let includeBirthYear: Bool
        let birthYear: Int
        let photoData: Data?
        let avatarColorHex: String
        let categoryIDs: Set<UUID>
        let interests: [String]
        let notes: String
        let remindersEnabled: Bool
        let useCustomReminders: Bool
        let customLeadTimes: Set<Int>
        let customHour: Int
        let customMinute: Int
        let customReminderMessage: String
    }

    private var currentSnapshot: FormSnapshot {
        let comps = calendar.dateComponents([.hour, .minute], from: customDeliveryDate)
        return FormSnapshot(
            firstName: firstName,
            lastName: lastName,
            nickname: nickname,
            isFavorite: isFavorite,
            hasBirthday: hasBirthday,
            birthMonth: birthMonth,
            birthDay: birthDay,
            includeBirthYear: includeBirthYear,
            birthYear: birthYear,
            photoData: photoData,
            avatarColorHex: avatarColorHex,
            categoryIDs: selectedCategoryIDs,
            interests: interests,
            notes: notes,
            remindersEnabled: remindersEnabled,
            useCustomReminders: useCustomReminders,
            customLeadTimes: customLeadTimes,
            customHour: comps.hour ?? 9,
            customMinute: comps.minute ?? 0,
            customReminderMessage: customReminderMessage
        )
    }

    private var hasUnsavedChanges: Bool {
        guard let initial = initialSnapshot else { return false }
        return initial != currentSnapshot
    }

    private var isEditing: Bool {
        friendToEdit != nil
    }

    private var maxDaysForSelectedMonth: Int {
        BirthdayValidator.maxDaysInMonth(
            month: birthMonth,
            year: includeBirthYear ? birthYear : nil
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            headerBar

            Divider()

            // Scrollable Form Content
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    // Profile Photo & Monogram Section
                    avatarSection

                    // Name & Basic Info Section
                    nameSection

                    // Birthday & Zodiac Section
                    birthdaySection

                    // Birthday Reminders & Overrides Section
                    remindersSection

                    // Categories Multi-Selection
                    categoriesSection

                    // Interests & Tags Section
                    interestsSection

                    // Personal Notes Section
                    notesSection
                }
                .padding(AppTheme.Spacing.large)
            }

            Divider()

            // Sheet Footer Actions
            footerBar
        }
        .frame(width: 540, height: 640)
        .background(AppTheme.Colors.windowBackground)
        .onAppear(perform: setupInitialValues)
        .alert("Discard Unsaved Changes?", isPresented: $showDiscardAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard Changes", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("You have unsaved changes in this friend's profile. Are you sure you want to discard them?")
        }
        .sheet(isPresented: $isShowingNewCategorySheet) {
            CategoryEditorSheet(categoryToEdit: nil) { newCat in
                selectedCategoryIDs.insert(newCat.id)
            }
        }
    }

    // MARK: - Subviews
    private var headerBar: some View {
        HStack {
            Text(isEditing ? "Edit Friend" : "New Friend")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                isFavorite.toggle()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(isFavorite ? "Unmark Favorite" : "Mark as Favorite")
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.medium)
        .background(.regularMaterial)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .foregroundStyle(.red)

            Spacer()

            Button {
                errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(AppTheme.Spacing.small)
        .background(Color.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
    }

    private var avatarSection: some View {
        GlassCard {
            HStack(spacing: AppTheme.Spacing.large) {
                FriendAvatar(
                    initials: initialsPreview,
                    colorHex: avatarColorHex,
                    size: 64,
                    name: "\(firstName) \(lastName)",
                    photoData: photoData
                )

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                    HStack(spacing: AppTheme.Spacing.xSmall) {
                        Button("Choose Photo…") {
                            selectPhoto()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if photoData != nil {
                            Button("Remove Photo") {
                                photoData = nil
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .foregroundStyle(.red)
                        }
                    }

                    // Avatar Color Swatches
                    HStack(spacing: 6) {
                        ForEach(AppTheme.Colors.presetColors, id: \.description) { color in
                            let hex = hexString(for: color)
                            Circle()
                                .fill(color)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: avatarColorHex == hex ? 2 : 0)
                                )
                                .onTapGesture {
                                    avatarColorHex = hex
                                }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var initialsPreview: String {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)
        if last.isEmpty {
            return first.isEmpty ? "?" : first.uppercased()
        }
        return "\(first)\(last)".uppercased()
    }

    private var nameSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Identity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: AppTheme.Spacing.medium) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("First Name *")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("First Name", text: $firstName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Name")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("Last Name", text: $lastName)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Nickname")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Optional nickname (e.g. Soph, Em)", text: $nickname)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var birthdaySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                HStack {
                    Text("Birthday")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Toggle("Include Birthday", isOn: $hasBirthday)
                        .toggleStyle(.checkbox)
                }

                if hasBirthday {
                    HStack(spacing: AppTheme.Spacing.medium) {
                        // Month Picker
                        Picker("Month", selection: $birthMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(calendar.monthSymbols[month - 1]).tag(month)
                            }
                        }
                        .pickerStyle(.menu)

                        // Day Picker
                        Picker("Day", selection: $birthDay) {
                            ForEach(1...maxDaysForSelectedMonth, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .onChange(of: birthMonth) { _, _ in
                        if birthDay > maxDaysForSelectedMonth {
                            birthDay = maxDaysForSelectedMonth
                        }
                    }

                    Divider()

                    Toggle("Include Birth Year", isOn: $includeBirthYear)
                        .toggleStyle(.checkbox)

                    if includeBirthYear {
                        HStack {
                            Text("Birth Year:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker("Year", selection: $birthYear) {
                                ForEach((1900...currentYear).reversed(), id: \.self) { year in
                                    Text("\(String(year))").tag(year)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 160)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews: Reminders Section
    private var remindersSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                HStack {
                    Text("Reminders")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Toggle("Enable Notifications", isOn: $remindersEnabled)
                        .toggleStyle(.checkbox)
                        .disabled(!hasBirthday)
                }

                if !hasBirthday {
                    Text("Reminders require a birthday date.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else if remindersEnabled {
                    Toggle("Customize schedule for this friend", isOn: $useCustomReminders)
                        .toggleStyle(.checkbox)
                        .font(.caption)

                    if useCustomReminders {
                        Divider()

                        // Delivery Time
                        HStack {
                            Text("Alert Time:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            DatePicker(
                                "",
                                selection: $customDeliveryDate,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                        }

                        // Custom Lead Times
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Advance Alerts:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(availableLeadTimes, id: \.days) { item in
                                    Toggle(isOn: Binding(
                                        get: { customLeadTimes.contains(item.days) },
                                        set: { isChecked in
                                            if isChecked {
                                                customLeadTimes.insert(item.days)
                                            } else {
                                                customLeadTimes.remove(item.days)
                                            }
                                        }
                                    )) {
                                        Text(item.label)
                                            .font(.caption)
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }

                        // Custom Message
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Notification Note:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("e.g. Bring birthday card, buy cake", text: $customReminderMessage)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        Text("Uses global default reminder rules from Settings.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var categoriesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                HStack {
                    Text("Categories")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        isShowingNewCategorySheet = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                            Text("New")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Add new category")
                }

                if availableCategories.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                        Text("No categories created yet.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Button("Create Category") {
                            isShowingNewCategorySheet = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(availableCategories) { category in
                            let isSelected = selectedCategoryIDs.contains(category.id)
                            let categoryColor = Color(hex: category.colorHex) ?? .accentColor

                            CategoryChip(
                                title: category.name,
                                color: categoryColor,
                                iconName: category.iconName,
                                isSelected: isSelected,
                                action: {
                                    if isSelected {
                                        selectedCategoryIDs.remove(category.id)
                                    } else {
                                        selectedCategoryIDs.insert(category.id)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private var interestsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Interests & Tags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Add interest or tag (press Return)", text: $newInterestText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addInterest)

                    Button("Add", action: addInterest)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(newInterestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !interests.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(interests, id: \.self) { interest in
                            HStack(spacing: 4) {
                                Text(interest)
                                    .font(.caption)

                                Button {
                                    interests.removeAll(where: { $0 == interest })
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.Colors.secondaryFill)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private var notesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Personal Notes & Gift Preferences")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $notes)
                    .font(.body)
                    .frame(height: 70)
                    .padding(4)
                    .background(AppTheme.Colors.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                            .stroke(AppTheme.Colors.separator.opacity(0.4), lineWidth: 1)
                    )
            }
        }
    }

    private var footerBar: some View {
        HStack {
            Button("Cancel") {
                handleCancel()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button(isEditing ? "Save Changes" : "Add Friend") {
                saveFriend()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.medium)
        .background(.regularMaterial)
    }

    // MARK: - Actions & Persistence
    private func setupInitialValues() {
        if let friend = friendToEdit {
            firstName = friend.firstName
            lastName = friend.lastName
            nickname = friend.nickname ?? ""
            isFavorite = friend.isFavorite
            hasBirthday = friend.hasBirthday
            birthMonth = friend.birthMonth
            birthDay = friend.birthDay
            includeBirthYear = friend.birthYear != nil
            birthYear = friend.birthYear ?? 1995
            photoData = friend.photoData
            avatarColorHex = friend.avatarColorHex
            selectedCategoryIDs = Set(friend.categories.map(\.id))
            interests = friend.tags
            notes = friend.notes ?? ""

            if let reminders = friend.reminderSettings {
                remindersEnabled = reminders.isEnabled
                useCustomReminders = true
                customLeadTimes = Set(reminders.leadTimeDays)
                var comps = calendar.dateComponents([.year, .month, .day], from: Date())
                comps.hour = reminders.notificationHour
                comps.minute = reminders.notificationMinute
                customDeliveryDate = calendar.date(from: comps) ?? Date()
                customReminderMessage = reminders.customMessage ?? ""
            } else {
                let defaultPrefs = NotificationPreferences.load()
                remindersEnabled = defaultPrefs.isEnabled
                useCustomReminders = false
                customLeadTimes = Set(defaultPrefs.leadTimeDays)
            }
        } else {
            // Default new friend
            let now = Date()
            birthMonth = calendar.component(.month, from: now)
            birthDay = calendar.component(.day, from: now)
            birthYear = calendar.component(.year, from: now) - 25
            includeBirthYear = false
            hasBirthday = true

            let defaultPrefs = NotificationPreferences.load()
            remindersEnabled = defaultPrefs.isEnabled
            useCustomReminders = false
            customLeadTimes = Set(defaultPrefs.leadTimeDays)
        }

        initialSnapshot = currentSnapshot
    }

    private func handleCancel() {
        if hasUnsavedChanges {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func addInterest() {
        let trimmed = newInterestText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !interests.contains(trimmed) {
            interests.append(trimmed)
        }
        newInterestText = ""
    }

    private func selectPhoto() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Select Photo"

        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                photoData = data
            }
        }
    }

    private func saveFriend() {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFirst.isEmpty else {
            errorMessage = "First name is required."
            return
        }

        let yearToSave = (hasBirthday && includeBirthYear) ? birthYear : nil

        // Validate birthday if enabled
        if hasBirthday {
            do {
                try BirthdayValidator.validate(
                    month: birthMonth,
                    day: birthDay,
                    year: yearToSave
                )
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        let chosenCategories = availableCategories.filter { selectedCategoryIDs.contains($0.id) }
        let comps = calendar.dateComponents([.hour, .minute], from: customDeliveryDate)
        let customHour = comps.hour ?? 9
        let customMin = comps.minute ?? 0

        do {
            let friend: Friend
            if let existingFriend = friendToEdit {
                // Update existing record
                existingFriend.firstName = trimmedFirst
                existingFriend.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                existingFriend.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                existingFriend.isFavorite = isFavorite
                existingFriend.hasBirthday = hasBirthday
                existingFriend.birthMonth = birthMonth
                existingFriend.birthDay = birthDay
                existingFriend.birthYear = yearToSave
                existingFriend.isBirthYearKnown = (yearToSave != nil)
                existingFriend.photoData = photoData
                existingFriend.avatarColorHex = avatarColorHex
                existingFriend.tags = interests
                existingFriend.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
                existingFriend.categories = chosenCategories

                // Update reminder settings
                if let reminders = existingFriend.reminderSettings {
                    reminders.isEnabled = remindersEnabled
                    if useCustomReminders {
                        reminders.leadTimeDays = Array(customLeadTimes).sorted()
                        reminders.notificationHour = customHour
                        reminders.notificationMinute = customMin
                        reminders.customMessage = customReminderMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customReminderMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    reminders.updatedAt = Date()
                } else if useCustomReminders || !remindersEnabled {
                    let reminders = ReminderSettings(
                        isEnabled: remindersEnabled,
                        leadTimeDays: Array(customLeadTimes).sorted(),
                        notificationHour: customHour,
                        notificationMinute: customMin,
                        customMessage: customReminderMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customReminderMessage.trimmingCharacters(in: .whitespacesAndNewlines),
                        friend: existingFriend
                    )
                    existingFriend.reminderSettings = reminders
                }

                try friendRepo.updateFriend(existingFriend, in: modelContext)
                friend = existingFriend
            } else {
                // Create new record
                let newFriend = try friendRepo.createFriend(
                    firstName: trimmedFirst,
                    lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                    nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                    birthMonth: birthMonth,
                    birthDay: birthDay,
                    birthYear: yearToSave,
                    hasBirthday: hasBirthday,
                    isFavorite: isFavorite,
                    photoData: photoData,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    avatarColorHex: avatarColorHex,
                    tags: interests,
                    categories: chosenCategories,
                    reminderLeadDays: Array(customLeadTimes).sorted(),
                    in: modelContext
                )

                if let reminders = newFriend.reminderSettings {
                    reminders.isEnabled = remindersEnabled
                    if useCustomReminders {
                        reminders.notificationHour = customHour
                        reminders.notificationMinute = customMin
                        reminders.customMessage = customReminderMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customReminderMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }

                friend = newFriend
            }

            onSaveSuccess?(friend)

            // Reconcile notifications asynchronously
            Task {
                await NotificationManager.shared.reconcileAll(in: modelContext)
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hexString(for color: Color) -> String {
        switch color {
        case .pink: return "#FF2D55"
        case .purple: return "#AF52DE"
        case .indigo: return "#5856D6"
        case .blue: return "#0A84FF"
        case .teal: return "#30B0C7"
        case .cyan: return "#32ADE6"
        case .green: return "#34C759"
        case .orange: return "#FF9500"
        case .yellow: return "#FFCC00"
        default: return "#0A84FF"
        }
    }
}

// MARK: - Flow Layout for Tag Chips
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            maxHeightInRow = max(maxHeightInRow, size.height)
            x += size.width + spacing
        }
        height = y + maxHeightInRow
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            maxHeightInRow = max(maxHeightInRow, size.height)
            x += size.width + spacing
        }
    }
}

#Preview {
    FriendEditorSheet(friendToEdit: nil)
        .modelContainer(SampleData.createSampleContainer())
}
