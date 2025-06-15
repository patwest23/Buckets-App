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

    deinit {
        userDocListener?.remove()
    }
}
