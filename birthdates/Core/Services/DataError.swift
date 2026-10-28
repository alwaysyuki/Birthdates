//
//  DataError.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation

/// Structured errors emitted during persistence, validation, or deletion operations.
enum DataError: LocalizedError, Equatable {
    case validationFailed(String)
    case saveFailed(String)
    case itemNotFound(UUID)
    case relationshipConflict(String)

    var errorDescription: String? {
        switch self {
        case .validationFailed(let reason):
            return "Validation Error: \(reason)"
        case .saveFailed(let reason):
            return "Persistent Save Error: \(reason)"
        case .itemNotFound(let id):
            return "Item not found with identifier \(id.uuidString)."
        case .relationshipConflict(let msg):
            return "Relationship Conflict: \(msg)"
        }
    }
}
