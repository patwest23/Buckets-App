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
    @StateObject private var imagePickerViewModel = ImagePickerViewModel()
    @State private var isEditMode = false
    @State private var showDeleteConfirmation = false

    // Define a flexible grid layout that fits exactly three photos per row
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

                        TextField("What do you want to do before you die?", text: $item.name)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 2)

                        TextField("Notes", text: Binding(
                            get: { item.description ?? "" },
                            set: { item.description = $0 }
                        ))
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)

                        Toggle("Completed", isOn: $item.completed)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }
                    .padding(.horizontal)

                    // Photos Grid Section
                    if !item.imagesData.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photos")
                                .font(.headline)
                                .foregroundColor(.black)

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(Array(item.imagesData.enumerated()), id: \.element) { index, imageData in
                                    if let uiImage = UIImage(data: imageData) {
                                        ZStack {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .cornerRadius(10)
                                                .clipped()
                                                .onLongPressGesture {
                                                    withAnimation {
                                                        isEditMode = true
                                                    }
                                                }

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
                                                        .offset(x: 10, y: -10)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Photos Picker Section
                    PhotosPicker(selection: $imagePickerViewModel.imageSelections, maxSelectionCount: 3, matching: .images, photoLibrary: .shared()) {
                        Text("Select Photos")
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }
                    .padding(.horizontal)

                    // Spacer to push buttons to the bottom
                    Spacer()

                    // Save and Delete Buttons
                    HStack {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Text("Delete Item")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }

                        Spacer()

                        Button(action: {
                            saveItem()
                        }) {
                            Text("Save")
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                    }
                    .padding([.horizontal, .bottom])
                }
                .padding(.top)
            }
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
            viewModel.saveItems()
            presentationMode.wrappedValue.dismiss()
        }
    }

    // Function to save changes and return to ListView
    private func saveItem() {
        viewModel.saveItems()
        presentationMode.wrappedValue.dismiss()
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










