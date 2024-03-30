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
        didSet {
            saveItems()
        }
    }
    
    private let itemsKey: String = "items_list"
    
//    @Published var sortingMode: SortingMode = .manual {
//        didSet {
//            sortItems()
//        }
//    }
    
    @Published private var showingAddItemView = false
    @Published private var selectedItem: ItemModel?
    
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
    
    func deleteItems(at indexSet: IndexSet) {
        items.remove(atOffsets: indexSet)
    }
    
//    private func sortItems() {
//        switch sortingMode {
//        case .manual:
//            // No sorting needed for manual mode
//            break
//        case .byDeadline:
//            items.sort { $0.dueDate ?? Date.distantPast < $1.dueDate ?? Date.distantPast }
//        case .byCreationDate:
//            items.sort { $0.creationDate.timeIntervalSinceReferenceDate < $1.creationDate.timeIntervalSinceReferenceDate }
//        case .byPriority:
//            items.sort { $0.priority.rawValue < $1.priority.rawValue }
//        case .byTitle:
//            items.sort { $0.name < $1.name }
//        }
//    }

    
    // Other methods...
}

 



