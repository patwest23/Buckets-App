//
//  DetailItemViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 7/20/25.
//

import Foundation
import SwiftUI
import MapKit
import Combine

@MainActor
final class DetailItemViewModel: ObservableObject {
    @Published var name: String {
        didSet { registerChangeIfNeeded() }
    }
    @Published var caption: String {
        didSet { registerChangeIfNeeded() }
    }
    @Published var locationText: String {
        didSet { registerChangeIfNeeded() }
    }
    @Published var completed: Bool {
        didSet { registerChangeIfNeeded() }
    }
    @Published var wasShared: Bool {
        didSet { registerChangeIfNeeded() }
    }
    @Published var imageUrls: [String] {
        didSet { registerChangeIfNeeded() }
    }
    @Published var dueDate: Date? {
        didSet { registerChangeIfNeeded() }
    }
    @Published var location: Location? {
        didSet { registerChangeIfNeeded() }
    }

    let itemID: UUID
    private let listViewModel: ListViewModel
    private let postViewModel: PostViewModel

    private var autosaveTask: Task<Void, Never>? = nil
    private var hasPendingChanges = false
    private var isApplyingExternalUpdate = false
    private var lastSyncedItem: ItemModel
    private var cancellables: Set<AnyCancellable> = []

    private let autosaveInterval: UInt64 = 4_000_000_000 // 4s for background autosave

    private func registerChangeIfNeeded() {
        guard !isApplyingExternalUpdate else { return }
        hasPendingChanges = true
        pushDraftToList()
        scheduleAutosave()
    }

    private func pushDraftToList() {
        let draft = applyingEdits(to: listViewModel.currentEditingItem ?? lastSyncedItem)
        listViewModel.updateEditingDraft(draft)
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: autosaveInterval)
            await self.saveIfNeeded()
        }
    }

    private func saveIfNeeded() async {
        guard hasPendingChanges else { return }
        await save()
    }

    init(item: ItemModel, listViewModel: ListViewModel, postViewModel: PostViewModel) {
        self.itemID = item.id
        self.name = item.name
        self.caption = item.caption ?? ""
        self.locationText = item.location?.address ?? ""
        self.location = item.location
        self.completed = item.completed
        self.wasShared = item.wasShared
        self.imageUrls = item.imageUrls
        self.dueDate = item.dueDate

        self.listViewModel = listViewModel
        self.postViewModel = postViewModel
        self.lastSyncedItem = item

        observeEditingItemUpdates()
    }

    deinit {
        autosaveTask?.cancel()
        cancellables.forEach { $0.cancel() }
    }


    func toggleCompleted() async {
        completed.toggle()
        dueDate = completed ? Date() : nil
    }

    func updateLocation(from searchResult: MKLocalSearchCompletion) async {
        let fullAddress = searchResult.title + ", " + searchResult.subtitle
        locationText = fullAddress
        var updatedLocation = location ?? Location(latitude: 0, longitude: 0, address: "")
        updatedLocation.address = fullAddress
        location = updatedLocation
    }

    func updateImageUrls(_ urls: [String]) async {
        imageUrls = urls
    }

    func save() async {
        let updatedItem = applyingEdits(to: lastSyncedItem)
        guard updatedItem != lastSyncedItem else {
            hasPendingChanges = false
            return
        }

        postViewModel.caption = caption
        await listViewModel.addOrUpdateItem(updatedItem, postViewModel: postViewModel)
        lastSyncedItem = updatedItem
        listViewModel.updateEditingDraft(updatedItem)
        hasPendingChanges = false
    }

    func commitPendingChanges() async {
        autosaveTask?.cancel()
        await saveIfNeeded()
    }

    var canPost: Bool {
        completed && !imageUrls.isEmpty && !wasShared
    }

    func applyingEdits(to item: ItemModel) -> ItemModel {
        var updated = item
        updated.name = name
        updated.caption = caption
        updated.completed = completed
        updated.wasShared = wasShared
        updated.imageUrls = imageUrls
        updated.dueDate = dueDate
        updated.location = location
        return updated
    }

    private func observeEditingItemUpdates() {
        listViewModel.$currentEditingItem
            .compactMap { $0 }
            .filter { [weak self] in
                guard let self else { return false }
                return $0.id == self.itemID
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] item in
                self?.handleExternalUpdate(item)
            }
            .store(in: &cancellables)
    }

    private func handleExternalUpdate(_ item: ItemModel) {
        guard !hasPendingChanges else { return }
        lastSyncedItem = item
        isApplyingExternalUpdate = true
        if name != item.name { name = item.name }
        if caption != (item.caption ?? "") { caption = item.caption ?? "" }
        let itemLocationText = item.location?.address ?? ""
        if locationText != itemLocationText { locationText = itemLocationText }
        if completed != item.completed { completed = item.completed }
        if wasShared != item.wasShared { wasShared = item.wasShared }
        if imageUrls != item.imageUrls { imageUrls = item.imageUrls }
        if dueDate != item.dueDate { dueDate = item.dueDate }
        if location != item.location { location = item.location }
        isApplyingExternalUpdate = false
    }
}
