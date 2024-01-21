//
//  EditItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//


import SwiftUI
import PhotosUI

struct EditItemView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String
    @State private var description: String
    @State private var completed: Bool
    @State private var imageData: Data?
    @StateObject var imagePicker = ImagePicker()
    
    let item: ItemModel
    let onSave: (ItemModel, Data?) -> Void

    init(item: ItemModel, onSave: @escaping (ItemModel, Data?) -> Void) {
        self.item = item
        _name = State(initialValue: item.name)
        _description = State(initialValue: item.description)
        _completed = State(initialValue: item.completed)
        _imageData = State(initialValue: item.imageData)
        self.onSave = onSave
        
        _imagePicker = StateObject(wrappedValue: ImagePicker())
        if let imageData = item.imageData, let image = UIImage(data: imageData) {
            _imagePicker.wrappedValue.uiImage = image
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Edit Item")) {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
                Toggle("Completed", isOn: $completed)

                VStack(alignment: .leading) {
                    PhotosPicker(selection: $imagePicker.imageSelection,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        Text("Select Photo")
                    }

                    HStack {
                        Spacer()
                        if let uiImage = imagePicker.uiImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(10)
                        }
                        Spacer()
                    }
                }
            }
        }
        .onDisappear {
            // Convert the selected image to Data
            let updatedImageData = imagePicker.uiImage?.jpegData(compressionQuality: 1.0)

            // Create a new instance of ItemModel
            var updatedItem = ItemModel(id: item.id, name: name, description: description, completed: completed)
            updatedItem.imageData = updatedImageData ?? imageData  // Update imageData separately

            onSave(updatedItem, updatedImageData)
        }
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
    }
}


struct EditItemView_Previews: PreviewProvider {
    static var previews: some View {
        // Create an instance of ItemModel for the preview
        var previewItem = ItemModel(id: UUID(), name: "Example Item", description: "An example item description", completed: false)
        // Set imageData to nil or provide sample data
        previewItem.imageData = nil

        return NavigationView {
            EditItemView(item: previewItem) { updatedItem, _ in
                // Preview action for saving the item
            }
        }
    }
}












