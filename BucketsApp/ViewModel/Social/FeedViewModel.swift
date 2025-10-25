//
//  FeedViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ItemSummary: Equatable, Sendable {
    let id: String
    let ownerId: String
    var name: String
    var dueDate: Date?
    var hasDueTime: Bool
    var completed: Bool
    var likedBy: [String]
}

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [PostModel] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published private(set) var itemSummaries: [String: ItemSummary] = [:]

    private let db = Firestore.firestore()
    private let pageSize: Int = 25

    private var postListeners: [String: ListenerRegistration] = [:]

    /// Authenticated user’s UID
    private var authenticatedUserId: String? {
        Auth.auth().currentUser?.uid
    }

    private var trackedUserIds: Set<String> = []
    private var paginationState: [String: DocumentSnapshot?] = [:]
    private var itemSummaryCache: [String: ItemSummary] = [:]
    private var postCache: [String: PostModel] = [:]
    private var pendingLikeUpdates: Set<String> = []
    
    init() {
        // You can call fetchFeedPosts() here or in the FeedView’s .onAppear.
        print("[FeedViewModel] init.")
    }
    
    deinit {
        print("[FeedViewModel] deinit.")
    }
    
    // MARK: - Fetch Feed
    func fetchFeedPosts(reset: Bool = false, targetedUserIds: [String]? = nil) async {
        guard !isLoading else {
            print("[FeedViewModel] fetchFeedPosts: already loading, skipping.")
            return
        }
        isLoading = true
        defer { isLoading = false }

        guard let currentUserId = authenticatedUserId else {
            print("[FeedViewModel] fetchFeedPosts: No authenticatedUserId (not authenticated).")
            return
        }

        trackedUserIds.insert(currentUserId)

        let resolvedTargetIds = targetedUserIds?.filter { !$0.isEmpty } ?? []
        var userIdsToFetch: [String] = resolvedTargetIds

        if userIdsToFetch.isEmpty {
            if trackedUserIds.isEmpty {
                userIdsToFetch = [currentUserId]
            } else {
                userIdsToFetch = Array(trackedUserIds)
            }
        }

        if reset {
            paginationState = [:]
            postCache = [:]
        }

        if !resolvedTargetIds.isEmpty {
            resolvedTargetIds.forEach { paginationState[$0] = nil }
        } else if reset {
            userIdsToFetch.forEach { paginationState[$0] = nil }
        }

        var fetchedPosts: [PostModel] = []
        var paginationUpdates: [String: DocumentSnapshot?] = [:]

        for userId in userIdsToFetch {
            do {
                let startAfter = paginationState[userId] ?? nil
                let (userPosts, lastSnapshot) = try await fetchPosts(for: userId, startAfter: startAfter)
                paginationUpdates[userId] = lastSnapshot
                for post in userPosts {
                    await ensureItemSummary(for: post)
                }
                fetchedPosts.append(contentsOf: userPosts)
            } catch {
                print("[FeedViewModel] Error fetching posts for user \(userId):", error.localizedDescription)
            }
        }

        for (userId, snapshot) in paginationUpdates {
            paginationState[userId] = snapshot
        }

        mergeFetchedPosts(fetchedPosts, replacingExisting: reset && resolvedTargetIds.isEmpty)
    }

    private func fetchPosts(for userId: String, startAfter: DocumentSnapshot?) async throws -> ([PostModel], DocumentSnapshot?) {
        var query = db
            .collection("users")
            .document(userId)
            .collection("posts")
            .order(by: "timestamp", descending: true)
            .limit(to: pageSize)

        if let startAfter {
            query = query.start(afterDocument: startAfter)
        }

        let snapshot = try await query.getDocuments()
        var posts: [PostModel] = []

        for document in snapshot.documents {
            let data = document.data()
            var post = buildPostModel(from: data, documentID: document.documentID)
            if post.id == nil || post.itemId.isEmpty {
                print("[FeedViewModel] Warning: Malformed post detected, skipping:", document.documentID)
                continue
            }

            if let summary = itemSummaryCache[post.itemId] {
                post.itemName = summary.name
            }

            posts.append(post)
        }

        return (posts, snapshot.documents.last)
    }

    private func ensureItemSummary(for post: PostModel) async {
        guard itemSummaryCache[post.itemId] == nil else { return }

        let itemRef = db
            .collection("users")
            .document(post.authorId)
            .collection("items")
            .document(post.itemId)

        do {
            let snapshot = try await itemRef.getDocument()
            guard let data = snapshot.data() else { return }

            let summary = ItemSummary(
                id: post.itemId,
                ownerId: post.authorId,
                name: data["name"] as? String ?? post.itemName ?? "Untitled Post",
                dueDate: (data["dueDate"] as? Timestamp)?.dateValue(),
                hasDueTime: data["hasDueTime"] as? Bool ?? false,
                completed: data["completed"] as? Bool ?? false,
                likedBy: data["likedBy"] as? [String] ?? []
            )

            itemSummaryCache[post.itemId] = summary
            itemSummaries = itemSummaryCache
        } catch {
            print("[FeedViewModel] Failed to fetch item summary for \(post.itemId):", error.localizedDescription)
        }
    }

    private func mergeFetchedPosts(_ fetchedPosts: [PostModel], replacingExisting: Bool) {
        if replacingExisting {
            postCache.removeAll()
        }

        for var post in fetchedPosts {
            guard let postId = post.id else { continue }

            if let summary = itemSummaryCache[post.itemId] {
                post.itemName = summary.name
            }

            if pendingLikeUpdates.contains(postId), let cached = postCache[postId] {
                if cached.likedBy != post.likedBy {
                    print("[FeedViewModel] Preserving optimistic likes for post", postId)
                    post.likedBy = cached.likedBy
                } else {
                    pendingLikeUpdates.remove(postId)
                }
            } else {
                pendingLikeUpdates.remove(postId)
            }

            postCache[postId] = post
        }

        posts = postCache.values.sorted { $0.timestamp > $1.timestamp }
        itemSummaries = itemSummaryCache
        let validIds = Set(postCache.keys)
        pendingLikeUpdates = pendingLikeUpdates.intersection(validIds)
    }

    private func attachListener(for userId: String) {
        let listener = db
            .collection("users")
            .document(userId)
            .collection("posts")
            .order(by: "timestamp", descending: true)
            .limit(to: pageSize)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("[FeedViewModel] Listener error for user \(userId):", error.localizedDescription)
                    return
                }
                guard let snapshot = snapshot else { return }

                var updatedPosts: [PostModel] = []
                var removedPostIds: [String] = []

                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added, .modified:
                        var post = self.buildPostModel(from: change.document.data(), documentID: change.document.documentID)
                        if post.id == nil || post.itemId.isEmpty {
                            continue
                        }
                        if let summary = self.itemSummaryCache[post.itemId] {
                            post.itemName = summary.name
                        }
                        updatedPosts.append(post)
                    case .removed:
                        removedPostIds.append(change.document.documentID)
                    @unknown default:
                        continue
                    }
                }

                guard !updatedPosts.isEmpty || !removedPostIds.isEmpty else {
                    return
                }

                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    await self.applySnapshotUpdates(updatedPosts: updatedPosts, removedPostIds: removedPostIds)
                }
            }

        postListeners[userId] = listener
    }

    @MainActor
    private func applySnapshotUpdates(updatedPosts: [PostModel], removedPostIds: [String]) async {
        var requiresResort = false

        for postId in removedPostIds {
            postCache[postId] = nil
            pendingLikeUpdates.remove(postId)
            requiresResort = true
        }

        for var post in updatedPosts {
            guard let postId = post.id else { continue }

            if itemSummaryCache[post.itemId] == nil {
                await ensureItemSummary(for: post)
            }

            if let summary = itemSummaryCache[post.itemId] {
                post.itemName = summary.name
            }

            if pendingLikeUpdates.contains(postId), let cached = postCache[postId] {
                if cached.likedBy != post.likedBy {
                    post.likedBy = cached.likedBy
                } else {
                    pendingLikeUpdates.remove(postId)
                }
            } else {
                pendingLikeUpdates.remove(postId)
            }

            postCache[postId] = post
            requiresResort = true
        }

        if requiresResort {
            posts = postCache.values.sorted { $0.timestamp > $1.timestamp }
        }

        let remainingItemIds = Set(postCache.values.map { $0.itemId })
        itemSummaryCache = itemSummaryCache.filter { remainingItemIds.contains($0.key) }
        itemSummaries = itemSummaryCache
        pendingLikeUpdates = pendingLikeUpdates.intersection(Set(postCache.keys))
    }

    private func removePosts(forAuthor authorId: String) {
        postCache = postCache.filter { $0.value.authorId != authorId }
        let validIds = Set(postCache.keys)
        pendingLikeUpdates = pendingLikeUpdates.intersection(validIds)
        let remainingItemIds = Set(postCache.values.map { $0.itemId })
        itemSummaryCache = itemSummaryCache.filter { remainingItemIds.contains($0.key) }
        posts = postCache.values.sorted { $0.timestamp > $1.timestamp }
        itemSummaries = itemSummaryCache
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
            authorProfileImageUrl: data["authorProfileImageUrl"] as? String,
            itemId: itemId,
            itemImageUrls: itemImageUrls,
            itemName: data["itemName"] as? String,
            type: type,
            timestamp: timestamp,
            caption: caption,
            taggedUserIds: taggedUserIds,
            visibility: visibility,
            likedBy: likedBy
        )
        if post.id == nil || post.itemId.isEmpty {
            print("[FeedViewModel] buildPostModel returned malformed post for docID:", documentID)
        }
        return post
    }
    
    func refreshFeed() async {
        await fetchFeedPosts(reset: true)
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
            let previousLikedBy = post.likedBy
            var newLikedBy = previousLikedBy
            if newLikedBy.contains(currentUID) {
                newLikedBy.removeAll { $0 == currentUID }
            } else {
                newLikedBy.append(currentUID)
            }

            // Optimistically update the local post so the UI responds immediately.
            if let idx = posts.firstIndex(where: { $0.id == postDocId }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    posts[idx].likedBy = newLikedBy
                }
                print("[FeedViewModel] toggleLike optimistic update for post:", postDocId)
            }

            if var cached = postCache[postDocId] {
                cached.likedBy = newLikedBy
                postCache[postDocId] = cached
            } else {
                var updatedPost = post
                updatedPost.likedBy = newLikedBy
                postCache[postDocId] = updatedPost
            }
            if var summary = itemSummaryCache[post.itemId] {
                summary.likedBy = newLikedBy
                itemSummaryCache[post.itemId] = summary
                itemSummaries = itemSummaryCache
            }
            pendingLikeUpdates.insert(postDocId)

            try await postRef.updateData(["likedBy": newLikedBy])

            print("[FeedViewModel] toggleLike: \(currentUID) => \(newLikedBy.count) likes total for post \(postDocId)")

        } catch {
            print("[FeedViewModel] toggleLike error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
            // Revert the optimistic update if Firestore write fails.
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    posts[idx].likedBy = post.likedBy
                }
                print("[FeedViewModel] toggleLike reverted local post due to error:", postDocId)
            }
            pendingLikeUpdates.remove(postDocId)
            if var cached = postCache[postDocId] {
                cached.likedBy = post.likedBy
                postCache[postDocId] = cached
            }
            if var summary = itemSummaryCache[post.itemId] {
                summary.likedBy = post.likedBy
                itemSummaryCache[post.itemId] = summary
                itemSummaries = itemSummaryCache
            }
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
        guard let currentUserId = authenticatedUserId else { return }

        var combinedIds = Set(userIds)
        combinedIds.insert(currentUserId)

        let removedIds = trackedUserIds.subtracting(combinedIds)
        let addedIds = combinedIds.subtracting(trackedUserIds)

        for id in removedIds {
            postListeners[id]?.remove()
            postListeners[id] = nil
            paginationState[id] = nil
            removePosts(forAuthor: id)
        }

        trackedUserIds = combinedIds

        for id in addedIds {
            attachListener(for: id)
        }

        if !addedIds.isEmpty {
            Task {
                await self.fetchFeedPosts(reset: false, targetedUserIds: Array(addedIds))
            }
        }
    }
    
    func itemSummary(for itemId: String) -> ItemSummary? {
        itemSummaryCache[itemId]
    }

    func getItemName(for itemId: String) -> String {
        return itemSummaryCache[itemId]?.name ?? "Untitled Post"
    }

}

class MockFeedViewModel: FeedViewModel {
    init(posts: [PostModel]) {
        super.init() // calls the real init
        self.posts = posts // set the sample data
    }
    
    override func fetchFeedPosts(
        reset: Bool = false,
        targetedUserIds: [String]? = nil
    ) async {
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

// Inside ItemModel, add the following method at the bottom of its definition:
extension ItemModel {
    func updatingLikeCount(to count: Int) -> ItemModel {
        var updated = self
        updated.likedBy = Array(repeating: "placeholderUserId", count: count)
        return updated
    }
}
