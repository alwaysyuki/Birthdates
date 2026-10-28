//
//  AppTheme.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import AppKit

/// Central design tokens, typography, motion curves, and adaptive liquid-glass styles for macOS.
enum AppTheme {
    // MARK: - Spacing Tokens (8pt Grid)
    enum Spacing {
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
        static let xxxLarge: CGFloat = 40
    }

    // MARK: - Corner Radii
    enum CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
        static let xLarge: CGFloat = 18
        static let circular: CGFloat = 999
    }

    // MARK: - Adaptive System Colors
    enum Colors {
        /// Native macOS window background color
        static var windowBackground: Color {
            Color(nsColor: .windowBackgroundColor)
        }

        /// Native macOS control / surface background
        static var controlBackground: Color {
            Color(nsColor: .controlBackgroundColor)
        }

        /// Subtle card/surface fill adapting to vibrant and solid desktop modes
        static var cardBackground: Color {
            Color(nsColor: .controlColor).opacity(0.35)
        }

        /// Slightly elevated surface background
        static var cardBackgroundElevated: Color {
            Color(nsColor: .controlColor).opacity(0.5)
        }

        /// Border and divider tone
        static var separator: Color {
            Color(nsColor: .separatorColor)
        }

        /// Subtle secondary fill for chips and input backgrounds
        static var secondaryFill: Color {
            Color(nsColor: .quaternaryLabelColor)
        }

        /// Soft accent background for active/selected items
        static var accentSoft: Color {
            Color.accentColor.opacity(0.12)
        }

        /// Category preset color palette for tagging friends
        static let presetColors: [Color] = [
            .pink,
            .purple,
            .indigo,
            .blue,
            .teal,
            .cyan,
            .green,
            .orange,
            .yellow
        ]

        /// Subtle liquid-glass specular border gradient
        static func glassBorderGradient(for colorScheme: ColorScheme) -> LinearGradient {
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.05),
                        Color.black.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [
                        Color.white.opacity(0.75),
                        Color.white.opacity(0.35),
                        Color.black.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    // MARK: - Motion & Animation Tokens
    enum Motion {
        static let quickEase: Animation = .easeInOut(duration: 0.16)
        static let smoothSpring: Animation = .spring(response: 0.28, dampingFraction: 0.78)
        static let subtleHover: Animation = .easeInOut(duration: 0.12)

        /// Returns the animation when reduce motion is disabled, or nil when enabled.
        static func animation(_ anim: Animation, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : anim
        }
    }

    // MARK: - Layout Constants & Breakpoints
    enum Layout {
        static let windowMinWidth: CGFloat = 820
        static let windowMinHeight: CGFloat = 520
        static let windowIdealWidth: CGFloat = 1020
        static let windowIdealHeight: CGFloat = 680

        static let sidebarMinWidth: CGFloat = 200
        static let sidebarIdealWidth: CGFloat = 230
        static let sidebarMaxWidth: CGFloat = 280

        static let compactWindowBreakpoint: CGFloat = 880
        static let wideWindowBreakpoint: CGFloat = 1120
    }
}

// MARK: - Color Hex Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: Double
        if hexSanitized.count == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if hexSanitized.count == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
