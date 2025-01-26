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

    // MARK: - Environment Objects
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
        

    // MARK: - Presentation
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Local States
    @State private var selectedPhotos: [PhotosPickerItem] = []

    // For date pickers (single-line display -> sheet)
    @State private var showDateCreatedSheet = false
    @State private var showDateCompletedSheet = false

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - First Row (ItemRowView style)
                    firstRowView
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)

                    // MARK: - Description Row
                    descriptionRow

                    // MARK: - Date Created
                    dateCreatedLine

                    // MARK: - Date Completed (dueDate)
                    dateCompletedLine

                    // MARK: - Location Row
                    locationRow

                    // MARK: - Select Photos Row
                    selectPhotosRow

                    // MARK: - Photo Grid
                    if !item.imageUrls.isEmpty {
                        photoGridView
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - First Row (Toggle + Editable Text Field + Images)
    private var firstRowView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Completion toggle
                Button(action: {
                    Task {
                        await toggleCompleted()
                    }
                }) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .font(.title2)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())

                // Editable Text Field for Item Name
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
                .onChange(of: item.name) { _ in
                    updateItem()
                }
            }

            // Optional TabView for Images (if available)
            if !item.imageUrls.isEmpty {
                TabView {
                    ForEach(item.imageUrls, id: \.self) { imageUrl in
                        AsyncImage(url: URL(string: imageUrl)) { phase in
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
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 300)
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Description Row
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
            .onChange(of: item.description) { _ in
                updateItem()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }

    // MARK: - Date Created Line
    private var dateCreatedLine: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📅   Date Created")
                    .font(.headline)
                Spacer()
                Text(formattedDate(item.creationDate))
                    .foregroundColor(.accentColor)
            }
            .onTapGesture {
                showDateCreatedSheet = true
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
        .sheet(isPresented: $showDateCreatedSheet) {
            VStack(spacing: 20) {
                Text("Select Date Created")
                    .font(.title3)
                    .padding(.top)

                DatePicker("", selection: $item.creationDate, displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .onChange(of: item.creationDate) { _ in
                        updateItem()
                    }

                Button("Done") {
                    showDateCreatedSheet = false
                }
                .font(.headline)
                .padding(.bottom, 20)
            }
            .presentationDetents([.height(350)]) // iOS16+ (optional)
        }
    }

    // MARK: - Date Completed (dueDate)
    private var dateCompletedLine: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📅   Date Completed")
                    .font(.headline)
                Spacer()
                Text(formattedDate(item.dueDate))
                    .foregroundColor(.accentColor)
            }
            .onTapGesture {
                showDateCompletedSheet = true
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
        .sheet(isPresented: $showDateCompletedSheet) {
            VStack(spacing: 20) {
                Text("Select Date Completed")
                    .font(.title3)
                    .padding(.top)

                DatePicker("", selection: Binding(
                    get: { item.dueDate ?? Date() },
                    set: { newValue in
                        item.dueDate = newValue
                        updateItem()
                    }
                ), displayedComponents: .date)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()

                Button("Done") {
                    showDateCompletedSheet = false
                }
                .font(.headline)
                .padding(.bottom, 20)
            }
            .presentationDetents([.height(350)]) // iOS16+ (optional)
        }
    }

    // MARK: - Location Row
    private var locationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📍")

                TextField(
                    "Enter location...",
                    text: Binding(
                        get: { item.location?.address ?? "" },
                        set: { newValue in
                            var updatedLocation = item.location ?? Location(
                                latitude: 0,
                                longitude: 0,
                                address: newValue
                            )
                            updatedLocation.address = newValue
                            item.location = updatedLocation
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

    // MARK: - Photos Picker Row
    private var selectPhotosRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 3, matching: .images) {
                Text("📸   Select Photos")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .font(.headline)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .onChange(of: selectedPhotos) { selections in
                handlePhotoSelection(selections)
            }
        }
    }

    // MARK: - Photo Grid
    private var photoGridView: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 10
        ) {
            ForEach(item.imageUrls, id: \.self) { urlString in
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .cornerRadius(10)
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
        .padding(.horizontal)
    }

    // MARK: - Formatting
    private func formattedDate(_ date: Date?) -> String {
        // If dueDate is nil, show something like "--"
        guard let date = date else { return "--" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Firestore / Item Updating
    private func updateItem() {
        Task {
            // Optional: guard user != nil if you want to be sure the user is logged in
            guard onboardingViewModel.user != nil else {
                print("Error: OnboardingViewModel user is nil.")
                return
            }
            
            // Now that your method no longer needs userId, just pass `item`
            bucketListViewModel.addOrUpdateItem(item)
        }
    }

    private func toggleCompleted() async {
        // Optional: guard user != nil to confirm authentication
        guard onboardingViewModel.user != nil else {
            print("Error: OnboardingViewModel user is missing")
            return
        }
        item.completed.toggle()
        bucketListViewModel.addOrUpdateItem(item)
    }

    // MARK: - Photos Upload
    private func handlePhotoSelection(_ selections: [PhotosPickerItem]) {
        Task {
            guard let userId = onboardingViewModel.user?.id else { return }
            let storageRef = Storage.storage().reference().child("users/\(userId)/images")

            var newUrls: [String] = []
            for (index, selection) in selections.prefix(3).enumerated() {
                do {
                    if let data = try? await selection.loadTransferable(type: Data.self) {
                        let imageRef = storageRef.child("detail-\(item.id.uuidString)-\(index + 1).jpg")
                        _ = try await imageRef.putDataAsync(data)
                        let downloadUrl = try await imageRef.downloadURL()
                        newUrls.append(downloadUrl.absoluteString)
                    }
                } catch {
                    print("Error uploading selected photo: \(error.localizedDescription)")
                }
            }

            if !newUrls.isEmpty {
                item.imageUrls.append(contentsOf: newUrls)
                updateItem()
            }
        }
    }

    // MARK: - UI Helpers
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
}

#if DEBUG
struct DetailItemView_Previews: PreviewProvider {
    static var previews: some View {
        // 1) Create mock environment objects
        let mockOnboardingVM = OnboardingViewModel()
        let mockListVM = ListViewModel()

        // 2) Create a sample ItemModel with both creationDate and dueDate
        let sampleItem = ItemModel(
            userId: "previewUser",
            name: "Sample Bucket List Item",
            description: "Short description for preview...",
            dueDate: Date().addingTimeInterval(86400 * 3), // 3 days in the future
            location: Location(latitude: 37.7749, longitude: -122.4194, address: "San Francisco"),
            completed: true,
            creationDate: Date().addingTimeInterval(-86400), // 1 day ago
            imageUrls: []
        )

        // 3) Provide a binding to `sampleItem`
        return DetailItemView(item: .constant(sampleItem))
            .environmentObject(mockOnboardingVM)
            .environmentObject(mockListVM)
            .previewDisplayName("DetailItemViewWorking Preview")
    }
}
#endif














