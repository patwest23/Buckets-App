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
    @Environment(\.presentationMode) var presentationMode // For dismissing the view
    @StateObject private var imagePickerViewModel = ImagePickerViewModel()
    @State private var isEditMode = false // To track if we are in "edit" mode for image deletion

    // Define a flexible grid layout
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        Form {
            // Item Details Section
            Section(header: Text("Item Details")) {
                TextField("Name", text: $item.name)
                TextField("Description", text: Binding(
                    get: { item.description ?? "" },
                    set: { item.description = $0 }
                ))
                Toggle("Completed", isOn: $item.completed)
            }

            // Photos Grid Section
            Section(header: Text("Photos")) {
                if !item.imagesData.isEmpty {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(item.imagesData.enumerated()), id: \.element) { index, imageData in
                            if let uiImage = UIImage(data: imageData) {
                                ZStack {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100) // Adjust size as needed
                                        .cornerRadius(10)
                                        .clipped()
                                        .onLongPressGesture {
                                            // Enable edit mode on long press
                                            withAnimation {
                                                isEditMode = true
                                            }
                                        }

                                    // Show subtract icon when in edit mode
                                    if isEditMode {
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Spacer()
                                                Button(action: {
                                                    deleteImage(at: index)
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .foregroundColor(.red)
                                                        .font(.title)
                                                        .background(Circle().fill(Color.white))
                                                }
                                                .offset(x: 10, y: -10) // Adjust the position
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("No Photos Selected")
                        .foregroundColor(.gray)
                }

                // Photos Picker to select new images
                PhotosPicker(selection: $imagePickerViewModel.imageSelections, maxSelectionCount: 3, matching: .images, photoLibrary: .shared()) {
                    Text("Select Photos")
                }
            }

            // Delete Button Section
            Section {
                Button(action: {
                    deleteItem()
                }) {
                    Text("Delete Item")
                        .foregroundColor(.red)
                }
            }
        }
        .onChange(of: imagePickerViewModel.uiImages) { newImages in
            for newImage in newImages {
                if let newImageData = newImage.jpegData(compressionQuality: 1.0) {
                    item.imagesData.append(newImageData)
                }
            }
        }
        .onAppear {
            imagePickerViewModel.loadExistingImages(from: item.imagesData)
        }
        .onTapGesture {
            // Exit edit mode when tapping outside
            withAnimation {
                isEditMode = false
            }
        }
    }

    // Function to delete an image at a given index
    private func deleteImage(at index: Int) {
        item.imagesData.remove(at: index)
    }

    // Function to delete the item and return to the previous view
    private func deleteItem() {
        if let index = viewModel.items.firstIndex(where: { $0.id == item.id }) {
            viewModel.items.remove(at: index)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct DetailItemView_Previews: PreviewProvider {
    @State static var item = ItemModel(name: "Sample Item", description: "Sample Description")
    
    static var previews: some View {
        NavigationView {
            DetailItemView(item: $item)
                .onAppear {
                    // Simulate three selected images by setting them directly in item.imagesData
                    if item.imagesData.isEmpty {
                        item.imagesData = [
                            UIImage(systemName: "photo")!.jpegData(compressionQuality: 1.0)!,
                            UIImage(systemName: "photo.fill")!.jpegData(compressionQuality: 1.0)!,
                            UIImage(systemName: "photo.on.rectangle.angled")!.jpegData(compressionQuality: 1.0)!
                        ]
                    }
                }
        }
    }
}










