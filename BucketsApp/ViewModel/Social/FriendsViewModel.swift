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
    @Published var allUsers: [UserModel] = []
    @Published var remoteSearchResults: [UserModel] = []
    @Published var isSearchingRemotely: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private var loadingRequestCount = 0

    private let db = Firestore.firestore()
    private var userDocListener: ListenerRegistration?
    private var searchTask: Task<Void, Never>?

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    // Prefer Firestore documentId; fall back to id if present in older models
    private func resolvedId(for user: UserModel) -> String? {
        return user.documentId ?? (user.id.isEmpty ? nil : user.id)
    }

    private func beginLoading(showIndicator: Bool) {
        guard showIndicator else { return }
        loadingRequestCount += 1
        if !isLoading {
            isLoading = true
        }
    }

    private func endLoading(showIndicator: Bool) {
        guard showIndicator else { return }
        loadingRequestCount = max(0, loadingRequestCount - 1)
        if loadingRequestCount == 0 {
            isLoading = false
        }
    }

    func loadFriendsData(showLoadingIndicator: Bool = true) async {
        beginLoading(showIndicator: showLoadingIndicator)
        defer { endLoading(showIndicator: showLoadingIndicator) }
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
            print("[FriendsViewModel] Following IDs: \(self.followingUsers.map { $0.documentId ?? $0.id })")
            print("[FriendsViewModel] Follower IDs: \(self.followerUsers.map { $0.documentId ?? $0.id })")
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
                    await self.loadFriendsData(showLoadingIndicator: false)
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
    
    func handleSearchChange() {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            searchTask?.cancel()
            searchTask = nil
            remoteSearchResults = []
            isSearchingRemotely = false
            return
        }

        searchTask?.cancel()
        isSearchingRemotely = true
        remoteSearchResults = []
        let normalizedQuery = trimmedQuery.lowercased()

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            await self?.performRemoteSearch(for: normalizedQuery)
        }
    }

    private func performRemoteSearch(for query: String) async {
        do {
            async let usernameSnapshot = db.collection("users")
                .whereField("username_lower", isGreaterThanOrEqualTo: query)
                .whereField("username_lower", isLessThan: query + "\u{f8ff}")
                .limit(to: 25)
                .getDocuments()

            async let nameSnapshot = db.collection("users")
                .whereField("name_lower", isGreaterThanOrEqualTo: query)
                .whereField("name_lower", isLessThan: query + "\u{f8ff}")
                .limit(to: 25)
                .getDocuments()

            let (usernameDocs, nameDocs) = try await (usernameSnapshot, nameSnapshot)
            let combinedDocs = usernameDocs.documents + nameDocs.documents

            var seenIds = Set<String>()
            var results: [UserModel] = []
            let currentId = currentUserId

            for doc in combinedDocs {
                let id = doc.documentID
                guard !seenIds.contains(id) else { continue }
                if let currentId, currentId == id { continue }

                if var user = try? doc.data(as: UserModel.self) {
                    user.documentId = id
                    results.append(user)
                    seenIds.insert(id)
                }
            }

            let activeQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard activeQuery == query else { return }

            remoteSearchResults = results.sorted { lhs, rhs in
                let leftKey = lhs.username?.lowercased() ?? lhs.name?.lowercased() ?? ""
                let rightKey = rhs.username?.lowercased() ?? rhs.name?.lowercased() ?? ""
                return leftKey < rightKey
            }
            isSearchingRemotely = false
            searchTask = nil
        } catch {
            guard !Task.isCancelled else { return }
            let activeQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard activeQuery == query else { return }

            print("[FriendsViewModel] ❌ Remote search failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            remoteSearchResults = []
            isSearchingRemotely = false
            searchTask = nil
        }
    }
    
    func loadAllUsers(showLoadingIndicator: Bool = true) async {
        beginLoading(showIndicator: showLoadingIndicator)
        defer { endLoading(showIndicator: showLoadingIndicator) }
        print("[FriendsViewModel] ⚙️ loadAllUsers started")

        await loadFriendsData(showLoadingIndicator: false)

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
                let userKey = resolvedId(for: user)
                let alreadyFollowing = followingUsers.contains { resolvedId(for: $0) == userKey }
                let alreadyFollower = followerUsers.contains { resolvedId(for: $0) == userKey }
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
            print("[FriendsViewModel] Explore IDs: \(finalUsers.map { $0.documentId ?? $0.id })")
            self.allUsers = finalUsers
        } catch {
            self.errorMessage = error.localizedDescription
            print("[FriendsViewModel] ❌ Failed to load all users: \(error.localizedDescription)")
        }
    }
    
    func isUserFollowed(_ user: UserModel) -> Bool {
        return followingUsers.contains { resolvedId(for: $0) == resolvedId(for: user) }
    }
    
    var exploreUsers: [UserModel] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard q.isEmpty else {
            return searchExploreResults
        }

        let followingIds = Set(followingUsers.compactMap { resolvedId(for: $0) })
        let followerIds = Set(followerUsers.compactMap { resolvedId(for: $0) })

        return allUsers.filter { user in
            guard let key = resolvedId(for: user) else { return false }
            return !followingIds.contains(key) && !followerIds.contains(key)
        }
    }

    var filteredFollowing: [UserModel] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return followingUsers }
        return followingUsers.filter { matches(user: $0, query: q) }
    }

    var filteredFollowers: [UserModel] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return followerUsers }
        return followerUsers.filter { matches(user: $0, query: q) }
    }

    private var searchExploreResults: [UserModel] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        var seen = Set<String>()
        var results: [UserModel] = []

        let localPool = followingUsers + followerUsers + allUsers
        let localMatches = localPool.filter { matches(user: $0, query: q) }
        appendUnique(localMatches, to: &results, seen: &seen)
        appendUnique(remoteSearchResults, to: &results, seen: &seen)

        return results
    }

    private func matches(user: UserModel, query: String) -> Bool {
        user.name?.lowercased().contains(query) == true ||
        user.username?.lowercased().contains(query) == true
    }

    private func appendUnique(_ users: [UserModel], to results: inout [UserModel], seen: inout Set<String>) {
        for var user in users {
            guard let key = resolvedId(for: user) else { continue }
            if seen.insert(key).inserted {
                if user.documentId == nil {
                    user.documentId = key
                }
                results.append(user)
            }
        }
    }

    func startAllListeners() {
        startListeningToFriendChanges()
        Task { await loadAllUsers(showLoadingIndicator: false) }
    }

    func follow(_ user: UserModel) async {
        guard let currentUserId = currentUserId else { return }

        do {
            let currentRef = db.collection("users").document(currentUserId)
            let targetRef = db.collection("users").document(resolvedId(for: user) ?? "")

            let followingUpdate: [String: Any] = ["following": FieldValue.arrayUnion([resolvedId(for: user) ?? ""])]
            let followersUpdate: [String: Any] = ["followers": FieldValue.arrayUnion([currentUserId])]
            try await currentRef.updateData(followingUpdate)
            try await targetRef.updateData(followersUpdate)

            await loadFriendsData(showLoadingIndicator: false)
            await loadAllUsers(showLoadingIndicator: false)
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
            let targetRef = db.collection("users").document(resolvedId(for: user) ?? "")

            let followingUpdate: [String: Any] = ["following": FieldValue.arrayRemove([resolvedId(for: user) ?? ""])]
            let followersUpdate: [String: Any] = ["followers": FieldValue.arrayRemove([currentUserId])]
            try await currentRef.updateData(followingUpdate)
            try await targetRef.updateData(followersUpdate)

            await loadFriendsData(showLoadingIndicator: false)
            await loadAllUsers(showLoadingIndicator: false)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to unfollow user: \(error.localizedDescription)"
            }
        }
    }

    deinit {
        userDocListener?.remove()
        searchTask?.cancel()
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


