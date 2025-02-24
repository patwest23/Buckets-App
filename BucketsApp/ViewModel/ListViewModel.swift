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
    @Published var showDeleteAlert: Bool = false
    @Published var itemToDelete: ItemModel?
    
    @Published var imageCache: [String : UIImage] = [:]
    
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
        print("[ListViewModel] deinit called.")
        listenerRegistration?.remove()
        listenerRegistration = nil
        print("[ListViewModel] Stopped listening to items.")
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
            print("[ListViewModel] loadItems: userId is nil (not authenticated).")
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
            
            await prefetchItemImages()
            
        } catch {
            print("[ListViewModel] loadItems error:", error.localizedDescription)
        }
    }
    
    // MARK: - Real-Time Updates
    func startListeningToItems() {
        guard let userId = userId else {
            print("[ListViewModel] startListeningToItems: userId is nil (not authenticated).")
            return
        }
        
        stopListeningToItems()
        
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
                print("[ListViewModel] startListeningToItems: Received \(self.items.count) items")
                self.sortItems()
                
                Task {
                    await self.prefetchItemImages()
                }
                
            } catch {
                print("[ListViewModel] Decoding error:", error.localizedDescription)
            }
        }
    }
    
    
    // MARK: - Add or Update
    func addOrUpdateItem(_ item: ItemModel) {
        guard let userId = userId else {
            print("[ListViewModel] addOrUpdateItem: userId is nil. Cannot save item.")
            return
        }
        
        // Use `let` instead of `var`
        let isNewItem = !items.contains { $0.id == item.id }
        
        // If new => set next orderIndex
        var newItem = item
        if isNewItem {
            let currentMaxOrder = items.map { $0.orderIndex }.max() ?? -1
            newItem.orderIndex = currentMaxOrder + 1
        }
        
        let docRef = db
            .collection("users").document(userId)
            .collection("items").document(item.id.uuidString)
        
        do {
            try docRef.setData(from: newItem, merge: true)
            print("[ListViewModel] addOrUpdateItem => wrote item \(newItem.id) to Firestore.")
            
            // Update local array only if item still in array
            if let idx = items.firstIndex(where: { $0.id == newItem.id }) {
                items[idx] = newItem
            }
            else if isNewItem {
                items.append(newItem)
            }
            // else skip if the item was removed in the meantime
            
            sortItems()
            Task { await prefetchImages(for: newItem) }
            
        } catch {
            print("[ListViewModel] addOrUpdateItem => Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Delete Item
    func deleteItem(_ item: ItemModel) async {
        guard let userId = userId else {
            print("[ListViewModel] deleteItem: userId is nil (not authenticated).")
            return
        }
        
        do {
            let docRef = db
                .collection("users")
                .document(userId)
                .collection("items")
                .document(item.id.uuidString)
            
            try await docRef.delete()
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
            items.sort { $0.orderIndex < $1.orderIndex }
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
    
    // MARK: - Pre-Fetch Logic
    func prefetchItemImages() async {
        for item in items {
            await prefetchImages(for: item)
        }
    }
    
    private func prefetchImages(for item: ItemModel) async {
        for urlStr in item.imageUrls {
            if imageCache[urlStr] != nil {
                continue
            }
            await loadImage(urlStr: urlStr)
        }
    }
    
    private func loadImage(urlStr: String) async {
        guard let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                imageCache[urlStr] = uiImage
                print("[ListViewModel] Cached image for \(urlStr)")
            }
        } catch {
            print("[ListViewModel] loadImage(\(urlStr)) error:", error.localizedDescription)
        }
    }
}














 



