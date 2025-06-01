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
    @State private var item: ItemModel?
    
    let post: PostModel
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let item = item {
                // 1) Top row: optional checkmark + item name
                HStack(spacing: 4) {
                    if item.completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    Text("\(post.authorUsername ?? "@\(post.authorId)") \(item.name)")
                        .font(.headline)
                        .foregroundColor(dynamicTextColor)
                    Spacer()
                }

                // 2) Image carousel (or fallback)
                if item.imageUrls.isEmpty == false {
                    TabView {
                        ForEach(item.imageUrls, id: \.self) { urlStr in
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

                // 3) Username + Caption
                if let caption = post.caption, !caption.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(post.authorUsername ?? "@\(post.authorId)")
                            .fontWeight(.semibold)
                        Text(caption)
                    }
                    .foregroundColor(dynamicTextColor)
                    .padding(.vertical, 8)
                }

                // 4) Like row
                HStack(spacing: 16) {
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                            Text("Like (\(post.likedBy.count))")
                        }
                    }
                    .foregroundColor(dynamicTextColor)

                    Spacer()
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading item for post...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(height: 350)
                .frame(maxWidth: .infinity)
            }
        }
        .task {
            print("[FeedRowView] Fetching item for postId: \(post.id ?? "nil") from user \(post.authorId) for itemId: \(post.itemId)")
            let fetchedItem = await postViewModel.fetchItem(for: post)
            if let fetchedItem {
                print("[FeedRowView] ✅ Successfully fetched item: \(fetchedItem.name)")
                item = fetchedItem
            } else {
                print("[FeedRowView] ❌ Failed to fetch item for postId: \(post.id ?? "nil")")
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
            type: .completed,
            timestamp: Date(),
            caption: "Had an amazing trip to Tokyo!",
            taggedUserIds: ["userXYZ"],
            visibility: nil,
            likedBy: ["user123", "user456"],
            itemImageUrls: [
                "https://picsum.photos/400/400?random=1",
                "https://picsum.photos/400/400?random=2"
            ]
        )
        
        return Group {
            NavigationStack {
                FeedRowView(
                    post: samplePost,
                    onLike: {
                        print("[Preview] Liked post \(samplePost.id ?? "nil")")
                    }
                )
                .environmentObject(postVM)
            }
            .previewDisplayName("FeedRowView - MVP Completed Item w/ Multiple Images")
            
            NavigationStack {
                // A variant with no images, incomplete item
                let noImagesPost = PostModel(
                    id: "post_002",
                    authorId: "userXYZ",
                    authorUsername: "@samantha",
                    itemId: "item_202",
                    type: .added,
                    timestamp: Date(),
                    caption: "No photos yet, but can't wait!",
                    taggedUserIds: [],
                    visibility: nil,
                    likedBy: [],
                    itemImageUrls: []
                )
                
                FeedRowView(
                    post: noImagesPost,
                    onLike: {
                        print("[Preview] Liked post \(noImagesPost.id ?? "nil")")
                    }
                )
                .environmentObject(postVM)
            }
            .previewDisplayName("FeedRowView - MVP Incomplete Item, No Images")
        }
    }
}
#endif
