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
        self._name = State(initialValue: item.name)
        self._description = State(initialValue: item.description)
        self._completed = State(initialValue: item.completed)
        self.onSave = onSave
        self._imageData = State(initialValue: item.imageData)
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text(item.name)) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    Toggle("Completed", isOn: $completed)
                    
                    
                    // Image picker form and image if there is one
                    VStack(alignment: .leading) {
                        PhotosPicker(selection: $imagePicker.imageSelection,
                                     matching: .images,
                                     photoLibrary: .shared()) {
                            Text("Select Photo")
                        }
                        
                        HStack {
                            Spacer()
                            if let uiImage = imagePicker.uiImage {
                                // Display the selected image
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(10)
                            } else {
                                Spacer()
                                
                                // Placeholder image or icon
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 300, height: 300, alignment: .center)
                                
                                Spacer()
                            }
                        }
                    }
                    
                }
            }
            .navigationBarTitle("Edit Item")
            
            // Save and cancel buttons
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(Color.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red, lineWidth: 1)
                        )
                        .padding(.horizontal)
                }
                Button(action: {
                    if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        if let uiImage = imagePicker.uiImage {
                            if let imageData = uiImage.jpegData(compressionQuality: 1.0) {
                                let updatedItem = ItemModel(id: item.id, name: name, description: description, completed: completed)
                                onSave(updatedItem, imageData)
                                presentationMode.wrappedValue.dismiss()
                            }
                        } else {
                            let updatedItem = ItemModel(id: item.id, name: name, description: description, completed: completed)
                            onSave(updatedItem, nil)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }) {
                    Text("Save")
                        .foregroundColor(Color("AccentColor"))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color("AccentColor"), lineWidth: 1)
                        )
                        .padding(.horizontal)
                }
            }
        }
    }
}



struct EditItemView_Previews: PreviewProvider {
    static let item = ItemModel(id: UUID(), name: "Example Item", description: "An example item description", completed: false)
    
    static var previews: some View {
        NavigationView {
            EditItemView(item: item) { updatedItem, _ in
                // Do something with updatedItem
            }
        }
    }
}















