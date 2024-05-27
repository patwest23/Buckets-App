//
//  ItemModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//


import Foundation
import SwiftUI

enum Priority: String, Codable {
    case none
    case low
    case medium
    case high
}

struct Tag: Codable {
    var title: String
}

struct Location: Codable {
    // Define properties of Location as needed
}

struct ItemModel: Codable, Identifiable {
    var id: UUID? // Changed to optional to match Reminder's docId
    var name: String
    var description: String?
    var url: String?
    var dueDate: Date?
    var hasDueTime: Bool = false
    var tags: [Tag]?
    var location: Location?
    var flagged: Bool = false
    var priority: Priority = .none
    var completed: Bool = false
    var order: Int = 0
    var userId: String? // Not present in Reminder, added for consistency
    var creationDate: Date? // Add creationDate property
    var imageData: Data? // Add imageData property

    // Initialize with a name and optional description
    init(name: String, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.creationDate = Date() // Set the creation date to the current date when initializing
    }
}









