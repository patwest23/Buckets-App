//
//  FollowViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/9/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

@MainActor
class FollowViewModel: ObservableObject {
    @Published var following: [FollowModel] = []
    @Published var followers: [FollowModel] = []
    @Published var followingUsers: [UserModel] = []
    @Published var followersUsers: [UserModel] = []
    @Published var allUsers: [UserModel] = []

    private let db = Firestore.firestore()

    func loadFollowingUsers(for userId: String) async {
        guard !userId.isEmpty else {
            print("[FollowViewModel] Provided userId is empty.")
            return
        }

        print("[FollowViewModel] Loading following users for userId: \(userId)")

        do {
            let snapshot = try await db.collection("follows")
                .whereField("followerId", isEqualTo: userId)
                .getDocuments()

            let loaded = snapshot.documents.compactMap { doc in
                try? doc.data(as: FollowModel.self)
            }

            self.following = loaded

            var users: [UserModel] = []
            for follow in loaded {
                if let user = try? await fetchUser(by: follow.followingId) {
                    users.append(user)
                } else {
                    print("[FollowViewModel] Failed to load user for id: \(follow.followingId)")
                }
            }

            self.followingUsers = users
            print("[FollowViewModel] Loaded following count: \(loaded.count)")
        } catch {
            print("[FollowViewModel] Error loading following: \(error.localizedDescription)")
        }
    }

    func loadFollowerUsers(for userId: String) async {
        guard !userId.isEmpty else {
            print("[FollowViewModel] Provided userId is empty.")
            return
        }

        print("[FollowViewModel] Loading follower users for userId: \(userId)")

        do {
            let snapshot = try await db.collection("follows")
                .whereField("followingId", isEqualTo: userId)
                .getDocuments()

            let loaded = snapshot.documents.compactMap { doc in
                try? doc.data(as: FollowModel.self)
            }

            self.followers = loaded

            var users: [UserModel] = []
            for follow in loaded {
                if let user = try? await fetchUser(by: follow.followerId) {
                    users.append(user)
                } else {
                    print("[FollowViewModel] Failed to load user for id: \(follow.followerId)")
                }
            }

            self.followersUsers = users
            print("[FollowViewModel] Loaded followers count: \(loaded.count)")
        } catch {
            print("[FollowViewModel] Error loading followers: \(error.localizedDescription)")
        }
    }

    private func fetchUser(by id: String) async throws -> UserModel? {
        let doc = try await db.collection("users").document(id).getDocument()
        return try doc.data(as: UserModel.self)
    }
}

#if DEBUG
extension FollowViewModel {
    static var mock: FollowViewModel {
        let vm = FollowViewModel()
        vm.followers = [
            FollowModel(id: "f1", followerId: "user1", followingId: "currentUser", timestamp: Date()),
            FollowModel(id: "f2", followerId: "user2", followingId: "currentUser", timestamp: Date())
        ]
        vm.following = [
            FollowModel(id: "f3", followerId: "currentUser", followingId: "user3", timestamp: Date())
        ]
        vm.followersUsers = [
            UserModel(id: "user1", email: "user1@example.com", createdAt: Date(), profileImageUrl: nil, name: "Alice", username: "@alice"),
            UserModel(id: "user2", email: "user2@example.com", createdAt: Date(), profileImageUrl: nil, name: "Bob", username: "@bob")
        ]
        vm.followingUsers = [
            UserModel(id: "user3", email: "user3@example.com", createdAt: Date(), profileImageUrl: nil, name: "Charlie", username: "@charlie")
        ]
        return vm
    }
}
#endif
