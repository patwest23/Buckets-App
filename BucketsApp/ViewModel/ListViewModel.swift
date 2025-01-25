//
//  ListViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation
import Combine
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum SortingMode: String, CaseIterable {
    case manual
    case byDeadline
    case byCreationDate
    case byPriority
    case byTitle
}

@MainActor
class ListViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var items: [ItemModel] = []
    @Published var showImages: Bool = true
    @Published var hideCompleted: Bool = false
    @Published var sortingMode: SortingMode = .manual
    @Published var currentEditingItem: ItemModel?

    // MARK: - Firestore
    private let db = Firestore.firestore()  // No further settings changes here
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Initialization
    init() {
        // Removed Firestore settings code from here
        // Firestore is already configured once in AppDelegate or BucketsApp
    }

    // MARK: - Firestore CRUD Operations

    /// Loads all items from Firestore for the given user, throwing on error.
    func loadItems(userId: String) async throws {
        print("[ListViewModel] loadItems called for userId: \(userId)")

        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            db.collection("users")
                .document(userId)
                .collection("items")
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("[ListViewModel] Error in getDocuments: \(error)")
                        continuation.resume(throwing: error)
                    } else if let snapshot = snapshot {
                        continuation.resume(returning: snapshot)
                    } else {
                        let noDataError = NSError(
                            domain: "LoadItemsError",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "No snapshot returned."]
                        )
                        print("[ListViewModel] Error: no snapshot returned.")
                        continuation.resume(throwing: noDataError)
                    }
                }
        }

        print("[ListViewModel] Fetched \(snapshot.documents.count) documents from Firestore.")

        var tempItems: [ItemModel] = []
        for document in snapshot.documents {
            do {
                let decodedItem = try document.data(as: ItemModel.self)
                tempItems.append(decodedItem)
                print("[ListViewModel] Successfully decoded item with ID: \(decodedItem.id)")
            } catch {
                print("[ListViewModel] Error decoding item with ID \(document.documentID): \(error.localizedDescription)")
            }
        }

        self.items = tempItems
        print("[ListViewModel] Items successfully loaded from Firestore. items.count = \(items.count)")
    }

    /// Adds or updates an item in Firestore, then updates local state.
    func addOrUpdateItem(_ item: ItemModel, userId: String) async {
        print("[ListViewModel] addOrUpdateItem called for item ID: \(item.id)")
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    let documentRef = db
                        .collection("users")
                        .document(userId)
                        .collection("items")
                        .document(item.id.uuidString)

                    try documentRef.setData(from: item, merge: true) { error in
                        if let error = error {
                            print("[ListViewModel] setData error: \(error)")
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                } catch {
                    print("[ListViewModel] Encoding error in setData: \(error)")
                    continuation.resume(throwing: error)
                }
            }

            // Update local array
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item
                print("[ListViewModel] Updated existing item in local array, index = \(index)")
            } else {
                items.append(item)
                print("[ListViewModel] Appended new item to local array, new count = \(items.count)")
            }

            print("[ListViewModel] Item with ID \(item.id) successfully added/updated in Firestore.")
        } catch {
            print("[ListViewModel] Error adding/updating item \(item.id) in Firestore: \(error.localizedDescription)")
        }
    }

    /// Deletes an item from Firestore and removes it from local state.
    func deleteItem(_ item: ItemModel, userId: String) async {
        print("[ListViewModel] deleteItem called for item ID: \(item.id)")
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                db.collection("users")
                    .document(userId)
                    .collection("items")
                    .document(item.id.uuidString)
                    .delete { error in
                        if let error = error {
                            print("[ListViewModel] delete error: \(error)")
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
            }

            // Remove from the local array
            items.removeAll { $0.id == item.id }
            print("[ListViewModel] Item \(item.id) successfully deleted from Firestore and local array.")
        } catch {
            print("[ListViewModel] Error deleting item \(item.id) from Firestore: \(error.localizedDescription)")
        }
    }

    /// Deletes multiple items (by index set) from Firestore.
    func deleteItems(at indexSet: IndexSet, userId: String) async {
        print("[ListViewModel] deleteItems called for indexSet: \(indexSet)")
        let itemsToDelete = indexSet.map { items[$0] }
        for item in itemsToDelete {
            await deleteItem(item, userId: userId)
        }
    }

    /// Retrieves a single item from the local array, if needed.
    func getItem(by id: UUID) -> ItemModel? {
        items.first { $0.id == id }
    }

    // MARK: - Sorting
    func sortItems() {
        print("[ListViewModel] sortItems called, mode = \(sortingMode)")
        switch sortingMode {
        case .manual:
            // Preserve manual order (no action)
            return
        case .byDeadline:
            items.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .byCreationDate:
            items.sort { $0.creationDate < $1.creationDate }
        case .byPriority:
            items.sort { $0.priority.rawValue < $1.priority.rawValue }
        case .byTitle:
            items.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
        print("[ListViewModel] items sorted, first item: \(items.first?.name ?? "none")")
    }

    // MARK: - Filtering
    var filteredItems: [ItemModel] {
        hideCompleted
        ? items.filter { !$0.completed }
        : items
    }
}















 



