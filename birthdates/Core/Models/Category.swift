//
//  Category.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation
import SwiftData

/// Represents an offline category or circle for friends.
/// Explicitly configured so deleting a category nullifies relationships and never deletes friends.
@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "folder"
    var colorHex: String = "#0A84FF"
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify)
    var friends: [Friend]? = []

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "folder",
        colorHex: String = "#0A84FF",
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.friends = []
    }
}
