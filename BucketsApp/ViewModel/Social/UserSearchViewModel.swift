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
    @Published var debouncedSearchText: String = ""
    @Published var searchResults: [UserModel] = []
    @Published var suggestedUsers: [UserModel] = []
    @Published var errorMessage: String?
    @Published var currentFollowing: [String] = []
    @Published var allUsers: [UserModel] = []

    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .assign(to: \.debouncedSearchText, on: self)
            .store(in: &cancellables)

        $debouncedSearchText
            .sink { [weak self] newValue in
                Task { await self?.searchUsers() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Current User's Following
    func loadFollowing() async {
        guard let currentId = currentUserId else { return }

        do {
            let doc = try await db.collection("users").document(currentId).getDocument()
            if let data = doc.data(),
               let following = data["following"] as? [String] {
                self.currentFollowing = following
            }
        } catch {
            print("[UserSearchViewModel] loadFollowing error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Search by Partial Username or Name
    func searchUsers() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        let lowercasedQuery = searchText.lowercased()

        do {
            async let usernameSnap = db.collection("users")
                .whereField("username_lower", isGreaterThanOrEqualTo: lowercasedQuery)
                .whereField("username_lower", isLessThan: lowercasedQuery + "\u{f8ff}")
                .getDocuments()

            async let nameSnap = db.collection("users")
                .whereField("name_lower", isGreaterThanOrEqualTo: lowercasedQuery)
                .whereField("name_lower", isLessThan: lowercasedQuery + "\u{f8ff}")
                .getDocuments()

            let (usernameDocs, nameDocs) = try await (usernameSnap, nameSnap)

            let combined = usernameDocs.documents + nameDocs.documents
            var users = try combined.compactMap { try $0.data(as: UserModel.self) }

            let currentId = currentUserId ?? ""
            var uniqueUsers = Array(Set(users)).filter { $0.id != currentId }

            for i in uniqueUsers.indices {
                if let userId = uniqueUsers[i].id {
                    uniqueUsers[i].isFollowed = currentFollowing.contains(userId)
                }
            }

            self.searchResults = uniqueUsers

        } catch {
            print("[UserSearchViewModel] searchUsers error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Suggested Followers
    func loadSuggestedUsers() async {
        guard let currentId = currentUserId else { return }

        do {
            let currentUserDoc = try await db.collection("users").document(currentId).getDocument()
            guard let currentData = currentUserDoc.data(),
                  let currentFollowing = currentData["following"] as? [String] else {
                print("[UserSearchViewModel] Current user doc missing 'following' array.")
                return
            }

            self.currentFollowing = currentFollowing

            var potentialSuggestions = Set<String>()

            for friendId in currentFollowing {
                let friendDoc = try await db.collection("users").document(friendId).getDocument()
                guard let friendData = friendDoc.data(),
                      let friendFollowing = friendData["following"] as? [String] else {
                    continue
                }

                friendFollowing.forEach { potentialSuggestions.insert($0) }
            }

            potentialSuggestions.remove(currentId)
            potentialSuggestions.subtract(currentFollowing)

            var fetchedSuggestions: [UserModel] = []
            for userId in potentialSuggestions {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if var suggestedUser = try? userDoc.data(as: UserModel.self) {
                    suggestedUser.isFollowed = false
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
            try await currentUserRef.updateData([
                "following": FieldValue.arrayUnion([userToFollowId])
            ])
            try await userToFollowRef.updateData([
                "followers": FieldValue.arrayUnion([currentId])
            ])

            self.currentFollowing.append(userToFollowId)
            self.searchResults.removeAll { $0.id == userToFollowId }
            self.suggestedUsers.removeAll { $0.id == userToFollowId }

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
            try await currentUserRef.updateData([
                "following": FieldValue.arrayRemove([userToUnfollowId])
            ])
            try await userToUnfollowRef.updateData([
                "followers": FieldValue.arrayRemove([currentId])
            ])

            self.currentFollowing.removeAll { $0 == userToUnfollowId }

            print("[UserSearchViewModel] unfollowUser => \(currentId) unfollowed \(userToUnfollowId)")
        } catch {
            print("[UserSearchViewModel] unfollowUser error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load All Users (for MVP)
    func loadAllUsers() async {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            var users = try snapshot.documents.compactMap { try $0.data(as: UserModel.self) }
            let currentId = currentUserId ?? ""

            users = users.filter { $0.id != currentId }

            for i in users.indices {
                if let id = users[i].id {
                    users[i].isFollowed = currentFollowing.contains(id)
                }
            }

            self.allUsers = users
        } catch {
            print("[UserSearchViewModel] loadAllUsers error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
}
