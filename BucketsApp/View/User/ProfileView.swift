//
//  ProfileView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/13/23.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    
    // ADD THIS: to show the user's own posts
    @EnvironmentObject var postViewModel: PostViewModel
    
    @State private var isPickerPresented = false
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var navigationPath = NavigationPath()
    
    // Styling constants
    private let cardCornerRadius: CGFloat = 12
    private let cardShadowColor = Color.black.opacity(0.1)
    private let cardShadowRadius: CGFloat = 4
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Profile Image + Username
                    profileHeader
                    
                    // MARK: - Stats Dashboard
                    statsDashboard
                    
                    // MARK: - User’s Posts
                    postsSection
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .navigationBarTitle("Profile", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // Hide default nav title text
                    EmptyView()
                }
                // Settings gear icon
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                            .environmentObject(onboardingViewModel)
                            .environmentObject(userViewModel)
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .onAppear {
                // LOAD the user's posts from Firestore
                Task {
                    await postViewModel.loadPosts()
                    await userViewModel.loadCurrentUser() // Add this line to refresh follow data
                }
            }
            .navigationDestination(isPresented: .constant(false)) {
                EmptyView()
            }
        }
    }
}

// MARK: - Subviews
extension ProfileView {
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Tappable profile image
            Button {
                isPickerPresented = true
            } label: {
                if let data = onboardingViewModel.profileImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 4)
                        )
                        .shadow(color: cardShadowColor, radius: 6, x: 0, y: 3)
                } else {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            // Photos picker for changing profile image
            .photosPicker(
                isPresented: $isPickerPresented,
                selection: $selectedImageItem,
                matching: .images
            )
            .onChange(of: selectedImageItem) { oldValue, newValue in
                loadProfileImage(newValue)
            }
            
            // Username or placeholder
            if let handle = onboardingViewModel.user?.username, !handle.isEmpty {
                Text(handle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            } else {
                Text("Username")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Stats Dashboard
    private var statsDashboard: some View {
        let totalCount = listViewModel.items.count
        let completedCount = listViewModel.items.filter { $0.completed }.count
        let incompleteCount = totalCount - completedCount
        
        // Most recent completion date
        let lastCompletedDate = listViewModel.items
            .filter { $0.completed }
            .compactMap { $0.dueDate ?? $0.creationDate }
            .max()
        
        // Days since last completion
        let daysSinceLastCompletion: Int = {
            guard let lastDate = lastCompletedDate else { return 0 }
            let components = Calendar.current.dateComponents([.day], from: lastDate, to: Date())
            return max(0, components.day ?? 0)
        }()
        
        // FOLLOWING / FOLLOWERS
        let followingCount = userViewModel.user?.following?.count ?? 0
        let followersCount = userViewModel.user?.followers?.count ?? 0
        
        return VStack(spacing: 20) {
            
            // 1) First row: total, completed, incomplete
            HStack(spacing: 16) {
                statCard(emoji: "📦", title: "Total",
                         value: "\(totalCount)", color: .blue)
                statCard(emoji: "✅", title: "Completed",
                         value: "\(completedCount)", color: .green)
                statCard(emoji: "🚧", title: "Incomplete",
                         value: "\(incompleteCount)", color: .orange)
            }
            
            // 2) Optional message if no completions
            if completedCount == 0 {
                Text("No items completed yet!")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                // Days since last completion
                HStack(spacing: 16) {
                    statCard(emoji: "⏰",
                             title: "Days Since Last Complete",
                             value: "\(daysSinceLastCompletion)",
                             color: .purple)
                }
            }
            
            // 3) Second row: Following / Followers
            HStack(spacing: 16) {
                NavigationLink {
                    FollowingListView()
                        .environmentObject(userViewModel)
                } label: {
                    statCard(emoji: "👥",
                             title: "Following",
                             value: "\(followingCount)",
                             color: .blue)
                }

                NavigationLink {
                    FollowersListView()
                        .environmentObject(userViewModel)
                } label: {
                    statCard(emoji: "🙋‍♂️",
                             title: "Followers",
                             value: "\(followersCount)",
                             color: .green)
                }
            }
        }
        .padding()
        // "Card" style background
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: 2)
        )
    }
    
    // MARK: - Posts Section / Activity Log
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Log")
                .font(.headline)
                .padding(.horizontal)

            if postViewModel.posts.isEmpty {
                Text("No posts yet!")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.horizontal)
            } else {
                ForEach(postViewModel.posts.sorted(by: { $0.timestamp > $1.timestamp })) { post in
                    ProfilePostRowView(post: post, injectedItem: postViewModel.injectedItems[post.itemId])
                        .environmentObject(postViewModel)
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Activity Log Helpers
    private func activityLabel(for post: PostModel) -> String {
        switch post.type {
        case .added: return "Added item"
        case .completed: return "✅ Completed item"
        case .photos: return "📸 Shared photos"
        }
    }

    private func icon(for type: PostType) -> String {
        switch type {
        case .added: return "plus.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .photos: return "photo.fill.on.rectangle.fill"
        }
    }

    private func color(for type: PostType) -> Color {
        switch type {
        case .added: return .blue
        case .completed: return .green
        case .photos: return .purple
        }
    }

    private func timeAgoString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Single Stat Card
    private func statCard(emoji: String,
                          title: String,
                          value: String,
                          color: Color) -> some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.largeTitle)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Private Helpers
extension ProfileView {
    private func loadProfileImage(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        Task {
            do {
                if let data = try await newItem.loadTransferable(type: Data.self) {
                    await onboardingViewModel.updateProfileImage(with: data)
                }
            } catch {
                print("Error loading image data: \(error)")
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let mockOnboardingVM = OnboardingViewModel()
        let mockListVM = ListViewModel()
        let mockUserVM = UserViewModel()
        let mockPostVM = PostViewModel()

        // Example bucket items for the stats
        mockListVM.items = [
            ItemModel(userId: "abc", name: "Bucket 1", completed: false),
            ItemModel(userId: "abc", name: "Bucket 2", completed: true)
        ]

        // Sample posts
        let posts: [PostModel] = [
            PostModel(
                id: "post_001",
                authorId: "abc",
                authorUsername: "@patrick",
                itemId: "item001",
                type: .completed,
                timestamp: Date().addingTimeInterval(-3600),
                caption: "Had an amazing trip to NYC!",
                taggedUserIds: [],
                likedBy: ["userXYZ"],
                itemImageUrls: ["https://picsum.photos/400/400?random=1"]
            ),
            PostModel(
                id: "post_002",
                authorId: "abc",
                authorUsername: "@patrick",
                itemId: "item002",
                type: .completed,
                timestamp: Date().addingTimeInterval(-7200),
                caption: "Finally finished my painting class!",
                taggedUserIds: [],
                likedBy: [],
                itemImageUrls: ["https://picsum.photos/400/400?random=2", "https://picsum.photos/400/400?random=3"]
            ),
            PostModel(
                id: "post_003",
                authorId: "abc",
                authorUsername: "@patrick",
                itemId: "item003",
                type: .added,
                timestamp: Date().addingTimeInterval(-10800),
                caption: "No images, but so excited about this!",
                taggedUserIds: [],
                likedBy: ["userABC", "user123"],
                itemImageUrls: []
            )
        ]

        mockPostVM.posts = posts

        // Inject mock items into PostViewModel
        for post in posts {
            mockPostVM.injectedItems[post.itemId] = ItemModel(
                id: UUID(),
                userId: post.authorId,
                name: "Mock Item for \(post.itemId)",
                completed: post.type == .completed,
                imageUrls: post.itemImageUrls
            )
        }

        return Group {
            // Light Mode
            NavigationView {
                ProfileView()
                    .environmentObject(mockOnboardingVM)
                    .environmentObject(mockListVM)
                    .environmentObject(mockUserVM)
                    .environmentObject(mockPostVM)
            }
            .previewDisplayName("ProfileView - Light Mode")

            // Dark Mode
            NavigationView {
                ProfileView()
                    .environmentObject(mockOnboardingVM)
                    .environmentObject(mockListVM)
                    .environmentObject(mockUserVM)
                    .environmentObject(mockPostVM)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("ProfileView - Dark Mode")
        }
    }
}
#endif
