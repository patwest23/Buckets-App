//
//  ItemModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//


import Foundation
import SwiftUI

enum Priority: String {
    case none
    case low
    case medium
    case high
}

struct Tag {
    var title: String
}

struct Location {
}

struct ItemModel {
    var id: UUID? // Changed to optional to match Reminder's docId
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
    var userId: String? // Not present in Reminder, added for consistency
    var creationDate: Date? // Add creationDate property

    // Initialize with a name and optional description
    init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
        self.creationDate = Date() // Set the creation date to the current date when initializing
    }
}

extension Priority: Codable, Equatable, Identifiable {
    var id: Priority { self }
}

//extension Priority: Comparable {
//    static func < (lhs: Priority, rhs: Priority) -> Bool {
//        guard let l = lhs.index, let r = rhs.index else { return false }
//        return l < r
//    }
//}

extension CaseIterable where Self: Equatable {
    var index: Self.AllCases.Index? {
        return Self.allCases.firstIndex { self == $0 }
    }
}

extension Tag: Codable, Equatable {
}

extension Location: Codable, Equatable {
}

extension ItemModel: Codable, Identifiable, Equatable {
}

// Updated the samples to use the new initializer
extension ItemModel {
    static let samples = [
        ItemModel(name: "Build sample app"),
        ItemModel(name: "Tweet about surprising findings", description: "Include interesting stats"),
        ItemModel(name: "Write newsletter"),
        ItemModel(name: "Run YouTube video series", description: "Plan content and schedule"),
        ItemModel(name: "???"),
    ]
}







