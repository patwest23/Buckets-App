//
//  DetailItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/1/24.
//

import SwiftUI
import PhotosUI

struct DetailItemView: View {
    @Binding var item: ItemModel
    @EnvironmentObject var viewModel: ListViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showDeleteConfirmation = false

    // Define a flexible grid layout for photos
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Item Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        // TextField for Item Name
                        TextField("What do you want to do before you die?", text: $item.name)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .onChange(of: item.name) { _ in saveItem() }

                        // TextEditor with "Notes" Placeholder
                        ZStack(alignment: .topLeading) {
                            if item.description?.isEmpty ?? true {
                                Text("Notes")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                            }
                            TextEditor(text: Binding(
                                get: { item.description ?? "" },
                                set: { item.description = $0 }
                            ))
                            .frame(minHeight: 150) // Adjust height for the description box
                            .padding(4)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .onChange(of: item.description) { _ in saveItem() }
                        }

                        // Toggle for Completed
                        Toggle("Completed", isOn: $item.completed)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .onChange(of: item.completed) { _ in saveItem() }
                    }
                    .padding(.horizontal)

                    // Photos Grid Section
                    if !item.imagesData.isEmpty {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Array(item.imagesData.enumerated()), id: \.offset) { _, imageData in
                                if let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(10)
                                        .clipped()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Photos Picker Button
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 3, matching: .images, photoLibrary: .shared()) {
                        Text("Select Photos")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }
                    .padding(.horizontal)
                    .onChange(of: selectedPhotos) { newSelections in
                        handlePhotoSelection(newSelections)
                    }
                }
                .padding(.top)
            }

            // Delete Button at the Bottom
            Button(action: {
                showDeleteConfirmation = true
            }) {
                Text("Delete")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
            .padding()
        }
        .background(Color.white.edgesIgnoringSafeArea(.all)) // Set full background to white
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Are you sure you want to delete this item?"),
                primaryButton: .destructive(Text("Yes"), action: {
                    deleteItem()
                }),
                secondaryButton: .cancel(Text("No"))
            )
        }
    }

    private func handlePhotoSelection(_ newSelections: [PhotosPickerItem]) {
        Task {
            var newImagesData: [Data] = []

            for item in newSelections {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    newImagesData.append(data)
                }
            }

            if !newImagesData.isEmpty {
                // Replace the current set of photos with the newly selected ones
                item.imagesData = newImagesData
                saveItem()
            }
        }
    }

    // Function to delete the item and return to the previous view
    private func deleteItem() {
        if let index = viewModel.items.firstIndex(where: { $0.id == item.id }) {
            viewModel.items.remove(at: index)
            viewModel.saveItems()
            presentationMode.wrappedValue.dismiss()
        }
    }

    // Function to save changes
    private func saveItem() {
        viewModel.saveItems()
    }
}

struct DetailItemView_Previews: PreviewProvider {
    static var previews: some View {
        let mockItem = ItemModel(
            name: "Mock Item Name",
            description: "Mock Item Description",
            imagesData: [
                UIImage(named: "MockImage1")!.jpegData(compressionQuality: 1.0)!,
                UIImage(named: "MockImage2")!.jpegData(compressionQuality: 1.0)!,
                UIImage(named: "MockImage3")!.jpegData(compressionQuality: 1.0)!
            ]
        )

        return NavigationView {
            DetailItemView(item: .constant(mockItem))
                .padding()
                .background(Color.white.edgesIgnoringSafeArea(.all))
        }
        .previewDisplayName("Detail Item View Preview with Mock Data")
    }
}










