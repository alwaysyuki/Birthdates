//
//  Memory.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation
import SwiftData

/// Captures a milestone, past celebration, or shared memory associated with a friend.
@Model
final class Memory {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var date: Date = Date()
    var year: Int?
    var photoData: Data?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify)
    var friend: Friend?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        date: Date = Date(),
        year: Int? = nil,
        photoData: Data? = nil,
        friend: Friend? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.date = date
        self.year = year ?? Calendar.current.component(.year, from: date)
        self.photoData = photoData
        self.friend = friend
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
