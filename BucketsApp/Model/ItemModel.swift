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
    case none
    case low
    case medium
    case high
}

struct Tag: Codable, Hashable {
    var title: String
}

struct Location: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var address: String?  // Optional address string if the user picks a place or uses geocoding
}

struct ItemModel: Codable, Identifiable, Hashable {

    // MARK: - Firestore Document ID (Optional)
    // If you want Firestore to manage the document ID automatically, uncomment this line:
    // @DocumentID var firebaseDocID: String?
    //
    // If you're already using your own UUID as the doc ID, you can ignore this property.

    // MARK: - Primary Fields
    var id: UUID            // Unique identifier for this item (also used as the Firestore doc ID, if you prefer).
    var userId: String      // The user who owns this item.
    var name: String        // Title or brief description of the bucket-list item.
    var description: String?
    var url: String?        // Possibly a reference link for more info (e.g., a travel site).
    var dueDate: Date?      // Optional date by which user wants to complete the item.
    var hasDueTime: Bool    // If `true`, the due date includes a specific time of day.
    var tags: [Tag]?        // Arbitrary tags for categorizing or filtering items.
    var location: Location? // Stores lat/long and optional address.
    var flagged: Bool       // If `true`, item is flagged/highlighted.
    var priority: Priority  // Priority level (none, low, medium, high).
    var completed: Bool     // If `true`, item is marked as complete.
    var orderIndex: Int     // Custom order index, useful for manual reordering in a list.
    var creationDate: Date  // When the item was created.

    /// Stores URLs (as strings) that point to images in Firebase Storage or elsewhere on the web.
    var imageUrls: [String]
    /// Stores URLs contributed by collaborators on shared list items.
    var sharedImageUrls: [String]
    /// Usernames (prefixed with "@") that this item has been shared with.
    var sharedWithUsernames: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case name
        case description
        case url
        case dueDate
        case hasDueTime
        case tags
        case location
        case flagged
        case priority
        case completed
        case orderIndex
        case creationDate
        case imageUrls
        case sharedImageUrls
        case sharedWithUsernames
    }

    // MARK: - Initializers

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
        orderIndex: Int = 0,
        creationDate: Date = Date(),
        imageUrls: [String] = [],
        sharedImageUrls: [String] = [],
        sharedWithUsernames: [String] = []
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
        self.orderIndex = orderIndex
        self.creationDate = creationDate
        self.imageUrls = imageUrls
        self.sharedImageUrls = sharedImageUrls
        self.sharedWithUsernames = sharedWithUsernames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        hasDueTime = try container.decodeIfPresent(Bool.self, forKey: .hasDueTime) ?? false
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags)
        location = try container.decodeIfPresent(Location.self, forKey: .location)
        flagged = try container.decodeIfPresent(Bool.self, forKey: .flagged) ?? false
        priority = try container.decodeIfPresent(Priority.self, forKey: .priority) ?? .none
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        orderIndex = try container.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate) ?? Date()
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        sharedImageUrls = try container.decodeIfPresent([String].self, forKey: .sharedImageUrls) ?? []
        sharedWithUsernames = try container.decodeIfPresent([String].self, forKey: .sharedWithUsernames) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(url, forKey: .url)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(hasDueTime, forKey: .hasDueTime)
        try container.encode(tags, forKey: .tags)
        try container.encode(location, forKey: .location)
        try container.encode(flagged, forKey: .flagged)
        try container.encode(priority, forKey: .priority)
        try container.encode(completed, forKey: .completed)
        try container.encode(orderIndex, forKey: .orderIndex)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(imageUrls, forKey: .imageUrls)
        try container.encode(sharedImageUrls, forKey: .sharedImageUrls)
        try container.encode(sharedWithUsernames, forKey: .sharedWithUsernames)
    }

    // MARK: - Computed Properties

    /// Combines the current user's images with any collaborator images, removing duplicates while
    /// preserving order.
    var allImageUrls: [String] {
        var seen = Set<String>()
        var combined: [String] = []

        for url in imageUrls + sharedImageUrls {
            if seen.insert(url).inserted {
                combined.append(url)
            }
        }

        return combined
    }

    /// Returns `true` if `url` is a valid URL scheme that can be opened on this platform.
    var isValidUrl: Bool {
        guard let urlString = url, let url = URL(string: urlString) else { return false }
        #if canImport(UIKit)
        return UIApplication.shared.canOpenURL(url)
        #else
        // For macOS or other platforms, you might simply do:
        return true // Or use another method of validation
        #endif
    }

    /// Firestore-friendly due date (in case you need a custom logic). Currently just returns `dueDate`.
    var firebaseDueDate: Date? {
        dueDate
    }
}
















