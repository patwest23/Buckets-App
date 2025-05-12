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

struct ItemModel: Codable, Identifiable, Hashable {
    
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
    var imageUrl1: String?
    var imageUrl2: String?
    var imageUrl3: String?
    
    // MARK: - Embedded Post Metadata
    var likeCount: Int? = nil
    var caption: String? = nil

    // MARK: - Post Status Flags
    var hasPostedAddEvent: Bool = false
    var hasPostedCompletion: Bool = false
    var hasPostedPhotos: Bool = false

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
        imageUrl1: String? = nil,
        imageUrl2: String? = nil,
        imageUrl3: String? = nil,
        likeCount: Int? = nil,
        caption: String? = nil,
        hasPostedAddEvent: Bool = false,
        hasPostedCompletion: Bool = false,
        hasPostedPhotos: Bool = false
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
        self.imageUrl1 = imageUrl1
        self.imageUrl2 = imageUrl2
        self.imageUrl3 = imageUrl3
        self.likeCount = likeCount
        self.caption = caption
        self.hasPostedAddEvent = hasPostedAddEvent
        self.hasPostedCompletion = hasPostedCompletion
        self.hasPostedPhotos = hasPostedPhotos
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
    
    var allImageUrls: [String] {
        [imageUrl1, imageUrl2, imageUrl3].compactMap { $0 }
    }
}
