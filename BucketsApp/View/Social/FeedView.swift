//
//  FeedView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct FeedView: View {
    @EnvironmentObject var feedViewModel: FeedViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var syncCoordinator: SyncCoordinator
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
                        ForEach($feedViewModel.posts) { $post in
                            let postValue = $post.wrappedValue
                            let matchedItem = bucketListViewModel.items.first { $0.postId == postValue.id }
                            VStack(alignment: .leading, spacing: 4) {
                                // MARK: - Feed Card
                                FeedRowView(
                                    post: $post,
                                    item: matchedItem,
                                    onLike: { updatedPost in
                                        await feedViewModel.toggleLike(post: updatedPost)
                                    }
                                )
                                .task {
                                    let latestPost = $post.wrappedValue
                                    print("🔍 FeedRowView - postId=\(latestPost.id ?? "nil"), likeCount=\(latestPost.likedBy.count)")
                                }

                                // MARK: - Timestamp
                                Text(timeAgoString(for: postValue.timestamp))
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
                await syncCoordinator.refreshFeedAndSyncLikes()
                showLoading = false
            }
            .onAppear {
                print("FeedView appeared, checking if initial sync is needed...")
                if feedViewModel.posts.isEmpty {
                    Task {
                        showLoading = true
                        await syncCoordinator.refreshFeedAndSyncLikes()
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

//// MARK: - Preview
//struct FeedView_Previews: PreviewProvider {
//    static var previews: some View {
//        // Sample posts for preview
//        let samplePosts = PostModel.mockData
//        
//        // Mock view model with sample posts
//        let mockVM = MockFeedViewModel(posts: samplePosts)
//        let listVM = ListViewModel()
//        let userVM = UserViewModel()
//        let sync = SyncCoordinator(postViewModel: PostViewModel(), listViewModel: listVM, feedViewModel: mockVM)
//        
//        VStack {
//            Text("🛠 DEBUG MODE")
//                .font(.caption)
//                .foregroundColor(.gray)
//            FeedView()
//                .environmentObject(mockVM)
//                .environmentObject(PostViewModel())
//                .environmentObject(userVM)
//                .environmentObject(listVM)
//                .environmentObject(sync)
//        }
//    }
//}
