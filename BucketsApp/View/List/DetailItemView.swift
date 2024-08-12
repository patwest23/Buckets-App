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
    @StateObject private var imagePickerViewModel = ImagePickerViewModel()

    var body: some View {
        Form {
            Section(header: Text("Item Details")) {
                TextField("Name", text: $item.name)
                TextField("Description", text: Binding(
                    get: { item.description ?? "" },
                    set: { item.description = $0 }
                ))
                Toggle("Completed", isOn: $item.completed)
            }

            Section(header: Text("Photos")) {
                if !item.imagesData.isEmpty {
                    TabView {
                        ForEach(item.imagesData, id: \.self) { imageData in
                            if let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .cornerRadius(10)
                                    .padding()
                                    .frame(height: 200)
                                    .clipped()
                            }
                        }
                    }
                    .tabViewStyle(PageTabViewStyle())
                    .frame(height: 200)
                } else {
                    Text("No Photos Selected")
                        .foregroundColor(.gray)
                }
                
                PhotosPicker(selection: $imagePickerViewModel.imageSelections, maxSelectionCount: 3, matching: .images, photoLibrary: .shared()) {
                    Text("Select Photos")
                }
            }
        }
        .navigationTitle("Edit Item")
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
    }
}

struct DetailItemView_Previews: PreviewProvider {
    @State static var item = ItemModel(name: "Sample Item", description: "Sample Description")
    
    static var previews: some View {
        NavigationView {
            DetailItemView(item: $item)
                .onAppear {
                    // Simulate three selected images by setting them directly in item.imagesData
                    item.imagesData = [
                        UIImage(systemName: "photo")!.jpegData(compressionQuality: 1.0)!,
                        UIImage(systemName: "photo.fill")!.jpegData(compressionQuality: 1.0)!,
                        UIImage(systemName: "photo.on.rectangle.angled")!.jpegData(compressionQuality: 1.0)!
                    ]
                }
        }
    }
}










