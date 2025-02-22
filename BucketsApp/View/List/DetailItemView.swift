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
    
    @State private var isUploading = false
    @State private var showDeleteAlert = false
    
    // Focus States
    @FocusState private var isNameFocused: Bool
    @FocusState private var isNotesFocused: Bool
    
    // MARK: - Styling Constants
    private let cardCornerRadius: CGFloat = 12
    private let cardShadowRadius: CGFloat = 4
    
    var body: some View {
        VStack {
            ScrollView {
                
                // Main Card Container
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Basic Info (title + checkmark)
                    basicInfoRow
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                    
                    // Photos
                    photoPickerRow
                        .padding(.horizontal, 12)
                    
                    // Dates
                    dateCreatedLine
                        .padding(.horizontal, 12)
                    dateCompletedLine
                        .padding(.horizontal, 12)
                    
                    // Location
                    locationRow
                        .padding(.horizontal, 12)
                    
                    // Notes
                    descriptionRow
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    
                }
                .background(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.1),
                                radius: cardShadowRadius, x: 0, y: 2)
                )
                .padding()  // Outer padding from screen edges
                
            }
            
            // DELETE BUTTON
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("Delete")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        // Navigation Title
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        
        // Toolbar: "Done" button for textfields
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
        
        // Delete Confirmation Alert
        .alert(
            "Are you sure you want to delete this item?",
            isPresented: $showDeleteAlert
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await bucketListViewModel.deleteItem(item)
                }
                presentationMode.wrappedValue.dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. You will lose “\(item.name)” permanently.")
        }
        
        // Update images on change
        .onChange(of: imagePickerVM.uiImages) { _, newImages in
            if !newImages.isEmpty {
                item.imageUrls.removeAll()
            }
            Task {
                await uploadPickedImages(newImages)
            }
        }
    }
}

// MARK: - Subviews
extension DetailItemView {
    
    // (1) Basic info row
    fileprivate var basicInfoRow: some View {
        HStack(spacing: 10) {
            Button {
                Task { await toggleCompleted() }
            } label: {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundColor(item.completed ? .accentColor : .gray)
            }
            .buttonStyle(.borderless)
            
            // Editable Title
            if #available(iOS 16.0, *) {
                TextField(
                    "Untitled",
                    text: Binding(
                        get: { item.name },
                        set: { newValue in
                            item.name = newValue
                            updateItem()
                        }
                    ),
                    axis: .vertical
                )
                .lineLimit(1...3)
                .foregroundColor(item.completed ? .gray : .primary)
                .focused($isNameFocused)
            } else {
                TextField(
                    "Untitled",
                    text: Binding(
                        get: { item.name },
                        set: { newValue in
                            item.name = newValue
                            updateItem()
                        }
                    )
                )
                .foregroundColor(item.completed ? .gray : .primary)
                .focused($isNameFocused)
            }
        }
        .padding(.vertical, 4)
    }
    
    // (2) Photos Picker
    fileprivate var photoPickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            if item.completed {
                HStack {
                    PhotosPicker(
                        selection: $imagePickerVM.imageSelections,
                        maxSelectionCount: 3,
                        matching: .images
                    ) {
                        Text("📸   Select Photos")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    if isUploading {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                }
                
                // Show UI images or downloaded URLs
                if !imagePickerVM.uiImages.isEmpty {
                    photoGrid(uiImages: imagePickerVM.uiImages)
                } else if !item.imageUrls.isEmpty {
                    photoGrid(urlStrings: item.imageUrls)
                }
            } else {
                // Disabled state if not completed
                Text("📸   Select Photos")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
    
    // (3) Date Created
    fileprivate var dateCreatedLine: some View {
        HStack {
            Text("📅   Created")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text(formattedDate(item.creationDate))
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
        .onTapGesture {
            showDateCreatedSheet = true
        }
        .sheet(isPresented: $showDateCreatedSheet) {
            datePickerSheet(
                title: "Select Date Created",
                date: $item.creationDate,
                onDismiss: { showDateCreatedSheet = false }
            )
        }
    }
    
    // (4) Date Completed
    fileprivate var dateCompletedLine: some View {
        HStack {
            Text("📅   Completed")
                .font(.headline)
                .foregroundColor(item.completed ? .primary : .gray)
            Spacer()
            Text(item.completed ? formattedDate(item.dueDate) : "--")
                .foregroundColor(item.completed ? .accentColor : .gray)
        }
        .padding(.vertical, 4)
        .onTapGesture {
            if item.completed {
                showDateCompletedSheet = true
            }
        }
        .sheet(isPresented: $showDateCompletedSheet) {
            if item.completed {
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
            } else {
                EmptyView()
            }
        }
    }
    
    // (5) Location Row
    fileprivate var locationRow: some View {
        VStack(alignment: .leading, spacing: 4) {
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
            .padding(.vertical, 4)
        }
    }
    
    // (6) Notes (Description)
    fileprivate var descriptionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
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
            .frame(minHeight: 120)
            .focused($isNotesFocused)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Photo Grid Helpers
extension DetailItemView {
    
    private func photoGrid(uiImages: [UIImage]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(uiImages, id: \.self) { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
                    .clipped()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func photoGrid(urlStrings: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
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
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
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
        .padding(.vertical, 4)
    }
}

// MARK: - Private Helpers
extension DetailItemView {
    /// Upload newly picked images => Firebase => update item.imageUrls
    private func uploadPickedImages(_ images: [UIImage]) async {
        guard let userId = onboardingViewModel.user?.id else { return }
        guard item.completed else { return }
        
        isUploading = true
        
        let storageRef = Storage.storage().reference()
            .child("users/\(userId)/item-\(item.id.uuidString)")
        
        var newUrls: [String] = []
        
        for (index, uiImage) in images.enumerated() {
            guard let imageData = uiImage.jpegData(compressionQuality: 0.8) else { continue }
            let imageRef = storageRef.child("photo\(index + 1).jpg")
            
            do {
                try await imageRef.putDataAsync(imageData)
                let downloadUrl = try await imageRef.downloadURL()
                newUrls.append(downloadUrl.absoluteString)
            } catch {
                print("Error uploading image \(index): \(error.localizedDescription)")
            }
        }
        
        isUploading = false
        
        if item.completed && !newUrls.isEmpty {
            item.imageUrls.append(contentsOf: newUrls)
            updateItem()
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
                .onChange(of: date.wrappedValue) {
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
    
    /// Toggle completed => set or clear dueDate + haptic feedback
    private func toggleCompleted() async {
        item.completed.toggle()
        item.dueDate = item.completed ? Date() : nil
        
        // Simple haptic for success
        if item.completed {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
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














