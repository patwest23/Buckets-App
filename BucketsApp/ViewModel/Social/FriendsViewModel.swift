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
    @Published var isLoading: Bool = false

    private let db = Firestore.firestore()
    private var userDocListener: ListenerRegistration?

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    func loadFriendsData() async {
        isLoading = true
        defer { isLoading = false }
        guard let userId = currentUserId else { return }

        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let data: [String: Any] = await MainActor.run {
                userDoc.data() ?? [:]
            }
            let followingIds = data["following"] as? [String] ?? []
            let followerIds = data["followers"] as? [String] ?? []

            async let fetchedFollowing = fetchUsers(with: followingIds)
            async let fetchedFollowers = fetchUsers(with: followerIds)

            let (following, followers) = try await (fetchedFollowing, fetchedFollowers)

            self.followingUsers = Dictionary(grouping: following, by: \.documentId)
                .compactMapValues { $0.first }
                .values
                .sorted { ($0.username ?? "") < ($1.username ?? "") }

            self.followerUsers = Dictionary(grouping: followers, by: \.documentId)
                .compactMapValues { $0.first }
                .values
                .sorted { ($0.username ?? "") < ($1.username ?? "") }

            print("[FriendsViewModel] ✅ Following loaded count: \(following.count)")
            print("[FriendsViewModel] ✅ Followers loaded count: \(followers.count)")
            print("[FriendsViewModel] Following IDs: \(self.followingUsers.map { $0.id })")
            print("[FriendsViewModel] Follower IDs: \(self.followerUsers.map { $0.id })")
        } catch {
            self.errorMessage = error.localizedDescription
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

        try await withThrowingTaskGroup(of: UserModel?.self) { group in
            for id in ids {
                group.addTask {
                    let doc = try await self.db.collection("users").document(id).getDocument()
                    if var user = try? doc.data(as: UserModel.self) {
                        user.documentId = doc.documentID
                        return user
                    }
                    return nil
                }
            }

            for try await user in group {
                if let user = user {
                    users.append(user)
                }
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
        isLoading = true
        defer { isLoading = false }
        print("[FriendsViewModel] ⚙️ loadAllUsers started")

        await loadFriendsData()

        guard let currentUserId = currentUserId else {
            print("[FriendsViewModel] ❌ currentUserId is nil")
            return
        }

        do {
            let snapshot = try await db.collection("users").getDocuments()
            let users = snapshot.documents.compactMap { doc in
                var user = try? doc.data(as: UserModel.self)
                user?.documentId = doc.documentID

                if user?.username == nil || user?.documentId == nil {
                    print("[FriendsViewModel] ⚠️ Skipped user with bad data: \(doc.data())")
                }

                return user
            }
            print("[FriendsViewModel] 🔄 Total users fetched: \(users.count)")

            let excludedIds: Set<String> = Set(
                [currentUserId]
            )
            print("[FriendsViewModel] 🚫 Excluding IDs: \(excludedIds)")

            let filteredUsers = users.filter { user in
                guard let id = user.documentId else { return false }
                if excludedIds.contains(id) {
                    return false
                }
                // Ensure uniqueness across sections
                let alreadyFollowing = followingUsers.contains(where: { $0.id == user.id })
                let alreadyFollower = followerUsers.contains(where: { $0.id == user.id })
                if alreadyFollowing || alreadyFollower {
                    print("[FriendsViewModel] 🔁 Skipping user already followed or following: \(user.username ?? "nil") - \(user.id)")
                    return false
                }
                return true
            }
            let finalUsers = Array(filteredUsers.prefix(10))

            print("[FriendsViewModel] ✅ Explore users count: \(finalUsers.count)")
            finalUsers.forEach { user in
                let username = user.username ?? "nil"
                print("[FriendsViewModel] 👤 \(username) - \(String(describing: user.documentId))")
            }
            print("[FriendsViewModel] Explore IDs: \(finalUsers.map { $0.id })")
            self.allUsers = finalUsers
        } catch {
            self.errorMessage = error.localizedDescription
            print("[FriendsViewModel] ❌ Failed to load all users: \(error.localizedDescription)")
        }
    }
    
    func isUserFollowed(_ user: UserModel) -> Bool {
        return followingUsers.contains(where: { $0.id == user.id })
    }

    func startAllListeners() {
        startListeningToFriendChanges()
    }

    func follow(_ user: UserModel) async {
        guard let currentUserId = currentUserId else { return }

        do {
            let currentRef = db.collection("users").document(currentUserId)
            let targetRef = db.collection("users").document(user.id)

            let followingUpdate: [String: Any] = ["following": FieldValue.arrayUnion([user.id])]
            let followersUpdate: [String: Any] = ["followers": FieldValue.arrayUnion([currentUserId])]
            try await currentRef.updateData(followingUpdate)
            try await targetRef.updateData(followersUpdate)

            await loadFriendsData()
            await loadAllUsers()
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

            let followingUpdate: [String: Any] = ["following": FieldValue.arrayRemove([user.id])]
            let followersUpdate: [String: Any] = ["followers": FieldValue.arrayRemove([currentUserId])]
            try await currentRef.updateData(followingUpdate)
            try await targetRef.updateData(followersUpdate)

            await loadFriendsData()
            await loadAllUsers()
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

extension FriendsViewModel {
    var exploreUsers: [UserModel] {
        let followingIds = Set(followingUsers.map { $0.id })
        let followerIds = Set(followerUsers.map { $0.id })

        return allUsers.filter { user in
            !followingIds.contains(user.id) &&
            !followerIds.contains(user.id)
        }
    }

    var filteredSearchResults: [UserModel] {
        let lowercasedQuery = searchText.lowercased()
        return exploreUsers.filter { user in
            let name = user.name?.lowercased() ?? ""
            let username = user.username?.lowercased() ?? ""
            return name.contains(lowercasedQuery) || username.contains(lowercasedQuery)
        }
    }
}

