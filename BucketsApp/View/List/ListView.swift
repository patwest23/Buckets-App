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
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var navigationPath = NavigationPath()
    @State private var selectedItem: ItemModel?
    
    // Additional states for list options
    @State private var hideCompleted = false
    @State private var showImages = true

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // List of Items
                ForEach(bucketListViewModel.items) { item in
                    NavigationLink(value: item) {
                        ItemRow(item: item, onCompleted: { completed in
                            bucketListViewModel.onCompleted(for: item, completed: completed)
                        }, showImages: $showImages)
                    }
                }
                .onDelete(perform: bucketListViewModel.deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        if let imageData = onboardingViewModel.profileImageData, let image = UIImage(data: imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 35, height: 35)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle")
                                .resizable()
                                .frame(width: 35, height: 35)
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    optionsMenu
                }
            }
            // Floating button for adding a new item
            .overlay(alignment: .bottomTrailing) {
                addButton
            }
            .navigationDestination(for: ItemModel.self) { item in
                EditItemView(item: item) { updatedItem, imageData in
                    bucketListViewModel.updateItem(updatedItem, withName: updatedItem.name, description: updatedItem.description, completed: updatedItem.completed, imageData: imageData)
                }
            }
        }
    }
    
    @ViewBuilder
    private var addButton: some View {
        Button(action: {
            // Handle add item action
        }) {
            Image(systemName: "plus")
                .font(.title)
                .foregroundColor(.white)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(28)
                .shadow(radius: 4)
                .padding(16)
        }
    }
    
    @ViewBuilder
    private var optionsMenu: some View {
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
                .font(.title)
        }
    }
}

struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        ListView()
            .environmentObject(ListViewModel())
            .environmentObject(OnboardingViewModel())
    }
}




