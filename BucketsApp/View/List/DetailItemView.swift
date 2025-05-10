//
//  DetailItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/1/24.
//

import SwiftUI
import PhotosUI
import FirebaseStorage

@MainActor
struct DetailItemView: View {
    let itemID: UUID

    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var currentItem: ItemModel
    @State private var tempLocation: String = ""
    @State private var tempDescription: String = ""
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
        Form {
            sectionTitleCompleted
            sectionPhotos
            // sectionDates
            // sectionLocation
            // sectionNotes
            sectionShare
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isTitleFocused || isNotesFocused {
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            refreshCurrentItemFromList()
            tempLocation = currentItem.location?.address ?? ""
            tempDescription = currentItem.description ?? ""
        }
        .alert("Share to Feed?", isPresented: $showShareAlert, actions: {
            Button("Post") {
                postToFeed(type: lastShareEvent ?? .added)
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text(shareMessage(for: lastShareEvent))
        })
    }
}

// MARK: - Sections
extension DetailItemView {

    private var sectionTitleCompleted: some View {
        Section {
            TextField("Title...", text: Binding(
                get: { currentItem.name },
                set: { currentItem.name = $0 }
            ))
            .focused($isTitleFocused)
            .foregroundColor(currentItem.completed ? .gray : .primary)

            Toggle(isOn: bindingForCompletion) {
                Label(
                    "Completed",
                    systemImage: currentItem.completed ? "checkmark.circle.fill" : "circle"
                )
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
    }

    private var sectionPhotos: some View {
        Section {
            PhotosPicker(
                selection: $imagePickerVM.imageSelections,
                maxSelectionCount: 3,
                matching: .images
            ) {
                HStack {
                    Text("📸  Select Photos")
                    Spacer()
                    if isShowingChevron {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
            }
            .disabled(!currentItem.completed)
            .onChange(of: imagePickerVM.imageSelections) { _ in
                Task {
                    let uploadedUrls = await uploadImagesToStorage(from: imagePickerVM.uiImages)
                    if !uploadedUrls.isEmpty {
                        currentItem.imageUrls = uploadedUrls
                        bucketListViewModel.addOrUpdateItem(currentItem)
                        await bucketListViewModel.prefetchImages(for: currentItem)
                        await bucketListViewModel.loadItems()
                    }
                }
            }

            if isShowingPhotoGrid {
                photoGridRow
            }
        }
    }

    /*
    private var sectionDates: some View {
        Section {
            DatePicker("📅 Created", selection: Binding(
                get: { currentItem.creationDate },
                set: { currentItem.creationDate = $0 }
            ), displayedComponents: .date)

            if currentItem.completed {
                DatePicker("📅 Completed", selection: Binding(
                    get: { currentItem.dueDate ?? Date() },
                    set: { currentItem.dueDate = $0 }
                ), displayedComponents: .date)
            }
        }
    }
    */

    /*
    private var sectionLocation: some View {
        Section(header: Text("📍 Location")) {
            TextField("Enter location...", text: $tempLocation)
                .onChange(of: tempLocation) { newValue in
                    var loc = currentItem.location ?? Location(latitude: 0, longitude: 0, address: "")
                    loc.address = newValue
                    currentItem.location = loc
                }
                .disableAutocorrection(true)
                .autocapitalization(.sentences)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.vertical, 4)
        }
    }
    */

    /*
    private var sectionNotes: some View {
        Section(header: Text("📝 Notes")) {
            ZStack(alignment: .topLeading) {
                if tempDescription.isEmpty {
                    Text("Write notes or thoughts...")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                }
                TextEditor(text: $tempDescription)
                    .onChange(of: tempDescription) { newValue in
                        currentItem.description = newValue
                    }
                    .focused($isNotesFocused)
                    .frame(minHeight: 120)
                    .padding(4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3))
            )
            .padding(.vertical, 4)
        }
    }
    */

    // 🔥 New: Share Section
    private var sectionShare: some View {
        Section(header: Text("📣 Share")) {
            Button("Post to Feed") {
                if currentItem.completed {
                    lastShareEvent = .completed
                } else if !imagePickerVM.uiImages.isEmpty || !currentItem.imageUrls.isEmpty {
                    lastShareEvent = .photos
                } else {
                    lastShareEvent = .added
                }
                showShareAlert = true
            }
            .foregroundColor(.blue)
        }
    }

    // sectionSave removed: replaced by real-time persistence in photo handling logic
}

// MARK: - Computed Props
extension DetailItemView {
    @MainActor private var isShowingChevron: Bool {
        !imagePickerVM.uiImages.isEmpty || !currentItem.imageUrls.isEmpty
    }

    @MainActor private var isShowingPhotoGrid: Bool {
        !imagePickerVM.uiImages.isEmpty || !currentItem.imageUrls.isEmpty
    }
}

// MARK: - Helpers
extension DetailItemView {

    private func refreshCurrentItemFromList() {
        if let updatedItem = bucketListViewModel.items.first(where: { $0.id == itemID }) {
            self.currentItem = updatedItem
        }
    }

    private func uploadImagesToStorage(from images: [UIImage]) async -> [String] {
        guard currentItem.completed else { return [] }
        guard let user = onboardingViewModel.user, let userId = user.id else { return [] }

        var newUrls: [String] = []
        let storageRef = Storage.storage().reference()
            .child("users/\(userId)/item-\(currentItem.id.uuidString)")

        for (index, uiImage) in images.prefix(3).enumerated() {
            if let imageData = uiImage.jpegData(compressionQuality: 0.8) {
                do {
                    let imageRef = storageRef.child("photo\(index + 1).jpg")
                    try await imageRef.putDataAsync(imageData)
                    let downloadURL = try await imageRef.downloadURL()
                    newUrls.append(downloadURL.absoluteString)
                    print("✅ Uploaded image \(index + 1):", downloadURL.absoluteString)
                } catch {
                    print("❌ Failed to upload image \(index + 1):", error.localizedDescription)
                }
            }
        }

        // Real-time persistence: update item and view model after upload
        if !newUrls.isEmpty {
            currentItem.imageUrls = newUrls
            bucketListViewModel.addOrUpdateItem(currentItem)
            await bucketListViewModel.prefetchImages(for: currentItem)
            await bucketListViewModel.loadItems()
        }

        return newUrls
    }

    private var bindingForCompletion: Binding<Bool> {
        Binding(
            get: { currentItem.completed },
            set: { newValue in
                currentItem.completed = newValue
                currentItem.dueDate = newValue ? Date() : nil
            }
        )
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
        if !imagePickerVM.uiImages.isEmpty {
            photoGrid(uiImages: imagePickerVM.uiImages)
        } else if !currentItem.imageUrls.isEmpty {
            photoGrid(urlStrings: currentItem.imageUrls)
        }
    }

    private func photoGrid(uiImages: [UIImage]) -> some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
            ForEach(uiImages, id: \.self) { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .cornerRadius(6)
                    .clipped()
            }
        }
    }

    private func photoGrid(urlStrings: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
            ForEach(urlStrings, id: \.self) { urlStr in
                if let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .cornerRadius(6)
                                .clipped()
                        default:
                            EmptyView()
                        }
                    }
                }
            }
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
            imageUrls: [
                "https://via.placeholder.com/300",
                "https://via.placeholder.com/300",
                "https://via.placeholder.com/300"
            ]
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














