//
//  EmptyStateView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI

/// Reusable empty state placeholder with liquid-glass iconography,
/// descriptive copy, and optional action buttons.
struct EmptyStateView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let iconName: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            // Icon in restrained glass circle
            ZStack {
                Circle()
                    .fill(reduceTransparency ? AppTheme.Colors.controlBackground : AppTheme.Colors.secondaryFill)
                    .frame(width: 80, height: 80)

                Circle()
                    .strokeBorder(
                        AppTheme.Colors.glassBorderGradient(for: colorScheme),
                        lineWidth: 1
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: iconName)
                    .font(.system(size: 36, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            // Headline and Description
            VStack(spacing: AppTheme.Spacing.xxSmall + 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            // Action Button
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: AppTheme.Spacing.xxSmall) {
                        if let actionIcon {
                            Image(systemName: actionIcon)
                        }
                        Text(actionTitle)
                    }
                    .padding(.horizontal, AppTheme.Spacing.small)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, AppTheme.Spacing.xxSmall)
            }
        }
        .padding(AppTheme.Spacing.xxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    EmptyStateView(
        iconName: "person.crop.circle.badge.plus",
        title: "No Friends Added",
        message: "Add your friends and family members to begin tracking upcoming birthdays.",
        actionTitle: "Add Friend",
        actionIcon: "plus",
        action: {}
    )
}
