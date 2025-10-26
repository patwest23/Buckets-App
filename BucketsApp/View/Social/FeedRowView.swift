//
//  FeedRowView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct FeedRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var userViewModel: UserViewModel

    @Binding var post: PostModel
    let itemSummary: ItemSummary?

    let onLike: @MainActor (PostModel) async -> Void

    private var isLikedByCurrentUser: Bool {
        guard let currentUserId = userViewModel.user?.id else { return false }
        return post.likedBy.contains(currentUserId)
    }

    private var completedDateString: String? {
        guard let summary = itemSummary, summary.completed, let date = summary.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BucketTheme.mediumSpacing) {
            header
            mediaCarousel
            interactionRow
            authorRow
        }
        .bucketCard()
    }

    private var header: some View {
        HStack(spacing: BucketTheme.smallSpacing) {
            Image(systemName: "sparkles")
                .foregroundStyle(BucketTheme.secondary)
            Text(itemSummary?.name ?? post.itemName ?? "Untitled Post")
                .font(.headline.weight(.semibold))
            Spacer()
        }
    }

    @ViewBuilder
    private var mediaCarousel: some View {
        if !post.itemImageUrls.isEmpty {
            TabView {
                ForEach(post.itemImageUrls, id: \.self) { urlStr in
                    FeedRowImageView(urlStr: urlStr)
                        .clipShape(RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                                .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                        )
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 280)
        } else {
            RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                .fill(BucketTheme.surface(for: colorScheme))
                .frame(height: 220)
                .overlay(
                    VStack(spacing: BucketTheme.smallSpacing) {
                        Image(systemName: "photo")
                        Text("No images shared yet")
                            .font(.caption)
                            .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                        .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                )
        }
    }

    private var interactionRow: some View {
        HStack(spacing: BucketTheme.mediumSpacing) {
            Button(action: {
                let currentPost = post
                Task { @MainActor in await onLike(currentPost) }
            }) {
                HStack(spacing: BucketTheme.smallSpacing) {
                    Image(systemName: isLikedByCurrentUser ? "heart.fill" : "heart")
                        .font(.headline)
                    Text("\(post.likedBy.count)")
                        .font(.headline)
                }
                .foregroundStyle(isLikedByCurrentUser ? Color.white : .primary)
                .padding(.horizontal, BucketTheme.mediumSpacing)
                .padding(.vertical, BucketTheme.smallSpacing + 2)
                .background(
                    RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                        .fill(
                            isLikedByCurrentUser
                            ? LinearGradient(
                                colors: [BucketTheme.primary, BucketTheme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : BucketTheme.surface(for: colorScheme)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                        .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                )
            }
            .buttonStyle(.plain)

            if let completed = completedDateString {
                Label(completed, systemImage: "checkmark.seal")
                    .font(.footnote)
                    .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
            }
            Spacer()
        }
    }

    private var authorRow: some View {
        HStack(alignment: .center, spacing: BucketTheme.smallSpacing) {
            if let profileUrl = post.authorProfileImageUrl, let url = URL(string: profileUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .resizable().scaledToFit()
                            .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                )
            }
            Text(post.authorUsername ?? "@\(post.authorId)")
                .font(.callout.weight(.semibold))
            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(.callout)
                    .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
            }
        }
    }
}

struct FeedRowImageView: View {
    let urlStr: String

    var body: some View {
        AsyncImage(url: URL(string: urlStr)) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                    ProgressView()
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure(_):
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipped()
    }
}

#if DEBUG
@MainActor
struct FeedRowView_Previews: PreviewProvider {
    static var previews: some View {
        let postVM = PostViewModel()

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

        return FeedRowView(
            post: .constant(samplePost),
            itemSummary: nil,
            onLike: { _ in }
        )
        .environmentObject(mockUserVM)
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
