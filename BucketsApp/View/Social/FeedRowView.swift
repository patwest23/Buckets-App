//
//  FeedRowView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct FeedRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    
    let post: PostModel
    let item: ItemModel? // NEW: injected from parent
    
    /// Callback for "like"
    let onLike: () -> Void
    
    /// Dynamically choose text color based on light/dark mode
    private var dynamicTextColor: Color {
        colorScheme == .light ? .black : .white
    }
    
    /// If item is completed, format the due date for display
    private var completedDateString: String? {
        guard item?.completed == true, let date = item?.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // No longer need computed property for currentUserId
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // List item name
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
//                print("[FeedRowView] item name: \(item?.name ?? "nil"), post.itemName: \(post.itemName ?? "nil")")
                Text(item?.name ?? post.itemName ?? "Untitled Post")
                    .font(.headline)
                    .bold()
                    .foregroundColor(dynamicTextColor)
            }

            // Image carousel
            if !post.itemImageUrls.isEmpty {
                TabView {
                    ForEach(post.itemImageUrls, id: \.self) { urlStr in
                        FeedRowImageView(urlStr: urlStr)
                            .frame(height: 300)
                            .clipped()
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 300)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 300)
                    .overlay(
                        Text("No images")
                            .foregroundColor(.gray)
                    )
            }

            // Like row with tappable heart and count
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        print("[FeedRowView] Tapping like on post: \(post.id ?? "nil")")
                        await postViewModel.toggleLike(for: post.id ?? "", by: userViewModel.user?.id ?? "")
                    }
                }) {
                    Image(systemName: post.likedBy.contains(userViewModel.user?.id ?? "") ? "heart.fill" : "heart")
                        .foregroundColor(post.likedBy.contains(userViewModel.user?.id ?? "") ? .red : dynamicTextColor)
                }
                Text("\(post.likedBy.count)")
                    .foregroundColor(dynamicTextColor)
                if let completed = completedDateString {
                    Label(completed, systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
            }

            // Username, optional profile image, and optional caption
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let profileUrl = post.authorProfileImageUrl, let url = URL(string: profileUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if phase.error != nil {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .resizable().scaledToFit()
                                .foregroundColor(.gray)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                }
                Text(post.authorUsername ?? "@\(post.authorId)")
                    .fontWeight(.bold)
                    .foregroundColor(dynamicTextColor)
                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .foregroundColor(dynamicTextColor)
                }
            }
        }
    }
}

// MARK: - Helper for loading images
struct FeedRowImageView: View {
    let urlStr: String
    
    var body: some View {
        AsyncImage(url: URL(string: urlStr)) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure(_):
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            @unknown default:
                EmptyView()
            }
        }
        .clipped()
    }
}

#if DEBUG
@MainActor
struct FeedRowView_Previews: PreviewProvider {
    static var previews: some View {
        let postVM = PostViewModel()
        
        // Sample mock post
        let samplePost = PostModel(
            id: "post_001",
            authorId: "userABC",
            authorUsername: "@patrick",
            itemId: "item_101",
            itemImageUrls: [
                "https://picsum.photos/400/400?random=1",
                "https://picsum.photos/400/400?random=2"
            ],
            type: .completed,
            timestamp: Date(),
            caption: "Had an amazing trip to Tokyo!",
            taggedUserIds: ["userXYZ"],
            visibility: nil,
            likedBy: ["user123", "user456"]
        )
        
        let mockUserVM = UserViewModel()
        mockUserVM.user = UserModel(documentId: "user123", email: "test@example.com", username: "@patrick")
        
        return Group {
            NavigationStack {
                FeedRowView(
                    post: samplePost,
                    item: nil,
                    onLike: {
                        print("[Preview] Liked post \(samplePost.id ?? "nil")")
                    }
                )
                .environmentObject(postVM)
                .environmentObject(mockUserVM)
                .environmentObject(ListViewModel())
            }
            .previewDisplayName("FeedRowView - MVP Completed Item w/ Multiple Images")
            
            NavigationStack {
                // A variant with no images, incomplete item
                let noImagesPost = PostModel(
                    id: "post_002",
                    authorId: "userXYZ",
                    authorUsername: "@samantha",
                    itemId: "item_202",
                    itemImageUrls: [],
                    type: .added,
                    timestamp: Date(),
                    caption: "No photos yet, but can't wait!",
                    taggedUserIds: [],
                    visibility: nil,
                    likedBy: []
                )
                
                FeedRowView(
                    post: noImagesPost,
                    item: nil,
                    onLike: {
                        print("[Preview] Liked post \(noImagesPost.id ?? "nil")")
                    }
                )
                .environmentObject(postVM)
                .environmentObject(mockUserVM)
                .environmentObject(ListViewModel())
            }
            .previewDisplayName("FeedRowView - MVP Incomplete Item, No Images")
        }
    }
}
#endif
