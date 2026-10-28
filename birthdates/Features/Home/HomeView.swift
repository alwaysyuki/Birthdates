//
//  HomeView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import SwiftData

/// Configurable date range options for upcoming birthday forecasting.
enum UpcomingRangeOption: Int, CaseIterable, Identifiable {
    case next7Days = 7
    case next14Days = 14
    case next30Days = 30
    case next60Days = 60
    case next90Days = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .next7Days: return "7 Days"
        case .next14Days: return "14 Days"
        case .next30Days: return "30 Days"
        case .next60Days: return "60 Days"
        case .next90Days: return "90 Days"
        }
    }
}

/// Comprehensive Home Dashboard showcasing today's celebrations, a hero spotlight
/// on the next birthday, configurable forecasting, metric cards, and instant profile navigation.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // SwiftData queries
    @Query private var friends: [Friend]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // Optional navigation coordinator
    var onNavigateToSection: ((NavigationSection) -> Void)? = nil

    // State
    @State private var selectedRange: UpcomingRangeOption = .next30Days
    @State private var friendToEdit: Friend? = nil

    private let calendar = Calendar.current
    private let calculator = BirthdayCalculator.shared

    // MARK: - Computed Properties
    private var activeFriends: [Friend] {
        friends.filter { !$0.isArchived }
    }

    private var activeFriendsWithBirthday: [Friend] {
        activeFriends.filter { $0.hasBirthday }
    }

    private var currentMonth: Int {
        calendar.component(.month, from: Date())
    }

    /// Friends celebrating birthdays today at calendar-day granularity
    private var todayFriends: [Friend] {
        let now = Date()
        return activeFriendsWithBirthday.filter { friend in
            calculator.isBirthdayToday(for: friend, relativeTo: now)
        }
    }

    /// Sorted list of all upcoming birthdays with calculated days remaining
    private var allUpcoming: [(friend: Friend, days: Int, nextDate: Date)] {
        let now = Date()
        return activeFriendsWithBirthday.compactMap { friend -> (Friend, Int, Date)? in
            guard let next = calculator.nextBirthday(for: friend, relativeTo: now),
                  let days = calculator.daysRemaining(for: friend, relativeTo: now) else {
                return nil
            }
            return (friend, days, next)
        }
        .sorted { a, b in
            if a.days == b.days {
                return a.friend.firstName.localizedCaseInsensitiveCompare(b.friend.firstName) == .orderedAscending
            }
            return a.days < b.days
        }
    }

    /// The single next closest birthday across the active directory
    private var nextBirthdayHero: (friend: Friend, days: Int, nextDate: Date)? {
        allUpcoming.first
    }

    /// Upcoming birthdays filtered to the user-selected date range
    private var upcomingInSelectedRange: [(friend: Friend, days: Int, nextDate: Date)] {
        allUpcoming.filter { $0.days <= selectedRange.rawValue }
    }

    /// Friends whose birthday falls within the current calendar month
    private var birthdaysThisMonthCount: Int {
        activeFriendsWithBirthday.filter { $0.birthMonth == currentMonth }.count
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xLarge) {
                // Header Banner
                headerSection

                // Metrics Grid
                metricsSection

                // Today's Birthdays Celebration Banner (if any)
                if !todayFriends.isEmpty {
                    todayCelebrationsSection
                }

                // Next Birthday Hero Card
                if let hero = nextBirthdayHero {
                    heroCardSection(hero: hero)
                }

                // Upcoming Celebrations Section with Range Selector
                upcomingForecastSection
            }
            .padding(AppTheme.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Home")
        .sheet(item: $friendToEdit) { friend in
            FriendEditorSheet(friendToEdit: friend)
        }
    }

    // MARK: - Subviews: Header
    private var headerSection: some View {
        GlassCard(padding: AppTheme.Spacing.large) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                    Text("Welcome to Birthdates")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Your offline-first personal birthday and friend celebration assistant.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !todayFriends.isEmpty {
                    StatusPillView(
                        title: "\(todayFriends.count) Birthday\(todayFriends.count == 1 ? "" : "s") Today! 🎉",
                        iconName: "party.popper.fill",
                        tintColor: .pink
                    )
                }
            }
        }
    }

    // MARK: - Subviews: Metrics Grid
    private var metricsSection: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: AppTheme.Spacing.medium)],
            spacing: AppTheme.Spacing.medium
        ) {
            MetricStatCardView(
                title: "Total Active Friends",
                value: "\(activeFriends.count)",
                subtitle: activeFriends.isEmpty ? "Add your first friend" : "In offline circle",
                iconName: "person.2.fill",
                tintColor: .blue,
                action: {
                    onNavigateToSection?(.friends)
                }
            )

            MetricStatCardView(
                title: "Birthdays Today",
                value: "\(todayFriends.count)",
                subtitle: todayFriends.isEmpty ? "None today" : "Ready to celebrate!",
                iconName: "party.popper.fill",
                tintColor: .pink
            )

            MetricStatCardView(
                title: "This Month",
                value: "\(birthdaysThisMonthCount)",
                subtitle: "\(calendar.monthSymbols[currentMonth - 1]) birthdays",
                iconName: "calendar.badge.clock",
                tintColor: .orange,
                action: {
                    onNavigateToSection?(.calendar)
                }
            )

            MetricStatCardView(
                title: "Categories",
                value: "\(categories.count)",
                subtitle: "Organized circles",
                iconName: "folder.fill",
                tintColor: .purple,
                action: {
                    onNavigateToSection?(.categories)
                }
            )
        }
    }

    // MARK: - Subviews: Today's Celebrations Section
    private var todayCelebrationsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(spacing: AppTheme.Spacing.xSmall) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.pink)
                    .font(.headline)

                Text("Celebrating Today!")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()
            }

            VStack(spacing: AppTheme.Spacing.small) {
                ForEach(todayFriends) { friend in
                    let age = calculator.ageTurning(for: friend)
                    let zodiac = calculator.zodiacSign(for: friend) ?? ""

                    GlassCard(isInteractive: true, tintColor: Color.pink.opacity(0.12)) {
                        HStack(spacing: AppTheme.Spacing.medium) {
                            FriendAvatar(
                                initials: friend.initials,
                                colorHex: friend.avatarColorHex,
                                size: 52,
                                name: friend.fullName,
                                photoData: friend.photoData
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: AppTheme.Spacing.xSmall) {
                                    Text(friend.displayName)
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.primary)

                                    if friend.isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundStyle(.yellow)
                                    }
                                }

                                HStack(spacing: AppTheme.Spacing.xSmall) {
                                    if let age {
                                        Text("Turns \(age) Today! 🎉")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.pink)
                                    } else {
                                        Text("Birthday Today! 🎉")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.pink)
                                    }

                                    if !zodiac.isEmpty {
                                        Text("• \(zodiac)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            Button("View Profile") {
                                friendToEdit = friend
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .tint(.pink)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews: Next Birthday Hero Card
    private func heroCardSection(hero: (friend: Friend, days: Int, nextDate: Date)) -> some View {
        let friend = hero.friend
        let days = hero.days
        let nextDate = hero.nextDate
        let age = calculator.ageTurning(for: friend)
        let zodiac = calculator.zodiacSign(for: friend) ?? ""

        return VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack {
                Label("Next Up", systemImage: "clock.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                StatusPillView(
                    title: days == 0 ? "Today! 🎉" : (days == 1 ? "Tomorrow" : "In \(days) days"),
                    iconName: days == 0 ? "party.popper.fill" : "calendar",
                    tintColor: days == 0 ? .pink : (days <= 7 ? .orange : .accentColor)
                )
            }

            GlassCard(padding: AppTheme.Spacing.large, isInteractive: true) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.large) {
                    FriendAvatar(
                        initials: friend.initials,
                        colorHex: friend.avatarColorHex,
                        size: 68,
                        name: friend.fullName,
                        photoData: friend.photoData
                    )

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                        HStack(spacing: AppTheme.Spacing.xSmall) {
                            Text(friend.fullName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)

                            if let nick = friend.nickname, !nick.isEmpty {
                                Text("(\(nick))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if friend.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }
                        }

                        // Milestone Date, Age, and Zodiac
                        HStack(spacing: AppTheme.Spacing.small) {
                            Text(nextDate.formatted(date: .long, time: .omitted))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            if let age {
                                Text("• Turning \(age)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }

                            if !zodiac.isEmpty {
                                Text("• \(zodiac)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Categories
                        if !friend.categories.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(friend.categories.prefix(3)) { cat in
                                    CategoryChip(
                                        title: cat.name,
                                        color: Color(hex: cat.colorHex) ?? .accentColor,
                                        iconName: cat.iconName,
                                        isSelected: false
                                    )
                                }
                            }
                            .padding(.top, 4)
                        }

                        // Notes Preview
                        if let notes = friend.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .padding(.top, 4)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Button("View Profile") {
                            friendToEdit = friend
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
            }
        }
    }

    // MARK: - Subviews: Upcoming Forecast Section
    private var upcomingForecastSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack(alignment: .center) {
                Text("Upcoming Celebrations")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                // Range Filter Pills: Generous spacing, smooth click, no edge overlap
                HStack(spacing: 2) {
                    ForEach(UpcomingRangeOption.allCases) { option in
                        Button {
                            selectedRange = option
                        } label: {
                            Text(option.title)
                                .font(.caption.weight(selectedRange == option ? .semibold : .regular))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    selectedRange == option
                                        ? AppTheme.Colors.controlBackground
                                        : Color.clear
                                )
                                .foregroundStyle(selectedRange == option ? Color.primary : Color.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(AppTheme.Colors.secondaryFill)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
            }

            if upcomingInSelectedRange.isEmpty {
                GlassCard {
                    EmptyStateView(
                        iconName: "calendar.badge.clock",
                        title: "No Birthdays in the Next \(selectedRange.title)",
                        message: "There are no birthdays scheduled for your friends in this window. Try selecting a broader range or adding more friends."
                    )
                }
            } else {
                GlassCard(padding: AppTheme.Spacing.xSmall) {
                    VStack(spacing: 0) {
                        ForEach(Array(upcomingInSelectedRange.enumerated()), id: \.element.friend.id) { index, item in
                            let friend = item.friend
                            let age = calculator.ageTurning(for: friend)
                            let zodiac = calculator.zodiacSign(for: friend)

                            BirthdayRow(
                                friend: friend,
                                daysRemaining: item.days,
                                nextBirthdayDate: item.nextDate,
                                turningAge: age,
                                zodiacSign: zodiac,
                                showCategories: true,
                                onToggleFavorite: {
                                    try? FriendRepository.shared.toggleFavorite(friend, in: modelContext)
                                },
                                onTap: {
                                    friendToEdit = friend
                                }
                            )

                            if index < upcomingInSelectedRange.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(SampleData.createSampleContainer())
}
