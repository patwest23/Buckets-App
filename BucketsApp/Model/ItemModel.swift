//
//  ItemModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation
import SwiftUI

struct ItemModel: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var completed: Bool

    init(id: UUID = UUID(), name: String, description: String, completed: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.completed = completed
    }
}

// do you need a function to return an updated Item?

//func updateCompletion() -> ItemModel {
//    return ItemModel(id: id, title: title, isCompleted: !isCompleted)
//}
//}

