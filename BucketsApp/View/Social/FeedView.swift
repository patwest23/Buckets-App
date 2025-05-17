//
//  FeedView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct FeedView: View {
    @StateObject var feedVM: FeedViewModel

    init(feedVM: FeedViewModel) {
        _feedVM = StateObject(wrappedValue: feedVM)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(feedVM.posts) { post in
                        VStack(alignment: .leading, spacing: 4) {
                            // MARK: - Feed Card
                            FeedRowView(
                                post: post,
                                onLike: {
                                    Task {
                                        await feedVM.toggleLike(post: post)
                                    }
                                }
                            )

                            // MARK: - Timestamp
                            Text(timeAgoString(for: post.timestamp))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
            .onAppear {
                Task {
                    await feedVM.fetchFeedPosts()
                }
            }
        }
    }

    // MARK: - Time Ago Formatter
    private func timeAgoString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
