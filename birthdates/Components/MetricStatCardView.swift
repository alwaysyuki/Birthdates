//
//  MetricStatCardView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI

/// Dashboard metric card showcasing key summary statistics with liquid-glass accents.
struct MetricStatCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let title: String
    let value: String
    let subtitle: String?
    let iconName: String
    var tintColor: Color = .accentColor
    var action: (() -> Void)? = nil

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        iconName: String,
        tintColor: Color = .accentColor,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.iconName = iconName
        self.tintColor = tintColor
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)\(subtitle != nil ? ", \(subtitle!)" : "")")
    }

    private var cardContent: some View {
        GlassCard(isInteractive: true, tintColor: tintColor) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(reduceTransparency ? tintColor.opacity(0.2) : tintColor.opacity(0.12))
                        .frame(width: 34, height: 34)

                    Circle()
                        .strokeBorder(
                            tintColor.opacity(colorScheme == .dark ? 0.35 : 0.25),
                            lineWidth: 1
                        )
                        .frame(width: 34, height: 34)

                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tintColor)
                }
            }
        }
    }
}

#Preview {
    HStack {
        MetricStatCardView(
            title: "Total Friends",
            value: "24",
            subtitle: "3 added this week",
            iconName: "person.2.fill",
            tintColor: .blue
        )

        MetricStatCardView(
            title: "Today",
            value: "1",
            subtitle: "Party time!",
            iconName: "gift.fill",
            tintColor: .pink
        )
    }
    .padding()
}
