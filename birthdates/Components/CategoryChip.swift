//
//  CategoryChip.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI

/// Reusable category chip/pill supporting display tags and interactive multi-select filtering
/// with liquid-glass accents and accessibility considerations.
struct CategoryChip: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var color: Color = .accentColor
    var iconName: String? = nil
    var count: Int? = nil
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    @State private var isHovered: Bool = false

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    chipContent
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if reduceMotion {
                        isHovered = hovering
                    } else {
                        withAnimation(AppTheme.Motion.subtleHover) {
                            isHovered = hovering
                        }
                    }
                }
            } else {
                chipContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(action != nil ? .isButton : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var accessibilityText: String {
        if let count {
            return "\(title), \(count) friends"
        }
        return title
    }

    private var chipContent: some View {
        HStack(spacing: AppTheme.Spacing.xxSmall + 2) {
            // Indicator Icon or Color Dot
            if let iconName {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconAndTextColor)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }

            // Category Title
            Text(title)
                .font(.caption.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(iconAndTextColor)

            // Optional Count Badge
            if let count {
                Text("\(count)")
                    .font(.caption2.monospacedDigit().weight(isSelected ? .bold : .medium))
                    .foregroundStyle(iconAndTextColor.opacity(0.8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(isSelected ? color.opacity(0.2) : AppTheme.Colors.secondaryFill)
                    )
            }
        }
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.xxSmall + 1)
        .background(chipBackground)
        .overlay(chipBorder)
        .clipShape(Capsule())
    }

    private var iconAndTextColor: Color {
        if isSelected {
            return color
        }
        return .primary
    }

    @ViewBuilder
    private var chipBackground: some View {
        if reduceTransparency {
            if isSelected {
                color.opacity(0.2)
            } else {
                AppTheme.Colors.controlBackground
            }
        } else {
            ZStack {
                if isSelected {
                    color.opacity(colorScheme == .dark ? 0.22 : 0.14)
                } else {
                    AppTheme.Colors.secondaryFill
                }

                if isHovered && action != nil {
                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2)
                }
            }
        }
    }

    private var chipBorder: some View {
        Group {
            if isSelected {
                Capsule()
                    .strokeBorder(color.opacity(0.45), lineWidth: 1)
            } else {
                Capsule()
                    .strokeBorder(AppTheme.Colors.separator.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

#Preview {
    HStack(spacing: AppTheme.Spacing.small) {
        CategoryChip(
            title: "All",
            color: .accentColor,
            count: 12,
            isSelected: true,
            action: {}
        )

        CategoryChip(
            title: "Family",
            color: .pink,
            iconName: "heart.fill",
            count: 4,
            isSelected: false,
            action: {}
        )

        CategoryChip(
            title: "Colleagues",
            color: .blue,
            isSelected: false
        )
    }
    .padding(AppTheme.Spacing.large)
}
