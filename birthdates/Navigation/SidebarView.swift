//
//  SidebarView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import SwiftData

/// Native macOS sidebar rendering navigation sections with dynamic count badges,
/// SF Symbols, and quick settings access at the bottom left.
struct SidebarView: View {
    @Binding var selectedSection: NavigationSection?
    @Query private var friends: [Friend]
    @Query private var categories: [Category]

    private let calculationService = BirthdayCalculationService()

    private var activeFriends: [Friend] {
        friends.filter { !$0.isArchived }
    }

    private var upcomingSoonCount: Int {
        let now = Date()
        return activeFriends.filter { friend in
            calculationService.daysRemaining(for: friend.birthdate, relativeTo: now) <= 30
        }.count
    }

    var body: some View {
        List(selection: $selectedSection) {
            Section("Overview") {
                Label(NavigationSection.home.title, systemImage: NavigationSection.home.iconName)
                    .tag(NavigationSection.home)

                HStack {
                    Label(NavigationSection.friends.title, systemImage: NavigationSection.friends.iconName)
                    Spacer()
                    if !activeFriends.isEmpty {
                        sidebarBadge(text: "\(activeFriends.count)")
                    }
                }
                .tag(NavigationSection.friends)

                HStack {
                    Label(NavigationSection.calendar.title, systemImage: NavigationSection.calendar.iconName)
                    Spacer()
                    if upcomingSoonCount > 0 {
                        sidebarBadge(text: "\(upcomingSoonCount)", highlight: true)
                    }
                }
                .tag(NavigationSection.calendar)
            }

            Section("Organize") {
                HStack {
                    Label(NavigationSection.categories.title, systemImage: NavigationSection.categories.iconName)
                    Spacer()
                    if !categories.isEmpty {
                        sidebarBadge(text: "\(categories.count)")
                    }
                }
                .tag(NavigationSection.categories)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Birthdates")
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }

    // MARK: - Subviews
    private func sidebarBadge(text: String, highlight: Bool = false) -> some View {
        Text(text)
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(highlight ? Color.white : Color.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(highlight ? Color.accentColor : AppTheme.Colors.secondaryFill)
            )
    }

    private var sidebarFooter: some View {
        HStack {
            Button {
                selectedSection = .settings
            } label: {
                HStack(spacing: AppTheme.Spacing.xSmall) {
                    Image(systemName: selectedSection == .settings ? "gearshape.fill" : "gearshape")
                        .font(.body)
                    Text("Settings")
                        .font(.body)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous)
                        .fill(selectedSection == .settings ? AppTheme.Colors.accentSoft : Color.clear)
                )
                .foregroundStyle(selectedSection == .settings ? Color.accentColor : Color.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings (⌘5)")

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.xSmall)
        .background(.regularMaterial)
    }
}

#Preview {
    SidebarView(selectedSection: .constant(.home))
        .modelContainer(SampleData.createSampleContainer())
}
