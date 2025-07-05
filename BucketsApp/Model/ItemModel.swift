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
    var address: String?
}

@dynamicMemberLookup
struct ItemModel: Codable, Identifiable, Hashable {
    @DocumentID var documentId: String?
    // MARK: - Primary Fields
    var id: UUID
    var userId: String
    var name: String
    var description: String?
    var url: String?
    var dueDate: Date?
    var hasDueTime: Bool
    var tags: [Tag]?
    var location: Location?
    var flagged: Bool
    var priority: Priority
    var completed: Bool
    var orderIndex: Int
    var creationDate: Date
    var imageUrls: [String] = []
    var likedBy: [String] = []
    
    // MARK: - Embedded Post Metadata
    var caption: String? = nil

    // MARK: - Post Status Flags
    var hasPostedAddEvent: Bool = false
    var hasPostedCompletion: Bool = false
    var hasPostedPhotos: Bool = false

    // MARK: - Post Linkage
    var postId: String? = nil
    var wasShared: Bool = false

    // MARK: - Initializer
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
        likedBy: [String] = [],
        caption: String? = nil,
        hasPostedAddEvent: Bool = false,
        hasPostedCompletion: Bool = false,
        hasPostedPhotos: Bool = false,
        postId: String? = nil,
        wasShared: Bool = false
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
        self.likedBy = likedBy
        self.caption = caption
        self.hasPostedAddEvent = hasPostedAddEvent
        self.hasPostedCompletion = hasPostedCompletion
        self.hasPostedPhotos = hasPostedPhotos
        self.postId = postId
        self.wasShared = wasShared
    }

    // MARK: - Custom Decoding to support legacy imageUrl fields
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
        case likedBy
        case caption
        case hasPostedAddEvent
        case hasPostedCompletion
        case hasPostedPhotos
        case postId
        case wasShared
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        hasDueTime = try container.decode(Bool.self, forKey: .hasDueTime)
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags)
        location = try container.decodeIfPresent(Location.self, forKey: .location)
        flagged = try container.decode(Bool.self, forKey: .flagged)
        priority = try container.decode(Priority.self, forKey: .priority)
        completed = try container.decode(Bool.self, forKey: .completed)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        creationDate = try container.decode(Date.self, forKey: .creationDate)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        hasPostedAddEvent = try container.decode(Bool.self, forKey: .hasPostedAddEvent)
        hasPostedCompletion = try container.decode(Bool.self, forKey: .hasPostedCompletion)
        hasPostedPhotos = try container.decode(Bool.self, forKey: .hasPostedPhotos)
        postId = try container.decodeIfPresent(String.self, forKey: .postId)
        wasShared = try container.decodeIfPresent(Bool.self, forKey: .wasShared) ?? false
        
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        likedBy = try container.decodeIfPresent([String].self, forKey: .likedBy) ?? []
    }

    // MARK: - Computed Properties
    var isValidUrl: Bool {
        guard let urlString = url, let url = URL(string: urlString) else { return false }
        #if canImport(UIKit)
        return UIApplication.shared.canOpenURL(url)
        #else
        return true
        #endif
    }

    var firebaseDueDate: Date? {
        dueDate
    }
    

    var wasRecentlyLiked: Bool {
        !likedBy.isEmpty
    }

    var likeCount: Int {
        return likedBy.count
    }

    var likeCountDisplay: Int {
        return likeCount
    }

    var debugLikeSummary: String {
        return "❤️ \(likeCountDisplay) likes (\(likedBy.count) users)"
    }
    
    // Enable @dynamicMemberLookup for key path access
    subscript<T>(dynamicMember keyPath: KeyPath<ItemModel, T>) -> T {
        return self[keyPath: keyPath]
    }
}
