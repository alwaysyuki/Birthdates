//
//  BirthdayRow.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI

/// Reusable birthday milestone row displaying friend identity, turning age,
/// zodiac symbols, category associations, and countdown badges.
struct BirthdayRow: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let friend: Friend
    let daysRemaining: Int
    let nextBirthdayDate: Date
    var turningAge: Int? = nil
    var zodiacSign: String? = nil
    var showCategories: Bool = true
    var onToggleFavorite: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    @State private var isHovered: Bool = false

    private var countdownTint: Color {
        guard friend.hasBirthday else { return .secondary }
        if daysRemaining == 0 {
            return .pink
        } else if daysRemaining <= 7 {
            return .orange
        } else {
            return .accentColor
        }
    }

    private var countdownIcon: String {
        guard friend.hasBirthday else { return "calendar.badge.minus" }
        if daysRemaining == 0 {
            return "party.popper.fill"
        } else if daysRemaining <= 7 {
            return "clock.fill"
        } else {
            return "calendar"
        }
    }

    private var countdownTitle: String {
        guard friend.hasBirthday else { return "No Date" }
        switch daysRemaining {
        case 0:
            return "Today! 🎉"
        case 1:
            return "Tomorrow"
        default:
            return "In \(daysRemaining)d"
        }
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            // Main info button (without wrapping the favorite button)
            Button {
                onTap?()
            } label: {
                HStack(spacing: AppTheme.Spacing.medium) {
                    // Friend Avatar
                    FriendAvatar(
                        initials: friend.initials,
                        colorHex: friend.avatarColorHex,
                        size: 38,
                        name: friend.fullName,
                        photoData: friend.photoData
                    )

                    // Name & Birthday Details
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                        // Name & Categories
                        HStack(spacing: AppTheme.Spacing.xSmall) {
                            Text(friend.displayName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)

                            if friend.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }

                            if showCategories {
                                ForEach(friend.categories.prefix(2)) { category in
                                    CategoryChip(
                                        title: category.name,
                                        color: Color(hex: category.colorHex) ?? .accentColor,
                                        isSelected: false
                                    )
                                }
                            }
                        }

                        // Subtitle: Date, Turning Age, Zodiac
                        HStack(spacing: AppTheme.Spacing.xSmall) {
                            if friend.hasBirthday {
                                Text(nextBirthdayDate.formatted(.dateTime.month(.wide).day()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let turningAge {
                                    Text("• Turning \(turningAge)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let zodiacSign {
                                    Text("• \(zodiacSign)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("No birthday recorded")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // Favorite Button (optional on hover)
            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: friend.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(friend.isFavorite ? Color.yellow : Color.secondary)
                        .font(.body)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(friend.isFavorite ? "Unmark Favorite" : "Mark as Favorite")
                .opacity(friend.isFavorite || isHovered ? 1.0 : 0.0)
            }

            // Countdown Pill
            StatusPillView(
                title: countdownTitle,
                iconName: countdownIcon,
                tintColor: countdownTint
            )
        }
        .padding(.vertical, AppTheme.Spacing.xSmall)
        .padding(.horizontal, AppTheme.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                .fill(isHovered ? AppTheme.Colors.secondaryFill.opacity(0.8) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var summary = "\(friend.displayName)"
        if friend.isFavorite {
            summary += ", Favorite"
        }
        if friend.hasBirthday {
            summary += ", birthday on \(nextBirthdayDate.formatted(.dateTime.month().day()))"
            if let turningAge {
                summary += ", turning \(turningAge)"
            }
            if daysRemaining == 0 {
                summary += ", today!"
            } else {
                summary += ", in \(daysRemaining) days"
            }
        } else {
            summary += ", no birthday recorded"
        }
        return summary
    }
}
