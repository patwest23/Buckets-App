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
    @Environment(\.colorScheme) private var colorScheme

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

    var body: some View {
        Group {
            if let editingItem = bucketListViewModel.currentEditingItem {
                detailContent(for: editingItem)
            } else {
                missingItemView
            }
        }
        .onAppear {
            if locationSearchVM.queryFragment.isEmpty {
                locationSearchVM.queryFragment = viewModel.locationText
            }
        }
        .onChange(of: locationSearchVM.queryFragment, initial: false) { _, newValue in
            if viewModel.locationText != newValue {
                viewModel.locationText = newValue
            }
        }
    }

    // MARK: - Content Builders
    private func detailContent(for editingItem: ItemModel) -> some View {
        ScrollView {
            VStack(spacing: BucketTheme.largeSpacing) {
                headerCard
                locationAndNotesCard
                if !viewModel.imageUrls.isEmpty {
                    galleryCard
                }
                photoPickerCard
                if !viewModel.wasShared {
                    shareCard(for: editingItem)
                }
                deleteCard
            }
            .padding(.horizontal, BucketTheme.mediumSpacing)
            .padding(.vertical, BucketTheme.largeSpacing)
        }
        .background { BucketTheme.backgroundGradient(for: colorScheme).ignoresSafeArea() }
        .bucketToolbarBackground()
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("Done") {
                        endEditing()
                    }
                    .font(.headline)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    endEditing()
                }
            }
        }
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .alert("✅ Shared to Feed!", isPresented: $showFeedConfirmation) {
            Button("OK", role: .cancel) {
                presentationMode.wrappedValue.dismiss()
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
            prepareEditingState(with: editingItem)
        }
        .onDisappear {
            Task { await viewModel.commitPendingChanges() }
        }
        .onChange(of: postViewModel.didSharePost, initial: false) { _, newValue in
            if newValue {
                postViewModel.didSharePost = false
            }
        }
    }

    private var missingItemView: some View {
        VStack(spacing: BucketTheme.mediumSpacing) {
            Text("🫥")
                .font(.largeTitle)
            Text("Item not found or unavailable.")
                .font(.headline)
                .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
        }
        .padding()
        .bucketCard()
        .padding()
        .background { BucketTheme.backgroundGradient(for: colorScheme).ignoresSafeArea() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: BucketTheme.mediumSpacing) {
            HStack(spacing: BucketTheme.mediumSpacing) {
                Button {
                    Task { await viewModel.toggleCompleted() }
                } label: {
                    Image(systemName: viewModel.completed ? "checkmark.circle.fill" : "circle")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(viewModel.completed ? BucketTheme.primary : BucketTheme.subtleText(for: colorScheme))
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous)
                                .fill(BucketTheme.surface(for: colorScheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous)
                                .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                        )
                }
                .buttonStyle(.plain)

                TextField("Title...", text: $viewModel.name)
                    .font(.title2.weight(.semibold))
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .bucketTextField(systemImage: "sparkles")
                    .onSubmit {
                        focusedField = .caption
                    }
            }

        }
        .bucketCard()
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = .title
        }
    }

    private var locationAndNotesCard: some View {
        VStack(alignment: .leading, spacing: BucketTheme.mediumSpacing) {
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

            VStack(alignment: .leading, spacing: BucketTheme.smallSpacing) {
                Text("Notes")
                    .font(.headline)
                TextEditor(text: $viewModel.caption)
                    .font(.body)
                    .frame(minHeight: 120)
                    .padding(.horizontal, BucketTheme.mediumSpacing)
                    .padding(.vertical, BucketTheme.smallSpacing)
                    .background(BucketTheme.surface(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                            .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                    )
                    .focused($focusedField, equals: .caption)
            }
        }
        .bucketCard()
    }

    private var galleryCard: some View {
        VStack(alignment: .leading, spacing: BucketTheme.mediumSpacing) {
            Text("Photos")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: BucketTheme.smallSpacing) {
                ForEach(viewModel.imageUrls, id: \.self) { urlStr in
                    if let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 100)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous))
                            default:
                                Image(systemName: "exclamationmark.triangle")
                                    .frame(height: 100)
                            }
                        }
                    }
                }
            }
        }
        .bucketCard()
    }

    private var photoPickerCard: some View {
        VStack(alignment: .leading, spacing: BucketTheme.mediumSpacing) {
            Text("Add more magic")
                .font(.headline)
            PhotosPicker(
                selection: $imagePickerVM.selectedItems,
                maxSelectionCount: 3,
                matching: .images
            ) {
                HStack(spacing: BucketTheme.mediumSpacing) {
                    Text("📸")
                        .font(.title2)
                    Text("Select Photos")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                }
                .padding(.horizontal, BucketTheme.mediumSpacing)
                .padding(.vertical, BucketTheme.smallSpacing + 4)
                .background(BucketTheme.surface(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                        .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                )
            }
            .disabled(imagePickerVM.isUploading)
        }
        .bucketCard()
    }

    private func shareCard(for editingItem: ItemModel) -> some View {
        VStack(alignment: .leading, spacing: BucketTheme.mediumSpacing) {
            Text("Share to your feed")
                .font(.headline)
            Button {
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
            } label: {
                if isPostingToFeed {
                    ProgressView()
                } else {
                    Label("Post to Feed", systemImage: "megaphone.fill")
                        .font(.headline)
                }
            }
            .buttonStyle(BucketPrimaryButtonStyle())
            .disabled(!viewModel.canPost || isPostingToFeed)

            VStack(alignment: .leading, spacing: 4) {
                if !viewModel.completed {
                    Text("Complete this bucket before sharing.")
                } else if viewModel.imageUrls.isEmpty {
                    Text("Add at least one photo to share the story.")
                }
            }
            .font(.footnote)
            .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
        }
        .bucketCard()
    }

    private var deleteCard: some View {
        VStack(alignment: .leading, spacing: BucketTheme.mediumSpacing) {
            Text("Danger Zone")
                .font(.headline)
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete This Item", systemImage: "trash.fill")
                    .font(.headline)
            }
            .buttonStyle(BucketSecondaryButtonStyle())
        }
        .bucketCard()
    }

    // MARK: - Helpers
    private var isEditing: Bool {
        focusedField != nil
    }

    private func endEditing() {
        focusedField = nil
        UIApplication.shared.endEditing()
        Task { await viewModel.commitPendingChanges() }
    }

    private func prepareEditingState(with editingItem: ItemModel) {
        if editingItem.userId.isEmpty, let authUserId = userViewModel.user?.id {
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
                if updatedItem.userId.isEmpty, let uid = userViewModel.user?.id {
                    updatedItem.userId = uid
                }
                await bucketListViewModel.updateImageUrls(for: updatedItem, urls: uploadedUrls)
            }
        }
    }
}

#if DEBUG
    struct DetailItemView_Previews: PreviewProvider {
        static var previews: some View {
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
