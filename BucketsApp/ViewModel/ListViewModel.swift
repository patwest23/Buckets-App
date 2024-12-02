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

    private let itemsKey = "items_list"
    private var cancellables = Set<AnyCancellable>()

    init() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadItems()
        }
    }

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

    func sortItems() {
        DispatchQueue.main.async {
            switch self.sortingMode {
            case .manual:
                break
            case .byDeadline:
                self.items.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            case .byCreationDate:
                self.items.sort { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
            case .byPriority:
                self.items.sort { $0.priority.rawValue < $1.priority.rawValue }
            case .byTitle:
                self.items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        }
    }

    func deleteItems(at indexSet: IndexSet) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        items.remove(atOffsets: indexSet)
    }

    func deleteItem(_ item: ItemModel) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
    }

    func addItem(_ item: ItemModel?) {
        guard let item = item, !item.name.isEmpty else { return }
        items.append(item)
    }
}















 



