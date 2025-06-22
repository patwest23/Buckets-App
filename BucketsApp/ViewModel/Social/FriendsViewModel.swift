//
//  FriendsViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/12/25.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var followingUsers: [UserModel] = []
    @Published var followerUsers: [UserModel] = []
    
    @Published var searchText: String = ""
    @Published var searchResults: [UserModel] = []
    @Published var allUsers: [UserModel] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var userDocListener: ListenerRegistration?

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    func loadFriendsData() async {
        guard let userId = currentUserId else { return }

        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let followingIds = userDoc.data()?["following"] as? [String] ?? []
            let followerIds = userDoc.data()?["followers"] as? [String] ?? []

            async let fetchedFollowing = fetchUsers(with: followingIds)
            async let fetchedFollowers = fetchUsers(with: followerIds)

            let (following, followers) = try await (fetchedFollowing, fetchedFollowers)

            self.followingUsers = following
            self.followerUsers = followers
        } catch {
            print("[FriendsViewModel] Error loading friends data: \(error.localizedDescription)")
        }
    }

    func startListeningToFriendChanges() {
        guard let userId = currentUserId else { return }

        userDocListener?.remove()

        userDocListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("[FriendsViewModel] Listener error:", error.localizedDescription)
                    return
                }

                Task {
                    await self.loadFriendsData()
                }
            }
    }

    private func fetchUsers(with ids: [String]) async throws -> [UserModel] {
        var users: [UserModel] = []

        for id in ids {
            let doc = try await db.collection("users").document(id).getDocument()
            if let user = try? doc.data(as: UserModel.self) {
                users.append(user)
            }
        }

        return users
    }
    
    func searchUsers() {
        let lowercasedQuery = searchText.lowercased()
        searchResults = allUsers.filter { user in
            guard let name = user.name?.lowercased(),
                  let username = user.username?.lowercased() else {
                return false
            }
            return name.contains(lowercasedQuery) || username.contains(lowercasedQuery)
        }
    }
    
    func loadAllUsers() async {
        guard let currentUserId = currentUserId else { return }

        do {
            let snapshot = try await db.collection("users").getDocuments()
            let users = snapshot.documents.compactMap { try? $0.data(as: UserModel.self) }
            let filteredUsers = users.filter { $0.documentId != currentUserId }
            self.allUsers = Array(filteredUsers.prefix(10))
        } catch {
            print("[FriendsViewModel] Failed to load all users: \(error.localizedDescription)")
        }
    }
    
    func isUserFollowed(_ user: UserModel) -> Bool {
        return followingUsers.contains(where: { $0.id == user.id })
    }

    func follow(_ user: UserModel) async {
        guard let currentUserId = currentUserId else { return }

        do {
            let currentRef = db.collection("users").document(currentUserId)
            let targetRef = db.collection("users").document(user.id)

            try await currentRef.updateData(["following": FieldValue.arrayUnion([user.id])])
            try await targetRef.updateData(["followers": FieldValue.arrayUnion([currentUserId])])
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to follow user: \(error.localizedDescription)"
            }
        }
    }

    func unfollow(_ user: UserModel) async {
        guard let currentUserId = currentUserId else { return }

        do {
            let currentRef = db.collection("users").document(currentUserId)
            let targetRef = db.collection("users").document(user.id)

            try await currentRef.updateData(["following": FieldValue.arrayRemove([user.id])])
            try await targetRef.updateData(["followers": FieldValue.arrayRemove([currentUserId])])
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to unfollow user: \(error.localizedDescription)"
            }
        }
    }

    deinit {
        userDocListener?.remove()
    }
}

extension FriendsViewModel {
    static var mock: FriendsViewModel {
        let vm = FriendsViewModel()

        let user1 = UserModel(documentId: "1", email: "alice@test.com", profileImageUrl: nil, name: "Alice", username: "@alice")
        let user2 = UserModel(documentId: "2", email: "bob@test.com", profileImageUrl: nil, name: "Bob", username: "@bob")
        let user3 = UserModel(documentId: "3", email: "charlie@test.com", profileImageUrl: nil, name: "Charlie", username: "@charlie")

        vm.allUsers = [user1, user2]
        vm.followingUsers = [user2]
        vm.followerUsers = [user3]

        return vm
    }
}
