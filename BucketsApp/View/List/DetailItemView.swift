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
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var currentItem: ItemModel
    @StateObject private var imagePickerVM = ImagePickerViewModel()

    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool

    // NEW: Social sharing state
    @State private var showShareAlert: Bool = false
    @State private var lastShareEvent: PostType? = nil

    init(item: ItemModel) {
        self.itemID = item.id
        _currentItem = State(initialValue: item)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Top row: Checkmark + editable title
                HStack(spacing: 8) {
                    Button(action: toggleCompleted) {
                        Image(systemName: currentItem.completed ? "checkmark.circle.fill" : "circle")
                            .imageScale(.large)
                            .foregroundColor(currentItem.completed ? .accentColor : .gray)
                    }
                    .buttonStyle(.borderless)

                    TextField("Title...", text: Binding(
                        get: { currentItem.name },
                        set: { newValue in
                            currentItem.name = newValue
                            bucketListViewModel.addOrUpdateItem(currentItem)
                        }
                    ))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .focused($isTitleFocused)

                    Spacer()
                }

                // Image picker row
                PhotosPicker(
                    selection: $imagePickerVM.selectedItems,
                    maxSelectionCount: 3,
                    matching: .images
                ) {
                    HStack {
                        Text("📸 Select Photo")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(!currentItem.completed)
                .onChange(of: imagePickerVM.selectedItems) { _ in
                    Task {
                        await imagePickerVM.loadImages()

                        var uploadedUrls: [String] = []
                        for image in imagePickerVM.images {
                            if let url = await uploadImageToStorage(image: image) {
                                uploadedUrls.append(url)
                            } else {
                                print("❌ Failed to get image URL from upload.")
                            }
                        }

                        if currentItem.userId.isEmpty,
                           let uid = onboardingViewModel.user?.id {
                            currentItem.userId = uid
                        }

                        currentItem.imageUrl1 = uploadedUrls.indices.contains(0) ? uploadedUrls[0] : currentItem.imageUrl1
                        currentItem.imageUrl2 = uploadedUrls.indices.contains(1) ? uploadedUrls[1] : currentItem.imageUrl2
                        currentItem.imageUrl3 = uploadedUrls.indices.contains(2) ? uploadedUrls[2] : currentItem.imageUrl3

                        bucketListViewModel.addOrUpdateItem(currentItem)
                    }
                }

                // Image preview grid
                if currentItem.imageUrl1 != nil || currentItem.imageUrl2 != nil || currentItem.imageUrl3 != nil {
                    photoGridRow
                }

                // Share button
                if currentItem.completed && currentItem.imageUrl1 != nil {
                    Button("📣 Share to Feed") {
                        lastShareEvent = .completed
                        showShareAlert = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Share to Feed?", isPresented: $showShareAlert, actions: {
            Button("Post") {
                postToFeed(type: lastShareEvent ?? .completed)
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text(shareMessage(for: lastShareEvent))
        })
        .onAppear {
            refreshCurrentItemFromList()
            
            if currentItem.userId.isEmpty,
               let authUserId = onboardingViewModel.user?.id {
                currentItem.userId = authUserId
                if !currentItem.name.isEmpty || currentItem.imageUrl1 != nil || currentItem.imageUrl2 != nil || currentItem.imageUrl3 != nil {
                    bucketListViewModel.addOrUpdateItem(currentItem)
                }
            }
        }
    }

    private func toggleCompleted() {
        currentItem.completed.toggle()
        if currentItem.completed {
            currentItem.dueDate = Date()
        } else {
            currentItem.dueDate = nil
        }
        bucketListViewModel.addOrUpdateItem(currentItem)
    }
}

// MARK: - Computed Props
extension DetailItemView {
    @MainActor private var isShowingChevron: Bool {
        currentItem.imageUrl1 != nil || currentItem.imageUrl2 != nil || currentItem.imageUrl3 != nil
    }

    @MainActor private var isShowingPhotoGrid: Bool {
        currentItem.imageUrl1 != nil || currentItem.imageUrl2 != nil || currentItem.imageUrl3 != nil
    }
}

// MARK: - Helpers
extension DetailItemView {

    private func refreshCurrentItemFromList() {
        if let updatedItem = bucketListViewModel.items.first(where: { $0.id == itemID }) {
            self.currentItem = updatedItem
        }
    }

    private func uploadImageToStorage(image: UIImage) async -> String? {
        print("🔍 Uploading single image in multi-image flow")
        
        guard currentItem.completed else { return nil }
        guard let userId = onboardingViewModel.userId, !userId.isEmpty else {
            print("❌ Missing userId")
            return nil
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert UIImage to JPEG data.")
            return nil
        }
        
        let uniqueId = UUID().uuidString
        let storageRef = Storage.storage().reference()
            .child("users/\(userId)/item-images/\(currentItem.id.uuidString)-image-\(uniqueId).jpg")
        
        print("Uploading to path: \(storageRef.fullPath) with size: \(imageData.count) bytes")
        
        do {
            try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            print("✅ Image uploaded to:", downloadURL.absoluteString)
            return downloadURL.absoluteString
        } catch {
            print("❌ Upload error:", error.localizedDescription)
        }

        return nil
    }

    private func hideKeyboard() {
        isTitleFocused = false
        isNotesFocused = false
    }

    private func postToFeed(type: PostType) {
        // Replace this with real PostModel creation logic later
        print("📣 Posting \(type.rawValue) to feed for item:", currentItem.name)

        // Optionally update flags (requires you add these to ItemModel)
        switch type {
        case .added: currentItem.hasPostedAddEvent = true
        case .completed: currentItem.hasPostedCompletion = true
        case .photos: currentItem.hasPostedPhotos = true
        }

        bucketListViewModel.addOrUpdateItem(currentItem)
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
        let urls = [currentItem.imageUrl1, currentItem.imageUrl2, currentItem.imageUrl3].compactMap { $0 }
        if !urls.isEmpty {
            photoGrid(urlStrings: urls)
        }
    }

    private func photoGrid(urlStrings: [String]) -> some View {
        HStack {
            HStack(spacing: 8) {
                ForEach(urlStrings, id: \.self) { urlStr in
                    if let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 110, height: 110)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 110, height: 110)
                                    .cornerRadius(10)
                                    .clipped()
                            default:
                                EmptyView()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}


#if DEBUG
struct DetailItemView_Previews: PreviewProvider {
    static var previews: some View {
        // 1) Create mock environment objects
        let mockOnboardingVM = OnboardingViewModel()
        let mockListVM = ListViewModel()
        let mockPostVM = PostViewModel()
        
        // 2) Create a sample ItemModel with placeholder images
        let sampleItem = ItemModel(
            userId: "previewUser",
            name: "Sample Bucket List Item",
            description: "Short description for preview...",
            dueDate: Date().addingTimeInterval(86400 * 3), // 3 days in the future
            location: Location(latitude: 37.7749, longitude: -122.4194, address: "San Francisco"),
            completed: true,
            creationDate: Date().addingTimeInterval(-86400), // 1 day ago
            imageUrl1: "https://via.placeholder.com/300",
            imageUrl2: "https://via.placeholder.com/300",
            imageUrl3: "https://via.placeholder.com/300"
        )
        
        // 3) Pass the sample item to DetailItemView in each preview
        return Group {
            DetailItemView(item: sampleItem)
                .environmentObject(mockOnboardingVM)
                .environmentObject(mockListVM)
                .environmentObject(mockPostVM)
                .previewDisplayName("DetailItemView - Light Mode")

            DetailItemView(item: sampleItem)
                .environmentObject(mockOnboardingVM)
                .environmentObject(mockListVM)
                .environmentObject(mockPostVM)
                .preferredColorScheme(.dark)
                .previewDisplayName("DetailItemView - Dark Mode")
        }
    }
}
#endif
