//
//  UserModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 12/29/24.
//

import Foundation
import FirebaseFirestore

struct UserModel: Codable, Hashable, Identifiable {
    // Use this for SwiftUI identity
    var id: String { documentId ?? "unknown-user-id" }

    @DocumentID var documentId: String?
    var wrappedId: String {
        documentId ?? "unknown-user-id"
    }

    var email: String?
    var createdAt: Date?
    var profileImageUrl: String?
    var name: String?
    var username: String?
    var following: [String] = []
    var followers: [String] = []
    var username_lower: String?
    var name_lower: String?
    var isFollowed: Bool = false

    enum CodingKeys: String, CodingKey {
        case documentId = "id"
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

    init(
        documentId: String? = nil,
        email: String? = nil,
        createdAt: Date? = nil,
        profileImageUrl: String? = nil,
        name: String? = "Guest",
        username: String? = nil,
        following: [String] = [],
        followers: [String] = [],
        username_lower: String? = nil,
        name_lower: String? = nil,
        isFollowed: Bool = false
    ) {
        self.documentId = documentId
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

