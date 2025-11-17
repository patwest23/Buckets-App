import SwiftUI

struct UserListView: View {
    let user: SocialUser
    var highlightedItemID: UUID?

    @State private var carouselPresentation: CarouselPresentation?

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
        .fullScreenCover(item: $carouselPresentation) { config in
            FullScreenCarouselView(
                images: config.images,
                initialIndex: config.initialIndex,
                itemName: config.itemTitle,
                isCompleted: config.isCompleted,
                location: config.locationDescription,
                dateCompleted: config.completionDate
            )
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
                        PublicItemRow(item: item) { tappedIndex in
                            let carouselImages = item.imageURLs.map { CarouselImageSource.remote($0.absoluteString) }
                            carouselPresentation = CarouselPresentation(
                                images: carouselImages,
                                initialIndex: tappedIndex,
                                itemTitle: item.title,
                                isCompleted: item.isCompleted,
                                locationDescription: item.locationDescription,
                                completionDate: item.completionDate
                            )
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
    let onImageTap: (Int) -> Void

    private let imageCellSize: CGFloat = 90
    private let spacing: CGFloat = 6

    private var formattedCompletionDate: String? {
        guard let date = item.completionDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .accentColor : .secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)

                    Text(item.blurb)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if formattedCompletionDate != nil || (item.locationDescription?.isEmpty == false) {
                        HStack(spacing: 8) {
                            if let formattedCompletionDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                    Text(formattedCompletionDate)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }

                            if let location = item.locationDescription, !location.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.and.ellipse")
                                    Text(location)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                Spacer()
            }

            if !item.imageURLs.isEmpty {
                imageGrid
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var imageGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(imageCellSize), spacing: spacing), count: 3)

        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(Array(item.imageURLs.enumerated()), id: \.offset) { index, url in
                RemoteGridThumbnail(url: url)
                    .onTapGesture {
                        onImageTap(index)
                    }
            }
        }
    }
}

private struct RemoteGridThumbnail: View {
    let url: URL

    private let size: CGFloat = 90

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: size, height: size)
                    .background(Color(.systemGray5))
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            case .failure:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.secondary)
                    )
                    .frame(width: size, height: size)
            @unknown default:
                EmptyView()
                    .frame(width: size, height: size)
            }
        }
        .cornerRadius(10)
    }
}

private struct CarouselPresentation: Identifiable {
    let id = UUID()
    let images: [CarouselImageSource]
    let initialIndex: Int
    let itemTitle: String
    let isCompleted: Bool
    let locationDescription: String?
    let completionDate: Date?
}

struct UserListView_Previews: PreviewProvider {
    static var previews: some View {
        let user = SocialUser.mockUsers.first!
        NavigationStack {
            UserListView(user: user, highlightedItemID: user.listItems.first?.id)
        }
    }
}
