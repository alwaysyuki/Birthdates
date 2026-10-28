//
//  NavigationSection.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI

/// Available primary navigation destinations across the app.
enum NavigationSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case friends
    case calendar
    case categories
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .friends:
            return "Friends"
        case .calendar:
            return "Calendar"
        case .categories:
            return "Categories"
        case .settings:
            return "Settings"
        }
    }

    var iconName: String {
        switch self {
        case .home:
            return "house"
        case .friends:
            return "person.2"
        case .calendar:
            return "calendar"
        case .categories:
            return "folder"
        case .settings:
            return "gearshape"
        }
    }
}
