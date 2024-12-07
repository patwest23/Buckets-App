//
//  ListViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation
import Combine
import SwiftUI

class ListViewModel: ObservableObject {
    @Published var items: [ItemModel] = [] {
        didSet { saveItems() }
    }
    @Published var showImages: Bool = true
    @Published var hideCompleted: Bool = false
    @Published var sortingMode: SortingMode = .manual
    @Published var currentEditingItem: ItemModel?

    private let itemsKey = "items_list"
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadItems()
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: itemsKey) else { return }
        do {
            self.items = try JSONDecoder().decode([ItemModel].self, from: data)
        } catch {
            print("Error decoding items: \(error)")
        }
    }

    func saveItems() {
        do {
            let encodedData = try JSONEncoder().encode(items)
            UserDefaults.standard.set(encodedData, forKey: itemsKey)
        } catch {
            print("Error encoding items: \(error)")
        }
    }

    func sortItems() {
        switch sortingMode {
        case .manual:
            break
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

    func deleteItems(at indexSet: IndexSet) {
        items.remove(atOffsets: indexSet)
    }

    func deleteItem(_ item: ItemModel) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
    }

    func addOrUpdateItem(_ item: ItemModel?) {
        guard let item = item, !item.name.isEmpty else { return }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item // Update existing item
        } else {
            items.append(item) // Add new item
        }
    }
}















 



