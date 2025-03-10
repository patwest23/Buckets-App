//
//  FeedView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct FeedView: View {
    @StateObject var feedVM: FeedViewModel
    
    /// We assume `feedVM.posts` is an array of `PostModel` objects
    /// that already contain embedded item data.
    init(feedVM: FeedViewModel) {
        _feedVM = StateObject(wrappedValue: feedVM)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                ForEach(feedVM.posts) { post in
                    // FeedRowView now takes a single `PostModel` argument
                    FeedRowView(
                        post: post,
                        onLike: {
                            Task {
                                await feedVM.toggleLike(post: post)
                            }
                        },
                        onComment: {
                            // Show comment UI or navigate to a comment screen
                        }
                    )
                }
            }
            .navigationTitle("Your Feed")
            .onAppear {
                Task {
                    await feedVM.fetchFeedPosts()
                }
            }
        }
    }
}

// MARK: - Preview
struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample posts for preview
        let samplePosts = PostModel.mockData
        
        // Mock view model with sample posts
        let mockVM = MockFeedViewModel(posts: samplePosts)
        
        // Inject the mock VM
        FeedView(feedVM: mockVM)
            .previewDisplayName("FeedView with Mock Data")
    }
}
