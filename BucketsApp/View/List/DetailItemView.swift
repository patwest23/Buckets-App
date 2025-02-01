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
    @StateObject private var imagePickerVM = ImagePickerViewModel() // simplified VM
    @State private var showDateCreatedSheet = false
    @State private var showDateCompletedSheet = false
    
    // Spinner for uploads
    @State private var isUploading = false
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    
                    // (1) Basic Info Row (toggle + multi-line name)
                    basicInfoRow
                        .padding(.horizontal)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    
                    // (2) Photos Picker + Grid (existing or newly picked)
                    photoPickerRow
                    
                    // (3) Date Created
                    dateCreatedLine
                    
                    // (4) Date Completed
                    dateCompletedLine
                    
                    // (5) Location
                    locationRow
                    
                    // (6) Notes at the Bottom
                    descriptionRow
                }
                .padding()
            }
        }
        .navigationTitle("")                // no text
        .navigationBarTitleDisplayMode(.inline)
        // Whenever `imagePickerVM.uiImages` changes, upload them to Firebase for this item
        .onChange(of: imagePickerVM.uiImages) { newImages in
            Task {
                await uploadPickedImages(newImages)
            }
        }
    }
}

// MARK: - Subviews
extension DetailItemView {
    
    /// Basic info row with a completion toggle & a multi-line TextField (iOS 16+)
    private var basicInfoRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Completion toggle
                Button(action: {
                    Task { await toggleCompleted() }
                }) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .font(.title2)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Multi-line TextField on iOS 16+, otherwise single line
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
                    .lineLimit(1...10) // Expand up to 10 lines (or use 1... for unlimited)
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
                    .font(.title3)
                    .foregroundColor(item.completed ? .gray : .primary)
                }
            }
            .padding(.vertical, 10)
        }
    }
    
    /// Photos Picker + Grid of images
    private var photoPickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Button + Spinner in the same horizontal row
            HStack {
                // PhotosPicker button
                PhotosPicker(
                    selection: $imagePickerVM.imageSelections,
                    maxSelectionCount: 3,
                    matching: .images
                ) {
                    Text("📸   Select Photos")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if isUploading {
                    ProgressView()
                        .padding(.trailing, 8)
                }
            }
            .padding()
            
            // If the user just picked new images, show them in a grid
            if !imagePickerVM.uiImages.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                    ForEach(imagePickerVM.uiImages, id: \.self) { uiImage in
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 10)
            }
            // Otherwise, if no new images, show existing item.imageUrls
            else if !item.imageUrls.isEmpty {
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
                                        .cornerRadius(8)
                                case .failure:
                                    EmptyView() // show nothing if it fails
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            EmptyView()
                        }
                    }
                }
//                .padding(.vertical, 10)
            }
        }
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    /// Date Created Row
    private var dateCreatedLine: some View {
        HStack {
            Text("📅   Created")
                .font(.headline)
            Spacer()
            Text(formattedDate(item.creationDate))
                .foregroundColor(.accentColor)
        }
        .onTapGesture { showDateCreatedSheet = true }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
        .sheet(isPresented: $showDateCreatedSheet) {
            datePickerSheet(
                title: "Select Date Created",
                date: $item.creationDate,
                onDismiss: { showDateCreatedSheet = false }
            )
        }
    }
    
    /// Date Completed Row
    private var dateCompletedLine: some View {
        HStack {
            Text("📅   Completed")
                .font(.headline)
            Spacer()
            Text(formattedDate(item.dueDate))
                .foregroundColor(.accentColor)
        }
        .onTapGesture { showDateCompletedSheet = true }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
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
    
    /// Location Row
    private var locationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📍")
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
            }
            .font(.headline)
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 2)
        }
    }
    
    /// Notes (Description) at the bottom
    private var descriptionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📝   Notes")
                .font(.headline)
            
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
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

// MARK: - Private Helpers
extension DetailItemView {
    
    /// Upload newly picked images to Firebase Storage, then update item.imageUrls with the new URLs.
    private func uploadPickedImages(_ images: [UIImage]) async {
        guard let userId = onboardingViewModel.user?.id else { return }
        
        // Start spinner
        isUploading = true
        
        let storageRef = Storage.storage().reference()
            .child("users/\(userId)/item-\(item.id.uuidString)")
        
        var newUrls: [String] = []
        
        for (index, uiImage) in images.enumerated() {
            guard let imageData = uiImage.jpegData(compressionQuality: 0.8) else { continue }
            let fileName = "photo\(index + 1).jpg"
            let imageRef = storageRef.child(fileName)
            
            do {
                // 1) Upload
                try await imageRef.putDataAsync(imageData)
                
                // 2) Retrieve download URL
                let downloadUrl = try await imageRef.downloadURL()
                newUrls.append(downloadUrl.absoluteString)
            } catch {
                print("Error uploading image \(index): \(error.localizedDescription)")
            }
        }
        
        // Stop spinner
        isUploading = false
        
        // If we got new URLs, replace item.imageUrls
        if !newUrls.isEmpty {
            item.imageUrls = newUrls
            updateItem() // Save the item with updated imageUrls
        }
    }
    
    /// Show a date picker inside a sheet
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
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .onChange(of: date.wrappedValue) { _ in
                    // Whenever user changes the date, update Firestore
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
    
    /// Updates the item in your ViewModel (persisting to Firestore or local storage)
    private func updateItem() {
        Task {
            bucketListViewModel.addOrUpdateItem(item)
        }
    }
    
    /// Toggles 'completed' state. If marking complete, set `item.dueDate` to now; otherwise clear it.
    private func toggleCompleted() async {
        if !item.completed {
            // Marking item as complete
            item.completed = true
            item.dueDate = Date()
        } else {
            // Marking item as incomplete
            item.completed = false
            item.dueDate = nil
        }
        
        bucketListViewModel.addOrUpdateItem(item)
    }
    
    /// Convert an optional `Date` to a user-friendly string.
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

        // 2) Create a sample ItemModel with three placeholder images
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

        // 3) Provide a binding to `sampleItem`
        return DetailItemView(item: .constant(sampleItem))
            .environmentObject(mockOnboardingVM)
            .environmentObject(mockListVM)
            .previewDisplayName("DetailItemView with 3 Blank Images")
    }
}
#endif














