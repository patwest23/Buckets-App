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
                        TextField("What do you want to do before you die?", text: $item.name)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .onChange(of: item.name) { _ in saveItem() }

                        TextEditor(text: Binding(
                            get: { item.description ?? "" },
                            set: { item.description = $0 }
                        ))
                        .frame(minHeight: 150) // Adjust height for the description box
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: item.description) { _ in saveItem() }

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
                            ForEach(Array(item.imagesData.enumerated()), id: \.element) { _, imageData in
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
                    Button(action: {
                        // Trigger the photo picker
                    }) {
                        Text("Select Photos")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }
                    .padding(.horizontal)
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
        .onChange(of: imagePickerViewModel.uiImages) { newImages in
            if !newImages.isEmpty {
                item.imagesData = newImages.compactMap { $0.jpegData(compressionQuality: 1.0) }
                saveItem()
            }
        }
        .onAppear {
            imagePickerViewModel.loadExistingImages(from: item.imagesData)
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
        NavigationView {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Mock Item Details Section
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("What do you want to do before you die?", text: .constant("Mock Item Name"))
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 2)
                            
                            TextEditor(text: .constant("Mock Item Description"))
                                .frame(minHeight: 150) // Set a larger height for notes
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 2)
                            
                            Toggle("Completed", isOn: .constant(false))
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 2)
                        }
                        .padding(.horizontal)
                        
                        // Mock Photos Picker Button
                        Button(action: {}) {
                            Text("Select Photos")
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 2)
                        }
                        .padding(.horizontal)
                        
                        // Mock Photos Grid Section
                        VStack(alignment: .leading, spacing: 10) {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 10) {
                                ForEach(["MockImage1", "MockImage2", "MockImage3"], id: \.self) { imageName in
                                    Image(imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(10)
                                        .clipped()
                                }
                            }
                            .padding(.horizontal)
                            
                            // Spacer to push delete button to the bottom
                            Spacer()
                        }
                        .padding(.top)
                    }
                    // Mock Delete Button
                    Button(action: {}) {
                        Text("Delete")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                    .padding(.horizontal)
                    .padding(.bottom) // Additional padding for safe area
                }
                .background(Color.white.edgesIgnoringSafeArea(.all))
            }
            .previewDisplayName("Detail Item View Preview with Mock Images")
        }
    }
}










