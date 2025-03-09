//
//  PostModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

struct PostModel: Identifiable {
    let id: String
    let authorID: String     // The user who posted
    let itemID: String       // The BucketList item posted
    let timestamp: Date
    let caption: String?     // Optional text or notes
    let taggedUserIDs: [String] // IDs of any tagged friends
    
    // You might include an image URL, a “completed” flag, etc.
}
