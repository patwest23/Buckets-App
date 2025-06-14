//
//  FollowViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

//import Foundation
//import Combine
//import SwiftUI
//import FirebaseAuth
//import FirebaseFirestore
//import UIKit
//
//@MainActor
//class FollowViewModel: ObservableObject {
//    @Published var following: [FollowModel] = []
//    @Published var followers: [FollowModel] = []
//    @Published var followingUsers: [UserModel] = []
//    @Published var followersUsers: [UserModel] = []
//    @Published var allUsers: [UserModel] = []
//
//    private let db = Firestore.firestore()
//
//    func addOrUpdateFollow(_ follow: FollowModel) async {
//        guard !follow.followerId.isEmpty, !follow.followingId.isEmpty else {
//            print("[FollowViewModel] Cannot save: followerId or followingId is empty.")
//            return
//        }
//
//        let docRef = db.collection("follows").document(follow.id)
//
//        do {
//            let encoded = try Firestore.Encoder().encode(follow)
//            try await docRef.setData(encoded, merge: true)
//            print("[FollowViewModel] Saved follow relationship: \(follow.followerId) -> \(follow.followingId)")
//
//            if let idx = following.firstIndex(where: { $0.id == follow.id }) {
//                following[idx] = follow
//            } else {
//                following.append(follow)
//            }
//        } catch {
//            print("[FollowViewModel] Error saving follow relationship:", error.localizedDescription)
//        }
//    }
//
//    func deleteFollow(_ follow: FollowModel) async {
//        let docRef = db.collection("follows").document(follow.id)
//
//        do {
//            try await docRef.delete()
//            following.removeAll { $0.id == follow.id }
//            followers.removeAll { $0.id == follow.id }
//            print("[FollowViewModel] Deleted follow relationship: \(follow.id)")
//        } catch {
//            print("[FollowViewModel] Error deleting follow relationship:", error.localizedDescription)
//        }
//    }
//
//    func getFollow(by id: String) -> FollowModel? {
//        return following.first { $0.id == id } ?? followers.first { $0.id == id }
//    }
//}
