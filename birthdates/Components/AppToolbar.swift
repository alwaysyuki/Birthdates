//
//  AppToolbar.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI

/// Reusable native macOS toolbar components with keyboard shortcuts and liquid-glass aesthetics.
struct AppToolbar {
    /// Primary add action button with standard Cmd+N shortcut.
    struct AddButton: View {
        var title: String = "Add Friend"
        var systemImage: String = "plus"
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                Label(title, systemImage: systemImage)
            }
            .help("\(title) (⌘N)")
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    /// Sidebar visibility toggle button with standard Cmd+S shortcut.
    struct SidebarToggle: View {
        @Binding var columnVisibility: NavigationSplitViewVisibility

        var body: some View {
            Button {
                withAnimation(AppTheme.Motion.quickEase) {
                    if columnVisibility == .detailOnly {
                        columnVisibility = .all
                    } else {
                        columnVisibility = .detailOnly
                    }
                }
            } label: {
                Label("Toggle Sidebar", systemImage: "sidebar.left")
            }
            .help("Toggle Sidebar (⌘S)")
            .keyboardShortcut("s", modifiers: .command)
        }
    }

    /// Filter menu button supporting single/multi-selection.
    struct FilterMenu<Option: Hashable & Identifiable>: View {
        let title: String
        let options: [Option]
        @Binding var selected: Option?
        let labelForOption: (Option) -> String

        var body: some View {
            Menu {
                Button {
                    selected = nil
                } label: {
                    HStack {
                        Text("All")
                        if selected == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(options) { option in
                    Button {
                        selected = option
                    } label: {
                        HStack {
                            Text(labelForOption(option))
                            if selected?.id == option.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(title, systemImage: "line.3.horizontal.decrease.circle")
            }
            .help(title)
        }
    }
}

// MARK: - Standard Toolbar Modifier
extension View {
    /// Applies consistent native toolbar configuration for macOS detail views.
    func nativeAppToolbar(
        title: String,
        addAction: (() -> Void)? = nil,
        addActionTitle: String = "Add Friend"
    ) -> some View {
        self
            .navigationTitle(title)
            .toolbar {
                if let addAction {
                    ToolbarItem(placement: .primaryAction) {
                        AppToolbar.AddButton(
                            title: addActionTitle,
                            action: addAction
                        )
                    }
                }
            }
    }
}
