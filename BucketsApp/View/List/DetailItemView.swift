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

    @StateObject private var viewModel: DetailItemViewModel
    
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool
    @FocusState private var isCaptionFocused: Bool
    @State private var captionText: String = ""
    
    
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
                .submitLabel(.next)
                .onSubmit {
                    isTitleFocused = false
                    isCaptionFocused = true
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
                    }
                )
                captionEditorView

                photoPickerView
                    .padding(.vertical, 2)

                if !(bucketListViewModel.currentEditingItem?.imageUrls.isEmpty ?? true) {
                    photoGridRow
                }

                // Post to Feed button if completed, has photos, and not already shared
                if viewModel.completed,
                   !viewModel.imageUrls.isEmpty,
                   !viewModel.wasShared {
                    Button(action: {
                        Task {
                            if let item = bucketListViewModel.currentEditingItem {
                                await postViewModel.createOrUpdatePost(for: item)
                                showFeedConfirmation = true
                            }
                        }
                    }) {
                        Text("📢 Post to Feed")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .padding()
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
                    .disabled(!viewModel.completed)
                    .opacity(viewModel.completed ? 1.0 : 0.5)
                    .focused($isCaptionFocused)
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
        .onTapGesture {
            UIApplication.shared.endEditing()
            isAnyTextFieldActive = false
            isCaptionFocused = false
        }
        
        return AnyView(
            content
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
    
    @ViewBuilder
    private var photoPickerView: some View {
        let isUploading = imagePickerVM.isUploading
        let completed = viewModel.completed
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
        .disabled(!completed || isUploading)
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

