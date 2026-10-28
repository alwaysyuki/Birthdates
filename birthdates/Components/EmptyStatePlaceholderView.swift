//
//  EmptyStatePlaceholderView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI

/// Reusable macOS-styled placeholder bridging to the EmptyStateView component.
struct EmptyStatePlaceholderView: View {
    let iconName: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        EmptyStateView(
            iconName: iconName,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }
}
