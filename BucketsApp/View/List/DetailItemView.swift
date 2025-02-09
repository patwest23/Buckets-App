//
//  DetailItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/1/24.
//

import SwiftUI
import PhotosUI
import FirebaseStorage

struct DetailItemView: View {
    // MARK: - Bound Item
    @Binding var item: ItemModel
    
    // MARK: - Environment
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // MARK: - Presentation
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Local States
    @StateObject private var imagePickerVM = ImagePickerViewModel()
    @State private var showDateCreatedSheet = false
    @State private var showDateCompletedSheet = false
    
    // Spinner for uploads
    @State private var isUploading = false
    
    // MARK: - Focus States for text editing
    @FocusState private var isNameFocused: Bool
    @FocusState private var isNotesFocused: Bool
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    
                    basicInfoRow       // Name toggle & textfield
                    photoPickerRow
                    dateCreatedLine
                    dateCompletedLine
                    locationRow
                    descriptionRow     // Notes text editor
                    
                }
                .padding()
                .background(Color(uiColor: .systemBackground))
            }
            .background(Color(uiColor: .systemBackground))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // MARK: - Conditionally show "Done" button if name or notes are focused
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isNameFocused || isNotesFocused {
                    Button("Done") {
                        // Clear focus => dismiss keyboard
                        isNameFocused = false
                        isNotesFocused = false
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
        // Whenever `imagePickerVM.uiImages` changes, upload them
        .onChange(of: imagePickerVM.uiImages) { newImages in
            Task {
                await uploadPickedImages(newImages)
            }
        }
    }
}

// MARK: - Subviews
extension DetailItemView {
    
    /// (1) Basic info row: toggle + multi-line name
    fileprivate var basicInfoRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Completion toggle
                Button {
                    Task { await toggleCompleted() }
                } label: {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(.borderless)
                
                // Multi-line TextField for item.name
                if #available(iOS 16.0, *) {
                    TextField(
                        "",
                        text: Binding(
                            get: { item.name },
                            set: { newValue in
                                item.name = newValue
                                updateItem()
                            }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(1...10)
                    .foregroundColor(item.completed ? .gray : .primary)
                    .focused($isNameFocused) // Focus binding
                } else {
                    TextField(
                        "",
                        text: Binding(
                            get: { item.name },
                            set: { newValue in
                                item.name = newValue
                                updateItem()
                            }
                        )
                    )
                    .foregroundColor(item.completed ? .gray : .primary)
                    .focused($isNameFocused) // For iOS < 16, won't multiline, but we can still focus
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    /// (2) Photos Picker + grid
    fileprivate var photoPickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PhotosPicker(
                    selection: $imagePickerVM.imageSelections,
                    maxSelectionCount: 3,
                    matching: .images
                ) {
                    Text("📸   Select Photos")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if isUploading {
                    ProgressView()
                        .padding(.trailing, 8)
                }
            }
            .padding(.vertical, 8)
            
            if !imagePickerVM.uiImages.isEmpty {
                // Show newly picked images
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                    ForEach(imagePickerVM.uiImages, id: \.self) { uiImage in
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                    }
                }
                .padding(.vertical, 10)
            }
            else if !item.imageUrls.isEmpty {
                // Show existing images from item.imageUrls
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                    ForEach(item.imageUrls, id: \.self) { urlStr in
                        if let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipped()
                                case .failure:
                                    EmptyView()
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            EmptyView()
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }
    
    /// (3) Date Created Row
    fileprivate var dateCreatedLine: some View {
        HStack {
            Text("📅   Created")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text(formattedDate(item.creationDate))
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 8)
        .onTapGesture { showDateCreatedSheet = true }
        .sheet(isPresented: $showDateCreatedSheet) {
            datePickerSheet(
                title: "Select Date Created",
                date: $item.creationDate,
                onDismiss: { showDateCreatedSheet = false }
            )
        }
    }
    
    /// (4) Date Completed Row
    fileprivate var dateCompletedLine: some View {
        HStack {
            Text("📅   Completed")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text(formattedDate(item.dueDate))
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 8)
        .onTapGesture { showDateCompletedSheet = true }
        .sheet(isPresented: $showDateCompletedSheet) {
            datePickerSheet(
                title: "Select Date Completed",
                date: Binding(
                    get: { item.dueDate ?? Date() },
                    set: { newValue in
                        item.dueDate = newValue
                        updateItem()
                    }
                ),
                onDismiss: { showDateCompletedSheet = false }
            )
        }
    }
    
    /// (5) Location Row
    fileprivate var locationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📍")
                    .foregroundColor(.primary)
                TextField(
                    "Enter location...",
                    text: Binding(
                        get: { item.location?.address ?? "" },
                        set: { newValue in
                            var loc = item.location ?? Location(latitude: 0, longitude: 0, address: "")
                            loc.address = newValue
                            item.location = loc
                            updateItem()
                        }
                    )
                )
                .foregroundColor(.primary)
            }
            .font(.headline)
            .padding(.vertical, 8)
        }
    }
    
    /// (6) Notes (Description)
    fileprivate var descriptionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📝   Caption")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextEditor(
                text: Binding(
                    get: { item.description ?? "" },
                    set: { newValue in
                        item.description = newValue
                        updateItem()
                    }
                )
            )
            .frame(minHeight: 150)
            .foregroundColor(.primary)
            // Focus this text editor as well
            .focused($isNotesFocused)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Private Helpers
extension DetailItemView {
    
    /// Upload newly picked images => Firebase => update item.imageUrls
    private func uploadPickedImages(_ images: [UIImage]) async {
        guard let userId = onboardingViewModel.user?.id else { return }

        isUploading = true

        // 1) Construct a reference to the folder:  "users/<userId>/item-<itemUUID>"
        let storageRef = Storage.storage().reference()
                         .child("users/\(userId)/item-\(item.id.uuidString)")

        var newUrls: [String] = []

        for (index, uiImage) in images.enumerated() {
            guard let imageData = uiImage.jpegData(compressionQuality: 0.8) else { continue }

            // 2) For each image, build a reference to "photo\(index+1).jpg" in that folder
            let imageRef = storageRef.child("photo\(index + 1).jpg")

            do {
                // 3) Upload the data
                try await imageRef.putDataAsync(imageData)

                // 4) Retrieve its download URL
                let downloadUrl = try await imageRef.downloadURL()
                newUrls.append(downloadUrl.absoluteString)
            } catch {
                print("Error uploading image \(index): \(error.localizedDescription)")
            }
        }

        isUploading = false

        // 5) Update item.imageUrls and sync to Firestore
        if !newUrls.isEmpty {
            item.imageUrls.append(contentsOf: newUrls)  // or = newUrls if you want to replace
            updateItem()  // calls bucketListViewModel.addOrUpdateItem(item)
        }
    }
    
    /// Show date picker in a sheet
    private func datePickerSheet(
        title: String,
        date: Binding<Date>,
        onDismiss: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title3)
                .padding(.top)
            
            DatePicker("", selection: date, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .onChange(of: date.wrappedValue) { _ in
                    updateItem()
                }
            
            Button("Done") {
                onDismiss()
            }
            .font(.headline)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(350)]) // iOS16+ (optional)
    }
    
    /// Update the item in Firestore
    private func updateItem() {
        Task {
            bucketListViewModel.addOrUpdateItem(item)
        }
    }
    
    /// Toggle completed => set or clear dueDate
    private func toggleCompleted() async {
        if !item.completed {
            item.completed = true
            item.dueDate = Date()
        } else {
            item.completed = false
            item.dueDate = nil
        }
        bucketListViewModel.addOrUpdateItem(item)
    }
    
    /// Format optional date
    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#if DEBUG
struct DetailItemView_Previews: PreviewProvider {
    static var previews: some View {
        // 1) Create mock environment objects
        let mockOnboardingVM = OnboardingViewModel()
        let mockListVM = ListViewModel()
        
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
        
        // 3) Provide a binding to sampleItem and preview in both color schemes
        return Group {
            DetailItemView(item: .constant(sampleItem))
                .environmentObject(mockOnboardingVM)
                .environmentObject(mockListVM)
                .previewDisplayName("DetailItemView - Light Mode")

            DetailItemView(item: .constant(sampleItem))
                .environmentObject(mockOnboardingVM)
                .environmentObject(mockListVM)
                .preferredColorScheme(.dark)
                .previewDisplayName("DetailItemView - Dark Mode")
        }
    }
}
#endif














