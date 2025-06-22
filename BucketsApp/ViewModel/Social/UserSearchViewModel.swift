////
////  UserSearchViewModel.swift
////  BucketsApp
////
////  Created by Patrick Westerkamp on 3/9/25.
////
//
//import SwiftUI
//import Combine
//import FirebaseAuth
//import FirebaseFirestore
//
//@MainActor
//class UserSearchViewModel: ObservableObject {
//    // MARK: - Published Properties
//    // @Published var searchText: String = ""
//    // @Published var searchResults: [UserModel] = []
//    @Published var errorMessage: String?
//    @Published var allUsers: [UserModel] = []
//
//    private let db = Firestore.firestore()
//    private var cancellables = Set<AnyCancellable>()
//
//    private var currentUserId: String? {
//        Auth.auth().currentUser?.uid
//    }
//
//    init() {
//        // Removed Combine subscriptions setup for MVP
//    }
//
//    // MARK: - Search by Partial Username or Name
//    /*
//    func searchUsers() async {
//        guard !searchText.isEmpty else {
//            searchResults = []
//            return
//        }
//
//        let lowercasedQuery = searchText.lowercased()
//
//        do {
//            async let usernameSnap = db.collection("users")
//                .whereField("username_lower", isGreaterThanOrEqualTo: lowercasedQuery)
//                .whereField("username_lower", isLessThan: lowercasedQuery + "\u{f8ff}")
//                .getDocuments()
//
//            async let nameSnap = db.collection("users")
//                .whereField("name_lower", isGreaterThanOrEqualTo: lowercasedQuery)
//                .whereField("name_lower", isLessThan: lowercasedQuery + "\u{f8ff}")
//                .getDocuments()
//
//            let (usernameDocs, nameDocs) = try await (usernameSnap, nameSnap)
//
//            let combined = usernameDocs.documents + nameDocs.documents
//            let users = try combined.compactMap { try $0.data(as: UserModel.self) }
//
//            let currentId = currentUserId ?? ""
//            var uniqueUsers = Array(Set(users)).filter { $0.id != currentId }
//
//            for i in uniqueUsers.indices {
//                if let userId = uniqueUsers[i].id {
//                    uniqueUsers[i].isFollowed = currentFollowing.contains(userId)
//                }
//            }
//
//            await MainActor.run {
//                self.searchResults = uniqueUsers
//            }
//
//        } catch {
//            print("[UserSearchViewModel] searchUsers error:", error.localizedDescription)
//            self.errorMessage = error.localizedDescription
//        }
//    }
//    */
//
//
//    // MARK: - Follow
//    func followUser(_ user: UserModel) async {
//        guard let currentId = currentUserId else { return }
//        let userToFollowId = user.id
//
//        let currentUserRef = db.collection("users").document(currentId)
//        let userToFollowRef = db.collection("users").document(userToFollowId)
//
//        do {
//            async let updateCurrent: Void = currentUserRef.updateData([
//                "following": FieldValue.arrayUnion([userToFollowId])
//            ])
//            async let updateTarget: Void = userToFollowRef.updateData([
//                "followers": FieldValue.arrayUnion([currentId])
//            ])
//            _ = try await (updateCurrent, updateTarget)
//
//            // self.currentFollowing.append(userToFollowId)
//            // self.searchResults.removeAll { $0.id == userToFollowId }
//            self.allUsers.removeAll { $0.id == userToFollowId }
//
//            print("[UserSearchViewModel] followUser => \(currentId) now follows \(userToFollowId)")
//        } catch {
//            print("[UserSearchViewModel] followUser error:", error.localizedDescription)
//            self.errorMessage = error.localizedDescription
//        }
//    }
//
//    // MARK: - Unfollow
//    func unfollowUser(_ user: UserModel) async {
//        guard let currentId = currentUserId else { return }
//        let userToUnfollowId = user.id
//
//        let currentUserRef = db.collection("users").document(currentId)
//        let userToUnfollowRef = db.collection("users").document(userToUnfollowId)
//
//        do {
//            async let updateCurrent: Void = currentUserRef.updateData([
//                "following": FieldValue.arrayRemove([userToUnfollowId])
//            ])
//            async let updateTarget: Void = userToUnfollowRef.updateData([
//                "followers": FieldValue.arrayRemove([currentId])
//            ])
//            _ = try await (updateCurrent, updateTarget)
//
//            // self.currentFollowing.removeAll { $0 == userToUnfollowId }
//
//            print("[UserSearchViewModel] unfollowUser => \(currentId) unfollowed \(userToUnfollowId)")
//        } catch {
//            print("[UserSearchViewModel] unfollowUser error:", error.localizedDescription)
//            self.errorMessage = error.localizedDescription
//        }
//    }
//
//    // MARK: - Load All Users (for MVP)
//    func loadAllUsers() async {
//        guard let currentId = currentUserId else { return }
//        do {
//            let currentUserDoc = try await db.collection("users").document(currentId).getDocument()
//            let following = currentUserDoc.data()?["following"] as? [String] ?? []
//
//            let snapshot = try await db.collection("users").getDocuments()
//            var users = try snapshot.documents.compactMap { try $0.data(as: UserModel.self) }
//
//            users = users.filter { $0.id != currentId }
//
//            for i in users.indices {
//                let id = users[i].id
//                users[i].isFollowed = following.contains(id)
//            }
//
//            await MainActor.run {
//                self.allUsers = users
//            }
//
//        } catch {
//            print("[UserSearchViewModel] loadAllUsers error:", error.localizedDescription)
//            self.errorMessage = error.localizedDescription
//        }
//    }
//}
