//
//  ListViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

/*

import Foundation
import SwiftUI
import PhotosUI


class ListViewModel: ObservableObject {
    
    @StateObject var imagePicker = ImagePicker()
    
    @Published var image: Image?
    @Published var images: [Image] = []
    @Published var imageSelection: PhotosPickerItem? {
        didSet {
            if let imageSelection = imageSelection {
                Task {
                    do {
                        try await imagePicker.loadTransferable(from: imageSelection)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
    @Published var imageSelections: [PhotosPickerItem] = [] {
        didSet {
            Task {
                if !imageSelections.isEmpty {
                    do {
                        try await imagePicker.loadTransferable(from: imageSelections)
                        imageSelections = []
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    @Published var items: [ItemModel] = [] {
        // any time the array is changed it will call the function saveItems
        didSet {
            saveItems()
        }
    }
    
    let itemsKey: String = "items_list"
    
    init() {
        loadItems()
    }
    
    
    
    
    
    
    
    
    // Simulate reading from a database
    func loadItems() {
        guard
            let data = UserDefaults.standard.data(forKey: itemsKey),
            let savedItems = try? JSONDecoder().decode([ItemModel].self, from: data)
        else {return}
        
        self.items = savedItems
    }
    
    
    
    
    
    func addItem(item: ItemModel) {
        guard !item.name.isEmpty else { return }
        items.append(item)
    }
    
    func updateItem(_ item: ItemModel, withName name: String, description: String, completed: Bool) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].name = name
            items[index].description = description
            items[index].completed = completed
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
    
    // for now just want to persist locally on my iphone
    // eventually will be on Firebase
    func saveItems() {
        if let encodeData = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encodeData, forKey: itemsKey)
        }
    }
    
    
    
    // image picker functions
    // revise these functions to be included in the Item Model
    
    
    
    func loadTransferable(from imageSelections: [PhotosPickerItem]) async throws {
        do {
            for imageSelection in imageSelections {
                if let data = try await imageSelection.loadTransferable(type: Data.self) {
                    if let uiImage = UIImage(data: data) {
                        self.images.append(Image(uiImage: uiImage))
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func loadTransferable(from imageSelection: PhotosPickerItem?) async throws {
//        print(Image.transferRepresentation)
        do {
            if let data = try await imageSelection?.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    self.image = Image(uiImage: uiImage)
                }
            }
        } catch {
            print(error.localizedDescription)
            image = nil
        }
    }
    
}

 
*/



