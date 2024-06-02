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
    
    var itemName: String {
        get {
            item.name
        }
        set {
            item.name = newValue
        }
    }
    
    var isCompleted: Bool {
        item.completed
    }
    
    func onToggleCompleted() {
        item.completed.toggle()
    }
}


