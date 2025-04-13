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
    
    // Styling constants
    private let cardCornerRadius: CGFloat = 12
    private let cardShadowColor = Color.black.opacity(0.1)
    private let cardShadowRadius: CGFloat = 4
    
    var body: some View {
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
                // (Assuming postViewModel loads only the current user’s posts)
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
        let followingCount = userViewModel.user?.following.count ?? 0
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
                statCard(emoji: "👥",
                         title: "Following",
                         value: "\(followingCount)",
                         color: .blue)
                
                statCard(emoji: "🙋‍♂️",
                         title: "Followers",
                         value: "\(followersCount)",
                         color: .green)
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
    
    // MARK: - Posts Section
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Posts")
                .font(.headline)
                .padding(.horizontal)
            
            if postViewModel.posts.isEmpty {
                Text("No posts yet!")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.horizontal)
            } else {
                // Display each post in a `FeedRowView`
                ForEach(postViewModel.posts) { post in
                    FeedRowView(
                        post: post,
                        onLike: {
                            Task {
                                // If you have a toggleLike method in postViewModel, call it here
                                // e.g. await postViewModel.toggleLike(post)
                            }
                        }
                    )
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 8)
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
        
        // Example bucket items for the stats
        mockListVM.items = [
            ItemModel(userId: "abc", name: "Bucket 1", completed: false),
            ItemModel(userId: "abc", name: "Bucket 2", completed: true)
        ]
        
        // Create a mock PostViewModel with some sample posts
        let mockPostVM = PostViewModel()
        
        // Provide 3 sample posts in chronological order
        mockPostVM.posts = [
            PostModel(
                id: "post_001",
                authorId: "abc",
                itemId: "item001",
                timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
                caption: "Had an amazing trip to NYC!",
                taggedUserIds: [],
                likedBy: ["userXYZ"],
                
                // Embedded item data
                itemName: "Visit NYC",
                itemCompleted: true,
                itemLocation: Location(latitude: 40.7128, longitude: -74.0060, address: "New York, NY"),
                itemDueDate: Date().addingTimeInterval(-86400), // completed 1 day ago
                itemImageUrls: ["https://picsum.photos/400/400?random=1"]
            ),
            PostModel(
                id: "post_002",
                authorId: "abc",
                itemId: "item002",
                timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
                caption: "Finally finished my painting class!",
                taggedUserIds: [],
                likedBy: [],
                
                itemName: "Painting Masterclass",
                itemCompleted: true,
                itemLocation: nil,
                itemDueDate: Date().addingTimeInterval(-172800), // 2 days ago
                itemImageUrls: ["https://picsum.photos/400/400?random=2", "https://picsum.photos/400/400?random=3"]
            ),
            PostModel(
                id: "post_003",
                authorId: "abc",
                itemId: "item003",
                timestamp: Date().addingTimeInterval(-10800), // 3 hours ago
                caption: "No images, but so excited about this!",
                taggedUserIds: [],
                likedBy: ["userABC", "user123"],
                
                itemName: "Future Item",
                itemCompleted: false,
                itemLocation: nil,
                itemDueDate: nil,
                itemImageUrls: []
            )
        ]
        
        return Group {
            // Light Mode
            NavigationView {
                ProfileView()
                    .environmentObject(mockOnboardingVM)
                    .environmentObject(mockListVM)
                    .environmentObject(mockUserVM)
                    .environmentObject(mockPostVM)  // <-- Provide mock posts here
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








