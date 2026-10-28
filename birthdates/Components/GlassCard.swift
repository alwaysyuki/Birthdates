//
//  GlassCard.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import AppKit

/// A refined macOS card surface with restrained liquid-glass styling,
/// adaptive system materials, and accessibility accommodations.
struct GlassCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var padding: CGFloat = AppTheme.Spacing.medium
    var cornerRadius: CGFloat = AppTheme.CornerRadius.medium
    var isInteractive: Bool = false
    var tintColor: Color? = nil
    var contentAlignment: HorizontalAlignment = .leading
    @ViewBuilder var content: () -> Content

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: contentAlignment, spacing: AppTheme.Spacing.small) {
            content()
        }
        .padding(padding)
        .background(backgroundMaterial)
        .overlay(borderOverlay)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.04),
            radius: isInteractive && isHovered ? 6 : 2,
            x: 0,
            y: isInteractive && isHovered ? 3 : 1
        )
        .onHover { hovering in
            guard isInteractive else { return }
            if reduceMotion {
                isHovered = hovering
            } else {
                withAnimation(AppTheme.Motion.subtleHover) {
                    isHovered = hovering
                }
            }
        }
    }

    // MARK: - Surface Material Layer
    @ViewBuilder
    private var backgroundMaterial: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            shape.fill(AppTheme.Colors.controlBackground)
        } else {
            ZStack {
                // Base native material
                shape.fill(.regularMaterial)

                // Optional subtle tint overlay
                if let tintColor {
                    shape.fill(tintColor.opacity(colorScheme == .dark ? 0.07 : 0.04))
                }

                // Hover sheen when interactive
                if isInteractive && isHovered {
                    shape.fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15))
                }
            }
        }
    }

    // MARK: - Specular Glass Border
    private var borderOverlay: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return Group {
            if reduceTransparency {
                shape.strokeBorder(AppTheme.Colors.separator.opacity(0.6), lineWidth: 1)
            } else {
                shape.strokeBorder(
                    AppTheme.Colors.glassBorderGradient(for: colorScheme),
                    lineWidth: 1
                )
            }
        }
    }
}

#Preview {
    VStack(spacing: AppTheme.Spacing.medium) {
        GlassCard(isInteractive: true) {
            Text("Interactive Glass Card")
                .font(.headline)
            Text("Hover over me to observe the restrained specular reflection.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        GlassCard(tintColor: .pink) {
            Text("Tinted Birthday Card")
                .font(.headline)
            Text("Displays with subtle category tinting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    .padding(AppTheme.Spacing.large)
    .frame(width: 360)
}
