//
//  SyncCoordinator.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 7/6/25.
//

import Foundation
import FirebaseFirestore

/// Coordinates syncing between PostViewModel, ListViewModel, and FeedViewModel.
/// Intended to centralize business logic and reduce duplication across view models.
@MainActor
class SyncCoordinator: ObservableObject {

    let postViewModel: PostViewModel
    let listViewModel: ListViewModel
    let feedViewModel: FeedViewModel
    let friendsViewModel: FriendsViewModel

    init(postViewModel: PostViewModel,
         listViewModel: ListViewModel,
         feedViewModel: FeedViewModel,
         friendsViewModel: FriendsViewModel) {
        self.postViewModel = postViewModel
        self.listViewModel = listViewModel
        self.feedViewModel = feedViewModel
        self.friendsViewModel = friendsViewModel
    }

    /// Call during app startup or after auth.
    func start() {
        print("[SyncCoordinator] Starting listeners...")
        postViewModel.startListeningToPosts(listViewModel: listViewModel)
    }

    /// Refresh all feed and re-sync likes into list items.
    func refreshFeedAndSyncLikes() async {
        print("[SyncCoordinator] Refreshing feed and syncing likes...")
        await feedViewModel.refreshFeed()
        await postViewModel.syncAllItemLikes(to: listViewModel)
    }



    /// Force sync of one specific item's likes.
    func syncLikes(for item: ItemModel) async {
        if let postId = item.postId,
           let post = postViewModel.posts.first(where: { $0.id == postId }) {
            await listViewModel.syncItemLikes(for: item.id, from: post.likedBy)
        }
    }
    
    /// Post an item to the feed and ensure both post and item are updated correctly.
    func post(item: ItemModel) async {
        guard let user = postViewModel.userViewModel?.user,
              !user.id.isEmpty else {
            print("[SyncCoordinator] post(item:) => User not found or invalid.")
            return
        }

        let newPost = PostModel(
            authorId: user.id,
            authorUsername: user.username ?? "@unknown",
            authorProfileImageUrl: user.profileImageUrl ?? "",
            itemId: item.id.uuidString,
            itemImageUrls: item.imageUrls,
            itemName: item.name,
            type: .completed,
            timestamp: Date(),
            caption: postViewModel.caption,
            taggedUserIds: postViewModel.taggedUserIds,
            likedBy: []
        )

        print("[SyncCoordinator] Posting new item:", newPost)

        guard let savedPost = await postViewModel.addOrUpdatePost(post: newPost),
              let postId = savedPost.id else {
            print("[SyncCoordinator] ❌ Failed to save or retrieve post ID.")
            return
        }

        var updatedItem = item
        updatedItem.wasShared = true
        updatedItem.postId = postId
        await listViewModel.addOrUpdateItem(updatedItem)
        print("[SyncCoordinator] Updated item after posting: \(updatedItem.name), wasShared: \(updatedItem.wasShared), postId: \(String(describing: updatedItem.postId))")
        await refreshFeedAndSyncLikes()

        // Reset UI state
        postViewModel.isPosting = false
        postViewModel.caption = ""
        postViewModel.taggedUserIds = []
        postViewModel.selectedItemID = nil
    }

    /// Start all real-time listeners for posts, items, and feed
    func startAllListeners(userId: String) {
        print("[SyncCoordinator] Starting all listeners...")
        postViewModel.startListeningToPosts(listViewModel: listViewModel)
        listViewModel.startListeningToItems()
        feedViewModel.startListeningToPosts(for: [userId])
        friendsViewModel.startListeningToFriendChanges()
    }
}
