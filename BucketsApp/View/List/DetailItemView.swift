//
//  DetailItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/1/24.
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseAuth
import MapKit

@MainActor
struct DetailItemView: View {
    let itemID: UUID

    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var syncCoordinator: SyncCoordinator
    @Environment(\.presentationMode) private var presentationMode

    // Removed local @State for currentItem; now using bucketListViewModel.currentEditingItem as single source of truth
    @StateObject private var imagePickerVM = ImagePickerViewModel()
    @StateObject private var locationSearchVM = LocationSearchViewModel()
    @State private var showFeedConfirmation = false
    @State private var showDeleteAlert = false
    @State private var isAnyTextFieldActive: Bool = false

    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool
    @FocusState private var isCaptionFocused: Bool
    @State private var captionText: String = ""


    init(item: ItemModel) {
        self.itemID = item.id
        // No local state for currentItem; initialization handled by view model
    }

    var body: some View {
        // Get the current editing item from the view model
        guard let editingItem = bucketListViewModel.currentEditingItem else {
            return AnyView(
                VStack {
                    Text("Item not found or unavailable.")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                }
            )
        }
        // Computed bindings for text and images
        let nameBinding = Binding<String>(
            get: { editingItem.name },
            set: { newValue in
                if var item = bucketListViewModel.currentEditingItem {
                    item.name = newValue
                    Task {
                        await bucketListViewModel.addOrUpdateItem(item)
                        await postViewModel.syncPostWithItem(item)
                    }
                }
            }
        )
        let locationBinding = Binding<String>(
            get: { editingItem.location?.address ?? "" },
            set: { newValue in
                if var item = bucketListViewModel.currentEditingItem {
                    var loc = item.location ?? Location(latitude: 0, longitude: 0, address: "")
                    loc.address = newValue
                    item.location = loc
                    Task {
                        await bucketListViewModel.addOrUpdateItem(item)
                        await postViewModel.syncPostWithItem(item)
                    }
                }
            }
        )
        let captionBinding = Binding<String>(
            get: { editingItem.caption ?? "" },
            set: { newValue in
                if var item = bucketListViewModel.currentEditingItem {
                    item.caption = newValue
                    Task {
                        await bucketListViewModel.addOrUpdateItem(item)
                        await postViewModel.syncPostWithItem(item)
                    }
                }
            }
        )
        let completed = editingItem.completed
        let wasShared = editingItem.wasShared
        let imageUrls = editingItem.imageUrls

        let content = ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Top row: Checkmark + editable title
                HStack(spacing: 8) {
                    Button {
                        Task {
                            await toggleCompleted()
                        }
                    } label: {
                        Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                            .imageScale(.large)
                            .foregroundColor(completed ? .accentColor : .gray)
                    }
                    .buttonStyle(.borderless)

                    TextField("Title...", text: nameBinding)
                        .font(.headline)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isTitleFocused ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: isTitleFocused ? 2 : 1)
                                .background(Color.white)
                        )
                        .focused($isTitleFocused)
                        .frame(maxWidth: .infinity)

                    Spacer()
                }

                HStack(spacing: 8) {
                    Text("📍")
                        .font(.system(size: 22))

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Add location...", text: Binding<String>(
                            get: { locationSearchVM.queryFragment },
                            set: { locationSearchVM.updateQuery($0) }
                        ))
                        .font(.body)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                .background(Color.white)
                        )

                        if !locationSearchVM.searchResults.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(locationSearchVM.searchResults, id: \.self) { result in
                                        Button {
                                            let selected = result.title + ", " + result.subtitle
                                            locationSearchVM.queryFragment = selected
                                            if var item = bucketListViewModel.currentEditingItem {
                                                var loc = item.location ?? Location(latitude: 0, longitude: 0, address: "")
                                                loc.address = selected
                                                item.location = loc
                                                Task {
                                                    await bucketListViewModel.addOrUpdateItem(item)
                                                    await postViewModel.syncPostWithItem(item)
                                                }
                                            }
                                            locationSearchVM.searchResults = []
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result.title).bold()
                                                if !result.subtitle.isEmpty {
                                                    Text(result.subtitle)
                                                        .font(.subheadline)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .padding(8)
                                        }
                                        Divider()
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("📝")
                        .font(.system(size: 22))
                        .padding(.top, 10)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCaptionFocused ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: isCaptionFocused ? 2 : 1)
                            .background(Color.white)
                        TextEditor(text: captionBinding)
                            .font(.body)
                            .padding(8)
                            .frame(minHeight: 80)
                            .disabled(!editingItem.completed)
                            .opacity(editingItem.completed ? 1.0 : 0.5)
                    }
                    .frame(maxWidth: .infinity)
                }

                photoPickerView

                if !imageUrls.isEmpty {
                    photoGridRow
                }

                Spacer()
            }
            .onAppear {
                print("[DetailItemView] onAppear fired for item: \(editingItem.name), wasShared: \(editingItem.wasShared)")

                if let editingItem = bucketListViewModel.currentEditingItem {
                    print("[DetailItemView] using currentEditingItem: \(editingItem.name)")
                }

                if editingItem.userId.isEmpty,
                   let authUserId = userViewModel.user?.id {
                    var updatedItem = editingItem
                    updatedItem.userId = authUserId
                    if !updatedItem.name.isEmpty || !updatedItem.imageUrls.isEmpty {
                        Task {
                            await bucketListViewModel.addOrUpdateItem(updatedItem)
                        }
                    }
                }

                imagePickerVM.onImagesLoaded = {
                    Task {
                        let uploadedUrls = await imagePickerVM.uploadImages(
                            userId: userViewModel.user?.id ?? "",
                            itemId: editingItem.id.uuidString
                        )
                        var updatedItem = editingItem
                        if updatedItem.userId.isEmpty,
                           let uid = userViewModel.user?.id {
                            updatedItem.userId = uid
                        }
                        await bucketListViewModel.updateImageUrls(for: updatedItem, urls: uploadedUrls)
                    }
                }

                NotificationCenter.default.addObserver(forName: UITextField.textDidBeginEditingNotification, object: nil, queue: .main) { _ in
                    isAnyTextFieldActive = true
                }
                NotificationCenter.default.addObserver(forName: UITextField.textDidEndEditingNotification, object: nil, queue: .main) { _ in
                    isAnyTextFieldActive = false
                }
            }
            .onAppear {
                print("[DetailItemView] body loaded. itemID: \(itemID)")
            }
            .padding()
            .onChange(of: postViewModel.didSharePost) { oldValue, newValue in
                if newValue {
                    postViewModel.didSharePost = false
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .alert("✅ Shared to Feed!", isPresented: $showFeedConfirmation) {
                Button("OK", role: .cancel) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isAnyTextFieldActive || isCaptionFocused {
                    Button("Done") {
                        UIApplication.shared.endEditing()
                        isAnyTextFieldActive = false
                        isCaptionFocused = false
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("🗑️ Delete This Item")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .alert("Are you sure?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task {
                        if let item = bucketListViewModel.currentEditingItem {
                            await bucketListViewModel.deleteItem(item)
                            if let post = postViewModel.posts.first(where: { $0.itemId == item.id.uuidString }) {
                                await postViewModel.deletePost(post)
                            }
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }

        return AnyView(content)
    }

    @ViewBuilder
    private var photoPickerView: some View {
        let isUploading = imagePickerVM.isUploading
        let completed = bucketListViewModel.currentEditingItem?.completed ?? false
        PhotosPicker(
            selection: $imagePickerVM.selectedItems,
            maxSelectionCount: 3,
            matching: .images
        ) {
            HStack(spacing: 8) {
                Text("📸")
                    .font(.system(size: 22))

                HStack {
                    Text("Select Photo")
                        .foregroundColor(.accentColor)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .disabled(!completed || isUploading)
    }

    private func toggleCompleted() async {
        guard var item = bucketListViewModel.currentEditingItem else { return }
        item.completed.toggle()
        if item.completed {
            item.dueDate = Date()
        } else {
            item.dueDate = nil
        }
        await bucketListViewModel.addOrUpdateItem(item)
        await postViewModel.syncPostWithItem(item)
    }
}

// MARK: - Computed Props
extension DetailItemView {
    @MainActor private var isShowingChevron: Bool {
        !(bucketListViewModel.currentEditingItem?.imageUrls.isEmpty ?? true)
    }

    @MainActor private var isShowingPhotoGrid: Bool {
        !(bucketListViewModel.currentEditingItem?.imageUrls.isEmpty ?? true)
    }
}

// MARK: - Helpers
extension DetailItemView {

    private func hideKeyboard() {
        isTitleFocused = false
        isNotesFocused = false
    }


    private func shareMessage(for type: PostType?) -> String {
        switch type {
        case .added:
            return "Share this new bucket list item to your feed?"
        case .completed:
            return "You completed this item! Want to post it to your feed?"
        case .photos:
            return "You’ve added photos — post an update to your feed?"
        default:
            return "Want to share this item to your feed?"
        }
    }

    @ViewBuilder
    private var photoGridRow: some View {
        let urls = bucketListViewModel.currentEditingItem?.imageUrls ?? []
        if !urls.isEmpty {
            photoGrid(urlStrings: urls)
        }
    }

    private func photoGrid(urlStrings: [String]) -> some View {
        let imageSize: CGFloat = (UIScreen.main.bounds.width - 64) / 3
        return AnyView(
            HStack(spacing: 8) {
                ForEach(urlStrings, id: \.self) { urlStr in
                    if let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: imageSize, height: imageSize)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: imageSize, height: imageSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .clipped()
                            default:
                                EmptyView()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        )
    }
}


#if DEBUG
struct DetailItemView_Previews: PreviewProvider {
    static var previews: some View {
        // 1) Create mock environment objects
        let mockUserVM = UserViewModel()
        let mockListVM = ListViewModel()
        let mockPostVM = PostViewModel()
        let mockFeedVM = FeedViewModel()
        let mockFriendsVM = FriendsViewModel()
        let mockSyncCoordinator = SyncCoordinator(
            postViewModel: mockPostVM,
            listViewModel: mockListVM,
            feedViewModel: mockFeedVM,
            friendsViewModel: mockFriendsVM
        )

        // 2) Create a sample ItemModel with placeholder images
        let sampleItem = ItemModel(
            userId: "previewUser",
            name: "Sample Bucket List Item",
            description: "Short description for preview...",
            dueDate: Date().addingTimeInterval(86400 * 3),
            location: Location(latitude: 37.7749, longitude: -122.4194, address: "San Francisco"),
            completed: true,
            creationDate: Date().addingTimeInterval(-86400),
            imageUrls: [
                "https://via.placeholder.com/300",
                "https://via.placeholder.com/300",
                "https://via.placeholder.com/300"
            ]
        )
        mockListVM.currentEditingItem = sampleItem

        let preview = DetailItemView(item: sampleItem)
            .environmentObject(mockUserVM)
            .environmentObject(mockListVM)
            .environmentObject(mockPostVM)
            .environmentObject(mockSyncCoordinator)

        return Group {
            preview
                .environment(\.colorScheme, .light)
                .previewDisplayName("DetailItemView - Light Mode")

            preview
                .environment(\.colorScheme, .dark)
                .previewDisplayName("DetailItemView - Dark Mode")
        }
    }
}
#endif
