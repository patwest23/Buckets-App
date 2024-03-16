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
    
    func addItem(item: ItemModel, imageData: Data?) {
        var newItem = item
        newItem.imageData = imageData
        items.append(newItem)
        removeEmptyItems()
    }
    
    func removeEmptyItems() {
        // Filter out empty items
        let nonEmptyItems = items.filter { !$0.name.isEmpty }
        // Update the items array with non-empty items
        items = nonEmptyItems
    }

    func updateItem(_ item: ItemModel, withName name: String, description: String, completed: Bool, imageData: Data?) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.name = name
            updatedItem.description = description
            updatedItem.completed = completed
            updatedItem.imageData = imageData
            items[index] = updatedItem
            removeEmptyItems()
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    func onCompleted(for item: ItemModel, completed: Bool) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].completed = completed
        }
    }
}





 
 



