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
    @StateObject var imagePicker = ImagePicker() // Initialize directly here
    
    let item: ItemModel
    let onSave: (ItemModel, Data?) -> Void

    init(item: ItemModel, onSave: @escaping (ItemModel, Data?) -> Void) {
        self.item = item
        _name = State(initialValue: item.name)
        _description = State(initialValue: item.description)
        _completed = State(initialValue: item.completed)
        _imageData = State(initialValue: item.imageData)
        self.onSave = onSave
        // Removed the imagePicker initialization from here
    }

    var body: some View {
        Form {
            Section() {
                TextField("what do you wan to do before you die", text: $name)
                TextField("notes", text: $description)
                Toggle("completed", isOn: $completed)

                VStack(alignment: .leading) {
                    PhotosPicker(selection: $imagePicker.imageSelection,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        Text("select photo")
                    }

                    HStack {
                        Spacer()
                        // Display the current or selected image if it exists
                        if let uiImage = imagePicker.uiImage ?? (item.imageData.flatMap(UIImage.init)) {
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
            let updatedImageData = imagePicker.uiImage?.jpegData(compressionQuality: 1.0) ?? item.imageData
            var updatedItem = item
            updatedItem.name = name
            updatedItem.description = description
            updatedItem.completed = completed
            updatedItem.imageData = updatedImageData

            onSave(updatedItem, updatedImageData)
        }
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












