//
//  PostModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import Foundation
import FirebaseFirestore

enum PostType: String, Codable, Sendable {
    case added
    case completed
    case photos
}

struct PostModel: Identifiable, Codable, Sendable {
    
    @DocumentID var id: String? = nil

    // MARK: - Author Info
    var authorId: String
    var authorUsername: String?
    var authorProfileImageUrl: String?

    // MARK: - Associated Item
    var itemId: String
    var itemImageUrls: [String]
    var itemName: String?

    // MARK: - Post Metadata
    var type: PostType
    var timestamp: Date
    var caption: String?
    var taggedUserIds: [String]
    var visibility: String?
    var likedBy: [String]

    // MARK: - Initializer
    init(
        id: String? = nil,
        authorId: String,
        authorUsername: String? = nil,
        authorProfileImageUrl: String? = nil,
        itemId: String,
        itemImageUrls: [String] = [],
        itemName: String? = nil,
        type: PostType,
        timestamp: Date = Date(),
        caption: String? = nil,
        taggedUserIds: [String] = [],
        visibility: String? = nil,
        likedBy: [String] = []
    ) {
        self.id = id
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.authorProfileImageUrl = authorProfileImageUrl
        self.itemId = itemId
        self.itemImageUrls = itemImageUrls
        self.itemName = itemName
        self.type = type
        self.timestamp = timestamp
        self.caption = caption
        self.taggedUserIds = taggedUserIds
        self.visibility = visibility
        self.likedBy = likedBy
    }

    var hasImages: Bool {
        !itemImageUrls.isEmpty
    }
}

extension PostModel {
    static var mockData: [PostModel] {
        [
            PostModel(
                id: "post_001",
                authorId: "userA",
                authorUsername: "@patrick",
                authorProfileImageUrl: "https://randomuser.me/api/portraits/men/1.jpg",
                itemId: "item_101",
                itemImageUrls: [
                    "https://picsum.photos/400/400?random=1",
                    "https://picsum.photos/400/400?random=2",
                    "https://picsum.photos/400/400?random=11"
                ],
                itemName: "Tokyo Trip",
                type: .completed,
                timestamp: Date(),
                caption: "My trip to Tokyo was amazing!",
                taggedUserIds: ["userB"],
                likedBy: ["userC", "userD"]
            ),
            PostModel(
                id: "post_002",
                authorId: "userB",
                authorUsername: "@sam",
                authorProfileImageUrl: "https://randomuser.me/api/portraits/men/2.jpg",
                itemId: "item_202",
                itemImageUrls: [
                    "https://picsum.photos/400/400?random=2"
                ],
                itemName: "Skydiving",
                type: .completed,
                timestamp: Date().addingTimeInterval(-3600),
                caption: "Finally completed skydiving!",
                taggedUserIds: [],
                likedBy: []
            ),
            PostModel(
                id: "post_003",
                authorId: "userC",
                authorUsername: "@emily",
                authorProfileImageUrl: "https://randomuser.me/api/portraits/women/3.jpg",
                itemId: "item_303",
                itemImageUrls: [
                    "https://picsum.photos/400/400?random=3"
                ],
                itemName: "Marathon",
                type: .photos,
                timestamp: Date().addingTimeInterval(-7200),
                caption: "Who wants to join me for a marathon?",
                taggedUserIds: ["userA"],
                likedBy: ["userA"]
            )
        ]
    }
}
