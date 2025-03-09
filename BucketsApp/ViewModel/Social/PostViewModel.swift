//
//  PostViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI
import Combine

class PostViewModel: ObservableObject {
    @Published var caption: String = ""
    @Published var taggedUserIDs: [String] = []
    @Published var selectedItemID: String?  // The item user wants to post
    @Published var isPosting = false
    
    // Any other fields needed (e.g., an image if you allow uploading)
    
    func postItem() {
        guard let itemID = selectedItemID else { return }
        isPosting = true
        
        // Build your PostModel
        let newPost = PostModel(
            id: UUID().uuidString,
            authorID: /* currentUser.id */ "",
            itemID: itemID,
            timestamp: Date(),
            caption: caption,
            taggedUserIDs: taggedUserIDs
        )
        
        // Upload to Firestore, Realtime DB, etc.
        // ...
        
        isPosting = false
    }
}
