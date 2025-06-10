//
//  FollowModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/9/25.
//

import Foundation

struct FollowModel: Identifiable, Codable {
    var id: String  // Document ID in Firestore
    var followerId: String  // The user who follows
    var followingId: String  // The user being followed
    var timestamp: Date  // When the follow happened

    enum CodingKeys: String, CodingKey {
        case id
        case followerId
        case followingId
        case timestamp
    }
}
