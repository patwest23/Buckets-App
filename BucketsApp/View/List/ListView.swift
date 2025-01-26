//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var isLoading = true
    @State private var showProfileView = false
    
    // For programmatic navigation to DetailItemView
    @State private var selectedItem: ItemModel?
    @State private var expandedItemId: UUID?
    
    // For delete confirmation
    @State private var itemToDelete: ItemModel? = nil
    
    var body: some View {
        NavigationStack {
            if #available(iOS 17.0, *) {
                ZStack {
                    contentView
                    
                    addButton
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                .navigationTitle("Bucket List")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if let user = onboardingViewModel.user {
                            Text(user.name ?? "Unknown")
                                .font(.headline)
                        } else {
                            Text("No Name")
                                .font(.headline)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showProfileView = true
                        } label: {
                            profileImageView
                        }
                    }
                }
                .onAppear {
                    #if DEBUG
                    // In previews, do nothing
                    #else
                    // In production, call loadItems()
                    loadItems()
                    #endif
                }
                // Navigate to ProfileView
                .navigationDestination(isPresented: $showProfileView) {
                    ProfileView()
                        .environmentObject(onboardingViewModel)
                }
                // Navigate to DetailItemView
                .navigationDestination(item: $selectedItem) { item in
                    DetailItemView(item: bindingForItem(item))
                        .environmentObject(bucketListViewModel)
                        .environmentObject(onboardingViewModel)
                }
                // Delete confirmation
                .confirmationDialog(
                    "Are you sure you want to delete this item?",
                    isPresented: $bucketListViewModel.showDeleteAlert
                ) {
                    if let itemToDelete = itemToDelete {
                        Button("Delete", role: .destructive) {
                            deleteItem(itemToDelete)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } else {
                // Fallback on earlier versions
                Text("Please use iOS 17 or later.")
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            itemListView
        } else if bucketListViewModel.items.isEmpty {
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
            VStack(spacing: 5) {
                ForEach($bucketListViewModel.items, id: \.id) { $item in
                    ItemRowView(
                        item: $item,
                        expandedItemId: $expandedItemId,
                        onNavigateToDetail: {
                            selectedItem = item
                        },
                        onEmptyNameLostFocus: {
                            // If the user didn't type anything, delete the item from the model
                            deleteItemIfEmpty(item)
                        }
                    )
                    // Swipe left = trailing
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            showDeleteConfirmation(for: item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    // Swipe right = leading
                    .swipeActions(edge: .leading) {
                        Button(role: .destructive) {
                            showDeleteConfirmation(for: item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Profile Image
    
    private var profileImageView: some View {
        if let data = onboardingViewModel.profileImageData,
           let uiImage = UIImage(data: data) {
            AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            )
        } else {
            AnyView(
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .foregroundColor(.gray)
            )
        }
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Button {
            // 1) Prevent multiple empty items
            let alreadyHasEmptyItem = bucketListViewModel.items.contains {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            guard !alreadyHasEmptyItem else {
                print("There's already an empty item. Not adding another.")
                return
            }
            
            let newItem = ItemModel(
                userId: onboardingViewModel.user?.id ?? "",
                name: ""
            )
            bucketListViewModel.items.append(newItem)
        } label: {
            ZStack {
                Circle()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.accentColor)
                    .shadow(color: .gray, radius: 10, x: 0, y: 5)
                
                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .font(.system(size: 30, weight: .bold))
            }
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func loadItems() {
        Task {
            isLoading = true
            // Simulate a half-second load
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
        }
    }
    
    /// Create a binding to the item in the array, so changes propagate.
    private func bindingForItem(_ item: ItemModel) -> Binding<ItemModel> {
        guard let index = bucketListViewModel.items.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $bucketListViewModel.items[index]
    }
    
    private func showDeleteConfirmation(for item: ItemModel) {
        itemToDelete = item
        bucketListViewModel.showDeleteAlert = true
    }
    
    private func deleteItemIfEmpty(_ item: ItemModel) {
        if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showDeleteConfirmation(for: item)
        }
    }
    
    private func deleteItem(_ item: ItemModel) {
        Task {
            await bucketListViewModel.deleteItem(item)
        }
    }
}


struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        let mockListViewModel = ListViewModel()         // Or your mock list VM
        let mockOnboardingViewModel = OnboardingViewModel() // Or a mock onboarding VM
        
        return NavigationStack {
            ListView()
                .environmentObject(mockListViewModel)
                .environmentObject(mockOnboardingViewModel)
        }
    }
}




