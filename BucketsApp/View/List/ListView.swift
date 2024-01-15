//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI
import PhotosUI

struct ListView: View {
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @State private var showingAddItemView = false
    @State private var showingEditItemView = false
    @State private var selectedItem: ItemModel? = nil
    @State private var showingProfileView = false
    @State private var showingOptions = false // State to control options menu

    // Additional states for list options
    @State private var hideCompleted = false
    @State private var showImages = true

    var body: some View {
        VStack (spacing: 0) {
            ZStack {
                NavigationView {
                    List {
                        ForEach(bucketListViewModel.items) { item in
                            ItemRow(item: item, onCompleted: { completed in
                                bucketListViewModel.onCompleted(for: item, completed: completed)
                            }, showImages: $showImages)
                            .onTapGesture {
                                // Handle tap on the item if needed
                            }
                        }
                        .onDelete(perform: bucketListViewModel.deleteItems)
                    }
                    .navigationBarTitle("Buckets App", displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showingProfileView = true
                            }) {
                                Image(systemName: "person.crop.circle")
                                    .imageScale(.large)
                            }
                        }

                        ToolbarItem(placement: .navigationBarLeading) {
                            Menu {
                                Button(hideCompleted ? "Show Completed" : "Hide Completed") {
                                    hideCompleted.toggle()
                                }
                                Button(showImages ? "Hide Images" : "Show Images") {
                                    showImages.toggle()
                                }
                                Button("Edit List") {
                                    // Your edit list action
                                }
                            } label: {
                                Image(systemName: "list.bullet.circle")
                                    .imageScale(.large)
                            }
                        }
                    }
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
        
        .actionSheet(isPresented: $showingOptions) {
            ActionSheet(
                title: Text("Options"),
                buttons: [
                    .default(Text(hideCompleted ? "Show Completed" : "Hide Completed")) {
                        hideCompleted.toggle()
                    },
                    .default(Text(showImages ? "Hide Images" : "Show Images")) {
                        showImages.toggle()
                    },
                    .default(Text("Edit List")) {
                        // Your edit list action
                    },
                    .cancel()
                ]
            )
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



