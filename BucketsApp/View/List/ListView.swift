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
    
    // Single source of truth for which row is "focused"
    @State private var selectedItemID: UUID? = nil
    
    // Tracks the newest item so it auto-focuses its text field
    @State private var newlyCreatedItemID: UUID? = nil
    
    // **New**: which item is actively editing the name field
    @State private var editingNameItemID: UUID? = nil
    
    // iOS 17: track item for scroll-to
    @State private var scrollToId: UUID?
    
    // For preview
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
                    // Background to clear focus on tap outside
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Clear selected row & editing
                            selectedItemID = nil
                            editingNameItemID = nil
                        }
                    
                    contentView
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
                                if editingNameItemID != nil {
                                    // If user is actually typing => show "Done"
                                    Button("Done") {
                                        editingNameItemID = nil
                                        selectedItemID = nil
                                    }
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                } else {
                                    // Otherwise => show profile button
                                    Button {
                                        showProfileView = true
                                    } label: {
                                        profileImageView
                                    }
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
                }
            } else {
                Text("Please use iOS 17 or later.")
                    .font(.headline)
                    .padding()
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
    
    // MARK: - Displayed Items
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
    private var itemListView: some View {
        List(displayedItems, id: \.id) { currentItem in
            let itemBinding = bindingForItem(currentItem)
            
            ItemRowView(
                item: itemBinding,
                selectedItemID: $selectedItemID,
                newlyCreatedItemID: newlyCreatedItemID,
                // *** 1) We pass a binding for editingNameItemID down
                editingNameItemID: $editingNameItemID,
                
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemBackground))
        .scrollTargetLayout()
        .scrollPosition(id: $scrollToId)
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
            // Simulate a short delay
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
            
            let newItem = ItemModel(userId: onboardingViewModel.user?.id ?? "")
            bucketListViewModel.addOrUpdateItem(newItem)
            
            scrollToId = newItem.id
            selectedItemID = newItem.id
            newlyCreatedItemID = newItem.id
            
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
            .aspectRatio(contentMode: .fill)
            .frame(width: 35, height: 35)
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

