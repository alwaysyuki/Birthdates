//
//  FriendAvatar.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI
import AppKit

/// Reusable monogram avatar displaying friend initials or custom profile photo with adaptive gradients,
/// specular rim lighting, and accessibility labels.
struct FriendAvatar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let initials: String
    var colorHex: String = "#0A84FF"
    var size: CGFloat = 36
    var name: String? = nil
    var photoData: Data? = nil

    private var avatarColor: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    private var labelText: String {
        if let name, !name.isEmpty {
            return name
        }
        return initials.isEmpty ? "Friend" : initials
    }

    private var profileImage: NSImage? {
        guard let photoData else { return nil }
        return NSImage(data: photoData)
    }

    var body: some View {
        ZStack {
            if let profileImage {
                Image(nsImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Background fill with subtle gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                avatarColor,
                                avatarColor.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Monogram Text
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: max(10, size * 0.40), weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 1, x: 0, y: 1)
            }

            // Restrained Specular Glass Rim
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.35 : 0.60),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(labelText)
    }
}

#Preview {
    HStack(spacing: AppTheme.Spacing.medium) {
        FriendAvatar(initials: "EW", colorHex: "#AF52DE", size: 44, name: "Emma Watson")
        FriendAvatar(initials: "LC", colorHex: "#34C759", size: 36, name: "Liam Chen")
        FriendAvatar(initials: "SM", colorHex: "#FF3B30", size: 28, name: "Sophia Miller")
    }
    .padding(AppTheme.Spacing.large)
}
