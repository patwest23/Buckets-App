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
    private let db = Firestore.firestore()
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Initialization
    init() {
        // Enable Firestore’s offline persistence via cacheSettings
        let settings = FirestoreSettings()
        let persistentCache = PersistentCacheSettings()
        // persistentCache.sizeBytes = 10485760 // (Optional) 10MB cache size, for example
        settings.cacheSettings = persistentCache
        db.settings = settings
    }

    // MARK: - Firestore CRUD Operations

    /// Loads all items from Firestore for the given user.
    func loadItems(userId: String) async {
        do {
            // Convert Firestore's completion-based getDocuments into an async call
            let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
                db.collection("users")
                  .document(userId)
                  .collection("items")
                  .getDocuments { snapshot, error in
                      if let error = error {
                          continuation.resume(throwing: error)
                      } else if let snapshot = snapshot {
                          continuation.resume(returning: snapshot)
                      } else {
                          // In theory, Firestore returns an empty snapshot rather than nil,
                          // but just in case, throw an error.
                          let noDataError = NSError(
                              domain: "LoadItemsError",
                              code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "No snapshot returned."]
                          )
                          continuation.resume(throwing: noDataError)
                      }
                  }
            }

            // Map Firestore documents to `ItemModel` array
            self.items = snapshot.documents.compactMap { document in
                do {
                    return try document.data(as: ItemModel.self)
                } catch {
                    print("Error decoding item with ID \(document.documentID): \(error.localizedDescription)")
                    return nil
                }
            }
            print("Items successfully loaded from Firestore.")
        } catch {
            print("Error loading items from Firestore: \(error.localizedDescription)")
        }
    }

    /// Adds or updates an item in Firestore, then updates local state.
    func addOrUpdateItem(_ item: ItemModel, userId: String) async {
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
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                } catch {
                    // If encoding fails (invalid field in `ItemModel`), throw immediately
                    continuation.resume(throwing: error)
                }
            }

            // Update local array
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item
            } else {
                items.append(item)
            }
            print("Item with ID \(item.id) successfully added/updated in Firestore.")
        } catch {
            print("Error adding/updating item \(item.id) in Firestore: \(error.localizedDescription)")
        }
    }

    /// Deletes an item from Firestore and removes it from local state.
    func deleteItem(_ item: ItemModel, userId: String) async {
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                db.collection("users")
                  .document(userId)
                  .collection("items")
                  .document(item.id.uuidString)
                  .delete { error in
                      if let error = error {
                          continuation.resume(throwing: error)
                      } else {
                          continuation.resume(returning: ())
                      }
                  }
            }

            // Remove from the local array
            items.removeAll { $0.id == item.id }
            print("Item successfully deleted from Firestore.")
        } catch {
            print("Error deleting item from Firestore: \(error.localizedDescription)")
        }
    }

    /// Deletes multiple items (by index set) from Firestore.
    func deleteItems(at indexSet: IndexSet, userId: String) async {
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

    /// Sorts the local array based on the selected sorting mode.
    func sortItems() {
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
    }

    // MARK: - Filtering

    /// Provides a filtered list of items based on completion status.
    var filteredItems: [ItemModel] {
        hideCompleted
        ? items.filter { !$0.completed }
        : items
    }
}















 



