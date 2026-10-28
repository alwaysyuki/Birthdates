//
//  AppSchema.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation
import SwiftData

/// Schema Version 1 definitions.
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Friend.self,
            Category.self,
            Memory.self,
            GiftIdea.self,
            ReminderSettings.self
        ]
    }
}

/// SwiftData schema migration plan documenting evolutionary stages.
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // As subsequent schema versions are designed (e.g. V2), lightweight or custom
        // MigrationStages will be appended here.
        []
    }
}
