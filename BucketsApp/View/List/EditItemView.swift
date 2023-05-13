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
    // @State private var imageData: Data
    @StateObject var imagePicker = ImagePicker()

    let columns = [GridItem(.adaptive(minimum: 50))]
    var item: ItemModel
    var onSave: ((ItemModel) -> Void)

    init(item: ItemModel, onSave: @escaping (ItemModel) -> Void) {
        self.item = item
        self._name = State(initialValue: item.name)
        self._description = State(initialValue: item.description)
        self._completed = State(initialValue: item.completed)
        // self._image = State(initialValue: item.image)
        self.onSave = onSave
    }

    var body: some View {
        VStack {
            Form {
                Section(header: Text(item.name)) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    Toggle("Completed", isOn: $completed)
                    //image picker form
                        HStack {
                            Spacer()
                            //image
                            if !imagePicker.images.isEmpty {
                                ScrollView {
                                    LazyVGrid(columns: columns, spacing: 10) {
                                        ForEach(0..<imagePicker.images.count, id: \.self) { index in
                                            imagePicker.images[index]
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 50, height: 50)
                                                .clipped()
                                        }
                                    }
                                }
                            } else {
                                Text("Tap the button to select multiple photos.")
                            }
                            
                            Spacer()
                        }
                        
                        HStack {
                            Spacer()
                            //button to bring up photo picker
                            PhotosPicker(selection: $imagePicker.imageSelections,
                                         maxSelectionCount: 10,
                                         matching: .images,
                                         photoLibrary: .shared()) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .imageScale(.large)
                            }
                            Spacer()
                        }
                }
            }
            .navigationBarTitle("Edit Item")
 
            
            
            
            
            // save and cancel buttons
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
                        let updatedItem = ItemModel(id: item.id, name: name, description: description, completed: completed)
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
}


struct EditItemView_Previews: PreviewProvider {
    static let item = ItemModel(id: UUID(), name: "Example Item", description: "An example item description", completed: false)
    
    static var previews: some View {
        NavigationView {
            EditItemView(item: item) { updatedItem in
                // Do something with updatedItem
            }
        }
    }
}















