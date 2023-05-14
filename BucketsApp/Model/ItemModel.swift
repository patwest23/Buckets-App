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
    var name: String
    var description: String
    var completed: Bool
    var images: [Data]

    private enum CodingKeys: String, CodingKey {
        case id, name, description, completed, images
    }

    init(id: UUID = UUID(), name: String, description: String, completed: Bool, images: [Data] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.completed = completed
        self.images = images
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        completed = try container.decode(Bool.self, forKey: .completed)
        images = try container.decode([Data].self, forKey: .images)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(completed, forKey: .completed)
        try container.encode(images, forKey: .images)
    }
}






