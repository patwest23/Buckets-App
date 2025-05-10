//
//  PostModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import Foundation
import FirebaseFirestore

enum PostType: String, Codable {
    case added
    case completed
    case photos
}

struct PostModel: Identifiable, Codable {
    
    @DocumentID var id: String? = nil

    // MARK: - Author Info
    var authorId: String
    var authorUsername: String?

    // MARK: - Associated Item
    var itemId: String
    var itemName: String
    var itemCompleted: Bool
    var itemLocation: Location?
    var itemDueDate: Date?
    var itemImageUrls: [String]

    // MARK: - Post Metadata
    var type: PostType
    var timestamp: Date
    var caption: String?
    var taggedUserIds: [String]?
    var visibility: String?
    var likedBy: [String]?

    // MARK: - Initializer
    init(
        id: String? = nil,
        authorId: String,
        authorUsername: String? = nil,
        itemId: String,
        type: PostType,
        timestamp: Date = Date(),
        caption: String? = nil,
        taggedUserIds: [String]? = nil,
        visibility: String? = nil,
        likedBy: [String]? = nil,
        
        itemName: String,
        itemCompleted: Bool,
        itemLocation: Location? = nil,
        itemDueDate: Date? = nil,
        itemImageUrls: [String] = []
    ) {
        self.id = id
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.itemId = itemId
        self.type = type
        self.timestamp = timestamp
        self.caption = caption
        self.taggedUserIds = taggedUserIds
        self.visibility = visibility
        self.likedBy = likedBy

        self.itemName = itemName
        self.itemCompleted = itemCompleted
        self.itemLocation = itemLocation
        self.itemDueDate = itemDueDate
        self.itemImageUrls = itemImageUrls
    }
}

extension PostModel {
    static var mockData: [PostModel] {
        [
            PostModel(
                id: "post_001",
                authorId: "userA",
                authorUsername: "@patrick",
                itemId: "item_101",
                type: .completed,
                timestamp: Date(),
                caption: "My trip to Tokyo was amazing!",
                taggedUserIds: ["userB"],
                likedBy: ["userC", "userD"],
                itemName: "Visit Tokyo",
                itemCompleted: true,
                itemLocation: Location(latitude: 35.6895, longitude: 139.6917, address: "Tokyo, Japan"),
                itemDueDate: Date().addingTimeInterval(-86400),
                itemImageUrls: [
                    "https://picsum.photos/400/400?random=1",
                    "https://picsum.photos/400/400?random=2",
                    "https://picsum.photos/400/400?random=11"
                ]
            ),
            PostModel(
                id: "post_002",
                authorId: "userB",
                authorUsername: "@sam",
                itemId: "item_202",
                type: .completed,
                timestamp: Date().addingTimeInterval(-3600),
                caption: "Finally completed skydiving!",
                taggedUserIds: [],
                likedBy: [],
                itemName: "Skydive",
                itemCompleted: true,
                itemLocation: nil,
                itemDueDate: nil,
                itemImageUrls: [
                    "https://picsum.photos/400/400?random=2"
                ]
            ),
            PostModel(
                id: "post_003",
                authorId: "userC",
                authorUsername: "@emily",
                itemId: "item_303",
                type: .photos,
                timestamp: Date().addingTimeInterval(-7200),
                caption: "Who wants to join me for a marathon?",
                taggedUserIds: ["userA"],
                likedBy: ["userA"],
                itemName: "Run a marathon",
                itemCompleted: false,
                itemLocation: nil,
                itemDueDate: Date().addingTimeInterval(86400 * 30),
                itemImageUrls: [
                    "https://picsum.photos/400/400?random=3"
                ]
            )
        ]
    }
}
