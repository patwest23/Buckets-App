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
    @Published var items: [ItemModel] = []
    @Published var showImages: Bool = true
    @Published var hideCompleted: Bool = false
    @Published var sortingMode: SortingMode = .manual
    @Published var currentEditingItem: ItemModel?
    @Published var showDeleteAlert: Bool = false
    @Published var itemToDelete: ItemModel?
    
    // MARK: - Firestore
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    init() {
        print("[ListViewModel] init.")
    }
    
    deinit {
        // Optionally remove real-time listener or do minimal synchronous cleanup
        print("[ListViewModel] deinit called.")
    }
    
    // MARK: - Stop Real-Time Listening
    func stopListeningToItems() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        print("[ListViewModel] Stopped listening to items.")
    }
    
    // MARK: - One-Time Fetch
    func loadItems() async {
        guard let userId = userId else {
            print("[ListViewModel] loadItems: Error: userId is nil (not authenticated).")
            return
        }
        
        do {
            let snapshot = try await db
                .collection("users")
                .document(userId)
                .collection("items")
                .getDocuments()
            
            let fetchedItems = try snapshot.documents.compactMap {
                try $0.data(as: ItemModel.self)
            }
            
            self.items = fetchedItems
            print("[ListViewModel] loadItems: Fetched \(items.count) items for userId: \(userId)")
            sortItems()
        } catch {
            print("[ListViewModel] loadItems error:", error.localizedDescription)
        }
    }
    
    // MARK: - Real-Time Updates
    func startListeningToItems() {
        guard let userId = userId else {
            print("[ListViewModel] startListeningToItems: Error: userId is nil (not authenticated).")
            return
        }
        
        stopListeningToItems()  // avoid multiple listeners
        
        let collectionRef = db
            .collection("users")
            .document(userId)
            .collection("items")
        
        listenerRegistration = collectionRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[ListViewModel] startListeningToItems error:", error.localizedDescription)
                return
            }
            
            guard let snapshot = snapshot else { return }
            
            do {
                let fetched = try snapshot.documents.compactMap {
                    try $0.data(as: ItemModel.self)
                }
                self.items = fetched
                print("[ListViewModel] startListeningToItems: Received \(self.items.count) items for userId \(userId)")
                self.sortItems()
            } catch {
                print("[ListViewModel] Decoding error:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Add/Update Item
    func addOrUpdateItem(_ item: ItemModel) {
        guard let userId = userId else {
            print("[ListViewModel] addOrUpdateItem: Error: userId is nil. Cannot save item.")
            return
        }
        
        let docRef = db
            .collection("users")
            .document(userId)
            .collection("items")
            .document(item.id.uuidString)
        
        do {
            try docRef.setData(from: item, merge: true)
            print("[ListViewModel] addOrUpdateItem: Wrote item \(item.id) to /users/\(userId)/items/\(item.id.uuidString)")
            
            // Update local array
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item
            } else {
                items.append(item)
            }
            sortItems()
        } catch {
            print("[ListViewModel] addOrUpdateItem: Error:", error.localizedDescription)
        }
    }
    
    // MARK: - Delete Item
    func deleteItem(_ item: ItemModel) async {
        guard let userId = userId else {
            print("[ListViewModel] deleteItem: Error: userId is nil (not authenticated).")
            return
        }
        
        do {
            try await db
                .collection("users")
                .document(userId)
                .collection("items")
                .document(item.id.uuidString)
                .delete()
            
            items.removeAll { $0.id == item.id }
            print("[ListViewModel] deleteItem: Deleted item \(item.id) from /users/\(userId)/items")
        } catch {
            print("[ListViewModel] deleteItem error:", error.localizedDescription)
        }
    }
    
    func deleteItems(at indexSet: IndexSet) async {
        let itemsToDelete = indexSet.map { items[$0] }
        for item in itemsToDelete {
            await deleteItem(item)
        }
    }
    
    // MARK: - Sorting
    func sortItems() {
        print("[ListViewModel] sortItems by \(sortingMode.rawValue)")
        
        switch sortingMode {
        case .manual:
            // If you want to use a custom 'orderIndex' in ItemModel for manual sorting:
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
    var filteredItems: [ItemModel] {
        hideCompleted ? items.filter { !$0.completed } : items
    }
    
    // MARK: - Helpers
    func setItemForDeletion(_ item: ItemModel) {
        self.itemToDelete = item
        self.showDeleteAlert = true
    }
    
    func getItem(by id: UUID) -> ItemModel? {
        items.first { $0.id == id }
    }
}














 



