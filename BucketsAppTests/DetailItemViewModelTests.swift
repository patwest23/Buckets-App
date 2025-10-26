import XCTest
@testable import BucketsApp

final class DetailItemViewModelTests: XCTestCase {

    @MainActor
    func testCommitPendingChangesPersistsDraft() async {
        let listViewModel = RecordingListViewModel()
        listViewModel.userIdProvider = { "user123" }

        let postViewModel = RecordingPostViewModel()

        let item = ItemModel(userId: "user123", name: "Original Title")
        listViewModel.items = [item]
        listViewModel.currentEditingItem = item

        let sut = DetailItemViewModel(item: item, listViewModel: listViewModel, postViewModel: postViewModel)
        sut.name = "Updated Title"
        sut.caption = "Updated Caption"

        await sut.commitPendingChanges()

        XCTAssertEqual(listViewModel.savedItems.count, 1)
        XCTAssertEqual(listViewModel.savedItems.first?.name, "Updated Title")
        XCTAssertEqual(listViewModel.currentEditingItem?.name, "Updated Title")
        XCTAssertEqual(postViewModel.capturedCaption, "Updated Caption")
    }
}

private final class RecordingListViewModel: ListViewModel {
    private(set) var savedItems: [ItemModel] = []

    override func addOrUpdateItem(_ item: ItemModel, postViewModel: PostViewModel? = nil) async {
        savedItems.append(item)
        updateEditingDraft(item)
    }
}

private final class RecordingPostViewModel: PostViewModel {
    private(set) var capturedCaption: String = ""

    override var caption: String {
        get { super.caption }
        set {
            capturedCaption = newValue
            super.caption = newValue
        }
    }

    override func syncPostWithItem(_ item: ItemModel) async {
        // No-op for tests
    }
}
