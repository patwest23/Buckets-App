import XCTest
@testable import BucketsApp

final class ListViewModelCacheTests: XCTestCase {

    private func makeCache() -> ItemCacheStore {
        let suiteName = "com.bucketsapp.tests.itemcache.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create test UserDefaults")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return ItemCacheStore(userDefaults: defaults)
    }

    @MainActor
    func testRestoreCachedItemsLoadsFromCache() {
        let cache = makeCache()
        let viewModel = ListViewModel(itemCache: cache)
        viewModel.userIdProvider = { "user123" }

        let cached = [
            ItemModel(userId: "user123", name: "Cached One"),
            ItemModel(userId: "user123", name: "Cached Two")
        ]

        cache.cache(items: cached, for: "user123")

        viewModel.restoreCachedItems()

        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.lastLoadedDataSource, .cache)
        XCTAssertEqual(viewModel.items.map(\.name), cached.map(\.name))
    }

    @MainActor
    func testCacheItemsPersistsToStore() {
        let cache = makeCache()
        let viewModel = ListViewModel(itemCache: cache)
        viewModel.userIdProvider = { "user123" }

        let items = [
            ItemModel(userId: "user123", name: "Remote 1"),
            ItemModel(userId: "user123", name: "Remote 2")
        ]

        viewModel.cacheItems(items, for: "user123")

        let cached = cache.cachedItems(for: "user123")
        XCTAssertEqual(cached?.count, 2)
        XCTAssertEqual(cached?.map(\.name), items.map(\.name))
    }
}
