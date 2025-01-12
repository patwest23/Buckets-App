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
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // MARK: - Presentation
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Local State
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: - Name Field
                    TextField("What do you want to do before you die?", text: $item.name)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: item.name) { _ in updateItem() }

                    // MARK: - Description
                    ZStack(alignment: .topLeading) {
                        if (item.description?.isEmpty ?? true) {
                            Text("Notes")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                        }
                        TextEditor(
                            text: Binding(
                                get: { item.description ?? "" },
                                set: { item.description = $0 }
                            )
                        )
                        .frame(minHeight: 150)
                        .padding(4)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: item.description) { _ in updateItem() }
                    }

                    // MARK: - Completed Toggle
                    Toggle("Completed", isOn: $item.completed)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: item.completed) { _ in updateItem() }

                    // MARK: - Photo Grid (Using imageUrls)
                    if item.imageUrls.isEmpty {
                        placeholderView()
                    } else {
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

                    // MARK: - Photos Picker
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 3, matching: .images) {
                        Text("Select Photos")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .onChange(of: selectedPhotos) { selections in
                        handlePhotoSelection(selections)
                    }
                }
                .padding()
            }

            Spacer()

            // MARK: - Delete Button
            Button(action: {
                showDeleteConfirmation = true
            }) {
                Text("Delete")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Item"),
                    message: Text("Are you sure you want to delete this item?"),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteItem()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .background(Color.white)
    }

    // MARK: - Helper Functions

    /// Updates the item in Firestore (via ListViewModel)
    private func updateItem() {
        Task {
            if let userId = onboardingViewModel.user?.id {
                await listViewModel.addOrUpdateItem(item, userId: userId)
            }
        }
    }

    /// Deletes the item from Firestore (via ListViewModel) and dismisses the view
    private func deleteItem() {
        Task {
            if let userId = onboardingViewModel.user?.id {
                await listViewModel.deleteItem(item, userId: userId)
                DispatchQueue.main.async {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    /// Uploads selected photos to a single user-level folder (`users/<userId>/images`),
    /// then appends their URLs to `item.imageUrls`.
    private func handlePhotoSelection(_ selections: [PhotosPickerItem]) {
        Task {
            guard let userId = onboardingViewModel.user?.id else { return }
            let storageRef = Storage.storage()
                .reference()
                .child("users/\(userId)/images")

            var newUrls: [String] = []
            for (index, selection) in selections.prefix(3).enumerated() {
                do {
                    if let data = try? await selection.loadTransferable(type: Data.self) {
                        // Upload the image data
                        let imageRef = storageRef.child("detail-\(item.id.uuidString)-\(index + 1).jpg")
                        _ = try await imageRef.putDataAsync(data)
                        
                        let downloadUrl = try await imageRef.downloadURL()
                        newUrls.append(downloadUrl.absoluteString)
                    }
                } catch {
                    print("Error uploading selected photo: \(error.localizedDescription)")
                }
            }

            // Append to existing imageUrls, then update Firestore
            if !newUrls.isEmpty {
                item.imageUrls.append(contentsOf: newUrls)
                updateItem()
            }
        }
    }

    /// A placeholder image for missing or invalid URLs
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

    /// A placeholder view when `imageUrls` is empty
    private func placeholderView() -> some View {
        VStack {
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)

            Text("No Photos Added")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }
}











