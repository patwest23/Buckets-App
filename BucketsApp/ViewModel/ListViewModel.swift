//
//  ListViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation
import Combine
import SwiftUI

enum SortingMode: String, CaseIterable {
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
    @Published var sortingMode: SortingMode = .manual
    @Published var currentEditingItem: ItemModel? // Used for tracking the item currently being edited

    private let itemsKey = "items_list"
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadItems() // Load saved items on initialization
    }

    /// Load items from persistent storage
    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: itemsKey) else { return }
        do {
            self.items = try JSONDecoder().decode([ItemModel].self, from: data)
        } catch {
            print("Error decoding items: \(error)")
        }
    }

    /// Save items to persistent storage
    func saveItems() {
        do {
            let encodedData = try JSONEncoder().encode(items)
            UserDefaults.standard.set(encodedData, forKey: itemsKey)
        } catch {
            print("Error encoding items: \(error)")
        }
    }

    /// Sort items based on the selected sorting mode
    func sortItems() {
        switch sortingMode {
        case .manual:
            break // No sorting required
        case .byDeadline:
            items.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .byCreationDate:
            items.sort { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        case .byPriority:
            items.sort { $0.priority.rawValue < $1.priority.rawValue }
        case .byTitle:
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// Delete items at specified indices
    func deleteItems(at indexSet: IndexSet) {
        items.remove(atOffsets: indexSet)
    }

    /// Delete a specific item by matching its ID
    func deleteItem(_ item: ItemModel) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
    }

    /// Add a new item or update an existing one
    func addOrUpdateItem(_ item: ItemModel?) {
        guard let item = item, !item.name.isEmpty else { return }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item // Update existing item
        } else {
            items.append(item) // Add new item
        }
    }

    /// Update an existing item by replacing it with a new version
    func updateItem(_ updatedItem: ItemModel) {
        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
            items[index] = updatedItem
        }
    }

    /// Get a specific item by ID
    func getItem(by id: UUID?) -> ItemModel? {
        guard let id = id else { return nil }
        return items.first(where: { $0.id == id })
    }

    /// Filter items based on completion status if `hideCompleted` is true
    var filteredItems: [ItemModel] {
        hideCompleted ? items.filter { !$0.completed } : items
    }
}















 



