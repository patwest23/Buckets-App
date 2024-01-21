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
        Form {
            Section(header: Text("What do you want to do before you die?")){
                TextField("Name", text: $newItem.name)
                TextField("Description", text: $newItem.description)
                Toggle("Completed", isOn: $newItem.completed)
            }
        }
        .onDisappear {
            // When the view disappears, save the data
            onSave(newItem, nil)
        }
        .navigationTitle("Add Item")
        .navigationBarTitleDisplayMode(.inline)
    }
}



struct AddItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddItemView { item, imageData in
            // Handle saving the item and imageData
        }
    }
}


