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
    @DocumentID var id: String?
    
    /// The user’s email address.
    var email: String?
    
    /// The date/time when this user record was created.
    var createdAt: Date?
    
    /// URL to the user’s profile image (stored in Firebase Storage or elsewhere).
    var profileImageUrl: String?
    
    /// The user’s full display name (e.g., “John Doe”). Defaults to "Guest" if none is provided.
    var name: String?
    
    /// A separate handle (like “@john123”). May be nil if user never set it.
    var username: String?
    
    /// An array of user IDs that this user is following.
    var following: [String]?
    
    /// An optional array of user IDs who follow this user.
    var followers: [String]?

    /// Lowercased versions of name/username for case-insensitive search.
    var username_lower: String?
    var name_lower: String?
    
    /// Local-only property to track if user is already followed (not written to Firestore)
    var isFollowed: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt
        case profileImageUrl
        case name
        case username
        case following
        case followers
        case username_lower
        case name_lower
    }
    
    // MARK: - Custom Initializer
    init(
        id: String? = nil,
        email: String? = nil,
        createdAt: Date? = nil,
        profileImageUrl: String? = nil,
        name: String? = "Guest",
        username: String? = nil,
        following: [String]? = nil,
        followers: [String]? = nil,
        username_lower: String? = nil,
        name_lower: String? = nil,
        isFollowed: Bool = false
    ) {
        self.id = id
        self.email = email ?? "unknown@example.com"
        self.createdAt = createdAt ?? Date()
        self.profileImageUrl = profileImageUrl
        self.name = name
        self.username = username
        self.following = following
        self.followers = followers
        self.username_lower = username_lower
        self.name_lower = name_lower
        self.isFollowed = isFollowed
    }
}
