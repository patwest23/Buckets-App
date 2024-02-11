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
    @State private var showingAddItemView = false  // State to control showing the AddItemView as a sheet
    @State private var selectedItem: ItemModel?  // Used for direct navigation to EditItemView

    // Additional states for list options
    @State private var hideCompleted = false
    @State private var showImages = true

    var body: some View {
        NavigationStack {
            List {
                ForEach(bucketListViewModel.items.filter { !hideCompleted || !$0.completed }) { item in
                    Button(action: {
                        self.selectedItem = item  // Set the selected item to trigger navigation
                    }) {
                        ItemRow(item: item, onCompleted: { completed in
                            bucketListViewModel.onCompleted(for: item, completed: completed)
                        }, showImages: $showImages)
                    }
                }
                .onDelete(perform: bucketListViewModel.deleteItems)
            }
            .navigationTitle("Buckets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    optionsMenu
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    profileNavigationLink
                }
            }
            .overlay(
                addButton.padding(16),
                alignment: .bottomTrailing
            )
        }
        .sheet(isPresented: $showingAddItemView) {
            AddItemView() { newItem, imageData in
                bucketListViewModel.addItem(item: newItem, imageData: imageData)
            }
        }
        .sheet(item: $selectedItem) { item in
            EditItemView(item: item) { updatedItem, imageData in
                bucketListViewModel.updateItem(updatedItem, withName: updatedItem.name, description: updatedItem.description, completed: updatedItem.completed, imageData: imageData)
            }
        }
    }

    @ViewBuilder
    private var addButton: some View {
        Button(action: {
            showingAddItemView = true
        }) {
            Image(systemName: "plus")
                .font(.title)
                .foregroundColor(.white)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(28)
                .shadow(radius: 4)
        }
    }
    
    private var optionsMenu: some View {
        Menu {
            Button(hideCompleted ? "Show Completed" : "Hide Completed") {
                hideCompleted.toggle()
            }

            Button(showImages ? "Hide Images" : "Show Images") {
                showImages.toggle()
            }

            Button("Edit List") {
                // Placeholder for future feature
            }
        } label: {
            Image(systemName: "list.bullet.circle")
        }
    }

    @ViewBuilder
    private var profileNavigationLink: some View {
        NavigationLink(destination: ProfileView()) {
            if let imageData = onboardingViewModel.profileImageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 35, height: 35)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle")
            }
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




