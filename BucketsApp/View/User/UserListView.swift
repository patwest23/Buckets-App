import SwiftUI

struct UserListView: View {
    let user: SocialUser
    var highlightedItemID: UUID?

    @State private var selectedImage: RemoteImageToken?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    listSection
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(user.username)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard let targetID = highlightedItemID else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeInOut) {
                        proxy.scrollTo(targetID, anchor: .top)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedImage) { token in
            RemoteImageViewer(token: token)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                ProfileAvatarView(
                    imageURL: user.profileImageURL,
                    placeholderSystemImage: user.avatarSystemImage,
                    size: 96
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(user.displayName)
                        .font(.title2.bold())
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let days = user.stats.daysSinceLastCompletion {
                        Text("Last completed \(days) d ago")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            HStack(spacing: 16) {
                statCard(title: "Total", value: user.stats.total)
                statCard(title: "Completed", value: user.stats.completed)
                statCard(title: "Open", value: user.stats.open)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bucket list")
                .font(.headline)
                .foregroundColor(.secondary)

            if user.listItems.isEmpty {
                ContentUnavailableView(
                    "Nothing yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("This list is still under wraps.")
                )
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(user.listItems) { item in
                        PublicItemRow(item: item) { token in
                            selectedImage = token
                        }
                        .id(item.id)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(highlightedItemID == item.id ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
        }
    }

    private func statCard(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title3.bold())
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}

private struct PublicItemRow: View {
    let item: SocialBucketItem
    let onImageTap: (RemoteImageToken) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .accentColor : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.blurb)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if let url = item.imageURL {
                Button {
                    onImageTap(RemoteImageToken(url: url))
                } label: {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().frame(maxWidth: .infinity, minHeight: 140)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipped()
                                .cornerRadius(14)
                        case .failure:
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.systemGray5))
                                .frame(height: 180)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "wifi.slash")
                                        Text("Image unavailable")
                                            .font(.footnote)
                                    }
                                    .foregroundColor(.secondary)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct RemoteImageToken: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
}

private struct RemoteImageViewer: View {
    let token: RemoteImageToken
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: token.url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                        Text("Could not load image")
                    }
                    .foregroundColor(.white)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

struct UserListView_Previews: PreviewProvider {
    static var previews: some View {
        let user = SocialUser.mockUsers.first!
        NavigationStack {
            UserListView(user: user, highlightedItemID: user.listItems.first?.id)
        }
    }
}
