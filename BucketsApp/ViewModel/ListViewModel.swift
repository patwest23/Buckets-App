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

// IMPORTANT: All mutations to the `items` array are handled by the Firestore snapshot listener.
// Direct array mutations (add, update, remove) should not be performed elsewhere.
// This avoids race conditions and ensures the UI always matches Firestore state.

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

enum ItemDataSource: String {
    case none
    case cache
    case remote
}

@MainActor
class ListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var items: [ItemModel] = []
    @Published var showImages: Bool = true
    @Published var hideCompleted: Bool = false
    @Published var sortingMode: SortingMode = .manual
    @Published var currentEditingItem: ItemModel? {
        didSet {
            if let item = currentEditingItem {
                print("[ListViewModel] currentEditingItem set: \(item.name)")
            } else {
                print("[ListViewModel] currentEditingItem cleared.")
            }
        }
    }
    @Published var showDeleteAlert: Bool = false
    @Published var itemToDelete: ItemModel?
    @Published private(set) var cachedUsers: [String: UserModel] = [:]
    @Published private(set) var lastLoadedDataSource: ItemDataSource = .none
    
    // @Published var imageCache: [String : UIImage] = [:]
    
    // MARK: - Firestore
    private lazy var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private var userListener: ListenerRegistration?
    private let userCacheStore = UserCache.shared
    private weak var defaultPostViewModel: PostViewModel?
    private let itemCache: ItemCacheStore

    var userIdProvider: () -> String? = {
        Auth.auth().currentUser?.uid
    }

    private var userId: String? {
        userIdProvider()
    }
    
    // MARK: - Throttling for image prefetch
    private var lastPrefetchTimestamps: [String: Date] = [:]
    
    // MARK: - Initialization
    init(itemCache: ItemCacheStore = .shared) {
        print("[ListViewModel] init.")
        self.itemCache = itemCache
    }
    
    deinit {
        print("[ListViewModel] deinit called.")
        listenerRegistration?.remove()
        listenerRegistration = nil
        userListener?.remove()
        print("[ListViewModel] Stopped listening to items.")
    }
    
    // MARK: - Stop Real-Time Listening
    func stopListeningToItems() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        print("[ListViewModel] Stopped listening to items.")
        clearImageCache()
        lastLoadedDataSource = .none
    }

    func restoreCachedItems() {
        guard let userId = userId else {
            print("[ListViewModel] restoreCachedItems: userId is nil.")
            return
        }

        guard let cached = itemCache.cachedItems(for: userId), !cached.isEmpty else {
            print("[ListViewModel] restoreCachedItems: no cached items found for userId=\(userId)")
            return
        }

        print("[ListViewModel] restoreCachedItems: Restoring \(cached.count) cached items for userId=\(userId)")
        items = cached
        lastLoadedDataSource = .cache
        sortItems()
    }

    func cacheItems(_ items: [ItemModel], for userId: String) {
        itemCache.cache(items: items, for: userId)
    }

    func updateEditingDraft(_ item: ItemModel) {
        if currentEditingItem == nil {
            currentEditingItem = item
        } else if currentEditingItem?.id == item.id {
            if currentEditingItem != item {
                currentEditingItem = item
            }
        } else {
            return
        }

        if let index = items.firstIndex(where: { $0.id == item.id }), items[index] != item {
            items[index] = item
        }
    }

    func fetchUserIfNeeded(for userId: String) async {
        if cachedUsers[userId] != nil { return }

        if let persisted = userCacheStore.cachedUser(for: userId) {
            cachedUsers[userId] = persisted
            print("[ListViewModel] Restored cached user \(persisted.username ?? "") for ID: \(userId)")
            return
        }

        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            if var user = try? doc.data(as: UserModel.self) {
                user.documentId = doc.documentID
                cachedUsers[userId] = user
                userCacheStore.cache(user: user, for: userId)
                print("[ListViewModel] Cached user \(user.username ?? "") for ID: \(userId)")
            }
        } catch {
            print("[ListViewModel] Failed to fetch user \(userId):", error.localizedDescription)
        }
    }
    
    // MARK: - One-Time Fetch
    func loadItems() async {
        guard let userId = userId else {
            print("[ListViewModel] loadItems: userId is nil (not authenticated).")
            return
        }

        restoreCachedItems()

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
            self.lastLoadedDataSource = .remote
            cacheItems(fetchedItems, for: userId)
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
        restoreCachedItems()

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
                self.lastLoadedDataSource = .remote
                self.cacheItems(fetched, for: userId)
                print("[ListViewModel] startListeningToItems: Received \(self.items.count) items")
                self.sortItems()
                
                Task {
                    for item in fetched {
                        await self.fetchUserIfNeeded(for: item.userId)
                    }
                }
                Task {
                    await self.prefetchItemImages()
                }
                
            } catch {
                print("[ListViewModel] Decoding error:", error.localizedDescription)
            }
        }
    }
    
    
    // MARK: - Add or Update
    /// Add or update an item in Firestore. If updating an item that was previously shared (posted), prompt user to update or repost.
    /// Note: For reposting logic, this function expects access to a PostViewModel. UI must handle the user prompt.
    func registerDefaultPostViewModel(_ postViewModel: PostViewModel) {
        defaultPostViewModel = postViewModel
    }

    func addOrUpdateItem(_ item: ItemModel, postViewModel: PostViewModel? = nil) async {
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

        let activePostViewModel = postViewModel ?? defaultPostViewModel

        // Handle repost/update logic for shared items
        if !isNewItem, newItem.wasShared, newItem.postId != nil {
            // Prompt user for action: update or repost
            let action = await promptUserForPostAction()
            if action == .repost, let postViewModel = activePostViewModel, let existingPostId = newItem.postId {
                // Delete the old post
                if let postToDelete = postViewModel.posts.first(where: { $0.id == existingPostId }) {
                    await postViewModel.deletePost(postToDelete)
                }
                // Clear postId and wasShared before saving updated item
                newItem.postId = nil
                newItem.wasShared = false
                // Save item update first (remove postId/wasShared)
                let docRef = db
                    .collection("users").document(userId)
                    .collection("items").document(newItem.id.uuidString)
                do {
                    let encoded = try Firestore.Encoder().encode(newItem)
                    try await docRef.setData(encoded, merge: true)
                } catch {
                    print("[ListViewModel] addOrUpdateItem => Error during repost save: \(error.localizedDescription)")
                }
                // End of repost logic (posting now handled by SyncCoordinator)
                return
            }
            // If .update, fall through to normal update logic below
        }

        do {
            print("[ListViewModel] Preparing to write item: \(newItem.id), wasShared: \(newItem.wasShared), postId: \(String(describing: newItem.postId))")
            try await writeItemToFirestore(newItem, userId: userId)
            print("[ListViewModel] addOrUpdateItem => wrote item \(newItem.id) to Firestore.")

            // Do not update self.items here. The Firestore snapshot listener will update items.

        // --- Sync post if this item is linked to a post
        if newItem.postId != nil, let postViewModel = activePostViewModel {
            await postViewModel.syncPostWithItem(newItem)
        }

            sortItems()
            Task { await prefetchImages(for: newItem) }

        } catch {
            print("[ListViewModel] addOrUpdateItem => Error: \(error.localizedDescription)")
        }
    }

    func addOrUpdateItem(_ item: ItemModel, syncingWith postViewModel: PostViewModel) async {
        await addOrUpdateItem(item, postViewModel: postViewModel)
    }

    func writeItemToFirestore(_ item: ItemModel, userId: String) async throws {
        let docRef = db
            .collection("users").document(userId)
            .collection("items").document(item.id.uuidString)
        let encoded = try Firestore.Encoder().encode(item)
        print("📝 Writing to Firestore:", encoded)
        try await docRef.setData(encoded, merge: true)
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
            // Do not remove from self.items here. The Firestore snapshot listener will update items.
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
        // Do not remove from self.items here. The Firestore snapshot listener will update items.
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

    func applyLocalEdits(_ updatedItem: ItemModel) {
        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
            if items[index] != updatedItem {
                items[index] = updatedItem
            }
        }

        if let editingItem = currentEditingItem,
           editingItem.id == updatedItem.id,
           editingItem != updatedItem {
            currentEditingItem = updatedItem
        }
    }

    // MARK: - User Cache Helpers
    func getUser(for userId: String) -> UserModel? {
        if let user = cachedUsers[userId] {
            return user
        }
        if let persisted = userCacheStore.cachedUser(for: userId) {
            cachedUsers[userId] = persisted
            return persisted
        }
        return nil
    }

    /// Allows tests and previews to inject deterministic user data.
    func seedCachedUser(_ user: UserModel, for userId: String) {
        cachedUsers[userId] = user
        userCacheStore.cache(user: user, for: userId)
    }
    
    // func getItem(by id: UUID) -> ItemModel? {
    //     items.first { $0.id == id }
    // }
    
    // MARK: - Pre-Fetch Logic
    func prefetchItemImages() async {
        for item in items {
            await prefetchImages(for: item)
        }
    }
    
    func prefetchImages(for item: ItemModel) async {
        let now = Date()
        let urls = allImageUrls(for: item)
        print("[ListViewModel] Prefetching \(urls.count) image(s) for item:", item.name)
        print("📦 Prefetching images for \(item.name):", urls)
        for urlStr in urls {
            if let last = lastPrefetchTimestamps[urlStr], now.timeIntervalSince(last) < 5 {
                continue // skip reloading this image too soon
            }
            lastPrefetchTimestamps[urlStr] = now
            if ImageCache.shared.image(forKey: urlStr) != nil {
                continue
            }
            await loadImage(urlStr: urlStr)
        }
    }
    
    private func loadImage(urlStr: String) async {
        guard let url = URL(string: urlStr) else { return }

        // First check disk cache
        if ImageCache.shared.image(forKey: urlStr) != nil {
            // imageCache[urlStr] = cachedImage
            print("[ListViewModel] Loaded image from shared cache for \(urlStr)")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                // imageCache[urlStr] = uiImage
                ImageCache.shared.setImage(uiImage, forKey: urlStr)
                print("[ListViewModel] Downloaded and cached image for \(urlStr)")
            }
        } catch {
            print("[ListViewModel] loadImage(\(urlStr)) error:", error.localizedDescription)
        }
    }
    
    // MARK: - Image Cache Helpers
    func clearImageCache() {
        // imageCache.removeAll()
        lastPrefetchTimestamps.removeAll()
        print("[ListViewModel] Cleared image cache and prefetch timestamps.")
    }

    // MARK: - Sync Likes Helper
    /// Syncs the likedBy array from a post to the corresponding item document in Firestore,
    /// and updates the in-memory item in `items` so SwiftUI can reflect it.
    func syncItemLikes(for itemId: UUID, from postLikedBy: [String]) async {
        guard let userId = userId else { return }

        print("🔄 [ListViewModel] Starting syncItemLikes for itemId: \(itemId)")

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

            // Update in-memory model so SwiftUI can reflect it
            if let index = self.items.firstIndex(where: { $0.id == itemId }) {
                var updated = self.items[index]
                updated.likedBy = postLikedBy
                updated.wasShared = true
                self.items[index] = updated
                print("🧠 Updated item \(itemId) likedBy count: \(postLikedBy.count), wasShared: true")
                print("✅ [ListViewModel] Finished syncItemLikes for itemId: \(itemId)")
            }

        } catch {
            print("❌ [ListViewModel] syncItemLikes failed for itemId: \(itemId) with error: \(error.localizedDescription)")
        }
    }

    // MARK: - Real-Time User Document Listener
    // func startListeningToUserDoc(for userId: String) {
    //     userListener?.remove()
    //     userListener = db.collection("users").document(userId)
    //         .addSnapshotListener { snapshot, error in
    //             if let error = error {
    //                 print("[ListViewModel] Error listening to user doc:", error.localizedDescription)
    //                 return
    //             }
    //             guard let data = snapshot?.data() else { return }
    //             print("[ListViewModel] User doc updated:", data)
    //         }
    // }

    func allImageUrls(for item: ItemModel) -> [String] {
        return item.imageUrls
    }

    // MARK: - Update Only Image URLs
    /// Updates only the imageUrls of the given item in Firestore.
    func updateImageUrls(for item: ItemModel, urls: [String]) async {
        var updatedItem = item
        updatedItem.imageUrls = urls
        await addOrUpdateItem(updatedItem)
    }

}

    // MARK: - Post Action Choice for Shared Items
    /// Enum for user post action selection when updating a shared item
    enum PostActionChoice {
        case update
        case repost
    }

    /// Placeholder for user prompt. UI must implement this prompt and call addOrUpdateItem accordingly.
    /// - Returns: PostActionChoice (.update or .repost)
    func promptUserForPostAction() async -> PostActionChoice {
        // In actual app, this will be replaced by a UI confirmation dialog.
        // For now, default to .repost for demonstration.
        return .repost
    }
