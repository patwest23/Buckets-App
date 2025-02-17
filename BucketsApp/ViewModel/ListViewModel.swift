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
    
    /// Stores actual `UIImage`s for each image URL, so we can display them instantly.
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
            
            // After items are loaded, pre-fetch their image URLs
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
                
                // Pre-fetch images in the background
                Task {
                    await self.prefetchItemImages()
                }
                
            } catch {
                print("[ListViewModel] Decoding error:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Add/Update Item
    func addOrUpdateItem(_ item: ItemModel) {
        guard let userId = userId else {
            print("[ListViewModel] addOrUpdateItem: userId is nil. Cannot save item.")
            return
        }
        
        // Determine if new
        var isNewItem = false
        if !items.contains(where: { $0.id == item.id }) {
            isNewItem = true
        }
        
        // If new, set orderIndex to bottom
        var newItem = item
        if isNewItem {
            let currentMaxOrder = items.map { $0.orderIndex }.max() ?? -1
            newItem.orderIndex = currentMaxOrder + 1
        }
        
        // Write to Firestore
        let docRef = db
            .collection("users")
            .document(userId)
            .collection("items")
            .document(item.id.uuidString)
        
        do {
            try docRef.setData(from: newItem, merge: true)
            print("[ListViewModel] addOrUpdateItem: Wrote item \(newItem.id) to Firestore.")
            
            // Update local array
            if let index = items.firstIndex(where: { $0.id == newItem.id }) {
                items[index] = newItem
            } else {
                items.append(newItem)
            }
            sortItems()
            
            // Also prefetch images for this item if any
            Task {
                await prefetchImages(for: newItem)
            }
            
        } catch {
            print("[ListViewModel] addOrUpdateItem: Error:", error.localizedDescription)
        }
    }
    
    // MARK: - Delete Item
    func deleteItem(_ item: ItemModel) async {
        guard let userId = userId else {
            print("[ListViewModel] deleteItem: userId is nil (not authenticated).")
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
    
    /// Calls `prefetchImages(for:)` for all items.
    func prefetchItemImages() async {
        for item in items {
            await prefetchImages(for: item)
        }
    }
    
    /// Loads all image URLs for a specific item, storing them in `imageCache`.
    private func prefetchImages(for item: ItemModel) async {
        for urlStr in item.imageUrls {
            // Already cached? skip
            if imageCache[urlStr] != nil {
                continue
            }
            await loadImage(urlStr: urlStr)
        }
    }
    
    /// Downloads image data from `urlStr`, sets in `imageCache`.
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














 



