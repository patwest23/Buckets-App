//
//  AddItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI

struct AddItemView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var newItem = ItemModel(id: UUID(), name: "", description: "", completed: false)

    let onSave: (ItemModel, Data?) -> Void

    var body: some View {
        VStack {
            Form {
                Section(header: Text("What do you want to do before you die?")){
                    TextField("Name", text: $newItem.name)
                    TextField("Description", text: $newItem.description)
                    Toggle("Completed", isOn: $newItem.completed)
                }
                
            }
            
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
                    onSave(newItem, nil)
                    presentationMode.wrappedValue.dismiss()
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


struct AddItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddItemView { item, imageData in
            // Handle saving the item and imageData
        }
    }
}


