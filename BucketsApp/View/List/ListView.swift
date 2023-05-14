//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var imageData: ImageData
    @State private var showingAddItemView = false
    @State private var showingEditItemView = false
    @State private var selectedItem: ItemModel? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                NavigationView {
                    List {
                        ForEach(imageData.itemModel) { item in
                            ItemRow(item: item) { completed in
                                imageData.onCompleted(for: item, completed: completed)
                            }
                            .onTapGesture {
                                selectedItem = item
                                showingEditItemView = true
                            }
                        }
                        .onDelete(perform: imageData.deleteItems)
                    }
                    .navigationBarTitle("My Bucket List")
                    .navigationBarItems(leading: EditButton())
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddItemView = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color("AccentColor"))
                                .cornerRadius(28)
                                .shadow(radius: 4)
                                .padding(.trailing, 16)
                                .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItemView) {
            AddItemView { item in
                imageData.addItem(item: item)
                showingAddItemView = false
            }
        }
        .sheet(item: $selectedItem) { item in
            EditItemView(item: item) { updatedItem in
                if !updatedItem.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    imageData.updateItem(updatedItem, withName: updatedItem.name, description: updatedItem.description, completed: updatedItem.completed)
                    // Save images locally
                    // ...
                }
                selectedItem = nil
                showingEditItemView = false
            }
        }
    }
}



struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        let imageData = ImageData()
        return ListView()
            .environmentObject(imageData)
    }
}




