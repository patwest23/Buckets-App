//
//  ProfilePostRowView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/4/25.
//

import SwiftUI

struct ProfilePostRowView: View {
    let post: PostModel
    let injectedItem: ItemModel?
    @EnvironmentObject var postViewModel: PostViewModel

    @State private var item: ItemModel?
    @State private var isEditSheetPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let item = item {
                // 1) Top row: checkmark + item name + edit menu
                HStack(spacing: 4) {
                    if item.completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    Text(item.name)
                        .font(.headline)
                    Spacer()
                    Menu {
                        Button(role: .destructive) {
                            Task {
                                await postViewModel.deletePost(post)
                            }
                        } label: {
                            Label("Delete Post", systemImage: "trash")
                        }

                        Button {
                            isEditSheetPresented = true
                        } label: {
                            Label("Edit Post", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                    }
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

                // 3) Caption
                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.subheadline)
                        .padding(.vertical, 8)
                }

                // 4) Timestamp
                Text(timeAgoString(for: post.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .sheet(isPresented: $isEditSheetPresented) {
            ProfilePostEditView(post: post)
                .environmentObject(postViewModel)
        }
        .task {
            if let injectedItem = injectedItem {
                self.item = injectedItem
            } else {
                print("[ProfilePostRowView] Fetching item for postId: \(post.id ?? "nil") from user \(post.authorId) for itemId: \(post.itemId)")
                let fetchedItem = await postViewModel.fetchItem(for: post)
                if let fetchedItem {
                    print("[ProfilePostRowView] ✅ Successfully fetched item: \(fetchedItem.name)")
                    item = fetchedItem
                } else {
                    print("[ProfilePostRowView] ❌ Failed to fetch item for postId: \(post.id ?? "nil")")
                }
            }
        }
    }

    // Activity display helpers
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
}

#if DEBUG
@MainActor
struct ProfilePostRowView_Previews: PreviewProvider {
    static var previews: some View {
        let postVM = PostViewModel()

        let mockPost = PostModel(
            id: "preview_001",
            authorId: "mockUser",
            authorUsername: "@preview",
            itemId: UUID().uuidString,
            type: .completed,
            timestamp: Date(),
            caption: "Just crossed this off my list!",
            taggedUserIds: [],
            visibility: nil,
            likedBy: [],
            itemImageUrls: [
                "https://picsum.photos/400/400?random=10",
                "https://picsum.photos/400/400?random=11"
            ]
        )

        let mockItem = ItemModel(
            id: UUID(),
            userId: "mockUser", name: "Visit Tokyo",
            completed: true,
            imageUrls: [
                "https://picsum.photos/400/400?random=10",
                "https://picsum.photos/400/400?random=11"
            ]
        )

        return NavigationStack {
            ProfilePostRowView(post: mockPost, injectedItem: mockItem)
                .environmentObject(postVM)
                .padding()
        }
        .previewDisplayName("ProfilePostRowView Preview - Static Mock")
    }
}
#endif
