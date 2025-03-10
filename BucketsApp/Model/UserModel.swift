//
//  UserModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 12/29/24.
//

import Foundation
import FirebaseFirestore


/// Represents a user document in Firestore.
struct UserModel: Identifiable, Codable, Hashable {
    
    /// The Firestore document ID for this user (managed automatically if using Firestore’s Swift APIs).
    @DocumentID var id: String? = nil
    
    /// The user’s email address.
    var email: String
    
    /// The date/time when this user record was created.
    var createdAt: Date
    
    /// URL to the user’s profile image (stored in Firebase Storage or elsewhere).
    var profileImageUrl: String?
    
    /// The user’s full display name (e.g., “John Doe”). Defaults to "Guest" if none is provided.
    var name: String?
    
    /// A separate handle (like “@john123”). May be nil if user never set it.
    var username: String?
    
    // In UserModel or a separate structure:
    var following: [String] = []

    // MARK: - Custom Initializer
    init(
        id: String? = nil,
        email: String,
        createdAt: Date? = nil,
        profileImageUrl: String? = nil,
        name: String? = "Guest",
        username: String? = nil
    ) {
        self.id = id
        self.email = email
        self.createdAt = createdAt ?? Date()
        self.profileImageUrl = profileImageUrl
        self.name = name
        self.username = username
    }
}
