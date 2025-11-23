//
//  UserModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 12/29/24.
//

import Foundation
import FirebaseFirestore


/// Represents a user document in Firestore.
struct UserModel: Identifiable, Codable {
    
    /// The Firestore document ID for this user (managed automatically if using Firestore’s Swift APIs).
    @DocumentID var id: String? = nil
    
    /// The user’s email address.
    var email: String

    /// The date/time when this user record was created.
    var createdAt: Date?

    /// URL to the user’s profile image (stored in Firebase Storage or elsewhere).
    var profileImageUrl: String?

    /// The user’s full display name (e.g., “John Doe”). Defaults to "Guest" if none is provided.
    var name: String?

    /// A separate handle (like “@john123”). May be nil if user never set it.
    var username: String?

    /// List of Firebase Auth UIDs that follow this user.
    var followers: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt
        case profileImageUrl
        case name
        case username
        case followers
    }

    // MARK: - Custom Initializer
    init(
        id: String? = nil,
        email: String,
        createdAt: Date? = nil,
        profileImageUrl: String? = nil,
        name: String? = "Guest",
        username: String? = nil,
        followers: [String] = []
    ) {
        self.id = id
        self.email = email
        self.createdAt = createdAt ?? Date()
        self.profileImageUrl = profileImageUrl
        self.name = name
        self.username = username
        self.followers = followers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        followers = try container.decodeIfPresent([String].self, forKey: .followers) ?? []
    }
}
