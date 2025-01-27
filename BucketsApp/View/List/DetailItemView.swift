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
    @StateObject private var imagePickerVM = ImagePickerViewModel() // The new view model
    @State private var showDateCreatedSheet = false
    @State private var showDateCompletedSheet = false
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // (1) Basic Info Row (toggle + name + image carousel)
                    basicInfoRow
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    
                    // (2) Photos Picker Row
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
        // Whenever `imagePickerVM.uiImages` changes, upload them and update item.imageUrls
        .onChange(of: imagePickerVM.uiImages) { newImages in
            Task {
                await uploadPickedImages(newImages)
            }
        }
    }
}

// MARK: - Subviews
extension DetailItemView {
    
    /// Basic info row with toggle & name. Also shows a TabView if item.imageUrls is not empty.
    private var basicInfoRow: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                
                // Editable Text Field
                TextField(
                    "📝 What do you want to do before you die?",
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
            
            // If item already has imageUrls, show them in a TabView (carousel)
            if !item.imageUrls.isEmpty {
                TabView {
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
                                        .frame(maxWidth: .infinity, maxHeight: 300)
                                        .cornerRadius(20)
                                        .clipped()
                                case .failure:
                                    placeholderImage()
                                @unknown default:
                                    placeholderImage()
                                }
                            }
                        } else {
                            placeholderImage()
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 300)
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 10)
    }
    
    /// Photos Picker Row
    private var photoPickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotosPicker(
                selection: $imagePickerVM.imageSelections,
                maxSelectionCount: 3,
                matching: .images
            ) {
                Text("📸   Select Photos")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .font(.headline)
            }
        }
    }
    
    /// Date Created Row
    private var dateCreatedLine: some View {
        HStack {
            Text("📅   Date Created")
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
            Text("📅   Date Completed")
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
    
    /// Upload the newly picked images from `imagePickerVM.uiImages` to Storage,
    /// then update item.imageUrls with the new download URLs.
    private func uploadPickedImages(_ images: [UIImage]) async {
        guard let userId = onboardingViewModel.user?.id else { return }
        
        let storageRef = Storage.storage().reference().child("users/\(userId)/item-\(item.id.uuidString)")
        var newUrls: [String] = []
        
        for (index, uiImage) in images.enumerated() {
            guard let imageData = uiImage.jpegData(compressionQuality: 0.8) else { continue }
            let fileName = "photo\(index + 1).jpg"
            let imageRef = storageRef.child(fileName)
            do {
                // Upload
                try await imageRef.putDataAsync(imageData)
                // Get URL
                let downloadUrl = try await imageRef.downloadURL()
                newUrls.append(downloadUrl.absoluteString)
            } catch {
                print("Error uploading image: \(error.localizedDescription)")
            }
        }
        
        // If we got new URLs, append them and update the item
        if !newUrls.isEmpty {
            item.imageUrls.append(contentsOf: newUrls)
            updateItem() // Save the item with updated imageUrls
        }
    }
    
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
    
    /// Save item to Firestore (or local model)
    private func updateItem() {
        Task {
            bucketListViewModel.addOrUpdateItem(item)
        }
    }
    
    /// Toggle 'completed' state and update item
    private func toggleCompleted() async {
        item.completed.toggle()
        bucketListViewModel.addOrUpdateItem(item)
    }
    
    /// A fallback image placeholder.
    private func placeholderImage() -> some View {
        ZStack {
            Color.white
                .frame(width: 100, height: 100)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
    }
    
    /// Convert a Date? to string or show "--".
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














