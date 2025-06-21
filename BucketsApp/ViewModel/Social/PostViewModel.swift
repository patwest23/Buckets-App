//
//  PostViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class PostViewModel: ObservableObject {
    
    // MARK: - Environment Objects
    /// Optionally injected user view model for username, etc.
    var userViewModel: UserViewModel?
    
    // MARK: - Published Properties
    @Published var posts: [PostModel] = []
    @Published var errorMessage: String?
    @Published var caption: String = ""
    @Published var isPosting = false
    @Published var taggedUserIds: [String] = []
    @Published var selectedItemID: String?
    @Published var injectedItems: [String: ItemModel] = [:]
    
    // MARK: - Firestore
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    /// Returns the UID of the currently authenticated user, or `nil` if none.
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    init() {
        print("[PostViewModel] init.")
    }
    
    deinit {
        // Hop onto the main actor asynchronously to stop the listener
        Task { @MainActor [weak self] in
            self?.stopListeningToPosts()
            print("[PostViewModel] deinit.")
        }
    }
    
    // MARK: - One-Time Fetch
    func loadPosts() async {
        guard let userId = userId else {
            print("[PostViewModel] loadPosts: userId is nil (not authenticated).")
            return
        }
        
        do {
            let snapshot = try await db
                .collection("users")
                .document(userId)
                .collection("posts")
                .getDocuments()
            
            let fetchedPosts = try snapshot.documents.compactMap {
                try $0.data(as: PostModel.self)
            }
            self.posts = fetchedPosts
            print("[PostViewModel] loadPosts: Fetched \(posts.count) posts for userId: \(userId)")
            
        } catch {
            print("[PostViewModel] loadPosts error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Real-Time Listener
    func startListeningToPosts() {
        guard let userId = userId else {
            print("[PostViewModel] startListeningToPosts: userId is nil (not authenticated).")
            return
        }
        
        stopListeningToPosts() // remove any existing listener
        
        let collectionRef = db
            .collection("users")
            .document(userId)
            .collection("posts")
        
        listenerRegistration = collectionRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[PostViewModel] startListeningToPosts error:", error.localizedDescription)
                self.errorMessage = error.localizedDescription
                return
            }
            guard let snapshot = snapshot else { return }
            
            do {
                let fetchedPosts = try snapshot.documents.compactMap {
                    try $0.data(as: PostModel.self)
                }
                self.posts = fetchedPosts
                print("[PostViewModel] startListeningToPosts: Received \(self.posts.count) posts.")
                
            } catch {
                print("[PostViewModel] Decoding error:", error.localizedDescription)
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func stopListeningToPosts() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        print("[PostViewModel] Stopped listening to posts.")
    }
    
    // MARK: - Post a New Item
    /// Creates and posts a new PostModel using the provided ItemModel.
    func postItem(with item: ItemModel) async {
        guard let userId = userViewModel?.user?.id, !userId.isEmpty else {
            print("[PostViewModel] postItem => userId is missing from userViewModel. Aborting.")
            return
        }
        print("DEBUG: postItem(with:) called => userId:", userId, "itemID:", item.id.uuidString)

        isPosting = true

        let newPost = PostModel(
            authorId: userId,
            authorUsername: userViewModel?.user?.username,
            itemId: item.id.uuidString,
            type: .completed, // or .added or .photos, depending on logic
            timestamp: Date(),
            caption: caption,
            taggedUserIds: taggedUserIds,
            likedBy: [],
            itemImageUrls: item.imageUrls
        )

        print("[PostViewModel] new post fields:", newPost)
        await addOrUpdatePost(post: newPost)
        print("[PostViewModel] postItem(with:) => Finished writing post to Firestore.")

        // Reset UI
        isPosting = false
        caption = ""
        taggedUserIds = []
        selectedItemID = nil
    }
    
    // MARK: - Fetch the Item from Firestore
    /// Loads an `ItemModel` from `/users/{userId}/items/{itemID}`.
    /// Returns `nil` if the doc doesn't exist or decoding fails.
    private func fetchItemFromFirestore(itemID: String) async throws -> ItemModel? {
        guard let userId = userId else { return nil }
        
        let docRef = db
            .collection("users")
            .document(userId)
            .collection("items")
            .document(itemID)
        
        let snapshot = try await docRef.getDocument()
        print("[PostViewModel] fetchItemFromFirestore => Snapshot exists:", snapshot.exists)
        guard snapshot.exists else {
            return nil
        }
        
        // Decode the snapshot into an ItemModel
        let item = try snapshot.data(as: ItemModel.self)
        print("[PostViewModel] fetchItemFromFirestore => Decoded item:", item.name)
        return item
    }
    
    // MARK: - Add or Update
    func addOrUpdatePost(post: PostModel) async {
        var post = post
        guard let userId = userViewModel?.user?.id, !userId.isEmpty else {
            print("[PostViewModel] addOrUpdatePost => userId is missing from userViewModel. Cannot save post.")
            return
        }
        // Ensure authorId is set
        if post.authorId.isEmpty {
            post.authorId = userId
        }
        if post.id == nil {
            post.id = UUID().uuidString
        }
        let postDocId = post.id!
        let docRef = db
            .collection("users")
            .document(userId)
            .collection("posts")
            .document(postDocId)
        do {
            let encoded = try Firestore.Encoder().encode(post)
            print("[PostViewModel] 🔒 Preparing to write post:")
            print("  id: \(post.id ?? "nil")")
            print("  itemId: \(post.itemId)")
            print("  imageURLs: \(post.itemImageUrls)")
            try await docRef.setData(encoded, merge: true)
            print("[PostViewModel] addOrUpdatePost => Wrote post \(postDocId) to Firestore. itemId:", post.itemId)
            // Update local posts array with the saved post
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx] = post
            } else {
                posts.append(post)
            }
        } catch {
            print("[PostViewModel] addOrUpdatePost => Error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Delete
    func deletePost(_ post: PostModel) async {
        guard let userId = userId else {
            print("[PostViewModel] deletePost: userId is nil (not authenticated).")
            return
        }
        guard let docId = post.id else {
            print("[PostViewModel] deletePost: post.id is nil. Cannot delete.")
            return
        }
        
        let docRef = db
            .collection("users")
            .document(userId)
            .collection("posts")
            .document(docId)
        
        do {
            try await docRef.delete()
            self.posts.removeAll { $0.id == docId }
            print("[PostViewModel] deletePost: Deleted post \(docId) from /users/\(userId)/posts.")
        } catch {
            print("[PostViewModel] deletePost error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Fetch Item for Post
    /// Fetches the ItemModel for a given PostModel's itemId from Firestore.
    func fetchItem(for post: PostModel) async -> ItemModel? {
        if let injected = injectedItems[post.itemId] {
            print("[PostViewModel] ⚡️ Using injected item for preview: \(injected.name)")
            return injected
        }

        let userId = post.authorId
        print("[PostViewModel] fetchItem: Attempting for itemId: \(post.itemId) by authorId: \(userId)")

        let docRef = db
            .collection("users")
            .document(userId)
            .collection("items")
            .document(post.itemId)

        do {
            let snapshot = try await docRef.getDocument()
            guard snapshot.exists else {
                print("[PostViewModel] fetchItem: ❌ Document not found at /users/\(userId)/items/\(post.itemId)")
                return nil
            }

            let item = try snapshot.data(as: ItemModel.self)
            print("[PostViewModel] fetchItem: ✅ Loaded item: \(item.name) from user: \(userId)")
            return item
        } catch {
            print("[PostViewModel] fetchItem: 🛑 Error loading item for \(post.itemId) by user \(userId):", error.localizedDescription)
            return nil
        }
    }
}
