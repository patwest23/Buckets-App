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
    @EnvironmentObject var friendsViewModel: FriendsViewModel
    @State private var isRefreshing = false
    @State private var showsInlineSpinner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if isRefreshing && showsInlineSpinner {
                        ProgressView("Loading Feed...")
                            .padding(.top, 12)
                    }

                    if feedViewModel.posts.isEmpty && !isRefreshing {
                        Text("No posts yet.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach($feedViewModel.posts) { $post in
                            let postValue = $post.wrappedValue
                            let summary = resolvedSummary(for: postValue)

                            VStack(alignment: .leading, spacing: 4) {
                                FeedRowView(
                                    post: $post,
                                    itemSummary: summary,
                                    onLike: { updatedPost in
                                        await feedViewModel.toggleLike(post: updatedPost)
                                    }
                                )

                                Text(timeAgoString(for: postValue.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await performRefresh(showSpinner: true) }
                    } label: {
                        if showsInlineSpinner {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .accessibilityLabel("Refresh feed")
                    .disabled(isRefreshing)
                }
            }
            .refreshable {
                await performRefresh(showSpinner: false)
            }
            .onAppear {
                updateTrackedUsers()
                if feedViewModel.posts.isEmpty {
                    Task { await performRefresh(showSpinner: true) }
                }
            }
            .onChange(of: friendsViewModel.followingUsers) { _ in
                updateTrackedUsers()
            }
            .onChange(of: userViewModel.user?.id) { _ in
                updateTrackedUsers()
            }
        }
    }

    // MARK: - Time Ago Formatter
    private func timeAgoString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    @MainActor
    private func performRefresh(showSpinner: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        showsInlineSpinner = showSpinner
        defer {
            isRefreshing = false
            showsInlineSpinner = false
        }
        await syncCoordinator.refreshFeedAndSyncLikes()
    }

    private func updateTrackedUsers() {
        let friendIds: [String] = friendsViewModel.followingUsers.compactMap { user in
            if let documentId = user.documentId { return documentId }
            let id = user.id
            return id == "unknown-user-id" ? nil : id
        }
        feedViewModel.startListeningToPosts(for: friendIds)
    }

    private func resolvedSummary(for post: PostModel) -> ItemSummary? {
        if let summary = feedViewModel.itemSummary(for: post.itemId) {
            return summary
        }

        if let localItem = bucketListViewModel.items.first(where: { $0.postId == post.id }) {
            return ItemSummary(
                id: localItem.id.uuidString,
                ownerId: localItem.userId,
                name: localItem.name,
                dueDate: localItem.dueDate,
                hasDueTime: localItem.hasDueTime,
                completed: localItem.completed,
                likedBy: localItem.likedBy
            )
        }

        return nil
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
