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
    case manual       // Preserves insertion order or uses 'orderIndex'
    case byDeadline
    case byCreationDate
    case byPriority
    case byTitle
}

@MainActor
class ListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The array of items in memory for the UI.
    @Published var items: [ItemModel] = []
    
    /// Controls whether images are shown in the UI (if you have toggles, you can hide them).
    @Published var showImages: Bool = true
    
    /// If `true`, completed items are hidden in the UI.
    @Published var hideCompleted: Bool = false
    
    /// Current sorting mode used by `sortItems()`.
    @Published var sortingMode: SortingMode = .manual
    
    /// The item currently being edited in detail, if any.
    @Published var currentEditingItem: ItemModel?
    
    /// Alert state for deletion confirmation.
    @Published var showDeleteAlert: Bool = false
    
    /// The item to be deleted if the user confirms.
    @Published var itemToDelete: ItemModel?
    
    // MARK: - Firestore
    
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    /// Convenience property to get the current logged-in user’s ID.
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    
    init() {}
    
    deinit {
            // No longer calling `stopListeningToItems()` here
            print("[ListViewModel] deinit called.")
        }

        func stopListeningToItems() {
            listenerRegistration?.remove()
            listenerRegistration = nil
            print("[ListViewModel] Stopped listening to items.")
        }
    
    // MARK: - One-Time Fetch
    
    /// Loads all items once from Firestore for the current user (no real-time updates).
    func loadItems() async {
        guard let userId = userId else {
            print("[ListViewModel] Error: User is not authenticated.")
            return
        }
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("items")
                .getDocuments()
            
            let fetchedItems = try snapshot.documents.compactMap { document -> ItemModel? in
                try document.data(as: ItemModel.self)
            }
            self.items = fetchedItems
            print("[ListViewModel] Successfully loaded \(items.count) items (one-time fetch).")
            
            // Sort after loading
            sortItems()
            
        } catch {
            print("[ListViewModel] Error loading items: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Real-Time Updates
    
    /// Starts listening to Firestore in real time. Call this method instead of `loadItems()`
    /// if you want continuous sync.
    func startListeningToItems() {
        guard let userId = userId else {
            print("[ListViewModel] Error: User is not authenticated.")
            return
        }
        
        stopListeningToItems() // Ensure we don't set up multiple listeners
        
        let collectionRef = db.collection("users")
            .document(userId)
            .collection("items")
        
        listenerRegistration = collectionRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("[ListViewModel] Error listening to items: \(error.localizedDescription)")
                return
            }
            guard let snapshot = snapshot else { return }
            
            do {
                let fetchedItems = try snapshot.documents.compactMap { document -> ItemModel? in
                    try document.data(as: ItemModel.self)
                }
                self.items = fetchedItems
                print("[ListViewModel] Received \(self.items.count) items (real-time).")
                
                // Sort after receiving updates
                self.sortItems()
                
            } catch {
                print("[ListViewModel] Decoding error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Add or Update Item
    
    /// Adds or updates an item in Firestore and updates local state.
    func addOrUpdateItem(_ item: ItemModel) {
        guard let userId = userId else { return }
        do {
            let docRef = db.collection("users")
                .document(userId)
                .collection("items")
                .document(item.id.uuidString)
            
            try docRef.setData(from: item, merge: true)
            // Synchronously update local items
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item
            } else {
                items.append(item)
            }
            sortItems()
            
        } catch {
            print("Error: \(error)")
        }
    }
    
    // MARK: - Delete Item
    
    /// Deletes an item from Firestore and from local state.
    func deleteItem(_ item: ItemModel) async {
        guard let userId = userId else {
            print("[ListViewModel] Error: User is not authenticated.")
            return
        }
        do {
            try await db.collection("users")
                .document(userId)
                .collection("items")
                .document(item.id.uuidString)
                .delete()
            
            // Remove from local list if using one-time fetch or non-real-time approach
            items.removeAll { $0.id == item.id }
            print("[ListViewModel] Deleted item with ID \(item.id).")
            
        } catch {
            print("[ListViewModel] Error deleting item: \(error.localizedDescription)")
        }
    }
    
    /// Deletes multiple items (by index set) from Firestore and local state.
    func deleteItems(at indexSet: IndexSet) async {
        // If real-time is on, you only need to remove them from Firestore,
        // the snapshot listener will update `items` automatically.
        
        let itemsToDelete = indexSet.map { items[$0] }
        for item in itemsToDelete {
            await deleteItem(item)
        }
    }
    
    // MARK: - Sorting
    
    /// Sorts `items` based on the current `sortingMode`.
    func sortItems() {
        print("[ListViewModel] Sorting items with mode: \(sortingMode.rawValue)")
        
        switch sortingMode {
        case .manual:
            // If you want pure "insertion order" from Firestore, do nothing.
            // But if you store a custom 'orderIndex' in ItemModel, you can do:
            items.sort { $0.orderIndex < $1.orderIndex }
            
        case .byDeadline:
            items.sort {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
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
    
    /// If `hideCompleted` is true, filters out completed items.
    var filteredItems: [ItemModel] {
        hideCompleted ? items.filter { !$0.completed } : items
    }
    
    // MARK: - Helpers
    
    /// Sets up the item that the user is trying to delete
    /// so the View can show a confirmation dialog.
    func setItemForDeletion(_ item: ItemModel) {
        self.itemToDelete = item
        self.showDeleteAlert = true
    }
    
    /// Finds an item in `items` by its UUID.
    func getItem(by id: UUID) -> ItemModel? {
        items.first { $0.id == id }
    }
}














 



