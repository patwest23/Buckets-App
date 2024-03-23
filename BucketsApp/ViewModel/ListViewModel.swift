//
//  ListViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation

class ListViewModel: ObservableObject {
    
    @Published var items: [ItemModel] = []
    @Published var selectedItem: ItemModel? // Property to store the selected item for editing
    @Published var filteredItems: [ItemModel] = [] // Ensure this property is published
    
    func addItem(item: ItemModel, imageData: Data?) {
        var newItem = item
        newItem.imageData = imageData
        items.append(newItem)
        updateFilteredItems() // Ensure filteredItems is updated after adding a new item
    }
    
    func removeEmptyItems() {
        // Filter out empty items
        let nonEmptyItems = items.filter { !$0.name.isEmpty }
        // Update the items array with non-empty items
        items = nonEmptyItems
        updateFilteredItems()
    }

    func updateItem(_ item: ItemModel, withName name: String, description: String, completed: Bool, imageData: Data?) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.name = name
            updatedItem.description = description
            updatedItem.completed = completed
            updatedItem.imageData = imageData
            items[index] = updatedItem
            updateFilteredItems()
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        updateFilteredItems()
    }
    
    func onCompleted(for item: ItemModel, completed: Bool) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].completed = completed
            updateFilteredItems()
        }
    }
    
    private func updateFilteredItems() {
        // Implement your filtering logic here
        // For example, you might filter items based on completion status
        // filteredItems = items.filter { !$0.completed }
    }
}






 
 



