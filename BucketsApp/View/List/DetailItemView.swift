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
    @EnvironmentObject var postViewModel: PostViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var currentItem: ItemModel
    @StateObject private var imagePickerVM = ImagePickerViewModel()

    @State private var showDateCreatedSheet = false
    @State private var showDateCompletedSheet = false
    @State private var showDeleteAlert = false

    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool

    init(item: ItemModel) {
        self.itemID = item.id
        _currentItem = State(initialValue: item)
    }

    var body: some View {
        Form {
            sectionTitleCompleted
            sectionPhotos
            sectionDates
            sectionLocation
            sectionNotes

            if currentItem.completed {
                sectionPost
            }

            sectionDelete
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
        .sheet(isPresented: $showDateCreatedSheet) {
            datePickerSheet(
                title: "Set Created Date",
                date: Binding(
                    get: { currentItem.creationDate },
                    set: { newValue in
                        currentItem.creationDate = newValue
                        bucketListViewModel.addOrUpdateItem(currentItem)
                    }
                )
            ) {
                showDateCreatedSheet = false
            }
        }
        .sheet(isPresented: $showDateCompletedSheet) {
            if currentItem.completed {
                datePickerSheet(
                    title: "Set Completion Date",
                    date: Binding(
                        get: { currentItem.dueDate ?? Date() },
                        set: { newValue in
                            currentItem.dueDate = newValue
                            bucketListViewModel.addOrUpdateItem(currentItem)
                        }
                    )
                ) {
                    showDateCompletedSheet = false
                }
            }
        }
        .alert("Delete Item?",
               isPresented: $showDeleteAlert,
               actions: {
                   Button("Delete", role: .destructive) {
                       Task {
                           await bucketListViewModel.deleteItem(currentItem)
                       }
                       presentationMode.wrappedValue.dismiss()
                   }
                   Button("Cancel", role: .cancel) {}
               },
               message: {
                   Text("This cannot be undone. You will lose “\(currentItem.name)” permanently.")
               })
        .onChange(of: imagePickerVM.uiImages) { _, newImages in
            Task {
                await uploadImagesToStorage(from: newImages)
            }
        }
        .onAppear {
            refreshCurrentItemFromList()
        }
    }
}

// MARK: - Sections
extension DetailItemView {
    
    private var sectionTitleCompleted: some View {
        Section {
            TextField("Title...", text: Binding(
                get: { currentItem.name },
                set: { newValue in
                    currentItem.name = newValue
                    bucketListViewModel.addOrUpdateItem(currentItem)
                }
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
                    let hasImages = !imagePickerVM.uiImages.isEmpty || !currentItem.imageUrls.isEmpty
                    if hasImages {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
            }
            .disabled(!currentItem.completed)

            let showGrid = !imagePickerVM.uiImages.isEmpty || !currentItem.imageUrls.isEmpty
            if showGrid {
                photoGridRow
            }
        }
    }

    private var sectionDates: some View {
        Section {
            Button {
                showDateCreatedSheet = true
            } label: {
                HStack {
                    Text("📅 Created").font(.headline)
                    Spacer()
                    Text(formatDate(currentItem.creationDate))
                        .foregroundColor(.accentColor)
                }
            }
            .buttonStyle(.plain)

            Button {
                if currentItem.completed {
                    showDateCompletedSheet = true
                }
            } label: {
                HStack {
                    Text("📅 Completed").font(.headline)
                    Spacer()
                    let dateStr = currentItem.completed ? formatDate(currentItem.dueDate) : "--"
                    Text(dateStr)
                        .foregroundColor(currentItem.completed ? .accentColor : .gray)
                }
            }
            .buttonStyle(.plain)
            .disabled(!currentItem.completed)
        }
    }

    private var sectionLocation: some View {
        Section {
            HStack {
                Text("📍 Location").font(.headline)
                Spacer()
                TextField("Enter location...", text: Binding(
                    get: { currentItem.location?.address ?? "" },
                    set: { newValue in
                        var loc = currentItem.location ?? Location(latitude: 0, longitude: 0, address: "")
                        loc.address = newValue
                        currentItem.location = loc
                        bucketListViewModel.addOrUpdateItem(currentItem)
                    }
                ))
                .disableAutocorrection(false)
                .autocapitalization(.none)
                .multilineTextAlignment(.trailing)
            }
        }
    }

    private var sectionNotes: some View {
        Section {
            TextEditor(
                text: Binding(
                    get: { currentItem.description ?? "" },
                    set: { newValue in
                        currentItem.description = newValue
                        bucketListViewModel.addOrUpdateItem(currentItem)
                    }
                )
            )
            .frame(minHeight: 100)
            .focused($isNotesFocused)
        }
    }

    private var sectionPost: some View {
        Section {
            Button("Post") {
                postViewModel.selectedItemID = currentItem.id.uuidString
                Task {
                    await postViewModel.postItem()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var sectionDelete: some View {
        Section {
            Button {
                showDeleteAlert = true
            } label: {
                Text("Delete")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
            .listRowBackground(Color.red.opacity(0.2))
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Helpers
extension DetailItemView {
    
    private func refreshCurrentItemFromList() {
        if let updatedItem = bucketListViewModel.items.first(where: { $0.id == itemID }) {
            self.currentItem = updatedItem
        }
    }

    private func uploadImagesToStorage(from images: [UIImage]) async {
        guard currentItem.completed else { return }
        guard let user = onboardingViewModel.user else { return }
        guard let userId = user.id else { return }

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
                } catch {
                    print("[DetailItemView] uploadImagesToStorage error:", error.localizedDescription)
                }
            }
        }

        currentItem.imageUrls = newUrls
        bucketListViewModel.addOrUpdateItem(currentItem)
    }

    private var bindingForCompletion: Binding<Bool> {
        Binding(get: {
            currentItem.completed
        }, set: { newValue in
            currentItem.completed = newValue
            currentItem.dueDate = newValue ? Date() : nil
            bucketListViewModel.addOrUpdateItem(currentItem)
        })
    }

    private func hideKeyboard() {
        isTitleFocused = false
        isNotesFocused = false
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func datePickerSheet(
        title: String,
        date: Binding<Date>,
        onDismiss: @escaping () -> Void
    ) -> some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(title)
                    .font(.title3)
                    .padding(.top)

                DatePicker("", selection: date, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Button("Done") {
                    onDismiss()
                }
                .font(.headline)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(350)])
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














