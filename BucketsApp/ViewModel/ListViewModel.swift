//
//  ListViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation
import SwiftUI

class ListViewModel: ObservableObject {
    
    @Published var items: [ItemModel] = [] {
        didSet {
            saveItems()
        }
    }
    
    let itemsKey: String = "items_list"
    
    init() {
        loadItems()
    }
    
    func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: itemsKey),
              let savedItems = try? JSONDecoder().decode([ItemModel].self, from: data)
        else {
            return
        }
        
        self.items = savedItems
    }
    
    func addItem(item: ItemModel, imageData: Data?) {
        guard !item.name.isEmpty else { return }
        var newItem = item
        newItem.imageData = imageData
        items.append(newItem)
    }
    
    func updateItem(_ item: ItemModel, withName name: String, description: String, completed: Bool, imageData: Data?) {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                var updatedItem = item
                updatedItem.name = name
                updatedItem.description = description
                updatedItem.completed = completed
                updatedItem.imageData = imageData
                items[index] = updatedItem
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
    
    func saveItems() {
        if let encodedData = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encodedData, forKey: itemsKey)
        }
    }
}

 
 



