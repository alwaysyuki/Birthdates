//
//  CalendarView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import SwiftData

/// Interactive monthly calendar view with month-to-month navigation, jump-to-today,
/// category filtering, multi-friend birthday indicators, and day-inspection panels.
struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // SwiftData queries
    @Query private var friends: [Friend]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // Navigation and Calendar State
    @State private var displayedDate: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var selectedCategoryId: UUID? = nil
    @State private var friendToEdit: Friend? = nil

    private let calendar = Calendar.current
    private let calculator = BirthdayCalculator.shared

    // MARK: - Computed Calendar Parameters
    private var displayedYear: Int {
        calendar.component(.year, from: displayedDate)
    }

    private var displayedMonth: Int {
        calendar.component(.month, from: displayedDate)
    }

    private var isCurrentMonthDisplayed: Bool {
        let now = Date()
        return calendar.component(.year, from: now) == displayedYear &&
               calendar.component(.month, from: now) == displayedMonth
    }

    /// Active friends with recorded birthdays matching the category filter
    private var eligibleFriends: [Friend] {
        friends.filter { friend in
            guard !friend.isArchived, friend.hasBirthday else { return false }
            if let selectedCategoryId {
                return friend.categories.contains(where: { $0.id == selectedCategoryId })
            }
            return true
        }
    }

    /// Days in the currently displayed month
    private var daysInDisplayedMonth: Int {
        calendar.range(of: .day, in: .month, for: displayedDate)?.count ?? 30
    }

    /// Weekday index (0...6) of the 1st of the displayed month
    private var firstWeekdayOffset: Int {
        var components = calendar.dateComponents([.year, .month], from: displayedDate)
        components.day = 1
        guard let firstDayOfMonth = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    /// Friends whose birthdays occur in the currently displayed month
    private var friendsInDisplayedMonth: [Friend] {
        eligibleFriends.filter { friend in
            guard let resolved = calculator.resolveDate(
                month: friend.birthMonth,
                day: friend.birthDay,
                inYear: displayedYear
            ) else {
                return false
            }
            return calendar.component(.month, from: resolved) == displayedMonth
        }
    }

    /// Friends whose birthdays fall on the currently selected date
    private var friendsOnSelectedDate: [Friend] {
        let selectedDay = calendar.component(.day, from: selectedDate)
        let selectedM = calendar.component(.month, from: selectedDate)
        let selectedY = calendar.component(.year, from: selectedDate)

        return eligibleFriends.filter { friend in
            guard let resolved = calculator.resolveDate(
                month: friend.birthMonth,
                day: friend.birthDay,
                inYear: selectedY
            ) else {
                return false
            }
            return calendar.component(.month, from: resolved) == selectedM &&
                   calendar.component(.day, from: resolved) == selectedDay
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar: Month/Year, Prev/Next, Today, Category Filters
            topControlBar

            Divider()

            // Responsive Layout: Grid on Left, Inspector on Right
            GeometryReader { geometry in
                let isCompact = geometry.size.width < 620

                if isCompact {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                            calendarGridSection
                            Divider()
                            selectedDayDetailsSection
                        }
                        .padding(AppTheme.Spacing.medium)
                    }
                } else {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.large) {
                        // Calendar Grid takes all flexible available width
                        ScrollView {
                            calendarGridSection
                                .padding(.vertical, AppTheme.Spacing.xSmall)
                        }
                        .frame(maxWidth: .infinity)

                        Divider()

                        // Selected Day Details Column
                        ScrollView {
                            selectedDayDetailsSection
                                .padding(.vertical, AppTheme.Spacing.xSmall)
                        }
                        .frame(width: min(300, max(240, geometry.size.width * 0.35)))
                    }
                    .padding(AppTheme.Spacing.large)
                }
            }
        }
        .navigationTitle("Calendar")
        .sheet(item: $friendToEdit) { friend in
            FriendEditorSheet(friendToEdit: friend)
        }
    }

    // MARK: - Subviews: Control Bar
    private var topControlBar: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            HStack {
                // Month & Year Display
                HStack(spacing: AppTheme.Spacing.small) {
                    Text(displayedDate.formatted(.dateTime.month(.wide).year()))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    if isCurrentMonthDisplayed {
                        Text("Current Month")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.accentSoft)
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                // Month Stepper & Today Buttons
                HStack(spacing: AppTheme.Spacing.xSmall) {
                    Button {
                        stepMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Previous Month")

                    Button("Today") {
                        jumpToToday()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Jump to Today")

                    Button {
                        stepMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Next Month")
                }
            }

            // Category Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.xSmall) {
                    CategoryChip(
                        title: "All Circles",
                        color: .accentColor,
                        count: friendsInDisplayedMonth.count,
                        isSelected: selectedCategoryId == nil,
                        action: { selectedCategoryId = nil }
                    )

                    ForEach(categories) { category in
                        let isSelected = selectedCategoryId == category.id
                        let count = friendsInDisplayedMonth.filter {
                            $0.categories.contains(where: { $0.id == category.id })
                        }.count

                        CategoryChip(
                            title: category.name,
                            color: Color(hex: category.colorHex) ?? .accentColor,
                            iconName: category.iconName,
                            count: count,
                            isSelected: isSelected,
                            action: {
                                selectedCategoryId = isSelected ? nil : category.id
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(.regularMaterial)
    }

    // MARK: - Subviews: Calendar Grid
    private var calendarGridSection: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            // Weekday Headers
            let weekdaySymbols = calendar.veryShortWeekdaySymbols
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekdaySymbols[(index + calendar.firstWeekday - 1) % 7])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            // Monthly 7-column Grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 36), spacing: 6), count: 7),
                spacing: 6
            ) {
                // Preceding Month Padding Spacers
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .frame(minHeight: 56)
                }

                // Month Days
                ForEach(1...daysInDisplayedMonth, id: \.self) { day in
                    calendarDayCell(for: day)
                }
            }
        }
    }

    private func calendarDayCell(for day: Int) -> some View {
        var dayComponents = calendar.dateComponents([.year, .month], from: displayedDate)
        dayComponents.day = day
        let cellDate = calendar.date(from: dayComponents) ?? displayedDate

        let isToday = calendar.isDateInToday(cellDate)
        let isSelected = calendar.isDate(cellDate, inSameDayAs: selectedDate)
        let dayFriends = friendsForDay(day)

        return Button {
            selectedDate = cellDate
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                // Day Number Header
                HStack {
                    if isToday {
                        Text("\(day)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.accentColor))
                    } else {
                        Text("\(day)")
                            .font(.caption.weight(isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    }

                    Spacer()

                    if !dayFriends.isEmpty {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8))
                            .foregroundStyle(.pink)
                    }
                }

                Spacer(minLength: 0)

                // Birthday indicators - designed so they NEVER overflow or collide
                if !dayFriends.isEmpty {
                    if dayFriends.count == 1, let friend = dayFriends.first {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color(hex: friend.avatarColorHex) ?? .pink)
                                .frame(width: 6, height: 6)

                            Text(friend.firstName)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: friend.avatarColorHex)?.opacity(0.18) ?? Color.pink.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    } else {
                        // Multiple friends: neat dot cluster + count
                        HStack(spacing: 3) {
                            ForEach(dayFriends.prefix(3)) { friend in
                                Circle()
                                    .fill(Color(hex: friend.avatarColorHex) ?? .pink)
                                    .frame(width: 5, height: 5)
                            }

                            Text("\(dayFriends.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.pink)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.pink.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
            }
            .padding(6)
            .frame(minHeight: 56, maxHeight: 70, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous)
                    .fill(isSelected ? AppTheme.Colors.accentSoft : AppTheme.Colors.secondaryFill.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.5) : Color.clear), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
            .clipped()
        }
        .buttonStyle(.plain)
    }

    private func friendsForDay(_ day: Int) -> [Friend] {
        friendsInDisplayedMonth.filter { friend in
            guard let resolved = calculator.resolveDate(
                month: friend.birthMonth,
                day: friend.birthDay,
                inYear: displayedYear
            ) else {
                return false
            }
            return calendar.component(.day, from: resolved) == day
        }
    }

    // MARK: - Subviews: Selected Day Details
    private var selectedDayDetailsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            // Selected Day Header
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedDate.formatted(date: .complete, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(friendsOnSelectedDate.count) celebration\(friendsOnSelectedDate.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // List of celebrations or empty state
            if friendsOnSelectedDate.isEmpty {
                VStack(spacing: AppTheme.Spacing.small) {
                    Image(systemName: "calendar")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.top, AppTheme.Spacing.large)

                    Text("No Birthdays Today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Select a highlighted date on the calendar to view scheduled celebrations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.small)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AppTheme.Spacing.large)
            } else {
                VStack(spacing: AppTheme.Spacing.small) {
                    ForEach(friendsOnSelectedDate) { friend in
                        let age = calculator.ageTurning(for: friend)
                        let zodiac = calculator.zodiacSign(for: friend)

                        GlassCard(isInteractive: true) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                                HStack(spacing: AppTheme.Spacing.small) {
                                    FriendAvatar(
                                        initials: friend.initials,
                                        colorHex: friend.avatarColorHex,
                                        size: 40,
                                        name: friend.fullName,
                                        photoData: friend.photoData
                                    )

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(friend.displayName)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.primary)

                                            if friend.isFavorite {
                                                Image(systemName: "star.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(.yellow)
                                            }
                                        }

                                        if let age {
                                            Text("Turning \(age)")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.pink)
                                        }

                                        if let zodiac {
                                            Text(zodiac)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()
                                }

                                if !friend.categories.isEmpty {
                                    HStack(spacing: 4) {
                                        ForEach(friend.categories.prefix(2)) { cat in
                                            Text(cat.name)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(hex: cat.colorHex)?.opacity(0.15) ?? AppTheme.Colors.secondaryFill)
                                                .foregroundStyle(Color(hex: cat.colorHex) ?? .primary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }

                                if let notes = friend.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                HStack {
                                    Spacer()
                                    Button("Edit Profile") {
                                        friendToEdit = friend
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions
    private func stepMonth(by delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: displayedDate) {
            if reduceMotion {
                displayedDate = next
            } else {
                withAnimation(AppTheme.Motion.smoothSpring) {
                    displayedDate = next
                }
            }
        }
    }

    private func jumpToToday() {
        let now = Date()
        if reduceMotion {
            displayedDate = now
            selectedDate = now
        } else {
            withAnimation(AppTheme.Motion.smoothSpring) {
                displayedDate = now
                selectedDate = now
            }
        }
    }
}

#Preview {
    CalendarView()
        .modelContainer(SampleData.createSampleContainer())
}
