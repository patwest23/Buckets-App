//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @State private var showingAddItemView = false
    @State private var showingEditItemView = false
    @State private var selectedItem: ItemModel? = nil
    @State private var showingProfileView = false  // State to control the display of ProfileView
    
    
    var body: some View {
        VStack (spacing: 0) {
            ZStack {
                NavigationView {
                    List {
                        ForEach(bucketListViewModel.items) { item in
                            ItemRow(item: item) { completed in
                                bucketListViewModel.onCompleted(for: item, completed: completed)
                            }
                            .onTapGesture {
                                selectedItem = item
                                showingEditItemView = true
                            }
                        }
                        .onDelete(perform: bucketListViewModel.deleteItems)
                        // create an onMove function!
                    }
                    .navigationBarTitle("My Bucket List")
                    
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showingProfileView = true
                            }) {
                                Image(systemName: "person.crop.circle")
                                    .imageScale(.large)
                            }
                        }
                    }
                    
                    .navigationBarItems(leading: EditButton())
                }
                
                // hovering button in the ZStack
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
        
        .sheet(isPresented: $showingProfileView) {
                    ProfileView()
                }
        
        .sheet(isPresented: $showingAddItemView) {
            AddItemView { item, imageData in
                bucketListViewModel.addItem(item: item, imageData: imageData)
                showingAddItemView = false
            }
        }
        .sheet(item: $selectedItem) { item in
            EditItemView(item: item) { updatedItem, imageData in
                if !updatedItem.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    bucketListViewModel.updateItem(updatedItem, withName: updatedItem.name, description: updatedItem.description, completed: updatedItem.completed, imageData: imageData)
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
        let viewModel = ListViewModel()
        viewModel.loadItems()
        return ListView()
            .environmentObject(viewModel)
    }
}



