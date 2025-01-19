//
//  ItemModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//


import Foundation
import SwiftUI
import CoreLocation
import FirebaseFirestore

enum Priority: String, Codable {
    case none, low, medium, high
}

struct Tag: Codable, Hashable {
    var title: String
}

struct Location: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var address: String?
}

struct ItemModel: Codable, Identifiable, Hashable {
    var id: UUID              // Unique identifier
    var userId: String        // Identifier for the user who owns this item
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
    var creationDate: Date
    
    // Now we only store URLs pointing to images in Firebase Storage
    var imageUrls: [String] = []

    init(
        id: UUID = UUID(),
        userId: String,
        name: String = "",
        description: String? = nil,
        url: String? = nil,
        dueDate: Date? = nil,
        hasDueTime: Bool = false,
        tags: [Tag]? = nil,
        location: Location? = nil,
        flagged: Bool = false,
        priority: Priority = .none,
        completed: Bool = false,
        order: Int = 0,
        creationDate: Date = Date(),
        imageUrls: [String] = []
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.description = description
        self.url = url
        self.dueDate = dueDate
        self.hasDueTime = hasDueTime
        self.tags = tags
        self.location = location
        self.flagged = flagged
        self.priority = priority
        self.completed = completed
        self.order = order
        self.creationDate = creationDate
        self.imageUrls = imageUrls
    }

    // MARK: - Computed Properties

    var isValidUrl: Bool {
        guard let url = URL(string: self.url ?? "") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    var firebaseDueDate: Date? {
        // Firestore-friendly due date (nil if not set)
        dueDate
    }
}
















