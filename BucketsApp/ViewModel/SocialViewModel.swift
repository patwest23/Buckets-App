import Foundation
import FirebaseFirestore

enum FriendListTab: String, CaseIterable, Identifiable {
    case followers
    case following
    case explore

    var id: String { rawValue }
    var title: String {
        switch self {
        case .followers: return "Followers"
        case .following: return "Following"
        case .explore: return "Explore"
        }
    }
}

@MainActor
final class SocialViewModel: ObservableObject {
    @Published private(set) var followers: [SocialUser] = []
    @Published private(set) var following: [SocialUser] = []
    @Published private(set) var explore: [SocialUser] = []
    @Published private(set) var activityLog: [ActivityEvent] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastErrorMessage: String?

    private var pendingEvents: [UUID: ActivityEvent] = [:]
    private var delayTasks: [UUID: Task<Void, Never>] = [:]
    private let activityDelay: UInt64 = 70 * 1_000_000_000 // ~70 seconds
    private let db = Firestore.firestore()
    private var hasLoadedFromFirestore = false

    init(useMockData: Bool = false) {
        if useMockData {
            loadMockData()
        }
    }

    func bootstrapIfNeeded() {
        guard !hasLoadedFromFirestore, !isLoading else { return }
        Task { await loadUsersFromFirestore(forceReload: false) }
    }

    var recentActivity: [ActivityEvent] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return activityLog
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func userCount(for tab: FriendListTab) -> Int {
        switch tab {
        case .followers: return followers.count
        case .following: return following.count
        case .explore: return explore.count
        }
    }

    func filteredUsers(for tab: FriendListTab, searchText: String) -> [SocialUser] {
        let source: [SocialUser]
        switch tab {
        case .followers: source = followers
        case .following: source = following
        case .explore: source = explore
        }
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return source }
        return source.filter {
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    func toggleFollow(_ user: SocialUser) {
        var updated = user
        updated.isFollowing.toggle()

        update(user: updated, in: &followers)
        update(user: updated, in: &following)
        update(user: updated, in: &explore)

        if updated.isFollowing {
            if !following.contains(where: { $0.id == updated.id }) {
                following.append(updated)
            }
        } else {
            following.removeAll { $0.id == updated.id }
        }
    }

    func refreshActivityLog() async {
        await loadUsersFromFirestore(forceReload: true)
    }

    func record(event: ActivityEvent) {
        pendingEvents[event.id] = event
        delayTasks[event.id]?.cancel()
        delayTasks[event.id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: activityDelay)
            await MainActor.run {
                guard let self = self else { return }
                self.pendingEvents[event.id] = nil
                self.activityLog.insert(event, at: 0)
                self.trimActivityLog()
            }
        }
    }

    func cancelPendingEvent(with id: UUID) {
        delayTasks[id]?.cancel()
        delayTasks[id] = nil
        pendingEvents[id] = nil
    }

    private func update(user: SocialUser, in array: inout [SocialUser]) {
        if let idx = array.firstIndex(where: { $0.id == user.id }) {
            array[idx] = user
        }
    }

    private func loadMockData() {
        let users = SocialUser.mockUsers
        followers = users
        following = users.filter { $0.isFollowing }
        explore = users
        activityLog = ActivityEvent.mockFeed(users: users)
    }

    private func trimActivityLog() {
        let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        activityLog = activityLog.filter { $0.timestamp >= cutoff }
    }

    private func loadUsersFromFirestore(forceReload: Bool) async {
        if isLoading { return }
        if !forceReload && hasLoadedFromFirestore { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("users").getDocuments()
            let previouslyFollowing = Set(following.map { $0.firebaseUserID })

            var loadedUsers: [SocialUser] = []
            var newActivityEvents: [ActivityEvent] = []

            for userDocument in snapshot.documents {
                let documentID = userDocument.documentID
                // Capture identifiers before awaiting so we never touch the snapshot after suspension.

                do {
                    let userModel = try userDocument.data(as: UserModel.self)
                    let itemsQuery = db.collection("users").document(documentID).collection("items")
                    let itemsSnapshot = try await itemsQuery.getDocuments()
                    let itemModels: [ItemModel] = try itemsSnapshot.documents.compactMap { document in
                        try document.data(as: ItemModel.self)
                    }

                    var (user, enrichedItems) = buildSocialUser(
                        from: userModel,
                        userID: documentID,
                        items: itemModels
                    )
                    if previouslyFollowing.contains(user.firebaseUserID) {
                        user.isFollowing = true
                    }

                    let events = buildActivityEvents(for: user, enrichedItems: enrichedItems)
                    newActivityEvents.append(contentsOf: events)
                    loadedUsers.append(user)
                } catch {
                    print("[SocialViewModel] Failed to decode user document \(documentID):", error.localizedDescription)
                }
            }

            followers = loadedUsers
            explore = loadedUsers
            following = loadedUsers.filter { $0.isFollowing }
            activityLog = newActivityEvents.sorted { $0.timestamp > $1.timestamp }
            trimActivityLog()
            hasLoadedFromFirestore = true
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            print("[SocialViewModel] Error loading users:", error.localizedDescription)

            if followers.isEmpty && explore.isEmpty {
                loadMockData()
            }
        }
    }

    private func buildSocialUser(
        from userModel: UserModel,
        userID: String,
        items: [ItemModel]
    ) -> (SocialUser, [(ItemModel, SocialBucketItem)]) {
        let enrichedItems = items.map { item -> (ItemModel, SocialBucketItem) in
            let imageURL = item.imageUrls.first.flatMap { URL(string: $0) }
            let blurbSource = item.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedBlurb: String
            if let blurb = blurbSource, !blurb.isEmpty {
                resolvedBlurb = blurb
            } else if let address = item.location?.address, !address.isEmpty {
                resolvedBlurb = address
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                resolvedBlurb = "Added on \(formatter.string(from: item.creationDate))"
            }

            let socialItem = SocialBucketItem(
                id: item.id,
                title: item.name.isEmpty ? "Untitled bucket" : item.name,
                isCompleted: item.completed,
                imageURL: imageURL,
                blurb: resolvedBlurb
            )

            return (item, socialItem)
        }

        let socialItems = enrichedItems.map { $0.1 }

        let completedItems = items.filter { $0.completed }
        let completionDates = completedItems.compactMap { $0.dueDate ?? $0.creationDate }

        let stats = SocialStats(
            total: items.count,
            completed: completedItems.count,
            lastCompletion: completionDates.max()
        )

        var username = userModel.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if username.isEmpty {
            let emailPrefix = userModel.email.split(separator: "@").first ?? "user"
            username = "@\(emailPrefix)"
        } else if !username.hasPrefix("@") {
            username = "@\(username)"
        }

        let displayName = userModel.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = displayName?.isEmpty == false ? displayName! : username.replacingOccurrences(of: "@", with: "").capitalized

        let profileImageURLString = userModel.profileImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileImageURL = profileImageURLString?.isEmpty == false ? URL(string: profileImageURLString!) : nil

        return (
            SocialUser(
                firebaseUserID: userID,
                username: username,
                displayName: resolvedDisplayName,
                email: userModel.email,
                memberSince: userModel.createdAt ?? Date(),
                avatarSystemImage: "person.crop.circle",
                profileImageURL: profileImageURL,
                stats: stats,
                listItems: socialItems,
                isFollowing: false,
                isFollower: true
            ),
            enrichedItems
        )
    }

    private func buildActivityEvents(
        for user: SocialUser,
        enrichedItems: [(ItemModel, SocialBucketItem)]
    ) -> [ActivityEvent] {
        enrichedItems.map { item, socialItem in
            let type: ActivityEventType = item.completed ? .completed : .added
            let timestamp = item.completed ? (item.dueDate ?? item.creationDate) : item.creationDate
            return ActivityEvent(user: user, item: socialItem, type: type, timestamp: timestamp)
        }
    }
}
