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
    @EnvironmentObject var userViewModel: UserViewModel
    
    // Loading, profile, detail
    @State private var isLoading = true
    @State private var showProfileView = false
    @State private var selectedItem: ItemModel?
    @State private var itemToDelete: ItemModel?
    
    init(previewMode: Bool = false) {
            if previewMode {
                _isLoading = State(initialValue: false)
            }
        }
    
    // Focus logic
    @FocusState private var focusedItemId: UUID?
    
    // iOS 17: track item for scroll-to
    @State private var scrollToId: UUID?
    
    private enum ViewStyle: String {
        case list, detailed, completed, incomplete
    }
    @State private var selectedViewStyle: ViewStyle = .list

    var body: some View {
        NavigationStack {
            if #available(iOS 17.0, *) {
                ZStack {
                    contentView
                    
                    // Show add button only if no item is being edited
                    if focusedItemId == nil {
                        addButton
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
                .navigationTitle("Bucket List")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // MARK: - Leading: user name
                    ToolbarItem(placement: .navigationBarLeading) {
                        if let user = onboardingViewModel.user {
                            Text(user.username ?? "Unknown")
                                .font(.headline)
                        } else {
                            Text("No Name")
                                .font(.headline)
                        }
                    }
                    // MARK: - Trailing: Done or Profile
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if focusedItemId != nil {
                            Button("Done") {
                                focusedItemId = nil
                                removeBlankItems()
                            }
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        } else {
                            Button {
                                showProfileView = true
                            } label: {
                                profileImageView
                            }
                        }
                    }
                }
                .onAppear {
                    loadItems()
                }
                // Navigation to Profile
                .navigationDestination(isPresented: $showProfileView) {
                    ProfileView()
                        .environmentObject(onboardingViewModel)
                        .environmentObject(userViewModel)
                        .environmentObject(bucketListViewModel)
                }
                // Navigation to Detail
                .navigationDestination(item: $selectedItem) { item in
                    DetailItemView(item: bindingForItem(item))
                        .environmentObject(bucketListViewModel)
                        .environmentObject(onboardingViewModel)
                }
                // Delete confirmation
                .alert("Are you sure you want to delete this item?",
                       isPresented: $bucketListViewModel.showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        if let toDelete = itemToDelete {
                            deleteItem(toDelete)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    if let toDelete = itemToDelete {
                        Text("Delete “\(toDelete.name)” from your list?")
                    }
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
    
    // MARK: - The List
    @ViewBuilder
    private var itemListView: some View {
        if #available(iOS 17.0, *) {
            List(displayedItems, id: \.id) { aItem in
                let itemBinding = bindingForItem(aItem)
                
                VStack(alignment: .leading, spacing: 0) {
                    ItemRowView(
                        item: itemBinding,
                        onNavigateToDetail: { selectedItem = aItem },
                        onEmptyNameLostFocus: { deleteItemIfEmpty(aItem) }
                    )
                    .focused($focusedItemId, equals: aItem.id)
                }
//                .padding(4) // smaller padding
                .background(
                    RoundedRectangle(cornerRadius: 8) // smaller corner radius
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                )
                // You can remove these if you want even less spacing
//                .padding(.vertical, 2)
                .padding(.horizontal, 2)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .scrollTargetLayout()
            .scrollPosition(id: $scrollToId)
            .listStyle(.plain)
            .listRowSeparator(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
        } else {
            // iOS < 17 fallback
            List(displayedItems, id: \.id) { aItem in
                let itemBinding = bindingForItem(aItem)
                
                VStack(alignment: .leading, spacing: 8) {
                    ItemRowView(
                        item: itemBinding,
                        onNavigateToDetail: {
                            selectedItem = aItem
                        },
                        onEmptyNameLostFocus: {
                            deleteItemIfEmpty(aItem)
                        }
                    )
                    .focused($focusedItemId, equals: aItem.id)
                }
//                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
//                .padding(.vertical, 1)
                .padding(.horizontal, 1)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .listRowSeparator(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    // MARK: - Loading / Empty
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
    
    // MARK: - Load Items
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
            bucketListViewModel.addOrUpdateItem(newItem)
            
            // Focus + scroll
            focusedItemId = newItem.id
            scrollToId = newItem.id
            
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
                    .frame(width: 35, height: 35)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
            )
        } else {
            AnyView(
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 35, height: 35)
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
    
    // MARK: - Deletion
    private func showDeleteConfirmation(for item: ItemModel) {
        itemToDelete = item
        bucketListViewModel.showDeleteAlert = true
    }
    
    private func deleteItemIfEmpty(_ item: ItemModel) {
        if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        let mockListVMEmpty = ListViewModel()
        
        let mockListVMWithItems = ListViewModel()
        mockListVMWithItems.items = [
            ItemModel(
                userId: "mockUID",
                name: "Skydive",
                completed: false
            ),
            ItemModel(
                userId: "mockUID",
                name: "Visit Tokyo",
                completed: true,
                // 3 random image URLs
                imageUrls: [
                    "https://picsum.photos/400/400?random=1",
                    "https://picsum.photos/400/400?random=2",
                    "https://picsum.photos/400/400?random=3"
                ]
            ),
            ItemModel(
                userId: "mockUID",
                name: "Learn Guitar",
                completed: false
            )
        ]
        
        let mockOnboardingVM = OnboardingViewModel()
        let mockUserVM = UserViewModel()
        
        return Group {
            // 1) Empty scenario
            NavigationStack {
                ListView()
                    .environmentObject(mockListVMEmpty)
                    .environmentObject(mockOnboardingVM)
                    .environmentObject(mockUserVM)
            }
            .previewDisplayName("ListView - Empty")
            
            // 2) Populated scenario
            NavigationStack {
                // Pass previewMode: true => isLoading = false
                ListView(previewMode: true)
                    .environmentObject(mockListVMWithItems)
                    .environmentObject(mockOnboardingVM)
                    .environmentObject(mockUserVM)
            }
            .previewDisplayName("ListView - With Items (3 real images)")
        }
    }
}

