//
//  UserViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 12/29/24.
//

import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
class UserViewModel: ObservableObject {
    @Published var user: UserModel?

    private let db = Firestore.firestore()

    func fetchUserData(userId: String) async {
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            self.user = try snapshot.data(as: UserModel.self)
        } catch {
            print("Error fetching user data: \(error)")
        }
    }

    func updateUserProfile(_ updatedUser: UserModel) async {
        guard let userId = updatedUser.id else {
            print("Error: User ID is nil")
            return
        }

        do {
            try await db.collection("users").document(userId).setData(from: updatedUser)
            self.user = updatedUser
        } catch {
            print("Error updating user profile: \(error)")
        }
    }
}
