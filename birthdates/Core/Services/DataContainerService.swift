//
//  DataContainerService.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation
import SwiftData

/// Service managing the local SwiftData model container, schema versioning, and initial database seeding.
final class DataContainerService {
    static let shared = DataContainerService()

    let modelContainer: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema(
            versionedSchema: AppSchemaV1.self
        )

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: [modelConfiguration]
            )
            self.modelContainer = container

            // Seed default categories if freshly launched
            if !inMemory {
                Task { @MainActor in
                    Self.seedDefaultCategoriesIfNeeded(context: container.mainContext)
                }
            }
        } catch {
            fatalError("Could not initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }

    /// Seeds standard offline categories if the database is empty.
    @MainActor
    static func seedDefaultCategoriesIfNeeded(context: ModelContext) {
        var descriptor = FetchDescriptor<Category>()
        descriptor.fetchLimit = 1

        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                let defaults = [
                    Category(name: "Family", iconName: "heart.fill", colorHex: "#FF2D55", sortOrder: 0),
                    Category(name: "Close Friends", iconName: "star.fill", colorHex: "#FF9500", sortOrder: 1),
                    Category(name: "Colleagues", iconName: "briefcase.fill", colorHex: "#007AFF", sortOrder: 2),
                    Category(name: "Acquaintances", iconName: "person.2.fill", colorHex: "#5856D6", sortOrder: 3)
                ]
                for category in defaults {
                    context.insert(category)
                }
                try? context.save()
            }
        } catch {
            // Silently continue if fetch fails during initial run
        }
    }
}
