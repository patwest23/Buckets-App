//
//  FollowModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/9/25.
//

//import Foundation
//
//struct FollowModel: Identifiable, Codable {
//    var id: String  // Document ID in Firestore
//    var followerId: String  // The user who follows
//    var followingId: String  // The user being followed
//    var timestamp: Date  // When the follow happened
//
//    // Default initializer (useful for previews and testing)
//    init(id: String = UUID().uuidString,
//         followerId: String,
//         followingId: String,
//         timestamp: Date = Date()) {
//        self.id = id
//        self.followerId = followerId
//        self.followingId = followingId
//        self.timestamp = timestamp
//    }
//
//    enum CodingKeys: String, CodingKey {
//        case id
//        case followerId
//        case followingId
//        case timestamp
//    }
//}
