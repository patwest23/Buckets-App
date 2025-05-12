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
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // MARK: - Published Properties
    @Published var posts: [PostModel] = []
    @Published var errorMessage: String?
    @Published var caption: String = ""
    @Published var isPosting = false
    @Published var taggedUserIds: [String] = []
    @Published var selectedItemID: String?
    
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
    /// Fetches the `ItemModel` from Firestore and embeds its fields in a new `PostModel`.
    func postItem() {
        guard let itemID = selectedItemID else {
            print("[PostViewModel] postItem => selectedItemID is nil. Aborting.")
            return
        }
        guard let userId = userId else {
            print("[PostViewModel] postItem => userId is nil. Aborting.")
            return
        }
        
        print("DEBUG: postItem() called => userId:", userId, "itemID:", itemID)
        
        isPosting = true

        Task {
            do {
                guard let item = try await fetchItemFromFirestore(itemID: itemID) else {
                    print("[PostViewModel] postItem => No item found with ID: \(itemID)")
                    isPosting = false
                    return
                }
                
                print("DEBUG: Fetched item doc successfully:", item.name)

                let newPost = PostModel(
                    authorId: userId,
                    authorUsername: onboardingViewModel.user?.username, // optional if available
                    itemId: itemID,
                    type: .completed, // or .added or .photos, depending on logic
                    timestamp: Date(),
                    caption: caption,
                    taggedUserIds: taggedUserIds,
                    likedBy: [],
                    
                    itemName: item.name,
                    itemCompleted: item.completed,
                    itemLocation: item.location,
                    itemDueDate: item.dueDate,
                    itemImageUrls: item.allImageUrls
                )

                await addOrUpdatePost(newPost)
                
            } catch {
                print("[PostViewModel] postItem => Error fetching item: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
            }
            
            // 4) Reset UI
            isPosting = false
            caption = ""
            taggedUserIds = []
            selectedItemID = nil
        }
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
        guard snapshot.exists else {
            return nil
        }
        
        // Decode the snapshot into an ItemModel
        let item = try snapshot.data(as: ItemModel.self)
        return item
    }
    
    // MARK: - Add or Update
    func addOrUpdatePost(_ post: PostModel) async {
        guard let userId = userId else {
            print("[PostViewModel] addOrUpdatePost => userId is nil. Cannot save post.")
            return
        }
        
        let postDocId = post.id ?? UUID().uuidString
        let docRef = db
            .collection("users")
            .document(userId)
            .collection("posts")
            .document(postDocId)
        
        print("DEBUG: Writing post doc => /users/\(userId)/posts/\(postDocId) itemName:", post.itemName)
        
        do {
            try docRef.setData(from: post, merge: true)
            print("[PostViewModel] addOrUpdatePost => Wrote post \(postDocId) to Firestore. itemName:", post.itemName)
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
}
