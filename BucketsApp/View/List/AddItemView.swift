//
//  AddItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

//import SwiftUI
//
//struct AddItemView: View {
//    @Environment(\.presentationMode) var presentationMode
//    @State private var newItem = ItemModel(name: "", description: "", completed: false)
//
//    let onSave: (ItemModel) -> Void
//
//    var body: some View {
//        Form {
//            Section(){
//                TextField("What do you want to do before you die?", text: $newItem.name)
//                TextField("Notes", text: $newItem.description)
//                Toggle("Completed", isOn: $newItem.completed)
//                // Location
//            }
//        }
//        .onDisappear {
//            // When the view disappears, save the data
//            onSave(newItem)
//        }
//    }
//}
//
//struct AddItemView_Previews: PreviewProvider {
//    static var previews: some View {
//        AddItemView { _ in
//            // Handle saving the item
//        }
//    }
//}



