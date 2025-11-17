import Foundation
import FirebaseFirestore
import FirebaseStorage

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
    private let storage = Storage.storage()
    private var hasLoadedFromFirestore = false
    private var imageURLCache: [String: URL] = [:]

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
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.activityDelay)
            await MainActor.run {
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

                    var (user, enrichedItems) = await buildSocialUser(
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
    ) async -> (SocialUser, [(ItemModel, SocialBucketItem)]) {
        var enrichedItems: [(ItemModel, SocialBucketItem)] = []
        for item in items {
            let resolvedImages = await resolveImageURLs(from: item.imageUrls)
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
                imageURLs: resolvedImages,
                blurb: resolvedBlurb,
                locationDescription: item.location?.address,
                completionDate: item.dueDate
            )

            enrichedItems.append((item, socialItem))
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

    private func resolveImageURLs(from urlStrings: [String]) async -> [URL] {
        var resolved: [URL] = []
        for raw in urlStrings {
            if let url = await resolveImageURL(from: raw) {
                resolved.append(url)
            }
        }
        return resolved
    }

    private func resolveImageURL(from rawString: String) async -> URL? {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let cached = imageURLCache[trimmed] {
            return cached
        }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            if let refreshed = await refreshedFirebaseDownloadURL(for: url, cacheKey: trimmed) {
                return refreshed
            }

            imageURLCache[trimmed] = url
            return url
        }

        if trimmed.hasPrefix("gs://") {
            do {
                let downloadURL = try await storage.reference(forURL: trimmed).downloadURL()
                cache(downloadURL, forRawKey: trimmed, storagePath: nil)
                return downloadURL
            } catch {
                print("[SocialViewModel] Failed to resolve storage URL \(trimmed):", error.localizedDescription)
            }
        } else if !trimmed.contains("://") {
            do {
                let downloadURL = try await storage.reference(withPath: trimmed).downloadURL()
                cache(downloadURL, forRawKey: trimmed, storagePath: trimmed)
                return downloadURL
            } catch {
                print("[SocialViewModel] Failed to resolve relative storage path \(trimmed):", error.localizedDescription)
            }
        }

        return nil
    }

    private func refreshedFirebaseDownloadURL(for url: URL, cacheKey: String) async -> URL? {
        guard let storagePath = firebaseStoragePath(from: url) else {
            return nil
        }

        if let cached = imageURLCache[storagePath] {
            imageURLCache[cacheKey] = cached
            return cached
        }

        do {
            let downloadURL = try await storage.reference(withPath: storagePath).downloadURL()
            cache(downloadURL, forRawKey: cacheKey, storagePath: storagePath)
            return downloadURL
        } catch {
            print("[SocialViewModel] Failed to refresh Firebase download URL for \(storagePath):", error.localizedDescription)
            return nil
        }
    }

    private func cache(_ url: URL, forRawKey rawKey: String, storagePath: String?) {
        imageURLCache[rawKey] = url
        if let storagePath {
            imageURLCache[storagePath] = url
        }
    }

    private func firebaseStoragePath(from url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }

        if host.contains("firebasestorage.googleapis.com") {
            guard let range = url.path.range(of: "/o/") else { return nil }
            let encodedPath = String(url.path[range.upperBound...])
            return encodedPath.removingPercentEncoding ?? encodedPath
        }

        if host == "storage.googleapis.com" {
            let trimmedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let components = trimmedPath.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
            guard components.count == 2 else { return nil }
            return String(components[1])
        }

        if host.hasSuffix(".appspot.com") || host.hasSuffix(".firebasestorage.app") {
            let trimmedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return trimmedPath.isEmpty ? nil : trimmedPath
        }

        return nil
    }
}
