import Foundation

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

    private var pendingEvents: [UUID: ActivityEvent] = [:]
    private var delayTasks: [UUID: Task<Void, Never>] = [:]
    private let activityDelay: UInt64 = 70 * 1_000_000_000 // ~70 seconds

    init() {
        loadMockData()
    }

    func bootstrapIfNeeded() {
        if followers.isEmpty && following.isEmpty && explore.isEmpty {
            loadMockData()
        }
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
        try? await Task.sleep(nanoseconds: 800_000_000)
        await MainActor.run {
            if let randomUser = (following + explore).randomElement(),
               let item = randomUser.listItems.randomElement() {
                let newEvent = ActivityEvent(user: randomUser, item: item, type: .added, timestamp: Date())
                activityLog.insert(newEvent, at: 0)
                trimActivityLog()
            }
        }
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
        followers = Array(users.prefix(3))
        following = users.filter { $0.isFollowing }
        explore = users
        activityLog = ActivityEvent.mockFeed(users: users)
    }

    private func trimActivityLog() {
        let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        activityLog = activityLog.filter { $0.timestamp >= cutoff }
    }
}
