//
//  ItemModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation
import SwiftUI


struct ItemModel: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    var imageData: Data?
    var name: String
    var description: String
    var completed: Bool

    // Ensure imageData is included in coding keys
    private enum CodingKeys: String, CodingKey {
        case id, imageData, name, description, completed
    }

    // Ensure there's an initializer to handle all parameters with default values
    init(id: UUID = UUID(), name: String = "", description: String = "", completed: Bool = false, imageData: Data? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.completed = completed
        self.imageData = imageData
    }
}








