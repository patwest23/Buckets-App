//
//  ItemRowViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/30/24.
//

import SwiftUI

class ItemRowViewModel: ObservableObject {
    @Binding var item: ItemModel

    init(item: Binding<ItemModel>) {
        self._item = item
    }
    
    /// Toggle the completed state of the item
    func toggleCompleted() {
        item.completed.toggle()
    }
}

