//
//  ItemModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import Foundation
import SwiftUI

struct ItemModel: Identifiable, Codable, Hashable {
    let id: UUID
    var imageData: Data?
    var name: String
    var description: String
    var completed: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id, name, description, completed
    }
    
    init(id: UUID = UUID(), name: String, description: String, completed: Bool) {
        self.id = id
        self.name = name
        self.description = description
        self.completed = completed
    }
}






