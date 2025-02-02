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
    @State private var expandedItemId: UUID?
    @State private var itemToDelete: ItemModel?
    
    // 1) Define view style enum & local state
    private enum ViewStyle: String {
        case list = "List View"
        case detailed = "Detailed View"
        case completed = "Completed Only"
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
                    
                    // Leading: user name
                    ToolbarItem(placement: .navigationBarLeading) {
                        if let user = onboardingViewModel.user {
                            Text(user.name ?? "Unknown")
                                .font(.headline)
                        } else {
                            Text("No Name")
                                .font(.headline)
                        }
                    }
                    
                    // Trailing: HStack of sorting menu + profile
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            // 2) The sorting/view-style Menu
                            Menu {
                                Button("List View")      { selectedViewStyle = .list }
                                Button("Detailed View")  { selectedViewStyle = .detailed }
                                Button("Completed Only") { selectedViewStyle = .completed }
                                Button("Incomplete")     { selectedViewStyle = .incomplete }
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.title3)
                            }
                            
                            // Existing profile button
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
    
    // MARK: - Filter/Style Items Based on selectedViewStyle
    private var displayedItems: [ItemModel] {
        switch selectedViewStyle {
        case .list:
            return bucketListViewModel.items
        case .detailed:
            return bucketListViewModel.items
        case .completed:
            return bucketListViewModel.items.filter { $0.completed }
        case .incomplete:
            return bucketListViewModel.items.filter { !$0.completed }
        }
    }
    
    private var itemListView: some View {
        ScrollView {
            VStack(spacing: 5) {
                ForEach(displayedItems, id: \.id) { aItem in
                    let itemBinding = bindingForItem(aItem)
                    
                    ItemRowView(
                        item: itemBinding,
                        expandedItemId: $expandedItemId,
                        onNavigateToDetail: {
                            selectedItem = aItem
                        },
                        onEmptyNameLostFocus: {
                            deleteItemIfEmpty(aItem)
                        }
                    )
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
            }
            .padding()
        }
    }
    
    // MARK: - Load & Empty State & etc
    private var loadingView: some View {
        ProgressView("Loading...")
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(1.5)
            .padding()
    }
    
    private var emptyStateView: some View {
        Text("What do you want to do before you die?")
            .foregroundColor(.accentColor)
            .font(.largeTitle)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .padding()
    }
    
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
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
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
    
    // MARK: - Binding & Deletion
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




