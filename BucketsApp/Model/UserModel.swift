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
    @DocumentID var id: String? // Firestore document ID
    var email: String
    var createdAt: Date?

    // Add other fields based on your Firestore "users" collection schema
    var profileImageUrl: String?
    var name: String?

    init(id: String? = nil, email: String, createdAt: Date? = nil, profileImageUrl: String? = nil, name: String? = nil) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
        self.profileImageUrl = profileImageUrl
        self.name = name
    }
}
