import Foundation
import SwiftUI

struct SocialStats: Hashable {
    var total: Int
    var completed: Int
    var lastCompletion: Date?

    var open: Int { max(total - completed, 0) }

    var completionRateText: String {
        guard total > 0 else { return "0% done" }
        let percentage = Double(completed) / Double(total)
        return "\(Int(percentage * 100))% complete"
    }

    var daysSinceLastCompletion: Int? {
        guard let lastCompletion else { return nil }
        let components = Calendar.current.dateComponents([.day], from: lastCompletion, to: Date())
        return components.day
    }
}

struct SocialBucketItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var imageURLs: [URL]
    var blurb: String
    var locationDescription: String?
    var completionDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool,
        imageURLs: [URL] = [],
        blurb: String,
        locationDescription: String? = nil,
        completionDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.imageURLs = imageURLs
        self.blurb = blurb
        self.locationDescription = locationDescription
        self.completionDate = completionDate
    }
}

struct SocialUser: Identifiable, Hashable {
    let id: UUID
    let firebaseUserID: String
    var username: String
    var displayName: String
    var email: String
    var memberSince: Date
    var avatarSystemImage: String
    var profileImageURL: URL?
    var stats: SocialStats
    var listItems: [SocialBucketItem]
    var isFollowing: Bool
    var isFollower: Bool

    init(
        id: UUID = UUID(),
        firebaseUserID: String = UUID().uuidString,
        username: String,
        displayName: String,
        email: String,
        memberSince: Date,
        avatarSystemImage: String = "person.crop.circle",
        profileImageURL: URL? = nil,
        stats: SocialStats,
        listItems: [SocialBucketItem] = [],
        isFollowing: Bool = false,
        isFollower: Bool = false
    ) {
        self.id = id
        self.firebaseUserID = firebaseUserID
        self.username = username
        self.displayName = displayName
        self.email = email
        self.memberSince = memberSince
        self.avatarSystemImage = avatarSystemImage
        self.profileImageURL = profileImageURL
        self.stats = stats
        self.listItems = listItems
        self.isFollowing = isFollowing
        self.isFollower = isFollower
    }
}

enum ActivityEventType: String, Codable {
    case added
    case completed
}

struct ActivityEvent: Identifiable, Hashable {
    let id: UUID
    let user: SocialUser
    let item: SocialBucketItem
    let type: ActivityEventType
    let timestamp: Date

    init(id: UUID = UUID(), user: SocialUser, item: SocialBucketItem, type: ActivityEventType, timestamp: Date) {
        self.id = id
        self.user = user
        self.item = item
        self.type = type
        self.timestamp = timestamp
    }
}

extension SocialUser {
    static var mockUsers: [SocialUser] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        let profileImageURLs: [URL] = [
            URL(string: "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=400&q=80")!,
            URL(string: "https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=400&q=80")!,
            URL(string: "https://images.unsplash.com/photo-1520340356584-8f5c05a004a0?w=400&q=80")!,
            URL(string: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&q=80")!
        ]

        let imageURLs: [URL] = [
            URL(string: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=600&q=80")!,
            URL(string: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=600&q=80")!,
            URL(string: "https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=600&q=80")!,
            URL(string: "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=600&q=80")!
        ]

        let blurbs = [
            "Snagged a coveted reservation downtown.",
            "Chasing waves on the West Coast.",
            "Learning to make fresh pasta from scratch.",
            "Exploring neon-lit side streets in Tokyo."
        ]

        func sampleItems(base: String) -> [SocialBucketItem] {
            return (0..<4).map { index in
                SocialBucketItem(
                    title: "\(base) adventure #\(index + 1)",
                    isCompleted: index % 2 == 0,
                    imageURLs: Array(imageURLs.shuffled().prefix(Int.random(in: 1...3))),
                    blurb: blurbs[index % blurbs.count],
                    locationDescription: index % 2 == 0 ? "Downtown Loft" : "Seaside Cliff",
                    completionDate: index % 2 == 0 ? Calendar.current.date(byAdding: .day, value: -index, to: Date()) : nil
                )
            }
        }

        return [
            SocialUser(
                firebaseUserID: UUID().uuidString,
                username: "@patwest",
                displayName: "Pat West",
                email: "pat@example.com",
                memberSince: formatter.date(from: "2019-05-03") ?? Date(),
                avatarSystemImage: "person.circle.fill",
                profileImageURL: profileImageURLs[0],
                stats: SocialStats(total: 42, completed: 18, lastCompletion: Calendar.current.date(byAdding: .day, value: -3, to: Date())),
                listItems: sampleItems(base: "City"),
                isFollowing: true,
                isFollower: true
            ),
            SocialUser(
                firebaseUserID: UUID().uuidString,
                username: "@wanderlux",
                displayName: "Jess Summers",
                email: "jess@example.com",
                memberSince: formatter.date(from: "2020-02-12") ?? Date(),
                avatarSystemImage: "person.crop.circle.fill.badge.checkmark",
                profileImageURL: profileImageURLs[1],
                stats: SocialStats(total: 30, completed: 10, lastCompletion: Calendar.current.date(byAdding: .day, value: -8, to: Date())),
                listItems: sampleItems(base: "Coast"),
                isFollowing: true,
                isFollower: false
            ),
            SocialUser(
                firebaseUserID: UUID().uuidString,
                username: "@kitetom",
                displayName: "Tom Lee",
                email: "tom@example.com",
                memberSince: formatter.date(from: "2018-10-23") ?? Date(),
                avatarSystemImage: "person.crop.circle.badge.moon",
                profileImageURL: profileImageURLs[2],
                stats: SocialStats(total: 55, completed: 44, lastCompletion: Calendar.current.date(byAdding: .day, value: -1, to: Date())),
                listItems: sampleItems(base: "Trail"),
                isFollowing: false,
                isFollower: true
            ),
            SocialUser(
                firebaseUserID: UUID().uuidString,
                username: "@heyamelia",
                displayName: "Amelia Chen",
                email: "amelia@example.com",
                memberSince: formatter.date(from: "2021-07-14") ?? Date(),
                avatarSystemImage: "person.crop.circle.badge.questionmark",
                profileImageURL: profileImageURLs[3],
                stats: SocialStats(total: 18, completed: 6, lastCompletion: Calendar.current.date(byAdding: .day, value: -20, to: Date())),
                listItems: sampleItems(base: "Food"),
                isFollowing: false,
                isFollower: false
            )
        ]
    }
}

extension ActivityEvent {
    static func mockFeed(users: [SocialUser]) -> [ActivityEvent] {
        let now = Date()
        var events: [ActivityEvent] = []
        for (offset, user) in users.enumerated() {
            guard let item = user.listItems.randomElement() else { continue }
            let addedDate = Calendar.current.date(byAdding: .day, value: -(offset * 3), to: now) ?? now
            events.append(ActivityEvent(user: user, item: item, type: .added, timestamp: addedDate))

            if let completedItem = user.listItems.first(where: { $0.isCompleted }) {
                let completionDate = Calendar.current.date(byAdding: .day, value: -(offset * 2 + 1), to: now) ?? now
                events.append(ActivityEvent(user: user, item: completedItem, type: .completed, timestamp: completionDate))
            }
        }
        return events.sorted { $0.timestamp > $1.timestamp }
    }
}
