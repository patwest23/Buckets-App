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
    @Published var name: String
    @Published var caption: String
    @Published var locationText: String
    @Published var completed: Bool
    @Published var wasShared: Bool
    @Published var imageUrls: [String]
    @Published var dueDate: Date?
    @Published var location: Location?

    let itemID: UUID
    private let listViewModel: ListViewModel
    private let postViewModel: PostViewModel

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


    func toggleCompleted() async {
        completed.toggle()
        dueDate = completed ? Date() : nil
        await save()
    }

    func updateLocation(from searchResult: MKLocalSearchCompletion) async {
        let fullAddress = searchResult.title + ", " + searchResult.subtitle
        locationText = fullAddress
        var updatedLocation = location ?? Location(latitude: 0, longitude: 0, address: "")
        updatedLocation.address = fullAddress
        location = updatedLocation
        await save()
    }

    func updateImageUrls(_ urls: [String]) async {
        imageUrls = urls
        await save()
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
        await listViewModel.addOrUpdateItem(current)
        await postViewModel.syncPostWithItem(current)
    }

    var canPost: Bool {
        completed && !imageUrls.isEmpty && !wasShared
    }
}
