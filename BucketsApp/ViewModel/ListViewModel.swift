//
//  ListViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation
import Combine
import SwiftUI

enum SortingMode {
    case manual
    case byDeadline
    case byCreationDate
    case byPriority
    case byTitle
}

class ListViewModel: ObservableObject {
    @Published var items: [ItemModel] = [] {
        didSet { saveItems() }
    }
    
    @Published var showImages: Bool = true
    @Published var hideCompleted: Bool = false
    @Published var sortingMode: SortingMode = .manual {
        didSet { sortItems() }
    }
    @Published var showingAddItemView = false
    @Published var selectedItem: ItemModel?
    
    private let itemsKey = "items_list"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Schedule item loading instead of performing it directly in init.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadItems()
        }
    }
    
    /// Asynchronously load items from persistent storage
    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: itemsKey) else { return }
        
        DispatchQueue.main.async {
            do {
                self.items = try JSONDecoder().decode([ItemModel].self, from: data)
            } catch {
                print("Error decoding items: \(error)")
            }
        }
    }
    
    /// Save items to persistent storage
    func saveItems() {
        DispatchQueue.global(qos: .background).async {
            do {
                let encodedData = try JSONEncoder().encode(self.items)
                UserDefaults.standard.set(encodedData, forKey: self.itemsKey)
            } catch {
                print("Error encoding items: \(error)")
            }
        }
    }
    
    /// Sort items based on the current sorting mode
    func sortItems() {
        DispatchQueue.main.async {
            switch self.sortingMode {
            case .manual:
                // No action needed
                break
            case .byDeadline:
                self.items.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            case .byCreationDate:
                self.items.sort { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
            case .byPriority:
                self.items.sort { $0.priority.rawValue < $1.priority.rawValue }
            case .byTitle:
                self.items.sort { $0.name < $1.name }
            }
        }
    }
    
    /// Delete items at specified indices (used in list swipe-to-delete)
    func deleteItems(at indexSet: IndexSet) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        items.remove(atOffsets: indexSet)
    }
    
    /// Delete a specific item
    func deleteItem(_ item: ItemModel) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
    }
    
    /// Add a new item and return it
    func addItem() -> ItemModel {
        let newItem = ItemModel(name: "")
        items.append(newItem)
        return newItem
    }
}















 



