//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var viewModel: ListViewModel
    @State private var newItem = ItemModel(name: "")// non-optional type
    @State private var isAddingNewItem = false   // Controls navigation to DetailItemView for new items

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewModel.items.indices, id: \.self) { index in
                        NavigationLink(value: viewModel.items[index]) {
                            ItemRowView(
                                viewModel: ItemRowViewModel(item: viewModel.items[index], listViewModel: viewModel),
                                isEditing: .constant(false)
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Buckets")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(addButton, alignment: .bottomTrailing)
            // Navigation for existing items
            .navigationDestination(for: ItemModel.self) { item in
                DetailItemView(item: Binding(
                    get: { viewModel.items.first { $0.id == item.id } ?? item },
                    set: { updatedItem in
                        if let index = viewModel.items.firstIndex(where: { $0.id == updatedItem.id }) {
                            viewModel.items[index] = updatedItem
                        }
                    }
                ))
            }
            // Navigation for adding a new item
                        .navigationDestination(isPresented: $isAddingNewItem) {
                            DetailItemView(item: $newItem)
                                .onDisappear {
                                    if !newItem.name.isEmpty {
                                        viewModel.addOrUpdateItem(newItem) // Add or update item
                                    }
                                    self.newItem = ItemModel(name: "") // Reset newItem
                                }
                        }
                    }
                }

    // MARK: Add Button
    private var addButton: some View {
        Button(action: {
            newItem = ItemModel(name: "")
            isAddingNewItem = true
        }) {
            ZStack {
                Circle()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
                    .shadow(color: .gray, radius: 10, x: 0, y: 5)

                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .font(.system(size: 30, weight: .bold))
            }
        }
        .padding()
    }
}


struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock view model with sample data
        let mockViewModel = ListViewModel()
        mockViewModel.items = [
            ItemModel(
                name: "Mock Item 1",
                description: "Description for mock item 1",
                imagesData: [UIImage(named: "MockImage1")!.jpegData(compressionQuality: 1.0)!]
            ),
            ItemModel(
                name: "Mock Item 2",
                description: "Description for mock item 2",
                imagesData: [UIImage(named: "MockImage2")!.jpegData(compressionQuality: 1.0)!]
            ),
            ItemModel(
                name: "Mock Item 3",
                description: nil,
                imagesData: [UIImage(named: "MockImage3")!.jpegData(compressionQuality: 1.0)!]
            )
        ]

        // Render the ListView with the mock environment object
        return NavigationStack {
            ListView()
                .environmentObject(mockViewModel) // Inject mock data
        }
        .previewDisplayName("ListView Preview with Mock Data")
    }
}


