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
    
    // (A) Track if ANY text field is active => controls "Done" visibility
    @State private var isAnyTextFieldActive: Bool = false
    
    // (B) Which item was newly created => auto-focus its row
    @State private var newlyCreatedItemID: UUID? = nil
    
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
                            
                            // (A) Trailing "Done" => only visible if a text field is active
                            ToolbarItem(placement: .navigationBarTrailing) {
                                if isAnyTextFieldActive {
                                    Button("Done") {
                                        // 1) Dismiss keyboard => no text fields are active
                                        UIApplication.shared.endEditing()
                                        isAnyTextFieldActive = false
                                        
                                        // 2) Optionally remove blank items
                                        removeBlankItems()
                                    }
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                }
                            }
                            
                            // MARK: - Bottom Bar => Add Button
                            ToolbarItem(placement: .bottomBar) {
                                HStack {
                                    Spacer()
                                    addButton
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                        }
                        .onAppear {
                            loadItems()
                            // (A) Start listening for text field notifications
                            startTextFieldListeners()
                        }
                        .onDisappear {
                            stopTextFieldListeners()
                        }
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
    
    // MARK: - The List
    private var itemListView: some View {
        List {
            // Reverse so new items appear at top
            ForEach(displayedItems.reversed(), id: \.id) { currentItem in
                let itemBinding = bindingForItem(currentItem)
                
                ItemRowView(
                    item: itemBinding,
                    newlyCreatedItemID: newlyCreatedItemID,  // (B)
                    onNavigateToDetail: {
                        selectedItem = currentItem
                    },
                    onEmptyNameLostFocus: {
                        deleteItemIfEmpty(currentItem)
                    }
                )
                .environmentObject(bucketListViewModel)
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
        case .list, .detailed: return bucketListViewModel.items
        case .completed: return bucketListViewModel.items.filter { $0.completed }
        case .incomplete: return bucketListViewModel.items.filter { !$0.completed }
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
            
            // Wait for SwiftUI to register new row in the List
            Task {
                await Task.yield()
                
                // Scroll to the new item => pinned at top
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollToId = newItem.id
                }
                
                // Mark newlyCreatedItemID => that row auto-focuses
                newlyCreatedItemID = newItem.id
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
    
    // MARK: - Remove Blank Items
    private func removeBlankItems() {
        let blanks = bucketListViewModel.items.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for blank in blanks {
            Task { await bucketListViewModel.deleteItem(blank) }
        }
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
        Task {
            await bucketListViewModel.deleteItem(item)
        }
    }
    
    // MARK: - Binding
    private func bindingForItem(_ item: ItemModel) -> Binding<ItemModel> {
        guard let index = bucketListViewModel.items.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $bucketListViewModel.items[index]
    }
    
    // MARK: - Load Items
    private func loadItems() {
        Task {
            isLoading = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
        }
    }

    // MARK: - Profile Image Helper
    @ViewBuilder
    private var profileImageView: some View {
        if let data = onboardingViewModel.profileImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .foregroundColor(.accentColor)
        }
    }
}

// MARK: - TextField Notifications => Track if ANY text field is active
extension ListView {
    /// Start listening for "didBeginEditing" / "didEndEditing" => toggles isAnyTextFieldActive
    private func startTextFieldListeners() {
        NotificationCenter.default.addObserver(
            forName: UITextField.textDidBeginEditingNotification,
            object: nil,
            queue: .main
        ) { _ in
            isAnyTextFieldActive = true
        }
        
        NotificationCenter.default.addObserver(
            forName: UITextField.textDidEndEditingNotification,
            object: nil,
            queue: .main
        ) { _ in
            // We assume only 1 text field is active at a time
            isAnyTextFieldActive = false
        }
    }
    
    private func stopTextFieldListeners() {
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidBeginEditingNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidEndEditingNotification, object: nil)
    }
}

// MARK: - Keyboard Dismiss Helper
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
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

