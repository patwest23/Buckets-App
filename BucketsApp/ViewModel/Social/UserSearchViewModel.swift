//
//  UserSearchViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class UserSearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchText: String = ""
    @Published var searchResults: [UserModel] = []
    @Published var suggestedUsers: [UserModel] = []
    
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    /// The current logged-in user’s UID
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Search by Lowercased Username or Name
    /// Uses `username_lower` and `name_lower` for case-insensitive matching.
    /// If your docs only have `username` or `name`, you must store them in lowercased form already.
    func searchUsers() async {
        // If searchText is empty, clear results
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        let lowercasedQuery = searchText.lowercased()
        
        do {
            // 1) Query: username_lower == lowercasedQuery
            let usernameSnap = try await db.collection("users")
                .whereField("username_lower", isEqualTo: lowercasedQuery)
                .getDocuments()
            
            // 2) Query: name_lower == lowercasedQuery
            let nameSnap = try await db.collection("users")
                .whereField("name_lower", isEqualTo: lowercasedQuery)
                .getDocuments()
            
            // 3) Decode results
            var allResults = [UserModel]()
            for doc in usernameSnap.documents + nameSnap.documents {
                if let user = try? doc.data(as: UserModel.self) {
                    allResults.append(user)
                }
            }
            
            // 4) Filter out duplicates & self
            let uniqueResults = Array(Set(allResults)).filter { $0.id != currentUserId }
            
            // 5) Update published property
            self.searchResults = uniqueResults
            
        } catch {
            print("[UserSearchViewModel] searchUsers error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Suggested Followers
    /// Loads a list of users who are followed by the people you follow
    func loadSuggestedUsers() async {
        guard let currentId = currentUserId else { return }
        
        do {
            // 1) Fetch current user doc to get their 'following' list
            let currentUserDoc = try await db.collection("users").document(currentId).getDocument()
            guard let currentData = currentUserDoc.data(),
                  let currentFollowing = currentData["following"] as? [String] else {
                print("[UserSearchViewModel] Current user doc missing 'following' array.")
                return
            }
            
            var potentialSuggestions = Set<String>()
            
            // 2) For each followed user, fetch their doc & read their 'following' array
            for friendId in currentFollowing {
                let friendDoc = try await db.collection("users").document(friendId).getDocument()
                guard let friendData = friendDoc.data(),
                      let friendFollowing = friendData["following"] as? [String] else {
                    continue
                }
                // 3) Add friendFollowing user IDs to our set
                friendFollowing.forEach { potentialSuggestions.insert($0) }
            }
            
            // 4) Remove yourself & anyone you already follow
            potentialSuggestions.remove(currentId)
            potentialSuggestions.subtract(currentFollowing)
            
            // 5) Fetch those user docs
            var fetchedSuggestions: [UserModel] = []
            for userId in potentialSuggestions {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let suggestedUser = try? userDoc.data(as: UserModel.self) {
                    fetchedSuggestions.append(suggestedUser)
                }
            }
            self.suggestedUsers = fetchedSuggestions
            
        } catch {
            print("[UserSearchViewModel] loadSuggestedUsers error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Follow
    func followUser(_ user: UserModel) async {
        guard let currentId = currentUserId else { return }
        guard let userToFollowId = user.id else { return }
        
        let currentUserRef = db.collection("users").document(currentId)
        let userToFollowRef = db.collection("users").document(userToFollowId)
        
        do {
            // Add their ID to this user's following array
            try await currentUserRef.updateData([
                "following": FieldValue.arrayUnion([userToFollowId])
            ])
            
            // Optionally add current user to their followers
            try await userToFollowRef.updateData([
                "followers": FieldValue.arrayUnion([currentId])
            ])
            
            // Remove from local results
            self.suggestedUsers.removeAll { $0.id == userToFollowId }
            self.searchResults.removeAll { $0.id == userToFollowId }
            
            print("[UserSearchViewModel] followUser => \(currentId) now follows \(userToFollowId)")
        } catch {
            print("[UserSearchViewModel] followUser error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Unfollow
    func unfollowUser(_ user: UserModel) async {
        guard let currentId = currentUserId else { return }
        guard let userToUnfollowId = user.id else { return }
        
        let currentUserRef = db.collection("users").document(currentId)
        let userToUnfollowRef = db.collection("users").document(userToUnfollowId)
        
        do {
            // Remove them from 'following'
            try await currentUserRef.updateData([
                "following": FieldValue.arrayRemove([userToUnfollowId])
            ])
            
            // Remove current user from their 'followers'
            try await userToUnfollowRef.updateData([
                "followers": FieldValue.arrayRemove([currentId])
            ])
            
            print("[UserSearchViewModel] unfollowUser => \(currentId) unfollowed \(userToUnfollowId)")
        } catch {
            print("[UserSearchViewModel] unfollowUser error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Mock For Previews
class MockUserSearchViewModel: UserSearchViewModel {
    override init() {
        super.init()
        self.searchResults = [
            UserModel(
                id: "user_123",
                email: "alice@example.com",
                createdAt: Date(),
                profileImageUrl: nil,
                name: "Alice Wonderland",
                username: "@alice"
            ),
            UserModel(
                id: "user_456",
                email: "bob@example.com",
                createdAt: Date(),
                profileImageUrl: nil,
                name: "Bob Builder",
                username: "@bob"
            )
        ]
        self.suggestedUsers = [
            UserModel(
                id: "user_789",
                email: "charlie@example.com",
                createdAt: Date(),
                profileImageUrl: nil,
                name: "Charlie Brown",
                username: "@charlie"
            )
        ]
    }
    
    override func searchUsers() async {
        print("[MockUserSearchViewModel] searchUsers() called in preview.")
    }
    
    override func loadSuggestedUsers() async {
        print("[MockUserSearchViewModel] loadSuggestedUsers() called in preview.")
    }
    
    override func followUser(_ user: UserModel) async {
        print("[MockUserSearchViewModel] followUser(\(user.username ?? "")) in preview.")
    }
    
    override func unfollowUser(_ user: UserModel) async {
        print("[MockUserSearchViewModel] unfollowUser(\(user.username ?? "")) in preview.")
    }
}
