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
    @StateObject private var viewModel: DetailItemViewModel
    @State private var isPostingToFeed = false

    @FocusState private var isTitleFocused: Bool
    @FocusState private var isCaptionFocused: Bool
    @FocusState private var isLocationFocused: Bool
    
    
    init(item: ItemModel, listViewModel: ListViewModel, postViewModel: PostViewModel) {
        self.itemID = item.id
        _viewModel = StateObject(wrappedValue: DetailItemViewModel(item: item, listViewModel: listViewModel, postViewModel: postViewModel))
    }
    
    // MARK: - Computed Views moved from extension
    @ViewBuilder
    private var checkmarkAndTitleRow: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.completed.toggle()
            } label: {
                Image(systemName: viewModel.completed ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundColor(viewModel.completed ? .accentColor : .gray)
                    .padding(8)
            }
            .contentShape(Rectangle())
            .buttonStyle(.borderless)

            TextField("Title...", text: $viewModel.name)
                .font(.headline)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isTitleFocused ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: isTitleFocused ? 2 : 1)
                        .background(Color(.systemBackground))
                )
                .focused($isTitleFocused)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .submitLabel(.next)
                .onSubmit {
                    isTitleFocused = false
                    isCaptionFocused = true
                }
                .onChange(of: isTitleFocused) { newValue in
                    if newValue {
                        isCaptionFocused = false
                        isLocationFocused = false
                    }
                }
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var photoGridRow: some View {
        let urls = viewModel.imageUrls
        if !urls.isEmpty {
            photoGrid(urlStrings: urls)
        }
    }
    
    @ViewBuilder
    private var scrollViewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Top row: Checkmark + editable title
                checkmarkAndTitleRow

                LocationSearchFieldView(
                    query: $locationSearchVM.queryFragment,
                    results: locationSearchVM.searchResults,
                    onSelect: { result in
                        Task {
                            await viewModel.updateLocation(from: result)
                        }
                        locationSearchVM.searchResults = []
                    },
                    focus: $isLocationFocused,
                    onFocusChange: { isFocused in
                        if isFocused {
                            isTitleFocused = false
                            isCaptionFocused = false
                        }
                    }
                )
                captionEditorView

                photoPickerView
                    .padding(.vertical, 2)

                photoGridRow

                if !viewModel.wasShared {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            Task {
                                guard !isPostingToFeed else { return }
                                isPostingToFeed = true
                                defer { isPostingToFeed = false }
                                await viewModel.commitPendingChanges()
                                postViewModel.caption = viewModel.caption
                                if var item = bucketListViewModel.currentEditingItem {
                                    item = viewModel.applyingEdits(to: item)
                                    await syncCoordinator.post(item: item)
                                    bucketListViewModel.currentEditingItem = item
                                    viewModel.wasShared = true
                                    showFeedConfirmation = true
                                }
                            }
                        }) {
                            HStack {
                                if isPostingToFeed {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("📢 Post to Feed")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.canPost ? Color.blue : Color.gray.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!viewModel.canPost || isPostingToFeed)

                        if !viewModel.completed {
                            Text("Mark this item complete before sharing to your feed.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else if viewModel.imageUrls.isEmpty {
                            Text("Add at least one photo before posting.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
        }
        .onChange(of: locationSearchVM.queryFragment) { newValue in
            if viewModel.locationText != newValue {
                viewModel.locationText = newValue
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }


    @ViewBuilder
    private var captionEditorView: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("📝")
                .font(.system(size: 22))
                .padding(.top, 10)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isCaptionFocused ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: isCaptionFocused ? 2 : 1)
                    .background(Color(.systemBackground))

                TextEditor(text: $viewModel.caption)
                    .font(.body)
                    .padding(8)
                    .frame(minHeight: 80)
                    .focused($isCaptionFocused)
                    .onChange(of: isCaptionFocused) { newValue in
                        if newValue {
                            isTitleFocused = false
                            isLocationFocused = false
                        }
                    }
            }
            .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
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
        let content =
        ZStack {
            scrollViewContent
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    guard isEditing else { return }
                    endEditing()
                }
        )

        return AnyView(
            content
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isEditing {
                            Button("Done") {
                                endEditing()
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, alignment: .center, spacing: 0) {
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
                .onAppear {
                    print("[DetailItemView] onAppear fired for item: \(editingItem.name), wasShared: \(editingItem.wasShared)")
                    
                    if let editingItem = bucketListViewModel.currentEditingItem {
                        print("[DetailItemView] using currentEditingItem: \(editingItem.name)")
                    }

                    if locationSearchVM.queryFragment.isEmpty {
                        locationSearchVM.queryFragment = viewModel.locationText
                    }

                    if editingItem.userId.isEmpty,
                       let authUserId = userViewModel.user?.id {
                        var updatedItem = editingItem
                        updatedItem.userId = authUserId
                        if !updatedItem.name.isEmpty || !updatedItem.imageUrls.isEmpty {
                            Task {
                                await bucketListViewModel.addOrUpdateItem(updatedItem, postViewModel: postViewModel)
                            }
                        }
                    }
                    
                    imagePickerVM.onImagesLoaded = {
                        Task {
                            let uploadedUrls = await imagePickerVM.uploadImages(
                                userId: userViewModel.user?.id ?? "",
                                itemId: editingItem.id.uuidString
                            )
                            await viewModel.updateImageUrls(uploadedUrls)
                            var updatedItem = editingItem
                            if updatedItem.userId.isEmpty,
                               let uid = userViewModel.user?.id {
                                updatedItem.userId = uid
                            }
                            await bucketListViewModel.updateImageUrls(for: updatedItem, urls: uploadedUrls)
                        }
                    }
                    
                }
                .onAppear {
                    print("[DetailItemView] body loaded. itemID: \(itemID)")
                }
                .onDisappear {
                    Task { await viewModel.commitPendingChanges() }
                }
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
        )
    }

    private var isEditing: Bool {
        isTitleFocused || isCaptionFocused || isLocationFocused
    }

    private func endEditing() {
        isTitleFocused = false
        isCaptionFocused = false
        isLocationFocused = false
        UIApplication.shared.endEditing()
        Task { await viewModel.commitPendingChanges() }
    }

    @ViewBuilder
    private var photoPickerView: some View {
        let isUploading = imagePickerVM.isUploading
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
                        .background(Color(.systemBackground))
                )
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .disabled(isUploading)
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
            
            let preview = DetailItemView(item: sampleItem, listViewModel: mockListVM, postViewModel: mockPostVM)
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

