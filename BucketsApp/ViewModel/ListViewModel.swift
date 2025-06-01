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

import UIKit
// MARK: - Shared ImageCache
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 100  // Limit to 100 images in memory
    }

    func image(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

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
    
    // MARK: - Throttling for image prefetch
    private var lastPrefetchTimestamps: [String: Date] = [:]
    
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
        clearImageCache()
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
    func addOrUpdateItem(_ item: ItemModel) async {
        guard let userId = userId else {
            print("[ListViewModel] addOrUpdateItem: userId is nil. Cannot save item.")
            return
        }
        
        let isNewItem = !items.contains { $0.id == item.id }
        
        // If new => set next orderIndex
        var newItem = item
        if isNewItem {
            let currentMaxOrder = items.map { $0.orderIndex }.max() ?? -1
            newItem.orderIndex = currentMaxOrder + 1
        }
        
        if newItem.userId.isEmpty {
            newItem.userId = userId
        }
        
        if newItem.userId.isEmpty {
            print("❌ [ListViewModel] Cannot save: userId is still empty.")
            return
        }
        
        let docRef = db
            .collection("users").document(userId)
            .collection("items").document(item.id.uuidString)
        
        do {
            let encoded = try Firestore.Encoder().encode(newItem)
            print("📝 Writing to Firestore:", encoded)
            try await docRef.setData(encoded, merge: true)
            print("[ListViewModel] addOrUpdateItem => wrote item \(newItem.id) to Firestore.")
            
            // Update local array with debug prints
            if let idx = items.firstIndex(where: { $0.id == newItem.id }) {
                print("[ListViewModel] addOrUpdateItem => found index \(idx), items.count=\(items.count)")
                items[idx] = newItem
                print("✅ Updated item image URLs:", newItem.allImageUrls)
            } else if isNewItem {
                print("[ListViewModel] addOrUpdateItem => appended new item. items.count was", items.count)
                items.append(newItem)
                print("[ListViewModel] Now items.count =", items.count)
                print("✅ Updated item image URLs:", newItem.allImageUrls)
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
        // Print info to catch any unexpected index
        print("[ListViewModel] deleteItems(at:). items.count =", items.count, "indexSet =", indexSet)
        
        // If you want extra safety:
        for index in indexSet {
            guard index < items.count else {
                print("[ListViewModel] WARNING: out-of-range index:", index,
                      "for items.count =", items.count)
                continue // skip or break
            }
            let item = items[index]
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
    
    func prefetchImages(for item: ItemModel) async {
        let now = Date()
        print("[ListViewModel] Prefetching \(item.allImageUrls.count) image(s) for item:", item.name)
        print("📦 Prefetching images for \(item.name):", item.allImageUrls)
        for urlStr in item.allImageUrls {
            if let last = lastPrefetchTimestamps[urlStr], now.timeIntervalSince(last) < 5 {
                continue // skip reloading this image too soon
            }
            lastPrefetchTimestamps[urlStr] = now
            if imageCache[urlStr] != nil {
                continue
            }
            await loadImage(urlStr: urlStr)
        }
    }
    
    private func loadImage(urlStr: String) async {
        guard let url = URL(string: urlStr) else { return }

        // First check disk cache
        if let cachedImage = ImageCache.shared.image(forKey: urlStr) {
            imageCache[urlStr] = cachedImage
            print("[ListViewModel] Loaded image from shared cache for \(urlStr)")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                imageCache[urlStr] = uiImage
                ImageCache.shared.setImage(uiImage, forKey: urlStr)
                print("[ListViewModel] Downloaded and cached image for \(urlStr)")
            }
        } catch {
            print("[ListViewModel] loadImage(\(urlStr)) error:", error.localizedDescription)
        }
    }
    
    // MARK: - Image Cache Helpers
    func clearImageCache() {
        imageCache.removeAll()
        lastPrefetchTimestamps.removeAll()
        print("[ListViewModel] Cleared image cache and prefetch timestamps.")
    }

    // MARK: - Sync Likes Helper
    /// Syncs the likedBy array from a post to the corresponding item document in Firestore.
    func syncItemLikes(for itemId: UUID, from postLikedBy: [String]) async {
        guard let userId = userId else { return }

        let docRef = db
            .collection("users")
            .document(userId)
            .collection("items")
            .document(itemId.uuidString)

        do {
            let update: [String: Any] = await MainActor.run {
                ["likedBy": postLikedBy]
            }
            try await docRef.updateData(update)
            print("❤️ Synced likes to item \(itemId)")
        } catch {
            print("❌ Failed to sync likes to item:", error.localizedDescription)
        }
    }
}
