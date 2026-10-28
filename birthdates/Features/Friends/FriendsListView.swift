//
//  FriendsListView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import SwiftData

/// Comprehensive Friends directory supporting List, Grid, and Compact views,
/// deep search, multi-axis sorting, category and favorite filters, archive states,
/// batch selection, and inline editing workflows.
struct FriendsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // SwiftData queries
    @Query private var allFriends: [Friend]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // Navigation & View Mode
    @State private var viewMode: FriendViewMode = .list
    @State private var sortOption: FriendSortOption = .nextBirthday
    @State private var sortAscending: Bool = true
    @State private var searchText: String = ""
    @State private var selectedCategoryId: UUID? = nil
    @State private var filterFavoritesOnly: Bool = false
    @State private var archiveFilter: ArchiveFilterOption = .activeOnly

    // Multi-Selection
    @State private var selectedFriendIDs: Set<UUID> = []

    // Sheets & Dialogs
    @State private var isAddSheetPresented: Bool = false
    @State private var friendToEdit: Friend? = nil
    @State private var friendToDelete: Friend? = nil
    @State private var showBatchDeleteAlert: Bool = false
    @State private var saveErrorMessage: String? = nil

    private let calculator = BirthdayCalculator.shared
    private let friendRepo = FriendRepository.shared

    // MARK: - Enums
    enum FriendViewMode: String, CaseIterable, Identifiable {
        case list = "List"
        case grid = "Grid"
        case compact = "Compact"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            case .compact: return "list.dash"
            }
        }
    }

    enum FriendSortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case nextBirthday = "Next Birthday"
        case createdDate = "Date Added"
        case updatedDate = "Recently Modified"

        var id: String { rawValue }
    }

    enum ArchiveFilterOption: String, CaseIterable, Identifiable {
        case activeOnly = "Active"
        case archivedOnly = "Archived"
        case all = "All"

        var id: String { rawValue }
    }

    // MARK: - Computed Filtered & Sorted Friends
    private var filteredAndSortedFriends: [Friend] {
        let now = Date()

        let filtered = allFriends.filter { friend in
            // Archive filter
            switch archiveFilter {
            case .activeOnly:
                guard !friend.isArchived else { return false }
            case .archivedOnly:
                guard friend.isArchived else { return false }
            case .all:
                break
            }

            // Favorites filter
            if filterFavoritesOnly && !friend.isFavorite {
                return false
            }

            // Category filter
            if let selectedCategoryId {
                guard friend.categories.contains(where: { $0.id == selectedCategoryId }) else {
                    return false
                }
            }

            // Search query (First name, Last name, Nickname, Tags/Interests)
            if !searchText.isEmpty {
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                let nameMatch = friend.fullName.localizedCaseInsensitiveContains(query)
                let nickMatch = friend.nickname?.localizedCaseInsensitiveContains(query) ?? false
                let tagMatch = friend.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                guard nameMatch || nickMatch || tagMatch else { return false }
            }

            return true
        }

        // Sorting
        return filtered.sorted { a, b in
            let comparison: Bool
            switch sortOption {
            case .name:
                comparison = a.firstName.localizedCaseInsensitiveCompare(b.firstName) == .orderedAscending
            case .nextBirthday:
                let daysA = a.hasBirthday ? (calculator.daysRemaining(for: a, relativeTo: now) ?? 99999) : 99999
                let daysB = b.hasBirthday ? (calculator.daysRemaining(for: b, relativeTo: now) ?? 99999) : 99999
                if daysA == daysB {
                    comparison = a.firstName.localizedCaseInsensitiveCompare(b.firstName) == .orderedAscending
                } else {
                    comparison = daysA < daysB
                }
            case .createdDate:
                comparison = a.createdAt > b.createdAt
            case .updatedDate:
                comparison = a.updatedAt > b.updatedAt
            }
            return sortAscending ? comparison : !comparison
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter Bar (Category Chips + Favorite Toggle + Archive State)
            filterAndControlBar

            Divider()

            // Main Content Area (List / Grid / Compact or Empty States)
            ZStack {
                if filteredAndSortedFriends.isEmpty {
                    emptyStateView
                } else {
                    switch viewMode {
                    case .list:
                        listView
                    case .grid:
                        gridView
                    case .compact:
                        compactView
                    }
                }
            }

            // Batch Actions Bar (when items are selected)
            if !selectedFriendIDs.isEmpty {
                Divider()
                batchActionBar
            }
        }
        .navigationTitle("Friends")
        .searchable(text: $searchText, prompt: "Search by name, nickname, or interests")
        .toolbar {
            toolbarItems
        }
        .sheet(isPresented: $isAddSheetPresented) {
            FriendEditorSheet(friendToEdit: nil)
        }
        .sheet(item: $friendToEdit) { friend in
            FriendEditorSheet(friendToEdit: friend)
        }
        .alert("Delete Friend?", isPresented: Binding(
            get: { friendToDelete != nil },
            set: { if !$0 { friendToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { friendToDelete = nil }
            Button("Delete Permanently", role: .destructive) {
                if let friend = friendToDelete {
                    permanentlyDelete(friend)
                }
            }
        } message: {
            if let friend = friendToDelete {
                Text("Are you sure you want to permanently delete \(friend.displayName)? All associated memories, gifts, and notes will be removed permanently.")
            }
        }
        .alert("Delete \(selectedFriendIDs.count) Friends?", isPresented: $showBatchDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Permanently", role: .destructive) {
                deleteSelectedFriends()
            }
        } message: {
            Text("Are you sure you want to permanently delete \(selectedFriendIDs.count) friends? This cannot be undone.")
        }
    }

    // MARK: - Filter & Control Bar
    private var filterAndControlBar: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            // Favorites Quick Toggle
            CategoryChip(
                title: "Favorites",
                color: .yellow,
                iconName: filterFavoritesOnly ? "star.fill" : "star",
                isSelected: filterFavoritesOnly,
                action: {
                    filterFavoritesOnly.toggle()
                }
            )

            // Categories Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.xSmall) {
                    CategoryChip(
                        title: "All",
                        color: .accentColor,
                        count: allFriends.filter { !($0.isArchived && archiveFilter == .activeOnly) }.count,
                        isSelected: selectedCategoryId == nil,
                        action: { selectedCategoryId = nil }
                    )

                    ForEach(categories) { category in
                        let isSelected = selectedCategoryId == category.id
                        let count = allFriends.filter { friend in
                            let matchesArchive = (archiveFilter == .all) || (archiveFilter == .activeOnly && !friend.isArchived) || (archiveFilter == .archivedOnly && friend.isArchived)
                            return matchesArchive && friend.categories.contains(where: { $0.id == category.id })
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

            Spacer()

            // Archive Scope Menu
            Menu {
                Picker("Archive Filter", selection: $archiveFilter) {
                    ForEach(ArchiveFilterOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Label(archiveFilter.rawValue, systemImage: archiveFilter == .activeOnly ? "person.crop.circle" : "archivebox")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(.regularMaterial)
    }

    // MARK: - Views: List View
    private var listView: some View {
        List(selection: $selectedFriendIDs) {
            ForEach(filteredAndSortedFriends) { friend in
                let days = calculator.daysRemaining(for: friend) ?? 0
                let nextDate = calculator.nextBirthday(for: friend) ?? Date()
                let age = calculator.ageTurning(for: friend)
                let zodiac = calculator.zodiacSign(for: friend)

                BirthdayRow(
                    friend: friend,
                    daysRemaining: days,
                    nextBirthdayDate: nextDate,
                    turningAge: age,
                    zodiacSign: zodiac,
                    showCategories: true,
                    onToggleFavorite: {
                        toggleFavorite(friend)
                    },
                    onTap: {
                        friendToEdit = friend
                    }
                )
                .tag(friend.id)
                .contextMenu {
                    friendContextMenu(for: friend)
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Views: Grid View
    private var gridView: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: AppTheme.Spacing.medium)],
                spacing: AppTheme.Spacing.medium
            ) {
                ForEach(filteredAndSortedFriends) { friend in
                    friendGridCard(for: friend)
                        .contextMenu {
                            friendContextMenu(for: friend)
                        }
                }
            }
            .padding(AppTheme.Spacing.large)
        }
    }

    private func friendGridCard(for friend: Friend) -> some View {
        let days = calculator.daysRemaining(for: friend) ?? 0
        let nextDate = calculator.nextBirthday(for: friend) ?? Date()
        let age = calculator.ageTurning(for: friend)
        let zodiac = calculator.zodiacSign(for: friend) ?? ""
        let isSelected = selectedFriendIDs.contains(friend.id)

        return GlassCard(isInteractive: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                // Top: Avatar + Names + Favorite Toggle
                HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                    FriendAvatar(
                        initials: friend.initials,
                        colorHex: friend.avatarColorHex,
                        size: 48,
                        name: friend.fullName,
                        photoData: friend.photoData
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(friend.fullName)
                                .font(.headline)
                                .lineLimit(1)

                            if let nick = friend.nickname, !nick.isEmpty {
                                Text("(\(nick))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if friend.hasBirthday {
                            Text(nextDate.formatted(.dateTime.month(.wide).day()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No birthday recorded")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Button {
                        toggleFavorite(friend)
                    } label: {
                        Image(systemName: friend.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(friend.isFavorite ? Color.yellow : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(friend.isFavorite ? "Unmark Favorite" : "Mark as Favorite")
                }

                // Middle: Turning Age, Zodiac & Countdown Pill
                if friend.hasBirthday {
                    HStack {
                        if let age {
                            Text("Turning \(age)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        Text("• \(zodiac)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        StatusPillView(
                            title: days == 0 ? "Today! 🎉" : (days == 1 ? "Tomorrow" : "In \(days)d"),
                            iconName: days == 0 ? "party.popper.fill" : "calendar",
                            tintColor: days == 0 ? .pink : (days <= 7 ? .orange : .accentColor)
                        )
                    }
                }

                Divider()

                // Bottom: Categories and Quick Actions
                HStack {
                    if !friend.categories.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(friend.categories.prefix(2)) { cat in
                                Text(cat.name)
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: cat.colorHex)?.opacity(0.15) ?? AppTheme.Colors.secondaryFill)
                                    .foregroundStyle(Color(hex: cat.colorHex) ?? .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    Button("Edit") {
                        friendToEdit = friend
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            friendToEdit = friend
        }
    }

    // MARK: - Views: Compact View
    private var compactView: some View {
        List(selection: $selectedFriendIDs) {
            ForEach(filteredAndSortedFriends) { friend in
                let days = calculator.daysRemaining(for: friend) ?? 0
                let nextDate = calculator.nextBirthday(for: friend) ?? Date()

                HStack(spacing: AppTheme.Spacing.small) {
                    FriendAvatar(
                        initials: friend.initials,
                        colorHex: friend.avatarColorHex,
                        size: 24,
                        name: friend.fullName,
                        photoData: friend.photoData
                    )

                    if friend.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }

                    Text(friend.displayName)
                        .font(.body)
                        .lineLimit(1)

                    if !friend.categories.isEmpty {
                        Text(friend.categories.map(\.name).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if friend.hasBirthday {
                        Text(nextDate.formatted(.dateTime.month().day()))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Text(days == 0 ? "Today! 🎉" : "In \(days)d")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(days == 0 ? Color.pink : Color.secondary)
                            .frame(width: 60, alignment: .trailing)
                    } else {
                        Text("No Date")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
                .tag(friend.id)
                .contextMenu {
                    friendContextMenu(for: friend)
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Empty States
    @ViewBuilder
    private var emptyStateView: some View {
        if allFriends.isEmpty {
            EmptyStateView(
                iconName: "person.crop.circle.badge.plus",
                title: "No Friends Added",
                message: "Start building your personal birthday circle entirely offline and private on your Mac.",
                actionTitle: "Add Friend",
                actionIcon: "plus",
                action: { isAddSheetPresented = true }
            )
        } else if archiveFilter == .archivedOnly {
            EmptyStateView(
                iconName: "archivebox",
                title: "No Archived Friends",
                message: "Friends you archive to temporarily silence notifications will appear here."
            )
        } else if filterFavoritesOnly {
            EmptyStateView(
                iconName: "star",
                title: "No Favorite Friends",
                message: "Click the star on any friend card to keep them handy in your Favorites list.",
                actionTitle: "Show All Friends",
                action: { filterFavoritesOnly = false }
            )
        } else {
            EmptyStateView(
                iconName: "magnifyingglass",
                title: "No Matching Friends",
                message: "No friends found matching your search term or category filters.",
                actionTitle: "Clear Filters",
                action: {
                    searchText = ""
                    selectedCategoryId = nil
                    filterFavoritesOnly = false
                }
            )
        }
    }

    // MARK: - Batch Action Bar
    private var batchActionBar: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Text("\(selectedFriendIDs.count) Selected")
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button("Archive Selected") {
                batchArchiveSelected()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Deselect All") {
                selectedFriendIDs.removeAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Delete Permanently") {
                showBatchDeleteAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(.regularMaterial)
    }

    // MARK: - Context Menu
    @ViewBuilder
    private func friendContextMenu(for friend: Friend) -> some View {
        Button {
            friendToEdit = friend
        } label: {
            Label("Edit Profile", systemImage: "pencil")
        }

        Button {
            toggleFavorite(friend)
        } label: {
            Label(friend.isFavorite ? "Unmark Favorite" : "Mark as Favorite", systemImage: friend.isFavorite ? "star.slash" : "star")
        }

        Divider()

        if friend.isArchived {
            Button {
                unarchiveFriend(friend)
            } label: {
                Label("Unarchive Friend", systemImage: "tray.and.arrow.up")
            }
        } else {
            Button {
                archiveFriend(friend)
            } label: {
                Label("Archive Friend", systemImage: "archivebox")
            }
        }

        Divider()

        Button(role: .destructive) {
            friendToDelete = friend
        } label: {
            Label("Delete Permanently…", systemImage: "trash")
        }
    }

    // MARK: - Toolbar Items
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                isAddSheetPresented = true
            } label: {
                Label("Add Friend", systemImage: "plus")
            }
            .help("Add New Friend (⌘N)")
            .keyboardShortcut("n", modifiers: .command)
        }

        ToolbarItem(placement: .automatic) {
            // View Mode Picker
            Picker("View Mode", selection: $viewMode) {
                ForEach(FriendViewMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .help("Switch View Mode")
        }

        ToolbarItem(placement: .automatic) {
            // Sort Menu
            Menu {
                Section("Sort By") {
                    ForEach(FriendSortOption.allCases) { option in
                        Button {
                            if sortOption == option {
                                sortAscending.toggle()
                            } else {
                                sortOption = option
                                sortAscending = true
                            }
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                }
                            }
                        }
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .help("Sort Friends")
        }
    }

    // MARK: - Actions
    private func toggleFavorite(_ friend: Friend) {
        do {
            try friendRepo.toggleFavorite(friend, in: modelContext)
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func archiveFriend(_ friend: Friend) {
        do {
            try friendRepo.archive(friend, in: modelContext)
            Task { await NotificationManager.shared.reconcileAll(in: modelContext) }
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func unarchiveFriend(_ friend: Friend) {
        do {
            try friendRepo.unarchive(friend, in: modelContext)
            Task { await NotificationManager.shared.reconcileAll(in: modelContext) }
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func permanentlyDelete(_ friend: Friend) {
        do {
            selectedFriendIDs.remove(friend.id)
            try friendRepo.deletePermanently(friend, in: modelContext)
            friendToDelete = nil
            Task { await NotificationManager.shared.reconcileAll(in: modelContext) }
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func batchArchiveSelected() {
        let friendsToArchive = allFriends.filter { selectedFriendIDs.contains($0.id) }
        for friend in friendsToArchive {
            try? friendRepo.archive(friend, in: modelContext)
        }
        selectedFriendIDs.removeAll()
        Task { await NotificationManager.shared.reconcileAll(in: modelContext) }
    }

    private func deleteSelectedFriends() {
        let friendsToDelete = allFriends.filter { selectedFriendIDs.contains($0.id) }
        for friend in friendsToDelete {
            try? friendRepo.deletePermanently(friend, in: modelContext)
        }
        selectedFriendIDs.removeAll()
        Task { await NotificationManager.shared.reconcileAll(in: modelContext) }
    }
}

#Preview {
    FriendsListView()
        .modelContainer(SampleData.createSampleContainer())
}
