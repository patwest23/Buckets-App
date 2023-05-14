//
//  ItemModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation
import SwiftUI

struct ItemModel: Identifiable, Codable, Hashable {
    let id: UUID
    var image: Data
    var name: String
    var description: String
    var completed: Bool
    
}

// Image data class
@MainActor class ImageData : ObservableObject {
    private let IMAGES_KEY = "ImagesKey"
    var itemModel: [ItemModel] {
        didSet {
            objectWillChange.send()
            saveItems()
        }
    }
    
    
    // initialize the item model
    init() {
        if let data = UserDefaults.standard.data(forKey: IMAGES_KEY) {
            if let decodedNotes = try? JSONDecoder().decode([ItemModel].self, from: data) {
                itemModel = decodedNotes
                print("Data successfully retrieved!")
                return
            }
        }
        itemModel = []
    }
    

    func addItem(item: ItemModel) {
        guard !item.name.isEmpty else { return }
        itemModel.append(item)
    }
    
    
    func updateItem(_ item: ItemModel, withName name: String, description: String, completed: Bool) {
        if let index = itemModel.firstIndex(where: { $0.id == item.id }) {
            itemModel[index].name = name
            itemModel[index].description = description
            itemModel[index].completed = completed
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        itemModel.remove(atOffsets: offsets)
    }
    
    func onCompleted(for item: ItemModel, completed: Bool) {
        if let index = itemModel.firstIndex(where: { $0.id == item.id }) {
            itemModel[index].completed = completed
        }
    }
    
    
    private func saveItems() {
        if let encodedNotes = try? JSONEncoder().encode(itemModel) {
            UserDefaults.standard.set(encodedNotes, forKey: IMAGES_KEY)
        }
    }
}

    
    





