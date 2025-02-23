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
    
    // Loading / detail
    @State private var isLoading = true
    @State private var showProfileView = false
    @State private var selectedItem: ItemModel?
    @State private var itemToDelete: ItemModel?
    
    // iOS 17: track item for scroll-to
    @State private var scrollToId: UUID? = nil
    
    // Tracks which item is currently editing => used to show/hide Done button
    @State private var editingItemID: UUID? = nil
    
    // For preview mode
    init(previewMode: Bool = false) {
        if previewMode {
            _isLoading = State(initialValue: false)
        }
    }
    
    private enum ViewStyle: String {
        case list, detailed, completed, incomplete
    }
    @State private var selectedViewStyle: ViewStyle = .list
    
    var body: some View {
        NavigationStack {
            if #available(iOS 17.0, *) {
                ZStack {
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                    
                    contentView
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            // MARK: - Principal
                            ToolbarItem(placement: .principal) {
                                HStack {
                                    Text("Bucket List")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    // Profile
                                    Button {
                                        showProfileView = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            if let user = onboardingViewModel.user {
                                                Text(user.username ?? "Unknown")
                                                    .font(.headline)
                                            } else {
                                                Text("@NoName")
                                                    .font(.headline)
                                            }
                                            profileImageView
                                                .frame(width: 35, height: 35)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // MARK: - Trailing: "Done" if editing any row
                            ToolbarItem(placement: .navigationBarTrailing) {
                                if editingItemID != nil {
                                    Button("Done") {
                                        // End editing across all rows
                                        editingItemID = nil
                                    }
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                }
                            }
                            
                            // MARK: - Bottom Bar: Add Button
                            ToolbarItem(placement: .bottomBar) {
                                HStack {
                                    Spacer()
                                    addButton
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                        }
                        .onAppear { loadItems() }
                        // Navigate to Profile
                        .navigationDestination(isPresented: $showProfileView) {
                            ProfileView()
                                .environmentObject(onboardingViewModel)
                                .environmentObject(userViewModel)
                                .environmentObject(bucketListViewModel)
                        }
                        // Navigate to Detail
                        .navigationDestination(item: $selectedItem) { item in
                            DetailItemView(item: bindingForItem(item))
                                .environmentObject(bucketListViewModel)
                                .environmentObject(onboardingViewModel)
                        }
                        // Delete confirmation
                        .alert(
                            "Are you sure you want to delete this item?",
                            isPresented: $bucketListViewModel.showDeleteAlert
                        ) {
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
                }
            } else {
                Text("Please use iOS 17 or later.")
                    .font(.headline)
                    .padding()
            }
        }
    }
    
    // MARK: - Content
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
    
    // MARK: - The List
    private var itemListView: some View {
        List {
            // Reverse so new items appear at top
            ForEach(displayedItems.reversed(), id: \.id) { currentItem in
                let itemBinding = bindingForItem(currentItem)
                
                // Remove the `editingItemID` argument:
                ItemRowView(
                    item: itemBinding,
                    onNavigateToDetail: {
                        selectedItem = currentItem
                    },
                    onEmptyNameLostFocus: {
                        deleteItemIfEmpty(currentItem)
                    }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollTargetLayout()
        .scrollPosition(id: $scrollToId, anchor: .top)
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
            
            // Create new item
            let newItem = ItemModel(userId: onboardingViewModel.user?.id ?? "")
            bucketListViewModel.addOrUpdateItem(newItem)
            
            // 1) Wait for SwiftUI to register the new row in the List
            Task {
                await Task.yield()
                
                // 2) Scroll to the new item
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollToId = newItem.id
                }
                
                // 3) Set editingItemID => row focuses text field
                editingItemID = newItem.id
            }
            
        } label: {
            ZStack {
                Circle()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.accentColor)
                    .shadow(color: .gray.opacity(0.6), radius: 6, x: 0, y: 3)
                
                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .font(.system(size: 30, weight: .bold))
            }
        }
    }
    
    // MARK: - Profile Image
    private var profileImageView: some View {
        let (image, hasCustomImage) = loadProfileImage()
        
        return image
            .resizable()
            .scaledToFill()
            .clipShape(Circle())
            .modifier(overlayOrColor(hasCustomImage: hasCustomImage))
    }
    
    private func loadProfileImage() -> (Image, Bool) {
        if let data = onboardingViewModel.profileImageData,
           let uiImage = UIImage(data: data) {
            return (Image(uiImage: uiImage), true)
        } else {
            return (Image(systemName: "person.crop.circle.fill"), false)
        }
    }
    
    private struct overlayOrColor: ViewModifier {
        let hasCustomImage: Bool
        
        func body(content: Content) -> some View {
            if hasCustomImage {
                return AnyView(
                    content
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
                )
            } else {
                return AnyView(
                    content
                        .foregroundColor(.accentColor)
                )
            }
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
    
    // MARK: - Load Items
    private func loadItems() {
        Task {
            isLoading = true
            // Simulate a short delay
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
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

