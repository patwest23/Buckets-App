//
//  FeedView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct FeedView: View {
    @EnvironmentObject var feedViewModel: FeedViewModel
    @State private var showLoading = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if showLoading {
                        ProgressView("Loading Feed...")
                            .padding()
                    }
                    if feedViewModel.posts.isEmpty {
                        Text("No posts yet.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(feedViewModel.posts) { post in
                            VStack(alignment: .leading, spacing: 4) {
                                // MARK: - Feed Card
                                FeedRowView(
                                    post: post,
                                    item: nil,
                                    onLike: {
                                        Task {
                                            await feedViewModel.toggleLike(post: post)
                                        }
                                    }
                                )
                                .task {
                                    print("🔍 FeedRowView - postId=\(post.id), likeCount=\(post.likedBy.count)")
                                }

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
            }
            .refreshable {
                showLoading = true
                await feedViewModel.fetchFeedPosts()
                showLoading = false
            }
            .onAppear {
                if feedViewModel.posts.isEmpty {
                    Task {
                        showLoading = true
                        await feedViewModel.fetchFeedPosts()
                        showLoading = false
                    }
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
        VStack {
            Text("🛠 DEBUG MODE")
                .font(.caption)
                .foregroundColor(.gray)
            FeedView()
                .environmentObject(mockVM)
                .environmentObject(PostViewModel())
        }
    }
}
