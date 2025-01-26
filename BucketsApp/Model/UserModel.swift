//
//  UserModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 12/29/24.
//

import SwiftUI
import Foundation
import CoreLocation
import FirebaseFirestore

struct UserModel: Identifiable, Codable {
    @DocumentID var id: String? = nil // Default to `nil` if no document ID is provided
        var email: String = "" // Default to an empty string for email
        var createdAt: Date = Date() // Default to the current date
        var profileImageUrl: String? = nil // Default to `nil` if no profile image URL
        var name: String? = "Guest" // Default to "Guest" if no name is provided

    init(id: String? = nil, email: String, createdAt: Date? = nil, profileImageUrl: String? = nil, name: String? = nil) {
        self.id = id
        self.email = email
        self.createdAt = createdAt ?? Date()
        self.profileImageUrl = profileImageUrl
        self.name = name
    }
}
