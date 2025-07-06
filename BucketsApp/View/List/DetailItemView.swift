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

@MainActor
struct DetailItemView: View {
    let itemID: UUID

    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var syncCoordinator: SyncCoordinator
    @Environment(\.presentationMode) private var presentationMode

    @State private var currentItem: ItemModel
    @StateObject private var imagePickerVM = ImagePickerViewModel()
    @State private var showFeedConfirmation = false
    @State private var showDeleteAlert = false

    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool

    // NEW: Social sharing state
    @State private var showShareAlert: Bool = false
    @State private var lastShareEvent: PostType? = nil

    @State private var showReshareUpdateAlert = false

    init(item: ItemModel) {
        self.itemID = item.id
        _currentItem = State(initialValue: item)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Top row: Checkmark + editable title
                HStack(spacing: 8) {
                    Button {
                        Task {
                            await toggleCompleted()
                        }
                    } label: {
                        Image(systemName: currentItem.completed ? "checkmark.circle.fill" : "circle")
                            .imageScale(.large)
                            .foregroundColor(currentItem.completed ? .accentColor : .gray)
                    }
                    .buttonStyle(.borderless)

                    TextField("Title...", text: Binding(
                        get: { currentItem.name },
                        set: { newValue in
                            currentItem.name = newValue
                            Task {
                                await bucketListViewModel.addOrUpdateItem(currentItem)
                                await postViewModel.syncPostWithItem(currentItem)
                                if currentItem.wasShared {
                                    showReshareUpdateAlert = true
                                }
                            }
                        }
                    ))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .focused($isTitleFocused)

                    Spacer()
                }

                photoPickerView


                // Image preview grid
                if !currentItem.imageUrls.isEmpty {
                    photoGridRow
                }

                // Share button
                if currentItem.completed && !currentItem.imageUrls.isEmpty {
                    Button("\(currentItem.wasShared ? "♻️ Repost to Feed" : "📣 Share to Feed")") {
                        lastShareEvent = .completed
                        showShareAlert = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text("🗑️ Delete This Item")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .alert("Are you sure?", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        Task {
                            await bucketListViewModel.deleteItem(currentItem)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                }

                Spacer()
        }
            .onAppear {
                print("[DetailItemView] onAppear fired for item: \(currentItem.name)")

                if let editingItem = bucketListViewModel.currentEditingItem {
                    print("[DetailItemView] using currentEditingItem: \(editingItem.name)")
                    currentItem = editingItem
                } else {
                    print("[DetailItemView] WARNING: currentEditingItem was nil — using init fallback: \(currentItem.name)")
                }

                if currentItem.userId.isEmpty,
                   let authUserId = userViewModel.user?.id {
                    currentItem.userId = authUserId
                    if !currentItem.name.isEmpty || !currentItem.imageUrls.isEmpty {
                        Task {
                            await bucketListViewModel.addOrUpdateItem(currentItem)
                        }
                    }
                }

                imagePickerVM.onImagesLoaded = {
                    Task {
                        let uploadedUrls = await imagePickerVM.uploadImages(
                            userId: userViewModel.user?.id ?? "",
                            itemId: currentItem.id.uuidString
                        )
                        if currentItem.userId.isEmpty,
                           let uid = userViewModel.user?.id {
                            currentItem.userId = uid
                        }
                        await bucketListViewModel.updateImageUrls(for: currentItem, urls: uploadedUrls)
                        if let updated = bucketListViewModel.items.first(where: { $0.id == currentItem.id }) {
                            currentItem = updated
                        }
                    }
                }
            }
            .onAppear {
                print("[DetailItemView] body loaded. itemID: \(itemID)")
            }
            .padding()
        }
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Share to Feed?", isPresented: $showShareAlert, actions: {
            Button("Post") {
                // Set selected item ID before posting
                postViewModel.selectedItemID = currentItem.id.uuidString
                Task {
                    // Ensure item is saved (with image URLs) before posting to feed
                    await bucketListViewModel.addOrUpdateItem(currentItem)
                    await syncCoordinator.post(item: currentItem)
                    // Show confirmation after posting
                    showFeedConfirmation = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text(shareMessage(for: lastShareEvent))
        })
        // Confirmation alert after posting
        .alert("✅ Shared to Feed!", isPresented: $showFeedConfirmation) {
            Button("OK", role: .cancel) {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .alert("Re-share this update?", isPresented: $showReshareUpdateAlert, actions: {
            Button("Re-share to Feed") {
                postViewModel.selectedItemID = currentItem.id.uuidString
                Task {
                    await syncCoordinator.post(item: currentItem)
                    showFeedConfirmation = true
                }
            }
            Button("Not Now", role: .cancel) {}
        }, message: {
            Text("You've already shared this item. Want to re-share the update in your feed?")
        })
        
    }

    @ViewBuilder
    private var photoPickerView: some View {
        let isUploading = imagePickerVM.isUploading
        PhotosPicker(
            selection: $imagePickerVM.selectedItems,
            maxSelectionCount: 3,
            matching: .images
        ) {
            HStack {
                Text("📸 Select Photo")
                if isUploading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .disabled(!currentItem.completed || isUploading)
    }

    private func toggleCompleted() async {
        currentItem.completed.toggle()
        if currentItem.completed {
            currentItem.dueDate = Date()
        } else {
            currentItem.dueDate = nil
        }
        await bucketListViewModel.addOrUpdateItem(currentItem)
        await postViewModel.syncPostWithItem(currentItem)
        if currentItem.wasShared {
            showReshareUpdateAlert = true
        }
    }
}

// MARK: - Computed Props
extension DetailItemView {
    @MainActor private var isShowingChevron: Bool {
        !currentItem.imageUrls.isEmpty
    }

    @MainActor private var isShowingPhotoGrid: Bool {
        !currentItem.imageUrls.isEmpty
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
        let urls = currentItem.imageUrls
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
        
        // 2) Create a sample ItemModel with placeholder images using the new imageUrls array
        let sampleItem = ItemModel(
            userId: "previewUser",
            name: "Sample Bucket List Item",
            description: "Short description for preview...",
            dueDate: Date().addingTimeInterval(86400 * 3), // 3 days in the future
            location: Location(latitude: 37.7749, longitude: -122.4194, address: "San Francisco"),
            completed: true,
            creationDate: Date().addingTimeInterval(-86400), // 1 day ago
            imageUrls: [
                "https://via.placeholder.com/300",
                "https://via.placeholder.com/300",
                "https://via.placeholder.com/300"
            ]
        )
        
        // 3) Pass the sample item to DetailItemView in each preview
        return Group {
            DetailItemView(item: sampleItem)
                .environmentObject(mockUserVM)
                .environmentObject(mockListVM)
                .environmentObject(mockPostVM)
                .environmentObject(SyncCoordinator(postViewModel: mockPostVM, listViewModel: mockListVM, feedViewModel: FeedViewModel()))
                .previewDisplayName("DetailItemView - Light Mode")

            DetailItemView(item: sampleItem)
                .environmentObject(mockUserVM)
                .environmentObject(mockListVM)
                .environmentObject(mockPostVM)
                .environmentObject(SyncCoordinator(postViewModel: mockPostVM, listViewModel: mockListVM, feedViewModel: FeedViewModel()))
                .preferredColorScheme(.dark)
                .previewDisplayName("DetailItemView - Dark Mode")
        }
    }
}
#endif
