//
//  FeedViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI
import Combine

class FeedViewModel: ObservableObject {
    @Published var posts: [PostModel] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Possibly call a fetch method in the init or wait for a .onAppear in the FeedView
        fetchFeedPosts()
    }
    
    func fetchFeedPosts() {
        // For each user the currentUser follows, load their posts from DB
        // Combine them into a single array, sort by timestamp, etc.
        // Then assign to self.posts
    }
    
    func refreshFeed() {
        // Force re-fetch or refresh logic
        fetchFeedPosts()
    }
}
