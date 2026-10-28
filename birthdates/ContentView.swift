//
//  ContentView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import SwiftData

/// Root application shell establishing native macOS navigation, liquid-glass chrome,
/// keyboard shortcuts, and responsive layout boundaries.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedSection: NavigationSection? = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedSection: $selectedSection)
                .navigationSplitViewColumnWidth(
                    min: AppTheme.Layout.sidebarMinWidth,
                    ideal: AppTheme.Layout.sidebarIdealWidth,
                    max: AppTheme.Layout.sidebarMaxWidth
                )
        } detail: {
            detailView(for: selectedSection ?? .home)
        }
        .frame(
            minWidth: AppTheme.Layout.windowMinWidth,
            idealWidth: AppTheme.Layout.windowIdealWidth,
            minHeight: AppTheme.Layout.windowMinHeight,
            idealHeight: AppTheme.Layout.windowIdealHeight
        )
        .background(AppTheme.Colors.windowBackground)
        // Global navigation keyboard shortcuts (Cmd+1 through Cmd+5)
        .background {
            Group {
                Button("") { selectedSection = .home }
                    .keyboardShortcut("1", modifiers: .command)
                Button("") { selectedSection = .friends }
                    .keyboardShortcut("2", modifiers: .command)
                Button("") { selectedSection = .calendar }
                    .keyboardShortcut("3", modifiers: .command)
                Button("") { selectedSection = .categories }
                    .keyboardShortcut("4", modifiers: .command)
                Button("") { selectedSection = .settings }
                    .keyboardShortcut("5", modifiers: .command)
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
        .task {
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
                  ProcessInfo.processInfo.environment["XCInjectBundleInto"] == nil,
                  NSClassFromString("XCTestCase") == nil else { return }
            await NotificationManager.shared.refreshAuthorizationStatus()
            await NotificationManager.shared.reconcileAll(in: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await NotificationManager.shared.refreshAuthorizationStatus()
                    await NotificationManager.shared.reconcileAll(in: modelContext)
                }
            }
        }
    }

    // MARK: - Detail Router
    @ViewBuilder
    private func detailView(for section: NavigationSection) -> some View {
        switch section {
        case .home:
            HomeView { targetSection in
                selectedSection = targetSection
            }
        case .friends:
            FriendsListView()
        case .calendar:
            CalendarView()
        case .categories:
            CategoriesView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.createSampleContainer())
}
