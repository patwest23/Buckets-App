//
//  PostModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import Foundation
import FirebaseFirestore

struct PostModel: Identifiable, Codable {
    
    @DocumentID var id: String? = nil
    
    /// The user ID of the post’s author. This should match `UserModel.id`.
    var authorId: String
    
    /// The ID of the associated bucket-list item (optional, if we embed all item data).
    var itemId: String
    
    /// Timestamp for when the post was created.
    var timestamp: Date
    
    /// Optional text or caption for this post.
    var caption: String?
    
    /// Array of user IDs referencing `UserModel.id` for any tagged users.
    var taggedUserIds: [String]?
    
    /// Who can see the post (public, friends, etc.).
    var visibility: String?
    
    /// The user IDs of those who liked this post.
    var likedBy: [String]?
    
    // MARK: - Embedded Item Fields
    
    /// Name of the item (e.g. “Visit Tokyo”)
    var itemName: String
    
    /// Whether the item is completed
    var itemCompleted: Bool
    
    /// Optional location (like from `ItemModel.location`)
    var itemLocation: Location?
    
    /// Optional date for item completion or due date
    var itemDueDate: Date?
    
    /// Image URLs for this item, displayed in the feed
    var itemImageUrls: [String]
    
    // MARK: - Initializer
    init(
        id: String? = nil,
        authorId: String,
        itemId: String,
        timestamp: Date = Date(),
        caption: String? = nil,
        taggedUserIds: [String]? = nil,
        visibility: String? = nil,
        likedBy: [String]? = nil,
        
        // Embedded item data
        itemName: String,
        itemCompleted: Bool,
        itemLocation: Location? = nil,
        itemDueDate: Date? = nil,
        itemImageUrls: [String] = []
    ) {
        self.id = id
        self.authorId = authorId
        self.itemId = itemId
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
                itemId: "item_101",
                timestamp: Date(),
                caption: "My trip to Tokyo was amazing!",
                taggedUserIds: ["userB"],
                likedBy: ["userC", "userD"],
                
                itemName: "Visit Tokyo",
                itemCompleted: true,
                itemLocation: Location(latitude: 35.6895, longitude: 139.6917, address: "Tokyo, Japan"),
                itemDueDate: Date().addingTimeInterval(-86400), // Yesterday
                // MULTIPLE IMAGE URLS
                itemImageUrls: [
                    "https://picsum.photos/400/400?random=1",
                    "https://picsum.photos/400/400?random=2",
                    "https://picsum.photos/400/400?random=11"
                ]
            ),
            PostModel(
                id: "post_002",
                authorId: "userB",
                itemId: "item_202",
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
                itemId: "item_303",
                timestamp: Date().addingTimeInterval(-7200),
                caption: "Who wants to join me for a marathon?",
                taggedUserIds: ["userA"],
                likedBy: ["userA"],
                
                itemName: "Run a marathon",
                itemCompleted: false,
                itemLocation: nil,
                itemDueDate: Date().addingTimeInterval(86400 * 30), // 30 days from now
                itemImageUrls: [
                    "https://picsum.photos/400/400?random=3"
                ]
            )
        ]
    }
}
