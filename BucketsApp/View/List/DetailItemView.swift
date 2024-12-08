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
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
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
                        .onChange(of: item.name) { _ in updateItem() }
                    
                    // Notes TextEditor
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
                        .frame(minHeight: 150)
                        .padding(4)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: item.description) { _ in updateItem() }
                    }
                    
                    // Completed Toggle
                    Toggle("Completed", isOn: $item.completed)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: item.completed) { _ in updateItem() }
                    
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
                                    // Fallback for invalid image data
                                    placeholderImage()
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Placeholder for no photos
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
        }
        .background(Color.white)
    }
    
    // MARK: Helper Functions
    
    private func updateItem() {
        viewModel.updateItem(item)
    }
    
    private func handlePhotoSelection(_ selections: [PhotosPickerItem]) {
        Task {
            var newImages: [Data] = []
            for selection in selections {
                if let data = try? await selection.loadTransferable(type: Data.self) {
                    newImages.append(data)
                }
            }
            if !newImages.isEmpty {
                // Keep only the last selection of images (up to 3)
                item.imagesData = Array(newImages.prefix(3))
                updateItem()
            }
        }
    }
    
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
    
    private func placeholderView() -> some View {
        VStack {
            HStack {
                ForEach(0..<3, id: \.self) { index in
                    if index < item.imagesData.count, let image = UIImage(data: item.imagesData[index]) {
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










