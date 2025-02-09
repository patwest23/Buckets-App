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
    @State private var selectedItem: ItemModel?
    @State private var itemToDelete: ItemModel?
    
    // FocusState to focus newly added items
    @FocusState private var focusedItemId: UUID?
    
    // MARK: - View Style (kept in case you revisit sorting later)
    private enum ViewStyle: String {
        case list       = "List View"
        case detailed   = "Detailed View"
        case completed  = "Completed Only"
        case incomplete = "Incomplete Only"
    }
    @State private var selectedViewStyle: ViewStyle = .list
    
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
                    
                    // MARK: - Leading: user name
                    ToolbarItem(placement: .navigationBarLeading) {
                        if let user = onboardingViewModel.user {
                            Text(user.name ?? "Unknown")
                                .font(.headline)
                        } else {
                            Text("No Name")
                                .font(.headline)
                        }
                    }
                    
                    // MARK: - Trailing: "Done" or [Sorting + Profile]
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if focusedItemId != nil {
                            // If user is editing a TextField, show a "Done" button
                            Button("Done") {
                                // 1) Remove focus => dismiss keyboard
                                focusedItemId = nil
                                
                                // 2) Optionally remove any blank items
                                removeBlankItems()
                            }
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        } else {
                            HStack {
                                // COMMENTED OUT SORTING MENU:
                                /*
                                Menu {
                                    Button("List")       { selectedViewStyle = .list }
                                    Button("Detailed")   { selectedViewStyle = .detailed }
                                    Button("Complete")   { selectedViewStyle = .completed }
                                    Button("Incomplete") { selectedViewStyle = .incomplete }
                                } label: {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .foregroundColor(.accentColor)
                                }
                                */
                                
                                // Profile button
                                Button {
                                    showProfileView = true
                                } label: {
                                    profileImageView
                                }
                            }
                        }
                    }
                }
                .onAppear { loadItems() }
                .navigationDestination(isPresented: $showProfileView) {
                    ProfileView()
                        .environmentObject(onboardingViewModel)
                }
                .navigationDestination(item: $selectedItem) { item in
                    DetailItemView(item: bindingForItem(item))
                        .environmentObject(bucketListViewModel)
                        .environmentObject(onboardingViewModel)
                }
                .confirmationDialog(
                    "Are you sure you want to delete this item?",
                    isPresented: $bucketListViewModel.showDeleteAlert
                ) {
                    if let itemToDelete {
                        Button("Delete", role: .destructive) {
                            deleteItem(itemToDelete)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } else {
                Text("Please use iOS 17 or later.")
            }
        }
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingView
        } else if bucketListViewModel.items.isEmpty {
            emptyStateView
        } else {
            // The actual List of items
            itemListView
        }
    }
    
    // MARK: - Derived Items
    private var displayedItems: [ItemModel] {
        switch selectedViewStyle {
        case .list, .detailed:
            return bucketListViewModel.items
        case .completed:
            return bucketListViewModel.items.filter { $0.completed }
        case .incomplete:
            return bucketListViewModel.items.filter { !$0.completed }
        }
    }
    
    // MARK: - List of Items
    private var itemListView: some View {
        List(displayedItems, id: \.id) { aItem in
            let itemBinding = bindingForItem(aItem)
            
            // Use the revised initializer without `showDetailed`
            ItemRowView(
                item: itemBinding,
                onNavigateToDetail: {
                    selectedItem = aItem
                },
                onEmptyNameLostFocus: {
                    deleteItemIfEmpty(aItem)
                }
            )
            // Focus the row’s TextField using our FocusState
            .focused($focusedItemId, equals: aItem.id)
            // Swipe to delete
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    showDeleteConfirmation(for: aItem)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button(role: .destructive) {
                    showDeleteConfirmation(for: aItem)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Loading/Empty
    private var loadingView: some View {
        ProgressView("Loading...")
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(1.5)
            .padding()
    }
    
    private var emptyStateView: some View {
        Text("What do you want to do before you die?")
            .foregroundColor(.primary)
            .font(.title)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .padding()
    }
    
    // MARK: - Simulated Load (just a placeholder delay)
    private func loadItems() {
        Task {
            isLoading = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
        }
    }
    
    // MARK: - Add Button
    private var addButton: some View {
        Button {
            let alreadyHasEmptyItem = bucketListViewModel.items.contains {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            guard !alreadyHasEmptyItem else {
                print("There's already an empty item. Not adding another.")
                return
            }
            
            let newItem = ItemModel(
                userId: onboardingViewModel.user?.id ?? ""
            )
            
            // Call addOrUpdateItem so it gets proper orderIndex & stored in Firestore
            bucketListViewModel.addOrUpdateItem(newItem)
            
            // Focus the new row’s TextField
            focusedItemId = newItem.id
            
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
    
    // MARK: - Profile Image
    private var profileImageView: some View {
        if let data = onboardingViewModel.profileImageData,
           let uiImage = UIImage(data: data) {
            AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
            )
        } else {
            AnyView(
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 25, height: 25)
                    .clipShape(Circle())
                    .foregroundColor(.accentColor)
            )
        }
    }
    
    // MARK: - Binding
    private func bindingForItem(_ item: ItemModel) -> Binding<ItemModel> {
        guard let index = bucketListViewModel.items.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $bucketListViewModel.items[index]
    }
    
    // MARK: - Deletion Logic
    private func showDeleteConfirmation(for item: ItemModel) {
        itemToDelete = item
        bucketListViewModel.showDeleteAlert = true
    }
    
    private func deleteItemIfEmpty(_ item: ItemModel) {
        if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Directly delete the blank item (no confirmation).
            Task {
                await bucketListViewModel.deleteItem(item)
            }
        }
    }
    
    private func deleteItem(_ item: ItemModel) {
        print("Deleting item: \(item.name)")
        Task {
            await bucketListViewModel.deleteItem(item)
        }
    }
    
    /// Removes any items that remain blank
    private func removeBlankItems() {
        let blankItems = bucketListViewModel.items.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for item in blankItems {
            Task {
                await bucketListViewModel.deleteItem(item)
            }
        }
    }
}

// MARK: - Preview
struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        let mockListViewModel = ListViewModel()
        let mockOnboardingViewModel = OnboardingViewModel()
        
        return NavigationStack {
            ListView()
                .environmentObject(mockListViewModel)
                .environmentObject(mockOnboardingViewModel)
        }
    }
}




