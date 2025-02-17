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

    @State private var isLoading = true
    @State private var showProfileView = false
    @State private var selectedItem: ItemModel?
    @State private var itemToDelete: ItemModel?
    
    // FocusState to focus newly added items
    @FocusState private var focusedItemId: UUID?
    
    // Full-screen carousel presentation states
    @State private var showFullScreenGallery = false
    @State private var galleryUrls: [String] = []
    
    private enum ViewStyle: String {
        case list, detailed, completed, incomplete
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
                
                
                // MARK: - Navigation Bar
                .background(Color(uiColor: .systemBackground))
                .navigationBarTitle("Bucket List", displayMode: .inline)

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
                    
                    // MARK: - Trailing: "Done" or Profile
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if focusedItemId != nil {
                            Button("Done") {
                                focusedItemId = nil
                                removeBlankItems()
                            }
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        } else {
                            HStack {
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
                        .environmentObject(userViewModel)
                        .environmentObject(bucketListViewModel)
                }
                .navigationDestination(item: $selectedItem) { item in
                    DetailItemView(item: bindingForItem(item))
                        .environmentObject(bucketListViewModel)
                        .environmentObject(onboardingViewModel)
                        .environmentObject(bucketListViewModel)
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
                // Full-screen cover for tapped carousel images
                .fullScreenCover(isPresented: $showFullScreenGallery) {
                    FullScreenCarouselView(imageUrls: galleryUrls)
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
    
    // MARK: - List of Items
    private var itemListView: some View {
        List(displayedItems, id: \.id) { aItem in
            let itemBinding = bindingForItem(aItem)
            
            VStack(alignment: .leading, spacing: 8) {
                // 1) Normal row
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
                
                // 2) Completed + has images => show carousel
                if aItem.completed, !aItem.imageUrls.isEmpty {
                    carouselView(for: aItem.imageUrls)
                }
            }
            .padding() // internal padding inside the card
            .background(
                RoundedRectangle(cornerRadius: 12)
                    // White in light mode, black in dark mode
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding(.vertical, 1)
            .padding(.horizontal, 1)
            .listRowBackground(Color.clear)        // Remove default background
            .listRowSeparator(.hidden)            // Remove the gray line
            // Swipe Actions
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
        .listRowSeparator(.hidden) // Hide all separators in the list
    }
    
    // MARK: - Carousel
    private func carouselView(for urls: [String]) -> some View {
        HStack {
            Spacer()
            
            GeometryReader { geo in
                let sideLength = min(geo.size.width * 0.9, 500)
                
                TabView {
                    ForEach(urls, id: \.self) { urlStr in
                        if let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: sideLength, height: sideLength)
                                        .clipped()
                                        .cornerRadius(10)
                                case .failure:
                                    Color.gray
                                        .frame(width: sideLength, height: sideLength)
                                        .cornerRadius(10)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Color.gray
                                .frame(width: sideLength, height: sideLength)
                                .cornerRadius(10)
                        }
                    }
                }
                .tabViewStyle(.page)
                .frame(width: geo.size.width, height: sideLength)
                .onTapGesture {
                    galleryUrls = urls
                    showFullScreenGallery = true
                }
            }
            .frame(height: 300)
//            Spacer()
        }
        .padding(.vertical, 1)
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
    
    // MARK: - Simulated Load
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
    
    // MARK: - Deletion Logic
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
                name: "Skydive Over the Grand Canyon",
                completed: false,
                orderIndex: 0, imageUrls: []
            ),
            ItemModel(
                userId: "mockUID",
                name: "Visit Tokyo",
                completed: true,
                orderIndex: 1, imageUrls: [
                    "https://picsum.photos/400/400?random=1"
                ]
            ),
            ItemModel(
                userId: "mockUID",
                name: "Learn to Play the Guitar",
                completed: false,
                orderIndex: 2, imageUrls: []
            )
        ]
        
        let mockOnboardingVM = OnboardingViewModel()
        let mockUserVM = UserViewModel()
        
        return Group {
            // 1) Empty List scenario
            NavigationStack {
                ListView()
                    .environmentObject(mockListVMEmpty)
                    .environmentObject(mockOnboardingVM)
                    .environmentObject(mockUserVM)
            }
            .previewDisplayName("ListView - Empty")
            
            // 2) Populated scenario
            NavigationStack {
                ListView()
                    .environmentObject(mockListVMWithItems)
                    .environmentObject(mockOnboardingVM)
                    .environmentObject(mockUserVM)
            }
            .previewDisplayName("ListView - With Items")
        }
    }
}




