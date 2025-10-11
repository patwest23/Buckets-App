//
//  DetailItemViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 7/20/25.
//

import Foundation
import SwiftUI
import MapKit

@MainActor
final class DetailItemViewModel: ObservableObject {
    @Published var name: String {
        didSet { startDebouncedSave() }
    }
    @Published var caption: String {
        didSet { startDebouncedSave() }
    }
    @Published var locationText: String {
        didSet { startDebouncedSave() }
    }
    @Published var completed: Bool {
        didSet { startDebouncedSave() }
    }
    @Published var wasShared: Bool {
        didSet { startDebouncedSave() }
    }
    @Published var imageUrls: [String] {
        didSet { startDebouncedSave() }
    }
    @Published var dueDate: Date? {
        didSet { startDebouncedSave() }
    }
    @Published var location: Location? {
        didSet { startDebouncedSave() }
    }

    let itemID: UUID
    private let listViewModel: ListViewModel
    private let postViewModel: PostViewModel

    private var saveTask: Task<Void, Never>? = nil
    private let debounceInterval: UInt64 = 1_200_000_000 // 1.2s debounce

    private func startDebouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: debounceInterval)
            await save()
        }
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
    }

    deinit {
        saveTask?.cancel()
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
        guard var current = listViewModel.currentEditingItem else { return }
        current.name = name
        current.caption = caption
        current.completed = completed
        current.wasShared = wasShared
        current.imageUrls = imageUrls
        current.dueDate = dueDate
        current.location = location
        await listViewModel.addOrUpdateItem(current, postViewModel: postViewModel)
    }

    func commitPendingChanges() async {
        saveTask?.cancel()
        await save()
    }

    var canPost: Bool {
        completed && !imageUrls.isEmpty && !wasShared
    }
}
