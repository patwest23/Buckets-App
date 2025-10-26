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
    @EnvironmentObject var syncCoordinator: SyncCoordinator
    // Loading / detail
    @State private var isLoading = true
    @State private var showProfileView = false
    @State private var selectedItem: ItemModel?
    @State private var itemToDelete: ItemModel?

    // The ID of the item we want to scroll to in ScrollViewReader
    @State private var scrollToId: UUID? = nil
    // Store the ScrollViewProxy for programmatic scrolling
    @State private var scrollProxy: ScrollViewProxy? = nil

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

    // MARK: - Focus State for Item Rows
    @FocusState private var focusedItemID: UUID?

    // Show refresh confirmation overlay
    @State private var showRefreshConfirmation = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            if #available(iOS 17.0, *) {
                ZStack(alignment: .top) {
                    BucketTheme.backgroundGradient(for: colorScheme)
                        .ignoresSafeArea()

                    ScrollViewReader { proxy in
                        contentView
                            .onAppear {
                                self.scrollProxy = proxy
                            }
                            .refreshable {
                                await loadItems()
                                await syncCoordinator.refreshFeedAndSyncLikes()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    showRefreshConfirmation = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        showRefreshConfirmation = false
                                    }
                                }
                            }
                            .task {
                                bucketListViewModel.registerDefaultPostViewModel(postViewModel)
                                bucketListViewModel.restoreCachedItems()
                                await loadItems()
                                await syncCoordinator.refreshFeedAndSyncLikes()
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
                                FeedView()
                                    .environmentObject(userViewModel)
                                    .environmentObject(feedViewModel)
                                    .environmentObject(postViewModel)
                                    .environmentObject(bucketListViewModel)
                                    .environmentObject(friendsViewModel)
                                    .environmentObject(syncCoordinator)
                            }
                            // Navigate to the User Search View
                            .navigationDestination(isPresented: $showUserSearch) {
                                FriendsView()
                                    .environmentObject(userViewModel)
                                    .environmentObject(friendsViewModel)
                                    .environmentObject(syncCoordinator)

                            }
                            // Navigate to Detail => PASS A COPY of the item
                            .navigationDestination(item: $selectedItem) { item in
                                if let _ = selectedItem {
                                    DetailItemView(item: item, listViewModel: bucketListViewModel, postViewModel: postViewModel)
                                        .environmentObject(bucketListViewModel)
                                        .environmentObject(postViewModel)
                                        .environmentObject(userViewModel)
                                        .environmentObject(syncCoordinator)
                                }
                            }
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
                            .onChange(of: scrollToId, initial: false) { _, newVal in
                                guard let newVal = newVal else { return }
                                if let proxy = scrollProxy {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        proxy.scrollTo(newVal, anchor: .center)
                                    }
                                }
                            }
                    }

                    if showRefreshConfirmation {
                        HStack(spacing: BucketTheme.smallSpacing) {
                            Text("✨")
                            Text("List Updated")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, BucketTheme.mediumSpacing)
                        .padding(.vertical, BucketTheme.smallSpacing)
                        .background(
                            Capsule()
                                .fill(BucketTheme.elevatedSurface(for: colorScheme))
                        )
                        .overlay(
                            Capsule()
                                .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                        )
                        .shadow(color: BucketTheme.shadow(for: colorScheme), radius: 10, x: 0, y: 4)
                        .padding(.top, BucketTheme.largeSpacing)
                    }
                }
                .bucketToolbarBackground()
                .onTapGesture {
                    UIApplication.shared.endEditing()
                    focusedItemID = nil
                }
                .navigationDestination(isPresented: $showFriends) {
                    FriendsView()
                        .environmentObject(userViewModel)
                        .environmentObject(friendsViewModel)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear
                        .frame(height: 70)
                        .allowsHitTesting(false)
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text("Your Buckets")
                                .font(.headline.weight(.semibold))
                            Text("Dream it. Do it. Share it.")
                                .font(.caption)
                                .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: BucketTheme.smallSpacing) {
                            Button {
                                showFeed = true
                            } label: {
                                Image(systemName: "sparkles.rectangle.stack")
                            }
                            .buttonStyle(BucketIconButtonStyle())

                            Button {
                                showProfileView = true
                            } label: {
                                profileImageView
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(BucketIconButtonStyle())

                            if isAnyTextFieldActive {
                                Button("Done") {
                                    UIApplication.shared.endEditing()
                                    focusedItemID = nil
                                }
                                .font(.headline)
                                .buttonStyle(BucketSecondaryButtonStyle())
                            }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    bottomActionBar
                        .padding(.horizontal, BucketTheme.largeSpacing)
                        .padding(.bottom, BucketTheme.largeSpacing)
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
            Section {
                ForEach($bucketListViewModel.items) { $item in
                    rowView(for: $item)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(
                            EdgeInsets(
                                top: BucketTheme.smallSpacing,
                                leading: BucketTheme.mediumSpacing,
                                bottom: BucketTheme.smallSpacing,
                                trailing: BucketTheme.mediumSpacing
                            )
                        )
                }
            }
            .listSectionSpacing(BucketTheme.smallSpacing)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.easeInOut, value: bucketListViewModel.items)
    }

    // MARK: - UI States
    private var loadingView: some View {
        VStack(spacing: BucketTheme.mediumSpacing) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Gathering your dreams…")
                .font(.callout)
                .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
        }
        .padding()
        .bucketCard()
        .padding(.horizontal, BucketTheme.largeSpacing)
        .padding(.top, BucketTheme.largeSpacing)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: BucketTheme.mediumSpacing) {
            Text("🎯")
                .font(.system(size: 48))
            Text("Let’s start your first bucket!")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Tap the plus to capture something magical you want to experience.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
        }
        .padding(.vertical, BucketTheme.largeSpacing)
        .padding(.horizontal, BucketTheme.largeSpacing)
        .bucketCard()
        .padding(.horizontal, BucketTheme.largeSpacing)
        .padding(.top, BucketTheme.largeSpacing)
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
                await bucketListViewModel.addOrUpdateItem(newItem, postViewModel: postViewModel)
            }

            newlyCreatedItemID = newItem.id

            Task {
                // Wait for SwiftUI to insert row
                await Task.yield()
                scrollToId = newItem.id
            }
        } label: {
            Label("Add Dream", systemImage: "plus")
                .font(.headline)
        }
        .buttonStyle(BucketPrimaryButtonStyle())
        .shadow(color: BucketTheme.shadow(for: colorScheme), radius: 12, x: 0, y: 6)
    }

    private var bottomActionBar: some View {
        HStack(spacing: BucketTheme.mediumSpacing) {
            Button {
                showFeed = true
            } label: {
                Label("Feed", systemImage: "sparkles")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(BucketIconButtonStyle())

            addButton

            Button {
                showUserSearch = true
            } label: {
                Label("Friends", systemImage: "person.2.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(BucketIconButtonStyle())
        }
        .padding(.vertical, BucketTheme.smallSpacing)
        .padding(.horizontal, BucketTheme.mediumSpacing)
        .background(BucketTheme.elevatedSurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous)
                .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
        )
        .shadow(color: BucketTheme.shadow(for: colorScheme), radius: 18, x: 0, y: 10)
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
    private func loadItems() async {
        isLoading = true
        await bucketListViewModel.loadItems()
        isLoading = false
    }
    
    // MARK: - Profile Image Helper
    @ViewBuilder
    private var profileImageView: some View {
        if let data = userViewModel.profileImageData,
           !data.isEmpty,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                )
        } else if let urlString = userViewModel.user?.profileImageUrl,
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
            },
            focusedItemID: $focusedItemID
        )
        .environmentObject(bucketListViewModel)
        .environmentObject(postViewModel)
        .onAppear {
            print("[ItemRowView] onAppear: \(item.wrappedValue.name) (id: \(item.wrappedValue.id)) wasShared: \(item.wrappedValue.wasShared), likeCount: \(item.wrappedValue.likeCount)")
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


