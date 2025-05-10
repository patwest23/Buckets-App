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
                    // If you prefer, you can do:
                    // let post = try doc.data(as: PostModel.self)
                    // return post
                    // ...assuming your Firestore doc exactly matches PostModel's fields.

                    // Manual approach:
                    let data = doc.data()
                    
                    // Basic fields
                    let authorId       = data["authorId"]       as? String   ?? ""
                    let itemId         = data["itemId"]         as? String   ?? ""
                    let timestampRaw   = data["timestamp"]      as? Timestamp
                    let timestamp      = timestampRaw?.dateValue() ?? Date()
                    let caption        = data["caption"]        as? String
                    let taggedUserIds  = data["taggedUserIds"]  as? [String]
                    let likedBy        = data["likedBy"]        as? [String]
                    let visibility     = data["visibility"]     as? String
                    
                    // Embedded item fields
                    let itemName       = data["itemName"]       as? String   ?? "Untitled"
                    let itemCompleted  = data["itemCompleted"]  as? Bool     ?? false
                    
                    // itemLocation (if stored as a dictionary)
                    var itemLocation: Location? = nil
                    if let locDict = data["itemLocation"] as? [String: Any] {
                        let lat = locDict["latitude"] as? Double ?? 0
                        let lon = locDict["longitude"] as? Double ?? 0
                        let addr = locDict["address"] as? String
                        itemLocation = Location(latitude: lat, longitude: lon, address: addr)
                    }
                    
                    // itemDueDate
                    let dueDateRaw  = data["itemDueDate"] as? Timestamp
                    let itemDueDate = dueDateRaw?.dateValue()
                    
                    let itemImageUrls = data["itemImageUrls"] as? [String] ?? []
                    
                    let typeRaw = data["type"] as? String ?? "added"
                    let type = PostType(rawValue: typeRaw) ?? .added
                    
                    let post = PostModel(
                        id: doc.documentID,
                        authorId: authorId,
                        authorUsername: data["authorUsername"] as? String,
                        itemId: itemId,
                        type: type,
                        timestamp: timestamp,
                        caption: caption,
                        taggedUserIds: taggedUserIds,
                        visibility: visibility,
                        likedBy: likedBy,
                        itemName: itemName,
                        itemCompleted: itemCompleted,
                        itemLocation: itemLocation,
                        itemDueDate: itemDueDate,
                        itemImageUrls: itemImageUrls
                    )
                    return post
                }
                allPosts.append(contentsOf: userPosts)
            }
            
            // 3) Sort combined posts by timestamp descending
            let sortedPosts = allPosts.sorted { $0.timestamp > $1.timestamp }
            
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
        
        if let likedBy = updated.likedBy, likedBy.contains(currentUserId) {
            // Unlike
            updated.likedBy = likedBy.filter { $0 != currentUserId }
        } else {
            // Like
            updated.likedBy = (updated.likedBy ?? []) + [currentUserId]
        }
        posts[idx] = updated
        print("[MockFeedViewModel] toggleLike - updated post \(updated.id ?? "nil") likes to: \(updated.likedBy?.count ?? 0)")
    }
}
