//
//  ListViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation
import Combine
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

enum SortingMode: String, CaseIterable {
    case manual
    case byDeadline
    case byCreationDate
    case byPriority
    case byTitle
}

@MainActor
class ListViewModel: ObservableObject {
    @Published var items: [ItemModel] = [] {
        didSet { saveItemsLocally() }
    }
    @Published var showImages: Bool = true
    @Published var hideCompleted: Bool = false
    @Published var sortingMode: SortingMode = .manual
    @Published var currentEditingItem: ItemModel?
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    private let db = Firestore.firestore()

    // MARK: - Initialization
    init() {
        loadItemsFromLocal()
    }

    // MARK: - Persistent Storage

    /// Load items from persistent storage or Firestore.
    func loadItems() async {
        guard let userId = userId else {
            print("Error: No userId available.")
            return
        }

        do {
            let snapshot = try await db.collection("users").document(userId).collection("items").getDocuments()
            self.items = snapshot.documents.compactMap { try? $0.data(as: ItemModel.self) }
            saveItemsLocally() // Cache items locally
            print("Items successfully loaded from Firestore.")
        } catch {
            print("Error loading items from Firestore: \(error.localizedDescription)")
        }
    }

    /// Save items locally to persistent storage.
    private func saveItemsLocally() {
        do {
            let encodedData = try JSONEncoder().encode(items)
            UserDefaults.standard.set(encodedData, forKey: "items_list")
        } catch {
            print("Error saving items locally: \(error.localizedDescription)")
        }
    }

    /// Load items from local storage (fallback).
    private func loadItemsFromLocal() {
        guard let data = UserDefaults.standard.data(forKey: "items_list") else { return }
        do {
            self.items = try JSONDecoder().decode([ItemModel].self, from: data)
        } catch {
            print("Error decoding items from local storage: \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD Operations with Firestore

    /// Add or update an item in Firestore.
    func addOrUpdateItem(_ item: ItemModel) async {
        guard let userId = userId else {
            print("Error: No userId available.")
            return
        }

        do {
            try await db.collection("users").document(userId).collection("items")
                .document(item.id.uuidString).setData(from: item, merge: true)
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item // Update local item
            } else {
                items.append(item) // Add new item locally
            }
            print("Item successfully added/updated in Firestore.")
        } catch {
            print("Error adding/updating item in Firestore: \(error.localizedDescription)")
        }
    }

    /// Delete an item from Firestore.
    func deleteItem(_ item: ItemModel) async {
        guard let userId = userId else {
            print("Error: No userId available.")
            return
        }

        do {
            try await db.collection("users").document(userId).collection("items")
                .document(item.id.uuidString).delete()
            items.removeAll { $0.id == item.id } // Remove locally
            print("Item successfully deleted from Firestore.")
        } catch {
            print("Error deleting item from Firestore: \(error.localizedDescription)")
        }
    }

    /// Delete items at specified indices in Firestore.
    func deleteItems(at indexSet: IndexSet) async {
        guard let userId = userId else {
            print("Error: No userId available.")
            return
        }

        let itemsToDelete = indexSet.map { items[$0] }
        for item in itemsToDelete {
            await deleteItem(item)
        }
    }

    /// Fetch a single item by its ID.
    func getItem(by id: UUID) -> ItemModel? {
        items.first { $0.id == id }
    }

    // MARK: - Sorting

    /// Sort items based on the selected sorting mode.
    func sortItems() {
        switch sortingMode {
        case .manual:
            break
        case .byDeadline:
            items.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .byCreationDate:
            items.sort { $0.creationDate < $1.creationDate }
        case .byPriority:
            items.sort { $0.priority.rawValue < $1.priority.rawValue }
        case .byTitle:
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    // MARK: - Filtering

    /// Filter items based on completion status.
    var filteredItems: [ItemModel] {
        hideCompleted ? items.filter { !$0.completed } : items
    }
}















 



