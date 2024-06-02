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

            Section(header: Text("Image")) {
                if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(10)
                } else {
                    Text("No Image Selected")
                        .foregroundColor(.gray)
                }
                PhotosPicker(selection: $imagePickerViewModel.imageSelection, matching: .images, photoLibrary: .shared()) {
                    Text("Select Photo")
                }
            }
        }
        .navigationTitle("Edit Item")
        .onChange(of: imagePickerViewModel.uiImage) { newImage in
            if let newImage = newImage {
                item.imageData = newImage.jpegData(compressionQuality: 1.0)
            }
        }
    }
}

struct DetailItemView_Previews: PreviewProvider {
    @State static var item = ItemModel(name: "Sample Item", description: "Sample Description")

    static var previews: some View {
        NavigationView {
            DetailItemView(item: $item)
        }
    }
}






