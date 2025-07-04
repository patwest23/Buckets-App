//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI
import PhotosUI
import FirebaseStorage

struct ListView: View {
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var postViewModel: PostViewModel
    //@EnvironmentObject var followViewModel: FollowViewModel
    @EnvironmentObject var friendsViewModel: FriendsViewModel // ✅ Add this to ListView
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    
    /// NEW: Consume the existing FeedViewModel from environment
    @EnvironmentObject var feedViewModel: FeedViewModel
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

    // Control for showing the FeedView
    @State private var showFeed = false
    @State private var showUserSearch = false
    @State private var showFriends = false

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
                            .task {
                                loadItems()
                                startTextFieldListeners()
                                friendsViewModel.startListeningToFriendChanges()
                            }
                            .navigationBarTitleDisplayMode(.inline)
                            .onDisappear {
                                newlyCreatedItemID = nil
                                UIApplication.shared.endEditing()
                                isAnyTextFieldActive = false
                                stopTextFieldListeners()
                            }
                            // Navigate to Profile
                            .navigationDestination(isPresented: $showProfileView) {
                                ProfileView(onboardingViewModel: onboardingViewModel)
                                    .environmentObject(userViewModel)
                                    .environmentObject(bucketListViewModel)
                                    .environmentObject(postViewModel)
                            }
                            // Navigate to Feed
                            .navigationDestination(isPresented: $showFeed) {
                                /// Use the existing environment object `feedViewModel`
                                FeedView()
                                    .environmentObject(userViewModel)
                                    .environmentObject(feedViewModel)
                                    .environmentObject(postViewModel)
                            }
                            // Navigate to the User Search View
                            .navigationDestination(isPresented: $showUserSearch) {
                                FriendsView()
                                    .environmentObject(userViewModel)
                                    .environmentObject(friendsViewModel)
                            }
                            // Navigate to Detail => PASS A COPY of the item
                            .navigationDestination(item: $selectedItem) { item in
                                // Only show DetailItemView after tapping chevron (not always)
                                if let _ = selectedItem {
                                    DetailItemView(item: item)
                                        .environmentObject(bucketListViewModel)
                                        .environmentObject(postViewModel)
                                        .environmentObject(userViewModel)
                                }
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
                            // Scroll to changed ID (Swift 5.9+ two-parameter .onChange)
                            .onChange(of: scrollToId, { oldVal, newVal in
                                guard let newVal = newVal else { return }
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(newVal, anchor: .bottom)
                                }
                            })
                    }
                }
                // Move toolbar here: apply to ZStack instead of inside ScrollViewReader/contentView
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Text("Bucket List")
                            .font(.headline)
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        if isAnyTextFieldActive {
                            Button("Done") {
                                UIApplication.shared.endEditing()
                                isAnyTextFieldActive = false
                                removeBlankItems()
                            }
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        } else {
                            Button {
                                showProfileView = true
                            } label: {
                                HStack(spacing: 8) {
                                    Text(userViewModel.user?.username?.isEmpty == false
                                         ? userViewModel.user!.username!
                                         : "@User")
                                        .font(.headline)
                                    profileImageView
                                        .frame(width: 35, height: 35)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        HStack {
                            Button {
                                showFeed = true
                            } label: {
                                Image(systemName: "house.fill")
                            }
                            Spacer()
                            addButton
                            Spacer()
                            Button {
                                showFriends = true
                            } label: {
                                Image(systemName: "person.2.fill")
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                // Navigation to FriendsView
                .navigationDestination(isPresented: $showFriends) {
                    FriendsView()
                        .environmentObject(userViewModel)
                        .environmentObject(friendsViewModel) // ✅ use the existing instance
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
            ForEach(bucketListViewModel.items.indices, id: \.self) { index in
                rowView(for: $bucketListViewModel.items[index])
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

            // Guard clause to ensure userId is not nil or empty
            guard let userId = userViewModel.user?.id, !userId.isEmpty else {
                print("❌ Cannot create item: userId is nil or empty")
                return
            }
            // Create new item
            let newItem = ItemModel(userId: userId)
            Task {
                await bucketListViewModel.addOrUpdateItem(newItem)
            }

            newlyCreatedItemID = newItem.id

            Task {
                // Wait for SwiftUI to insert row
                await Task.yield()
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
    
    
    // MARK: - Load
    private func loadItems() {
        Task {
            isLoading = true
            await bucketListViewModel.loadItems()

            // 🚨 Delay to ensure items are ready for navigation
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            isLoading = false
        }
    }
    
    // MARK: - Profile Image Helper
    @ViewBuilder
    private var profileImageView: some View {
        if let urlString = userViewModel.user?.profileImageUrl,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image.resizable()
                case .failure:
                    Image(systemName: "person.fill")
                        .resizable()
                @unknown default:
                    Image(systemName: "person.fill")
                        .resizable()
                }
            }
            .scaledToFill()
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
            )
        } else {
            Image(systemName: "person.fill")
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
            isAnyTextFieldActive = true
        }
        
        NotificationCenter.default.addObserver(
            forName: UITextField.textDidEndEditingNotification,
            object: nil,
            queue: .main
        ) { _ in
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
                imageUrls: ["https://picsum.photos/400/400?random=1"]
            ),
            ItemModel(
                userId: "mockUID",
                name: "Learn Guitar",
                completed: false
            )
        ]
        // Optionally preload the mock image into the image cache for testing display
        if let mockImage = UIImage(systemName: "photo") {
            ImageCache.shared.setImage(mockImage, forKey: "https://picsum.photos/400/400?random=1")
        }

        let mockUserVM = UserViewModel()
        mockUserVM.user = UserModel(
            documentId: "mockUID",
            email: "test@example.com",
            profileImageUrl: "https://picsum.photos/100",
            username: "@previewUser"
        )
        let mockFeedVM = FeedViewModel()
        let mockPostVM = PostViewModel()

        return Group {
            // 1) Empty scenario
            NavigationStack {
                ListView()
                    .environmentObject(mockListVMEmpty)
                    .environmentObject(mockUserVM)
                    .environmentObject(mockFeedVM)
                    .environmentObject(mockPostVM)
                    .environmentObject(FriendsViewModel.mock)
                    .environmentObject(OnboardingViewModel())
            }
            .previewDisplayName("ListView - Empty")

            // 2) Populated scenario
            NavigationStack {
                ListView(previewMode: true)
                    .environmentObject(mockListVMWithItems)
                    .environmentObject(mockUserVM)
                    .environmentObject(mockFeedVM)
                    .environmentObject(mockPostVM)
                    .environmentObject(FriendsViewModel.mock)
                    .environmentObject(OnboardingViewModel())
            }
            .previewDisplayName("ListView - With Items (3 real images)")
        }
    }
}



// MARK: - Move bindingForItem and rowView inside ListView struct
extension ListView {
    // MARK: - Item Row ViewBuilder for type-checking performance
    @ViewBuilder
    private func rowView(for item: Binding<ItemModel>) -> some View {
        ItemRowView(
            item: item,
            newlyCreatedItemID: newlyCreatedItemID,
            onEmptyNameLostFocus: {
                deleteItemIfEmpty(item.wrappedValue)
            },
            onNavigateToDetail: {
                print("[ListView] selectedItem set: \(item.wrappedValue.name)")
                bucketListViewModel.currentEditingItem = item.wrappedValue
                selectedItem = item.wrappedValue
            }
        )
        .environmentObject(bucketListViewModel)
        .onAppear {
            print("[DetailItemView Trigger] Appeared item: \(item.wrappedValue.name)")
            print("[ListView] Total items in view model: \(bucketListViewModel.items.count)")
            if let match = bucketListViewModel.items.first(where: { $0.id == item.wrappedValue.id }) {
                print("[ListView] ✅ Found matching item: \(match.name)")
            } else {
                print("[ListView] ❌ Could not find item in items array")
            }
            Task {
                await bucketListViewModel.prefetchImages(for: item.wrappedValue)
            }
        }
        .onTapGesture {
            print("[ListView] User tapped on item row: \(item.wrappedValue.name)")
        }
        .listRowSeparator(.hidden)
        .id(item.wrappedValue.id)
    }
}
