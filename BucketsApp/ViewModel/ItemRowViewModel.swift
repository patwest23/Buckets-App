//
//  ItemRowViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/30/24.
//

import SwiftUI

class ItemRowViewModel: ObservableObject {
    @Published var item: ItemModel
    private weak var listViewModel: ListViewModel?

    init(item: ItemModel, listViewModel: ListViewModel?) {
        self.item = item
        self.listViewModel = listViewModel
    }

    /// Toggle the completed state of the item
    func toggleCompleted() {
        item.completed.toggle()
        updateItem()
    }

    /// Update the item in the centralized ListViewModel
    private func updateItem() {
        listViewModel?.updateItem(item)
    }
}

