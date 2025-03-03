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
    
    // The ID of the item we want to scroll to in ScrollViewReader
    @State private var scrollToId: UUID? = nil
    
    // Whether any text field is active => shows/hides "Done" button
    @State private var isAnyTextFieldActive: Bool = false
    
    // Which newly created item => row can auto-focus
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
                    
                    ScrollViewReader { proxy in
                        contentView
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                // MARK: - Leading: "Bucket List"
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Text("Bucket List")
                                        .font(.headline)
                                }
                                
                                // MARK: - Trailing: "Done" (if editing) or Profile
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    if isAnyTextFieldActive {
                                        Button("Done") {
                                            UIApplication.shared.endEditing()
                                            isAnyTextFieldActive = false
                                            removeBlankItems()
                                        }
                                        .font(.headline)
                                        .foregroundColor(.accentColor)
                                    } else {
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
                                startTextFieldListeners()
                            }
                            .onDisappear {
                                // ——— Fix #1: reset newlyCreatedItemID, so no auto-focus after coming back
                                newlyCreatedItemID = nil
                                
                                // ——— Fix #2: end any active editing => no keyboard
                                UIApplication.shared.endEditing()
                                isAnyTextFieldActive = false
                                
                                stopTextFieldListeners()
                            }
                            // Navigate to Profile
                            .navigationDestination(isPresented: $showProfileView) {
                                ProfileView()
                                    .environmentObject(onboardingViewModel)
                                    .environmentObject(userViewModel)
                                    .environmentObject(bucketListViewModel)
                            }
                            // Navigate to Detail => PASS A COPY of the item
                            .navigationDestination(item: $selectedItem) { item in
                                // The detail view will do local copy handling
                                DetailItemView(item: item)
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
                            // Scroll to changed ID
                            .onChange(of: scrollToId) { _, newVal in
                                guard let newVal = newVal else { return }
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(newVal, anchor: .bottom)
                                }
                            }
                    }
                }
                // Extra space above keyboard
                .safeAreaInset(edge: .bottom) {
                    Color.clear
                        .frame(height: 70)
                        .allowsHitTesting(false)
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
    
    // MARK: - List of Items
    private var itemListView: some View {
        List {
            ForEach(displayedItems, id: \.id) { currentItem in
                // We still bind to the row for inline editing
                let itemBinding = bindingForItem(currentItem)
                
                ItemRowView(
                    item: itemBinding,
                    newlyCreatedItemID: newlyCreatedItemID,
                    onNavigateToDetail: {
                        // For detail: pass a *copy* via selectedItem
                        selectedItem = currentItem
                    },
                    onEmptyNameLostFocus: {
                        deleteItemIfEmpty(currentItem)
                    }
                )
                .environmentObject(bucketListViewModel)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .id(currentItem.id)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
    
    // MARK: - UI States
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
                print("Already has empty item => not adding another.")
                return
            }
            
            // Create new item
            let newItem = ItemModel(userId: onboardingViewModel.user?.id ?? "")
            bucketListViewModel.addOrUpdateItem(newItem)
            
            // Mark newlyCreatedItemID => row auto-focus once in .onAppear
            newlyCreatedItemID = newItem.id
            
            Task {
                // Wait for SwiftUI to insert row
                await Task.yield()
                
                // Then scroll to it
                scrollToId = newItem.id
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
    
    // MARK: - Removing blank items
    private func removeBlankItems() {
        let blanks = bucketListViewModel.items.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for blank in blanks {
            Task {
                await bucketListViewModel.deleteItem(blank)
            }
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
    
    // MARK: - Binding for Row
    private func bindingForItem(_ item: ItemModel) -> Binding<ItemModel> {
        guard let index = bucketListViewModel.items.firstIndex(where: { $0.id == item.id }) else {
            // If not found, return a constant to avoid out-of-range errors
            return .constant(item)
        }
        return $bucketListViewModel.items[index]
    }
    
    // MARK: - Load
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
                .overlay(
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                )
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .foregroundColor(.accentColor)
        }
    }
}

// MARK: - Keyboard / Text Field Observers
extension ListView {
    private func startTextFieldListeners() {
        NotificationCenter.default.addObserver(
            forName: UITextField.textDidBeginEditingNotification,
            object: nil,
            queue: .main
        ) { _ in
            // A text field begins editing
            isAnyTextFieldActive = true
        }
        
        NotificationCenter.default.addObserver(
            forName: UITextField.textDidEndEditingNotification,
            object: nil,
            queue: .main
        ) { _ in
            // A text field ends editing
            isAnyTextFieldActive = false
        }
    }
    
    private func stopTextFieldListeners() {
        NotificationCenter.default.removeObserver(
            self,
            name: UITextField.textDidBeginEditingNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UITextField.textDidEndEditingNotification,
            object: nil
        )
    }
}

// MARK: - Keyboard Dismissal Helper
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil,
                   from: nil,
                   for: nil)
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

