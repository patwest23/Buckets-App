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
    
    // The current logged-in user’s UID
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Search by Username or Name
    /// Searches Firestore for users whose `username` or `name` exactly matches `searchText`.
    /// For partial matches, you'd need more advanced indexing or a 3rd-party solution.
    func searchUsers() async {
        // If searchText is empty, clear results and return
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        do {
            // 1) Query: username == searchText
            let usernameQuerySnap = try await db.collection("users")
                .whereField("username", isEqualTo: searchText)
                .getDocuments()
            
            // 2) Query: name == searchText
            let nameQuerySnap = try await db.collection("users")
                .whereField("name", isEqualTo: searchText)
                .getDocuments()
            
            // 3) Decode results
            var allResults = [UserModel]()
            for doc in usernameQuerySnap.documents + nameQuerySnap.documents {
                // Safely decode into your UserModel
                if let user = try? doc.data(as: UserModel.self) {
                    allResults.append(user)
                }
            }
            
            // 4) Remove duplicates and self
            let uniqueResults = Array(Set(allResults)).filter { $0.id != currentUserId }
            
            // 5) Assign to published property
            self.searchResults = uniqueResults
            
        } catch {
            print("[UserSearchViewModel] searchUsers error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Suggested Followers
    /// Loads a list of “suggested” users, i.e. those who are followed by the people you follow.
    /// In other words, we look at `following` array of each user you follow, and gather that.
    func loadSuggestedUsers() async {
        guard let currentId = currentUserId else { return }
        
        do {
            // 1) Fetch the current user doc to get their following list
            let currentUserDoc = try await db.collection("users").document(currentId).getDocument()
            guard let currentData = currentUserDoc.data(),
                  let currentFollowing = currentData["following"] as? [String] else {
                print("[UserSearchViewModel] Current user doc missing 'following' field.")
                return
            }
            
            // We'll collect the “followed by your following” in a set to avoid duplicates
            var potentialSuggestions = Set<String>()
            
            // 2) For each user you follow, fetch that user’s doc and read _their_ following
            for friendId in currentFollowing {
                let friendDoc = try await db.collection("users").document(friendId).getDocument()
                guard let friendData = friendDoc.data(),
                      let friendFollowing = friendData["following"] as? [String] else {
                    continue
                }
                
                // 3) Add all friendFollowing userIds to the potential suggestions
                for userId in friendFollowing {
                    potentialSuggestions.insert(userId)
                }
            }
            
            // 4) Remove yourself and anyone you already follow
            potentialSuggestions.remove(currentId)
            potentialSuggestions.subtract(currentFollowing)
            
            // 5) Fetch those user docs from Firestore
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
        
        // Optionally, if you also track a "followers" array in the user being followed:
        let userToFollowRef = db.collection("users").document(userToFollowId)
        
        do {
            // 1) Add their ID to the current user’s "following" array
            try await currentUserRef.updateData([
                "following": FieldValue.arrayUnion([userToFollowId])
            ])
            
            // 2) (optional) Add current user ID to the target user’s "followers" array
            try await userToFollowRef.updateData([
                "followers": FieldValue.arrayUnion([currentId])
            ])
            
            // If you want immediate UI updates (e.g. removing from suggestedUsers):
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
            // 1) Remove their ID from "following"
            try await currentUserRef.updateData([
                "following": FieldValue.arrayRemove([userToUnfollowId])
            ])
            
            // 2) (optional) Remove the current user from their "followers"
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

class MockUserSearchViewModel: UserSearchViewModel {
    override init() {
        super.init()
        
        // Provide some static data right away
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
        // No real Firestore call—maybe just filter or do nothing for the preview
        print("[MockUserSearchViewModel] searchUsers() called in preview.")
    }
    
    override func loadSuggestedUsers() async {
        // Already have some suggested users set
        print("[MockUserSearchViewModel] loadSuggestedUsers() called in preview.")
    }
    
    override func followUser(_ user: UserModel) async {
        // In a real call, we’d update Firestore—here we just print
        print("[MockUserSearchViewModel] followUser(\(user.username ?? "")) in preview.")
    }
    
    override func unfollowUser(_ user: UserModel) async {
        // Same as above—just a stub for previews
        print("[MockUserSearchViewModel] unfollowUser(\(user.username ?? "")) in preview.")
    }
}
