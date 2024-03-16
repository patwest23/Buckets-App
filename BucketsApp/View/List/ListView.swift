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
    @State private var showingAddItemView = false
    @State private var newItemName: String = ""
    @State private var selectedItem: ItemModel?

    @State private var hideCompleted = false
    @State private var showImages = true
    @State private var focusedItemID: UUID?
    @FocusState private var isAddingNewItem: Bool

    var body: some View {
        NavigationView {
            List {
                ForEach(bucketListViewModel.items.filter { !hideCompleted || !$0.completed }) { item in
                    ItemRow(item: item, onCompleted: { completed in
                        bucketListViewModel.onCompleted(for: item, completed: completed)
                    }, showImages: $showImages) {
                        self.selectedItem = item
                    }
                    .id(item.id)
                    .focused($isAddingNewItem)
                    .onTapGesture {
                        focusedItemID = item.id
                    }
                }
                .onDelete { indexSet in
                    bucketListViewModel.deleteItems(at: indexSet)
                }
            }

            if showingAddItemView {
                TextField("New item", text: $newItemName, onCommit: {
                    if !newItemName.isEmpty {
                        let newItem = ItemModel(name: newItemName, description: "", completed: false)
                        bucketListViewModel.addItem(item: newItem, imageData: nil)
                        newItemName = ""
                        showingAddItemView = false
                        focusedItemID = newItem.id
                    }
                })
                .font(.title3)
                .foregroundColor(.primary)
                .padding()
                .textFieldStyle(PlainTextFieldStyle())
            }
        }
        .navigationTitle("Buckets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                optionsMenu
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                profileNavigationLink
            }
        }
        .overlay(
            addButton.padding(16),
            alignment: .bottomTrailing
        )
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
}






struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        ListView()
            .environmentObject(ListViewModel())
            .environmentObject(OnboardingViewModel())
    }
}



