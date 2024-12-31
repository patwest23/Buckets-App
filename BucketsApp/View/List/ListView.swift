//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var viewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var newItem = ItemModel(userId: "", name: "")
    @State private var isAddingNewItem = false
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                contentView
                addButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .navigationTitle("Buckets")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadItems() }
            .navigationDestination(isPresented: $isAddingNewItem) {
                DetailItemView(item: $newItem)
                    .onDisappear { handleNewItemSave() }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingView
        } else if viewModel.items.isEmpty {
            emptyStateView
        } else {
            itemListView
        }
    }

    private var loadingView: some View {
        ProgressView("Loading...")
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(1.5)
            .padding()
    }

    private var emptyStateView: some View {
        Text("No items yet. Tap + to add a new item.")
            .foregroundColor(.gray)
            .font(.headline)
            .multilineTextAlignment(.center)
            .padding()
    }

    private var itemListView: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(viewModel.items, id: \.id) { item in
                    navigationLink(for: item)
                }
            }
            .padding()
        }
    }

    private func navigationLink(for item: ItemModel) -> some View {
        NavigationLink(
            destination: DetailItemView(item: Binding(
                get: { viewModel.items.first { $0.id == item.id } ?? item },
                set: { updatedItem in handleItemUpdate(updatedItem) }
            ))
        ) {
            ItemRowView(
                viewModel: ItemRowViewModel(item: item),
                isEditing: .constant(false)
            )
        }
    }

    private var addButton: some View {
        Button(action: {
            newItem = ItemModel(userId: "", name: "")
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

    // MARK: - Helper Functions

    private func loadItems() {
        Task {
            if let userId = onboardingViewModel.user?.id {
                isLoading = true
                await viewModel.loadItems(userId: userId)
                isLoading = false
            }
        }
    }

    private func handleItemUpdate(_ updatedItem: ItemModel) {
        Task {
            if let userId = onboardingViewModel.user?.id {
                await viewModel.addOrUpdateItem(updatedItem, userId: userId)
            }
        }
    }

    private func handleNewItemSave() {
        Task {
            if let userId = onboardingViewModel.user?.id {
                if !newItem.name.isEmpty {
                    await viewModel.addOrUpdateItem(newItem, userId: userId)
                }
                newItem = ItemModel(userId: "", name: "")
            }
        }
    }
}

//struct ListView_Previews: PreviewProvider {
//    static var previews: some View {
//        let mockViewModel = ListViewModel()
//        mockViewModel.items = [
//            ItemModel(name: "Mock Item 1", description: "Description for mock item 1"),
//            ItemModel(name: "Mock Item 2", description: "Description for mock item 2"),
//            ItemModel(name: "Mock Item 3", description: nil)
//        ]
//
//        let mockOnboardingViewModel = MockOnboardingViewModel()
//        mockOnboardingViewModel.isAuthenticated = true
//        mockOnboardingViewModel.email = "mockuser@example.com"
//
//        return NavigationStack {
//            ListView()
//                .environmentObject(mockViewModel)
//                .environmentObject(mockOnboardingViewModel)
//        }
//    }
//}


