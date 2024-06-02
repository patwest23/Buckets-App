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

enum Focusable: Hashable {
    case none
    case row(id: UUID)
}

class ListViewModel: ObservableObject {
    @Published var items: [ItemModel] = [] {
        didSet {
            saveItems()
        }
    }
    @Published var showImages: Bool = true
    @Published var hideCompleted: Bool = false
    @Published var focusedItemID: Focusable? = Focusable.none

    private let itemsKey: String = "items_list"
    
    @Published var sortingMode: SortingMode = .manual {
        didSet {
            sortItems()
        }
    }
    
    @Published var showingAddItemView = false
    @Published var selectedItem: ItemModel?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadItems()
    }
    
    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: itemsKey) else {
            return
        }
        
        do {
            self.items = try JSONDecoder().decode([ItemModel].self, from: data)
        } catch {
            print("Error decoding items: \(error)")
        }
    }
    
    private func saveItems() {
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
            items.sort {
                guard let date1 = $0.dueDate, let date2 = $1.dueDate else { return false }
                return date1 < date2
            }
        case .byCreationDate:
            items.sort {
                guard let date1 = $0.creationDate, let date2 = $1.creationDate else { return false }
                return date1 < date2
            }
        case .byPriority:
            items.sort { $0.priority.rawValue < $1.priority.rawValue }
        case .byTitle:
            items.sort { $0.name < $1.name }
        }
    }
    
    func deleteItems(at indexSet: IndexSet) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        items.remove(atOffsets: indexSet)
    }
}






 



