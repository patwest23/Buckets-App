//
//  FeedViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [PostModel] = []
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    /// Current logged-in user’s UID
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    init() {
        // You can call fetchFeedPosts() here or in the FeedView’s .onAppear.
        print("[FeedViewModel] init.")
    }
    
    deinit {
        print("[FeedViewModel] deinit.")
    }
    
    // MARK: - Fetch Feed
    func fetchFeedPosts() async {
        guard let userId = currentUserId else {
            print("[FeedViewModel] fetchFeedPosts: No currentUserId (not authenticated).")
            return
        }
        
        do {
            // 1) Fetch the current user doc to get the `following` list
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let userData = userDoc.data() else {
                print("[FeedViewModel] Current user doc is empty.")
                return
            }
            
            // If your UserModel has an array `following: [String]`,
            // we try to parse it from the doc data:
            guard let followingList = userData["following"] as? [String] else {
                print("[FeedViewModel] No 'following' array found, or it's not a [String].")
                return
            }
            
            // Optionally include the user’s own userId to see the user's own posts in the feed
            let allUserIds = [userId] + followingList
            
            // 2) For each user in allUserIds, fetch their /posts subcollection
            var allPosts: [PostModel] = []
            
            for followedUserId in allUserIds {
                let snapshot = try await db
                    .collection("users")
                    .document(followedUserId)
                    .collection("posts")
                    .getDocuments()
                
                let userPosts = try snapshot.documents.map { doc -> PostModel in
                    // Manual decoding or `doc.data(as: PostModel.self)` if using Firestore’s codable
                    let data = doc.data()
                    let post = PostModel(
                        id: doc.documentID,
                        authorId: data["authorId"] as? String ?? "",
                        itemId: data["itemId"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        caption: data["caption"] as? String,
                        taggedUserIds: data["taggedUserIds"] as? [String],
                        likedBy: data["likedBy"] as? [String]
                    )
                    return post
                }
                allPosts.append(contentsOf: userPosts)
            }
            
            // 3) Sort combined posts by timestamp descending
            let sortedPosts = allPosts.sorted(by: { $0.timestamp > $1.timestamp })
            
            // 4) Assign to published property
            self.posts = sortedPosts
            print("[FeedViewModel] fetchFeedPosts => loaded \(allPosts.count) total posts.")
            
        } catch {
            print("[FeedViewModel] fetchFeedPosts error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    func refreshFeed() async {
        await fetchFeedPosts()
    }
    
    // MARK: - Like a Post
    func toggleLike(post: PostModel) async {
        guard let currentUID = currentUserId else { return }
        guard let postDocId = post.id else { return }
        
        let authorId = post.authorId  // The owner of that post’s doc path
        let postRef = db
            .collection("users")
            .document(authorId)
            .collection("posts")
            .document(postDocId)
        
        do {
            // If `likedBy` already contains currentUID, remove it. Otherwise, add it.
            var newLikedBy = post.likedBy ?? []
            if newLikedBy.contains(currentUID) {
                // Unlike
                newLikedBy.removeAll { $0 == currentUID }
            } else {
                // Like
                newLikedBy.append(currentUID)
            }
            
            try await postRef.updateData(["likedBy": newLikedBy])
            
            // Update local feed array for immediate UI feedback
            if let idx = posts.firstIndex(where: { $0.id == postDocId }) {
                var updatedPost = posts[idx]
                updatedPost.likedBy = newLikedBy
                posts[idx] = updatedPost
            }
            
        } catch {
            print("[FeedViewModel] toggleLike error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Add a Comment (Simple Example)
    /// For comments, we’ll assume each post has a subcollection `comments` in Firestore:
    /// /users/{postAuthorId}/posts/{postId}/comments
    /// Each comment doc can have fields: `authorId, text, timestamp`.
    
    func addComment(to post: PostModel, text: String) async {
        guard let currentUID = currentUserId else { return }
        guard let postDocId = post.id else { return }
        
        let authorId = post.authorId
        let commentRef = db
            .collection("users")
            .document(authorId)
            .collection("posts")
            .document(postDocId)
            .collection("comments")
            .document()  // auto-generated ID
        
        let newCommentData: [String: Any] = [
            "authorId": currentUID,
            "text": text,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        do {
            try await commentRef.setData(newCommentData)
            print("[FeedViewModel] addComment => Added comment for post \(postDocId)")
        } catch {
            print("[FeedViewModel] addComment error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
}
