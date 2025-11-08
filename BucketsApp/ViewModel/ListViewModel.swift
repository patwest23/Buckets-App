//
//  ListViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

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
    @Published var pendingLocalImages: [UUID: [UIImage]] = [:]

    // MARK: - Attachments
    private let attachmentStore = AttachmentPersistence.shared
    private var uploadTasks: [UUID: Task<Void, Never>] = [:]
    
    // MARK: - Firestore
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    init() {
        print("[ListViewModel] init.")
        Task { [weak self] in
            await self?.initializeAttachmentState()
        }
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
            
            // Update local array with debug prints
            if let idx = items.firstIndex(where: { $0.id == newItem.id }) {
                print("[ListViewModel] addOrUpdateItem => found index \(idx), items.count=\(items.count)")
                items[idx] = newItem
            } else if isNewItem {
                print("[ListViewModel] addOrUpdateItem => appended new item. items.count was", items.count)
                items.append(newItem)
                print("[ListViewModel] Now items.count =", items.count)
            }
            // else skip if the item was removed in the meantime
            
            sortItems()
            Task { await prefetchImages(for: newItem) }
            
        } catch {
            print("[ListViewModel] addOrUpdateItem => Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Persist Images
    func persistImageURLs(_ urls: [String], for itemID: UUID) async {
        guard let userId = userId else {
            print("[ListViewModel] persistImageURLs: userId is nil. Cannot save images.")
            return
        }

        let docRef = db
            .collection("users")
            .document(userId)
            .collection("items")
            .document(itemID.uuidString)

        do {
            try await docRef.setData(["imageUrls": urls], merge: true)

            if let index = items.firstIndex(where: { $0.id == itemID }) {
                items[index].imageUrls = urls
            }

            print("[ListViewModel] persistImageURLs: Saved \(urls.count) image URLs for item \(itemID).")
        } catch {
            print("[ListViewModel] persistImageURLs error:", error.localizedDescription)
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
            pendingLocalImages.removeValue(forKey: item.id)
            let attachments = await attachmentStore.attachments(for: item.id)
            for attachment in attachments {
                if let task = uploadTasks.removeValue(forKey: attachment.id) {
                    task.cancel()
                }
            }
            await attachmentStore.removeAllAttachments(for: item.id)
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

    // MARK: - Attachments
    func stageImagesForUpload(_ images: [UIImage], for itemID: UUID) async {
        guard !images.isEmpty else { return }
        guard let item = getItem(by: itemID), item.completed else { return }

        let availableSlots = await availableSlotsForNewAttachments(itemID: itemID)
        guard availableSlots > 0 else {
            print("[ListViewModel] stageImagesForUpload: no available slots for item \(itemID)")
            return
        }

        let imagesToStore = Array(images.prefix(availableSlots))
        var newAttachments: [ItemAttachment] = []

        for image in imagesToStore {
            guard let data = image.jpegData(compressionQuality: 0.85) else { continue }
            do {
                let attachment = try await attachmentStore.createAttachment(for: itemID, imageData: data)
                newAttachments.append(attachment)
            } catch {
                print("[ListViewModel] stageImagesForUpload: failed to create attachment:", error.localizedDescription)
            }
        }

        guard !newAttachments.isEmpty else { return }

        await refreshPendingImages(for: itemID)

        for attachment in newAttachments {
            scheduleUpload(for: attachment)
        }
    }

    func clearLocalAttachments(for itemID: UUID) {
        Task { [weak self] in
            guard let self else { return }
            let attachments = await self.attachmentStore.attachments(for: itemID)
            for attachment in attachments {
                if let task = self.uploadTasks.removeValue(forKey: attachment.id) {
                    task.cancel()
                }
            }
            await self.attachmentStore.removeAllAttachments(for: itemID)
            await self.refreshPendingImages(for: itemID)
        }
    }

    private func initializeAttachmentState() async {
        let allAttachments = await attachmentStore.allAttachments()
        let grouped = Dictionary(grouping: allAttachments, by: { $0.itemID })

        for (itemID, attachments) in grouped {
            let pending = attachments.filter { $0.status != .synced }
            if !pending.isEmpty {
                await refreshPendingImages(for: itemID)
            }

            for attachment in attachments where attachment.status == .pendingUpload || attachment.status == .failed {
                scheduleUpload(for: attachment)
            }
        }
    }

    private func availableSlotsForNewAttachments(itemID: UUID) async -> Int {
        let remoteCount = getItem(by: itemID)?.imageUrls.count ?? 0
        let existingAttachments = await attachmentStore.attachments(for: itemID)
        let pendingCount = existingAttachments.filter { $0.status != .synced }.count
        return max(0, 3 - remoteCount - pendingCount)
    }

    @MainActor
    private func refreshPendingImagesOnMain(itemID: UUID, images: [UIImage]) {
        if images.isEmpty {
            pendingLocalImages.removeValue(forKey: itemID)
        } else {
            pendingLocalImages[itemID] = images
        }
    }

    nonisolated private func refreshPendingImages(for itemID: UUID) async {
        let attachments = await attachmentStore.attachments(for: itemID)
        var images: [UIImage] = []

        for attachment in attachments where attachment.status != .synced {
            if let fileURL = await attachmentStore.fileURL(for: attachment.id),
               let image = UIImage(contentsOfFile: fileURL.path) {
                images.append(image)
            }
        }

        await MainActor.run {
            self.refreshPendingImagesOnMain(itemID: itemID, images: images)
        }
    }

    private func scheduleUpload(for attachment: ItemAttachment) {
        guard uploadTasks[attachment.id] == nil else { return }

        let task = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            await self.performUpload(for: attachment.id)
        }

        uploadTasks[attachment.id] = task
    }

    nonisolated private func performUpload(for attachmentID: UUID) async {
        guard let attachment = await attachmentStore.attachment(withID: attachmentID) else {
            await MainActor.run { self.uploadTasks.removeValue(forKey: attachmentID) }
            return
        }

        guard let userId = await MainActor.run(body: { self.userId }) else {
            await MainActor.run { self.uploadTasks.removeValue(forKey: attachmentID) }
            return
        }

        await attachmentStore.updateStatus(for: attachmentID, to: .uploading)
        await refreshPendingImages(for: attachment.itemID)

        guard let fileURL = await attachmentStore.fileURL(for: attachmentID) else {
            await attachmentStore.incrementRetryCount(for: attachmentID)
            await refreshPendingImages(for: attachment.itemID)
            await MainActor.run { self.uploadTasks.removeValue(forKey: attachmentID) }

            if let updated = await attachmentStore.attachment(withID: attachmentID), updated.retryCount < 3 {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        self.scheduleUpload(for: updated)
                    }
                }
            }
            return
        }

        var retryCandidate: ItemAttachment?

        do {
            let data = try Data(contentsOf: fileURL)
            let storageRef = Storage.storage().reference()
                .child("users/\(userId)/item-\(attachment.itemID.uuidString)/\(attachment.id.uuidString).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            try await storageRef.putDataAsync(data, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()

            await attachmentStore.setRemoteURL(downloadURL.absoluteString, for: attachmentID)

            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.imageCache[downloadURL.absoluteString] = image
                }
            }

            await MainActor.run {
                self.mergeRemoteURL(downloadURL.absoluteString, for: attachment.itemID)
            }
        } catch {
            print("[ListViewModel] performUpload error:", error.localizedDescription)
            await attachmentStore.incrementRetryCount(for: attachmentID)
            retryCandidate = await attachmentStore.attachment(withID: attachmentID)
        }

        await refreshPendingImages(for: attachment.itemID)
        await MainActor.run { self.uploadTasks.removeValue(forKey: attachmentID) }

        if let retryAttachment = retryCandidate, retryAttachment.retryCount < 3 {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    self.scheduleUpload(for: retryAttachment)
                }
            }
        }
    }

    @MainActor
    private func mergeRemoteURL(_ url: String, for itemID: UUID) {
        guard var item = getItem(by: itemID) else { return }
        if !item.imageUrls.contains(url) {
            item.imageUrls.append(url)
            if item.imageUrls.count > 3 {
                item.imageUrls = Array(item.imageUrls.suffix(3))
            }
            if let index = items.firstIndex(where: { $0.id == itemID }) {
                items[index] = item
            }
            Task { await self.persistImageURLs(item.imageUrls, for: itemID) }
        }
    }
}














 



