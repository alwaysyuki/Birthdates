//
//  StatusPillView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI

/// Compact pill/tag used for milestone status, remaining days, or category labels
/// with liquid-glass accents and accessibility support.
struct StatusPillView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var iconName: String?
    var tintColor: Color = .accentColor

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxSmall) {
            if let iconName {
                Image(systemName: iconName)
                    .font(.caption2.weight(.semibold))
            }
            Text(title)
                .font(.caption.monospacedDigit().weight(.medium))
        }
        .padding(.horizontal, AppTheme.Spacing.xSmall + 2)
        .padding(.vertical, AppTheme.Spacing.xxSmall + 1)
        .background(
            Capsule()
                .fill(reduceTransparency ? tintColor.opacity(0.18) : tintColor.opacity(colorScheme == .dark ? 0.20 : 0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(tintColor.opacity(colorScheme == .dark ? 0.35 : 0.25), lineWidth: 0.8)
        )
        .foregroundStyle(tintColor)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack {
        StatusPillView(title: "Today! 🎉", iconName: "party.popper.fill", tintColor: .pink)
        StatusPillView(title: "In 3 days", iconName: "clock.fill", tintColor: .orange)
        StatusPillView(title: "In 32 days", iconName: "calendar", tintColor: .blue)
    }
    .padding()
}
