//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var viewModel: ListViewModel
    @State private var newItem: ItemModel? // Temporary item for adding a new entry

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewModel.items, id: \.id) { item in
                        NavigationLink(value: item) {
                            ItemRowView(
                                viewModel: ItemRowViewModel(item: item, listViewModel: viewModel),
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
            .navigationDestination(for: ItemModel.self) { item in
                DetailItemView(item: Binding(
                    get: { viewModel.items.first { $0.id == item.id } ?? item },
                    set: { updatedItem in
                        if let index = viewModel.items.firstIndex(where: { $0.id == item.id }) {
                            viewModel.items[index] = updatedItem
                        }
                    }
                ))
            }
            .navigationDestination(isPresented: Binding(
                get: { newItem != nil },
                set: { if !$0 { newItem = nil } }
            )) {
                if let newItem = newItem {
                    DetailItemView(item: .constant(newItem))
                        .onDisappear {
                            if !newItem.name.isEmpty {
                                viewModel.addItem(newItem)
                            }
                            self.newItem = nil // Clear the temporary item
                        }
                }
            }
        }
    }

    // MARK: Add Button
    private var addButton: some View {
        Button(action: {
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            // Initialize a new item for navigation
            newItem = ItemModel(name: "")
        }) {
            ZStack {
                Circle()
                    .frame(width: 60, height: 60)
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
        let mockViewModel = ListViewModel()
        mockViewModel.items = [
            ItemModel(
                name: "Mock Item 1",
                description: "Description for mock item 1",
                imagesData: [
                    UIImage(named: "MockImage1")!.jpegData(compressionQuality: 1.0)!,
                    UIImage(named: "MockImage2")!.jpegData(compressionQuality: 1.0)!,
                    UIImage(named: "MockImage3")!.jpegData(compressionQuality: 1.0)!
                ]
            ),
            ItemModel(
                name: "Mock Item 2",
                description: "Description for mock item 2"
            )
        ]

        return NavigationStack {
            ListView()
                .environmentObject(mockViewModel)
        }
        .previewDisplayName("ListView Preview")
    }
}


