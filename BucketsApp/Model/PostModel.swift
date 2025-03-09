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
    
    /// The ID of the associated bucket-list item. This should match `ItemModel.id` (converted to String as needed).
    var itemId: String
    
    /// Timestamp for when the post was created.
    var timestamp: Date
    
    /// Optional text or caption for this post.
    var caption: String?
    
    /// Array of user IDs referencing `UserModel.id` for any tagged users.
    var taggedUserIds: [String]?
    
    /// Example property for controlling who can see the post.
    var visibility: String?
    
    // NEW: Store the user IDs of those who liked the post.
    var likedBy: [String]?
    
    // MARK: - Initializer
    init(
        id: String? = nil,
        authorId: String,
        itemId: String,
        timestamp: Date = Date(),
        caption: String? = nil,
        taggedUserIds: [String]? = nil,
        visibility: String? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.itemId = itemId
        self.timestamp = timestamp
        self.caption = caption
        self.taggedUserIds = taggedUserIds
        self.visibility = visibility
    }
}
