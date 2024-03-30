//
//  EditItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//


//import SwiftUI
//
//struct EditItemView: View {
//    @Environment(\.presentationMode) var presentationMode
//    @State private var name: String
//    @State private var description: String
//    @State private var completed: Bool
//    @State private var image: Image?
//    @State private var showingImagePicker = false
//
//    let item: ItemModel
//    let onSave: (ItemModel, Data?) -> Void
//
//    init(item: ItemModel, onSave: @escaping (ItemModel, Data?) -> Void) {
//        self.item = item
//        _name = State(initialValue: item.name)
//        _description = State(initialValue: item.description ?? "")
//        _completed = State(initialValue: item.completed)
//        _image = State(initialValue: item.imageData.map { Image(uiImage: UIImage(data: $0)!) })
//        self.onSave = onSave
//    }
//
//    var body: some View {
//        Form {
//            Section() {
//                TextField("What do you want to do before you die", text: $name)
//                TextField("Notes", text: $description)
//                Toggle("Completed", isOn: $completed)
//
//                Button(action: {
//                    showingImagePicker = true
//                }) {
//                    Text("Select Image")
//                }
//
//                if let image = image {
//                    image
//                        .resizable()
//                        .scaledToFit()
//                        .frame(maxHeight: 200)
//                }
//            }
//        }
//        .sheet(isPresented: $showingImagePicker, onDismiss: loadImage) {
//            ImagePicker(image: $image)
//        }
//        .onDisappear {
//            let updatedImageData = image?.uiImage?.jpegData(compressionQuality: 1.0)
//            var updatedItem = item
//            updatedItem.name = name
//            updatedItem.description = description
//            updatedItem.completed = completed
//
//            onSave(updatedItem, updatedImageData)
//        }
//    }
//
//    private func loadImage() {
//        guard let selectedImage = image else { return }
//        image = selectedImage
//    }
//}
//
//
//struct EditItemView_Previews: PreviewProvider {
//    static var previews: some View {
//        // Create an instance of ItemModel for the preview
//        let previewItem = ItemModel(name: "Example Item", description: "An example item description", completed: false)
//        // Set imageData to nil or provide sample data
//        let imageData: Data? = nil
//
//        return NavigationView {
//            EditItemView(item: previewItem) { updatedItem, _ in
//                // Preview action for saving the item
//            }
//        }
//    }
//}













