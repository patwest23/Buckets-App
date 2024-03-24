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
    
    @FocusState private var focusedItem: Focusable?
    @State private var selectedItem: ItemModel?
    @State private var showingAddItemView = false
    @State private var newItemName = ""
    @State private var hideCompleted = false
    @State private var showImages = true

    var body: some View {
        NavigationView {
            List {
                ForEach($bucketListViewModel.items) { $item in
                    Button(action: {
                        selectedItem = item
                    }) {
                        ItemRow(
                            item: item,
                            onCompleted: { completed in
                                bucketListViewModel.onCompleted(for: item, completed: completed)
                            },
                            showImages: $showImages
                        )
                    }
                    .id(item.id)
                    .focused($focusedItem, equals: .row(id: item.id))
                    .swipeActions {
                        Button(role: .destructive) {
                            bucketListViewModel.deleteItems(at: IndexSet(arrayLiteral: bucketListViewModel.items.firstIndex(of: item)!))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete { indexSet in
                    bucketListViewModel.deleteItems(at: indexSet)
                }
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
        .onChange(of: focusedItem) { newValue in
            if case .row(let id) = newValue {
                if let id = id, let item = bucketListViewModel.items.first(where: { $0.id == id }) {
                    selectedItem = item
                }
            }
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
