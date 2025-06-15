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
    @Published var isLoading: Bool = false
    
    private let db = Firestore.firestore()
    
    private var postListeners: [ListenerRegistration] = []
    
    /// Authenticated user’s UID
    private var authenticatedUserId: String? {
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
        guard !isLoading else {
            print("[FeedViewModel] fetchFeedPosts: already loading, skipping.")
            return
        }
        isLoading = true
        defer { isLoading = false }
        
        guard let userId = authenticatedUserId else {
            print("[FeedViewModel] fetchFeedPosts: No authenticatedUserId (not authenticated).")
            return
        }
        
        print("[FeedViewModel] Current UID:", userId)
        
        do {
            // 1) Fetch ALL user IDs (MVP)
            let usersSnapshot = try await db.collection("users").getDocuments()
            let allUserIds = usersSnapshot.documents.map { $0.documentID }
            print("[FeedViewModel] Retrieved all userIds: \(allUserIds.count)")
            print("[FeedViewModel] Fetching posts for userIds:", allUserIds)
            print("[FeedViewModel] Includes current user?", allUserIds.contains(userId))
            
            // 2) For each user in allUserIds, fetch their /posts subcollection
            var allPosts: [PostModel] = []
            
            for followedUserId in allUserIds {
                print("[FeedViewModel] Fetching posts for user:", followedUserId)
                do {
                    let snapshot = try await db
                        .collection("users")
                        .document(followedUserId)
                        .collection("posts")
                        .getDocuments()
                    
                    if snapshot.documents.isEmpty {
                        print("[FeedViewModel] No posts found for user:", followedUserId)
                    } else {
                        print("[FeedViewModel] Retrieved \(snapshot.documents.count) post(s) for user:", followedUserId)
                    }
                    
                    var userPosts: [PostModel] = []
                    for doc in snapshot.documents {
                        print("[FeedViewModel] Document ID:", doc.documentID)
                        print("[FeedViewModel] Raw data keys:", Array(doc.data().keys))
                        let data: [String: Any] = doc.data()
                        let post = await MainActor.run {
                            return self.buildPostModel(from: data, documentID: doc.documentID)
                        }
                        if post.id == nil || post.itemId.isEmpty {
                            print("[FeedViewModel] Warning: Malformed post detected, skipping:", doc.documentID)
                            continue
                        }
                        print("[FeedViewModel] Post loaded:", post.id ?? "nil", "-", post.itemImageUrls)
                        userPosts.append(post)
                    }
                    allPosts.append(contentsOf: userPosts)
                    print("[FeedViewModel] \(followedUserId) => loaded \(userPosts.count) post(s)")
                } catch {
                    print("[FeedViewModel] Error fetching posts for user \(followedUserId):", error.localizedDescription)
                }
            }
            
            startListeningToPosts(for: allUserIds)
            
            // 3) Sort combined posts by timestamp descending
            let sortedPosts = allPosts.sorted { $0.timestamp > $1.timestamp }
            print("[FeedViewModel] Sorted posts (latest first):", sortedPosts.map { $0.itemId })
            
            // 4) Assign to published property
            print("[FeedViewModel] Assigning sorted posts to self.posts...")
            self.posts = sortedPosts
            print("[FeedViewModel] Assigned posts count:", self.posts.count)
            print("[FeedViewModel] fetchFeedPosts => loaded \(allPosts.count) total posts.")
            print("✅ fetchFeedPosts completed. Total posts:", allPosts.count)
            
        } catch {
            print("[FeedViewModel] fetchFeedPosts error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
            // Even on error, ensure posts is set to empty to reflect failure state
            self.posts = []
        }
    }

    private func buildPostModel(from data: [String: Any], documentID: String) -> PostModel {
        // Basic fields
        let authorId       = data["authorId"]       as? String   ?? ""
        let itemId         = data["itemId"]         as? String   ?? ""
        let timestampRaw   = data["timestamp"]      as? Timestamp
        let timestamp      = timestampRaw?.dateValue() ?? Date()
        let caption        = data["caption"]        as? String
        let taggedUserIds  = data["taggedUserIds"]  as? [String] ?? []
        let likedBy        = data["likedBy"]        as? [String] ?? []
        let visibility     = data["visibility"]     as? String
        
        let itemImageUrls = data["itemImageUrls"] as? [String] ?? []
        
        let typeRaw = data["type"] as? String ?? "added"
        let type = PostType(rawValue: typeRaw) ?? .added
        
        let post = PostModel(
            id: documentID,
            authorId: authorId,
            authorUsername: data["authorUsername"] as? String,
            itemId: itemId,
            type: type,
            timestamp: timestamp,
            caption: caption,
            taggedUserIds: taggedUserIds,
            visibility: visibility,
            likedBy: likedBy,
            itemImageUrls: itemImageUrls
        )
        if post.id == nil || post.itemId.isEmpty {
            print("[FeedViewModel] buildPostModel returned malformed post for docID:", documentID)
        }
        return post
    }
    
    func refreshFeed() async {
        await fetchFeedPosts()
    }
    
    // MARK: - Like a Post
    func toggleLike(post: PostModel) async {
        guard let currentUID = authenticatedUserId else { return }
        guard let postDocId = post.id else { return }
        
        let authorId = post.authorId  // The owner of that post’s doc path
        let postRef = db
            .collection("users")
            .document(authorId)
            .collection("posts")
            .document(postDocId)
        
        do {
            // If `likedBy` already contains currentUID, remove it. Otherwise, add it.
            var newLikedBy = post.likedBy
            if newLikedBy.contains(currentUID) {
                // Unlike
                newLikedBy.removeAll { $0 == currentUID }
            } else {
                // Like
                newLikedBy.append(currentUID)
            }
            
            let update: [String: Any] = await MainActor.run {
                ["likedBy": newLikedBy]
            }
            try await postRef.updateData(update)
            
            // Update local feed array for immediate UI feedback
            if let idx = posts.firstIndex(where: { $0.id == postDocId }) {
                var updatedPost = posts[idx]
                updatedPost.likedBy = newLikedBy
                posts[idx] = updatedPost
                print("[FeedViewModel] toggleLike updated local post:", postDocId)
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
        guard let currentUID = authenticatedUserId else { return }
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
    
    func startListeningToPosts(for userIds: [String]) {
        // Remove old listeners
        postListeners.forEach { $0.remove() }
        postListeners.removeAll()

        for uid in userIds {
            let listener = db.collection("users")
                .document(uid)
                .collection("posts")
                .addSnapshotListener { [weak self] _, error in
                    guard let self = self else { return }
                    if let error = error {
                        print("[FeedViewModel] Listener error for user \(uid):", error.localizedDescription)
                        return
                    }

                    Task {
                        await self.fetchFeedPosts()
                    }
                }

            postListeners.append(listener)
        }
    }
}

class MockFeedViewModel: FeedViewModel {
    init(posts: [PostModel]) {
        super.init() // calls the real init
        self.posts = posts // set the sample data
    }
    
    override func fetchFeedPosts() async {
        // Normally would load from Firestore
        // Here, do nothing or maybe update `posts` with a new array
        print("[MockFeedViewModel] fetchFeedPosts() - in preview, so no network call.")
    }
    
    override func toggleLike(post: PostModel) async {
        // In a real app, you'd hit Firestore to update `likedBy`.
        // Here, just do a local toggle for preview:
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        var updated = posts[idx]
        let currentUserId = "mockCurrentUserID"
        
        if updated.likedBy.contains(currentUserId) {
            updated.likedBy.removeAll { $0 == currentUserId }
        } else {
            updated.likedBy.append(currentUserId)
        }
        posts[idx] = updated
        print("[MockFeedViewModel] toggleLike - updated post \(updated.id ?? "nil") likes to: \(updated.likedBy.count)")
    }
}
