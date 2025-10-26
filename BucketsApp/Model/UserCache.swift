//
//  UserCache.swift
//  BucketsApp
//
//  Created by AI on 2024.
//

import Foundation

/// A lightweight helper that caches the authenticated user's data in `UserDefaults`.
///
/// Data is stored per-user using the Firebase Auth UID as the key. Both the
/// `UserModel` payload and optional profile image bytes are persisted so the app
/// can bootstrap UI state before hitting Firestore.
final class UserCache {
    static let shared = UserCache()

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder
    }

    // MARK: - Cache Keys

    private func userKey(for uid: String) -> String {
        "cachedUser_\(uid)"
    }

    private func imageKey(for uid: String) -> String {
        "cachedUserImage_\(uid)"
    }

    // MARK: - User

    func cache(user: UserModel, for uid: String) {
        var userToStore = user
        userToStore.documentId = user.documentId ?? uid

        do {
            let data = try encoder.encode(userToStore)
            defaults.set(data, forKey: userKey(for: uid))
        } catch {
            print("[UserCache] Failed to encode user for uid=\(uid):", error.localizedDescription)
        }
    }

    func cachedUser(for uid: String) -> UserModel? {
        guard let data = defaults.data(forKey: userKey(for: uid)) else { return nil }

        do {
            var cachedUser = try decoder.decode(UserModel.self, from: data)
            cachedUser.documentId = cachedUser.documentId ?? uid
            return cachedUser
        } catch {
            print("[UserCache] Failed to decode cached user for uid=\(uid):", error.localizedDescription)
            defaults.removeObject(forKey: userKey(for: uid))
            return nil
        }
    }

    // MARK: - Profile Image

    func cacheProfileImageData(_ data: Data?, for uid: String) {
        let key = imageKey(for: uid)
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func cachedProfileImageData(for uid: String) -> Data? {
        defaults.data(forKey: imageKey(for: uid))
    }

    // MARK: - Clearing

    func clearCache(for uid: String) {
        defaults.removeObject(forKey: userKey(for: uid))
        defaults.removeObject(forKey: imageKey(for: uid))
    }

    func clearAll() {
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("cachedUser_") }
            .forEach { defaults.removeObject(forKey: $0) }

        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("cachedUserImage_") }
            .forEach { defaults.removeObject(forKey: $0) }
    }
}
