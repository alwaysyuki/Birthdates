//
//  CategoryRepository.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation
import SwiftData

/// Protocol defining operations on friend categories with explicit friend safety guarantees.
protocol CategoryRepositoryProtocol: Sendable {
    func createCategory(
        name: String,
        iconName: String,
        colorHex: String,
        sortOrder: Int,
        in context: ModelContext
    ) throws -> Category

    func updateCategory(_ category: Category, in context: ModelContext) throws
    func deleteCategory(_ category: Category, in context: ModelContext) throws
}

/// Persistent repository managing offline categories.
final class CategoryRepository: CategoryRepositoryProtocol {
    static let shared = CategoryRepository()

    init() {}

    /// Creates and persists a new category.
    @discardableResult
    func createCategory(
        name: String,
        iconName: String = "folder",
        colorHex: String = "#0A84FF",
        sortOrder: Int = 0,
        in context: ModelContext
    ) throws -> Category {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw DataError.validationFailed("Category name cannot be empty.")
        }

        let category = Category(
            name: trimmedName,
            iconName: iconName,
            colorHex: colorHex,
            sortOrder: sortOrder
        )
        context.insert(category)
        try save(context: context)
        return category
    }

    /// Persists updates to an existing category.
    func updateCategory(_ category: Category, in context: ModelContext) throws {
        let trimmedName = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw DataError.validationFailed("Category name cannot be empty.")
        }
        category.name = trimmedName
        category.updatedAt = Date()
        try save(context: context)
    }

    /// Deletes a category with the explicit rule that no associated friends are ever deleted.
    func deleteCategory(_ category: Category, in context: ModelContext) throws {
        // Disassociate all friends cleanly
        if let associatedFriends = category.friends {
            for friend in associatedFriends {
                friend.categories.removeAll(where: { $0.id == category.id })
                friend.updatedAt = Date()
            }
        }
        category.friends?.removeAll()

        // Delete the category entity only
        context.delete(category)
        try save(context: context)
    }

    private func save(context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            throw DataError.saveFailed(error.localizedDescription)
        }
    }
}
