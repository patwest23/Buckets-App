//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var viewModel: ListViewModel
    @State private var newItem: ItemModel? // Store the new item to navigate to

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewModel.items.indices, id: \.self) { index in
                        NavigationLink(value: viewModel.items[index]) {
                            ItemRowView(
                                viewModel: ItemRowViewModel(item: $viewModel.items[index]), // Pass the binding directly
                                isEditing: .constant(false)
                            )
                        }
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    profileNavigationLink
                }
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
        }
    }

    // MARK: Profile Navigation Link
    private var profileNavigationLink: some View {
        NavigationLink(value: "Profile") {
            Image(systemName: "person.crop.circle")
        }
        .navigationDestination(for: String.self) { value in
            if value == "Profile" {
                ProfileView()
            }
        }
    }

    // MARK: Add Button
    private var addButton: some View {
        Button(action: {
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()

            let addedItem = viewModel.addItem() // Capture the newly added item
            newItem = addedItem // Set new item to navigate to
        }) {
            ZStack {
                Circle()
                    .frame(width: 60, height: 60)
                    .shadow(color: .gray, radius: 10, x: 0, y: 5)

                Image(systemName: "plus")
                    .foregroundColor(Color("AccentColor")) // Replace "AccentColor" with your custom color name
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            newItem.map { item in
                NavigationLink(value: item, label: { EmptyView() }).hidden()
            }
        )
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
