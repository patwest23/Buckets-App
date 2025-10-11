import XCTest
@testable import BucketsApp

final class ListViewModelSharedItemTests: XCTestCase {

    func testSharedItemUpdateSyncsPost() async {
        let listViewModel = TestListViewModel()
        listViewModel.userIdProvider = { "user123" }
        let mockPostViewModel = MockPostViewModel()

        var item = ItemModel(userId: "user123", name: "Test Item")
        item.wasShared = true
        item.postId = "post-1"
        listViewModel.items = [item]

        await listViewModel.addOrUpdateItem(item, postViewModel: mockPostViewModel)

        XCTAssertEqual(mockPostViewModel.syncedItems.count, 1)
        XCTAssertEqual(mockPostViewModel.syncedItems.first?.id, item.id)
    }

    func testDefaultPostViewModelUsedWhenRegistered() async {
        let listViewModel = TestListViewModel()
        listViewModel.userIdProvider = { "user123" }
        let mockPostViewModel = MockPostViewModel()
        listViewModel.registerDefaultPostViewModel(mockPostViewModel)

        var item = ItemModel(userId: "user123", name: "Another Item")
        item.wasShared = true
        item.postId = "post-2"
        listViewModel.items = [item]

        await listViewModel.addOrUpdateItem(item)

        XCTAssertEqual(mockPostViewModel.syncedItems.count, 1)
        XCTAssertEqual(mockPostViewModel.syncedItems.first?.id, item.id)
    }
}

private final class MockPostViewModel: PostViewModel {
    private(set) var syncedItems: [ItemModel] = []

    override func syncPostWithItem(_ item: ItemModel) async {
        syncedItems.append(item)
    }
}

private final class TestListViewModel: ListViewModel {
    private(set) var writtenItems: [ItemModel] = []

    override func writeItemToFirestore(_ item: ItemModel, userId: String) async throws {
        writtenItems.append(item)
    }

    override func promptUserForPostAction() async -> PostActionChoice {
        .update
    }
}
