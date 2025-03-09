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
    
    // MARK: - Published Properties
    @Published var posts: [PostModel] = []
    @Published var errorMessage: String?
    
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
        stopListeningToPosts()
        print("[PostViewModel] deinit.")
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
    
    // MARK: - Add or Update
    func addOrUpdatePost(_ post: PostModel) async {
        guard let userId = userId else {
            print("[PostViewModel] addOrUpdatePost: userId is nil. Cannot save post.")
            return
        }
        
        // If `post.id` is nil, Firestore will assign a new doc ID automatically.
        // Or you can generate it if you prefer: `UUID().uuidString`.
        let postDocId = post.id ?? UUID().uuidString
        
        let docRef = db
            .collection("users")
            .document(userId)
            .collection("posts")
            .document(postDocId)
        
        do {
            try docRef.setData(from: post, merge: true)
            print("[PostViewModel] addOrUpdatePost => wrote post \(postDocId) to Firestore.")
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
