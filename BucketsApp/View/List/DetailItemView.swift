//
//  DetailItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/1/24.
//

import SwiftUI
import PhotosUI

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
                    // TextField for Item Name
                    TextField("What do you want to do before you die?", text: $item.name)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: item.name) { _ in
                            updateItem()
                        }

                    // Notes TextEditor
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
                        .onChange(of: item.description) { _ in
                            updateItem()
                        }
                    }

                    // Completed Toggle
                    Toggle("Completed", isOn: $item.completed)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: item.completed) { _ in
                            updateItem()
                        }

                    // Photos Grid
                    if !item.imagesData.isEmpty {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            ForEach(Array(item.imagesData.enumerated()), id: \.offset) { _, imageData in
                                if let image = UIImage(data: imageData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(10)
                                        .clipped()
                                } else {
                                    placeholderImage()
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        placeholderView()
                    }

                    // Photos Picker
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

            // Delete Button
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

    /// Updates the item in Firestore via ListViewModel
    private func updateItem() {
        Task {
            if let userId = onboardingViewModel.user?.id {
                await listViewModel.addOrUpdateItem(item, userId: userId)
            }
        }
    }

    /// Deletes the item from Firestore via ListViewModel, then dismisses the view
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

    /// Handles photo selection, updates `item.imagesData`, and syncs changes
    private func handlePhotoSelection(_ selections: [PhotosPickerItem]) {
        Task {
            var newImages: [Data] = []
            for selection in selections {
                if let data = try? await selection.loadTransferable(type: Data.self) {
                    newImages.append(data)
                }
            }
            if !newImages.isEmpty {
                item.imagesData = Array(newImages.prefix(3)) // Keep up to 3
                updateItem()
            }
        }
    }

    /// A placeholder image for empty photo slots
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

    /// A placeholder view for no photos
    private func placeholderView() -> some View {
        VStack {
            HStack {
                ForEach(0..<3, id: \.self) { index in
                    if index < item.imagesData.count,
                       let image = UIImage(data: item.imagesData[index]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .cornerRadius(10)
                            .clipped()
                    } else {
                        placeholderImage()
                    }
                }
            }
            Text(item.imagesData.isEmpty ? "No Photos Added" : "Max 3 Photos")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }
}











