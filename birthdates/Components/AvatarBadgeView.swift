//
//  AvatarBadgeView.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import SwiftUI

/// Circular monogram badge bridging to the unified FriendAvatar component.
struct AvatarBadgeView: View {
    let initials: String
    var colorHex: String = "#0A84FF"
    var size: CGFloat = 36

    var body: some View {
        FriendAvatar(
            initials: initials,
            colorHex: colorHex,
            size: size
        )
    }
}

#Preview {
    AvatarBadgeView(initials: "EW", colorHex: "#AF52DE", size: 40)
        .padding()
}
