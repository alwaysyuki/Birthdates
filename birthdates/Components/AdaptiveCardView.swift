//
//  AdaptiveCardView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI

/// Adaptive macOS card container backed by the liquid-glass design system.
struct AdaptiveCardView<Content: View>: View {
    var padding: CGFloat = AppTheme.Spacing.medium
    var cornerRadius: CGFloat = AppTheme.CornerRadius.medium
    var isInteractive: Bool = false
    var tintColor: Color? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassCard(
            padding: padding,
            cornerRadius: cornerRadius,
            isInteractive: isInteractive,
            tintColor: tintColor,
            content: content
        )
    }
}
