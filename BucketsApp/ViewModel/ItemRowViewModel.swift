//
//  ItemRowViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/30/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class ItemRowViewModel: ObservableObject {
    @Published var item: ItemModel
    private let db = Firestore.firestore()
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    init(item: ItemModel) {
        self.item = item
    }

    /// Toggle the completed state of the item and sync with Firestore
    func toggleCompleted() async {
        item.completed.toggle()
        await updateItemInFirestore(item: item)
    }

    /// Update the item in Firestore
    func updateItemInFirestore(item: ItemModel) async {
        guard let userId = userId else { return }
        let itemRef = db.collection("users")
            .document(userId)
            .collection("bucketList")
            .document(item.id.uuidString)

        do {
            try await itemRef.setData(from: item, merge: true)
            print("Item updated successfully in Firestore.")
        } catch {
            print("Error updating item in Firestore: \(error.localizedDescription)")
        }
    }

    /// Delete the item from Firestore
    func deleteItemFromFirestore() async {
        guard let userId = userId else { return }
        let itemRef = db.collection("users")
            .document(userId)
            .collection("bucketList")
            .document(item.id.uuidString)

        do {
            try await itemRef.delete()
            print("Item deleted successfully from Firestore.")
        } catch {
            print("Error deleting item from Firestore: \(error.localizedDescription)")
        }
    }
}

