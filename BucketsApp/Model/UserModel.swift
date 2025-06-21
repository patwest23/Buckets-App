//
//  UserModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 12/29/24.
//

import Foundation
import FirebaseFirestore

struct UserModel: Codable, Hashable, Identifiable {
    var id: String { documentId ?? "unknown-user-id" }

    @DocumentID var documentId: String?

    var email: String?
    var createdAt: Date?
    var profileImageUrl: String?
    var name: String?
    var username: String?
    var following: [String]
    var followers: [String]
    var username_lower: String?
    var name_lower: String?
    var isFollowed: Bool

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
        case isFollowed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.documentId = nil // Assigned manually in ViewModel after decoding
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.following = try container.decodeIfPresent([String].self, forKey: .following) ?? []
        self.followers = try container.decodeIfPresent([String].self, forKey: .followers) ?? []
        self.username_lower = try container.decodeIfPresent(String.self, forKey: .username_lower)
        self.name_lower = try container.decodeIfPresent(String.self, forKey: .name_lower)
        self.isFollowed = try container.decodeIfPresent(Bool.self, forKey: .isFollowed) ?? false
    }

    // Preview/test initializer
    init(
        documentId: String? = nil,
        email: String? = nil,
        profileImageUrl: String? = nil,
        name: String? = nil,
        username: String? = nil
    ) {
        self.documentId = documentId
        self.email = email
        self.createdAt = nil
        self.profileImageUrl = profileImageUrl
        self.name = name
        self.username = username
        self.following = []
        self.followers = []
        self.username_lower = nil
        self.name_lower = nil
        self.isFollowed = false
    }
}
