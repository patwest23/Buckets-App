//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var viewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel // To access the userId
    @State private var newItem = ItemModel(name: "")
    @State private var isAddingNewItem = false
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding()
                } else if viewModel.items.isEmpty {
                    Text("No items yet. Tap + to add a new item.")
                        .foregroundColor(.gray)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(viewModel.filteredItems.indices, id: \.self) { index in
                                NavigationLink(value: viewModel.filteredItems[index]) {
                                    ItemRowView(
                                        viewModel: ItemRowViewModel(item: viewModel.filteredItems[index], listViewModel: viewModel),
                                        isEditing: .constant(false)
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                }

                addButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .navigationTitle("Buckets")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadItems()
            }
            .navigationDestination(for: ItemModel.self) { item in
                DetailItemView(item: Binding(
                    get: { viewModel.items.first { $0.id == item.id } ?? item },
                    set: { updatedItem in
                        Task {
                            guard let userId = onboardingViewModel.user?.id else { return }
                            await viewModel.addOrUpdateItem(updatedItem, userId: userId)
                        }
                    }
                ))
            }
            .navigationDestination(isPresented: $isAddingNewItem) {
                DetailItemView(item: $newItem)
                    .onDisappear {
                        Task {
                            guard let userId = onboardingViewModel.user?.id else { return }
                            if !newItem.name.isEmpty {
                                await viewModel.addOrUpdateItem(newItem, userId: userId)
                            }
                            self.newItem = ItemModel(name: "")
                        }
                    }
            }
        }
    }

    private func loadItems() {
        Task {
            guard let userId = onboardingViewModel.user?.id else { return }
            isLoading = true
            await viewModel.loadItems(userId: userId)
            isLoading = false
        }
    }

    private var addButton: some View {
        Button(action: {
            newItem = ItemModel(name: "")
            isAddingNewItem = true
        }) {
            ZStack {
                Circle()
                    .frame(width: 60, height: 60)
                    .foregroundColor(Color.accentColor)
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


