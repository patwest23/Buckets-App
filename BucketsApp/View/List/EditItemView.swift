//
//  EditItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//


import SwiftUI
import UIKit

struct EditItemView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String
    @State private var description: String
    @State private var completed: Bool
    @State private var image: UIImage?

    let columns = [GridItem(.adaptive(minimum: 50))]
    var item: ItemModel
    var onSave: ((ItemModel) -> Void)

    init(item: ItemModel, onSave: @escaping (ItemModel) -> Void) {
        self.item = item
        self._name = State(initialValue: item.name)
        self._description = State(initialValue: item.description)
        self._completed = State(initialValue: item.completed)
        self.onSave = onSave
    }

    var body: some View {
        VStack {
            Form {
                Section(header: Text(item.name)) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    Toggle("Completed", isOn: $completed)
                    // Image picker form
                    HStack {
                        Spacer()
                        // Image
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipped()
                        } else {
                            Text("Tap the button to select an image.")
                        }
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        // Button to bring up photo picker
                        Button(action: {
                            selectImage()
                        }) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .imageScale(.large)
                        }
                        Spacer()
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
                        let updatedItem = ItemModel(id: item.id, image: image?.pngData(), name: name, description: description, completed: completed)
                        onSave(updatedItem)
                        presentationMode.wrappedValue.dismiss()
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

    private func selectImage() {
        let imagePicker = ImagePicker(sourceType: .photoLibrary) { image in
            self.image = image
        }
        presentationMode.wrappedValue.dismiss()
        UIApplication.shared.windows.first?.rootViewController?.present(imagePicker, animated: true, completion: nil)
    }
}





struct EditItemView_Previews: PreviewProvider {
    static let item = ItemModel(id: UUID(), image: Data(), name: "Example Item", description: "An example item description", completed: false)
    
    static var previews: some View {
        NavigationView {
            EditItemView(item: item) { updatedItem in
                // Do something with updatedItem
            }
        }
    }
}















