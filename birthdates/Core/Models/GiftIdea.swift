//
//  GiftIdea.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation
import SwiftData

/// Represents a gift idea, wishlist item, or purchased present for a friend.
@Model
final class GiftIdea {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var url: String?
    var price: Double?
    var isPurchased: Bool = false
    var purchasedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify)
    var friend: Friend?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        url: String? = nil,
        price: Double? = nil,
        isPurchased: Bool = false,
        purchasedAt: Date? = nil,
        friend: Friend? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.url = url
        self.price = price
        self.isPurchased = isPurchased
        self.purchasedAt = purchasedAt
        self.friend = friend
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Mark the gift idea as purchased.
    func markPurchased() {
        self.isPurchased = true
        self.purchasedAt = Date()
        self.updatedAt = Date()
    }

    /// Unmark the gift idea as purchased.
    func markUnpurchased() {
        self.isPurchased = false
        self.purchasedAt = nil
        self.updatedAt = Date()
    }
}
