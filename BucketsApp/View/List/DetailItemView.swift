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

enum DetailItemField: Hashable {
    case title
    case caption
    case location
}

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

    @FocusState private var focusedField: DetailItemField?
    
    
    init(item: ItemModel, listViewModel: ListViewModel, postViewModel: PostViewModel) {
        self.itemID = item.id
        _viewModel = StateObject(wrappedValue: DetailItemViewModel(item: item, listViewModel: listViewModel, postViewModel: postViewModel))
    }
    
    // MARK: - Computed Views moved from extension
    @ViewBuilder
    private var checkmarkAndTitleRow: some View {
        HStack(spacing: 8) {
            Button {
                Task { await viewModel.toggleCompleted() }
            } label: {
                Image(systemName: viewModel.completed ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundColor(viewModel.completed ? .accentColor : .gray)
                    .padding(8)
            }
            .contentShape(Rectangle())
            .buttonStyle(.borderless)

            VStack(spacing: 0) {
                TextField("Title...", text: $viewModel.name)
                    .font(.headline)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(focusedField == .title ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: focusedField == .title ? 2 : 1)
                            .background(Color(.systemBackground))
                    )
                    .focused($focusedField, equals: .title)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .caption
                    }
                    .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusField(.title)
            }

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
    private var captionEditorView: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("📝")
                .font(.system(size: 22))
                .padding(.top, 10)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(focusedField == .caption ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: focusedField == .caption ? 2 : 1)
                    .background(Color(.systemBackground))

                TextEditor(text: $viewModel.caption)
                    .font(.body)
                    .padding(8)
                    .frame(minHeight: 80)
                    .focused($focusedField, equals: .caption)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                focusField(.caption)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .onTapGesture {
            focusField(.caption)
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
        Form {
            Section {
                checkmarkAndTitleRow
            }

            Section {
                LocationSearchFieldView(
                    query: $locationSearchVM.queryFragment,
                    results: locationSearchVM.searchResults,
                    onSelect: { result in
                        Task {
                            await viewModel.updateLocation(from: result)
                        }
                        locationSearchVM.searchResults = []
                    },
                    focus: $focusedField
                )

                captionEditorView
            }

            if !viewModel.imageUrls.isEmpty {
                Section("Photos") {
                    photoGridRow
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }

            Section {
                photoPickerView
            }

            if !viewModel.wasShared {
                Section {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text("🗑️ Delete This Item")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: locationSearchVM.queryFragment, initial: false) { _, newValue in
            if viewModel.locationText != newValue {
                viewModel.locationText = newValue
            }
        }

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
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            endEditing()
                        }
                    }
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
                .onChange(of: postViewModel.didSharePost, initial: false) { oldValue, newValue in
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
        focusedField != nil
    }

    private func endEditing() {
        focusedField = nil
        UIApplication.shared.endEditing()
        Task { await viewModel.commitPendingChanges() }
    }

    private func focusField(_ field: DetailItemField) {
        if focusedField != field {
            focusedField = field
        }
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

