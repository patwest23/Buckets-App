//
//  ItemModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//


import Foundation
import SwiftUI

enum Priority: String, Codable {
    case none, low, medium, high
}

struct Tag: Codable, Hashable {
    var title: String
}

struct Location: Codable, Hashable {
    // Define properties of Location as needed
}

struct ItemModel: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var description: String?
    var url: String?
    var dueDate: Date?
    var hasDueTime: Bool = false
    var tags: [Tag]?
    var location: Location?
    var flagged: Bool = false
    var priority: Priority = .none
    var completed: Bool = false
    var order: Int = 0
    var userId: String?
    var creationDate: Date = Date()
    var imagesData: [Data] = [] // Array to hold multiple image data

    init(name: String = "", description: String? = nil, imagesData: [Data] = []) {
        self.name = name
        self.description = description
        self.imagesData = imagesData
    }
}














