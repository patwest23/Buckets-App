//
//  ItemCacheStore.swift
//  BucketsApp
//
//  Created by OpenAI Assistant on 2025-03-15.
//

import Foundation

/// Persists lightweight snapshots of a user's bucket list items so the UI can
/// bootstrap instantly while Firestore listeners warm up.
///
/// The cache is intentionally simple and uses `UserDefaults` so it remains
/// available even if the user terminates the app offline. Items are stored per
/// user to avoid any accidental data leakage between accounts.
final class ItemCacheStore {
    static let shared = ItemCacheStore()

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "com.bucketsapp.itemcache", qos: .userInitiated)

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

    private func cacheKey(for userId: String) -> String {
        "bucket_items_\(userId)"
    }

    // MARK: - CRUD

    func cache(items: [ItemModel], for userId: String) {
        queue.async {
            do {
                let data = try self.encoder.encode(items)
                self.defaults.set(data, forKey: self.cacheKey(for: userId))
                self.defaults.set(Date().timeIntervalSince1970, forKey: self.cacheKey(for: userId) + "_timestamp")
            } catch {
                print("[ItemCacheStore] Failed to encode items for userId=\(userId):", error.localizedDescription)
            }
        }
    }

    func cachedItems(for userId: String) -> [ItemModel]? {
        queue.sync {
            guard let data = self.defaults.data(forKey: self.cacheKey(for: userId)) else {
                return nil
            }

            do {
                return try self.decoder.decode([ItemModel].self, from: data)
            } catch {
                print("[ItemCacheStore] Failed to decode cached items for userId=\(userId):", error.localizedDescription)
                self.defaults.removeObject(forKey: self.cacheKey(for: userId))
                return nil
            }
        }
    }

    func lastUpdatedAt(for userId: String) -> Date? {
        queue.sync {
            guard defaults.object(forKey: cacheKey(for: userId) + "_timestamp") != nil else { return nil }
            let timestamp = defaults.double(forKey: cacheKey(for: userId) + "_timestamp")
            return Date(timeIntervalSince1970: timestamp)
        }
    }

    func clear(for userId: String) {
        queue.async {
            self.defaults.removeObject(forKey: self.cacheKey(for: userId))
            self.defaults.removeObject(forKey: self.cacheKey(for: userId) + "_timestamp")
        }
    }
}
