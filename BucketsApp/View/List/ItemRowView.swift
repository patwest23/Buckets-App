//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    @Binding var item: ItemModel

    let newlyCreatedItemID: UUID?
    let onEmptyNameLostFocus: (() -> Void)?
    let onNavigateToDetail: (() -> Void)?
    let focusedItemID: FocusState<UUID?>.Binding

    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var postViewModel: PostViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showFullScreenGallery = false

    private let imageHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: BucketTheme.mediumSpacing) {
            topRow
            carouselView
            iconsRow
            captionRow
        }
        .bucketCard()
        .contentShape(Rectangle())
        .onAppear {
            print("[ItemRowView] onAppear: \(item.name) (id: \(item.id)) wasShared: \(item.wasShared)")
            if item.id == newlyCreatedItemID {
                focusedItemID.wrappedValue = item.id
            }
            Task {
                await bucketListViewModel.prefetchImages(for: item)
            }
        }
        .onChange(of: bucketListViewModel.allImageUrls(for: item), initial: false) {
            Task {
                await bucketListViewModel.prefetchImages(for: item)
            }
        }
    }

    private var topRow: some View {
        HStack(spacing: BucketTheme.mediumSpacing) {
            Button(action: toggleCompleted) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(item.completed ? BucketTheme.primary : BucketTheme.subtleText(for: colorScheme))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                            .fill(BucketTheme.surface(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                            .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.completed ? "Mark item as incomplete" : "Mark item as complete")

            TextField("Name your bucket dream", text: bindingForName(), onCommit: handleOnSubmit)
                .font(.headline)
                .foregroundColor(.primary)
                .focused(focusedItemID, equals: item.id)
                .submitLabel(.done)
                .bucketTextField(systemImage: item.completed ? "checkmark.seal.fill" : "sparkles")

            Button {
                onNavigateToDetail?()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(BucketTheme.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                            .fill(BucketTheme.surface(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                            .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                    )
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Open item details")
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
    }

    private var carouselView: some View {
        Group {
            if item.completed {
                let urls = bucketListViewModel.allImageUrls(for: item)
                if !urls.isEmpty {
                    TabView {
                        ForEach(urls, id: \.self) { urlStr in
                            if let image = ImageCache.shared.image(forKey: urlStr) {
                                carouselImageView(for: image)
                            } else {
                                ProgressView()
                                    .frame(height: imageHeight)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                            .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                    )
                    .shadow(color: BucketTheme.shadow(for: colorScheme), radius: 8, x: 0, y: 6)
                }
            }
        }
    }

    private var iconsRow: some View {
        Group {
            if item.completed {
                HStack(spacing: BucketTheme.mediumSpacing) {
                    if item.wasShared {
                        Image(systemName: "megaphone.fill")
                            .font(.caption)
                            .foregroundStyle(BucketTheme.secondary)
                    }

                    if item.likedBy.count > 0 {
                        Label("\(item.likedBy.count)", systemImage: "heart.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.red)
                    }

                    if item.completed {
                        Label {
                            Text(formatDate(item.dueDate ?? Date()))
                                .font(.caption)
                                .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                        } icon: {
                            Image(systemName: "checkmark.seal")
                                .foregroundColor(.green)
                        }
                    }
                    if let location = item.location?.address, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var captionRow: some View {
        Group {
            if item.completed, let caption = item.caption, !caption.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: BucketTheme.smallSpacing) {
                    let username = bucketListViewModel.getUser(for: item.userId)?.username ?? "@\(item.userId.prefix(6))"
                    Text(username)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(caption)
                        .font(.callout)
                        .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func carouselImageView(for uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: imageHeight)
            .clipped()
            .onTapGesture {
                showFullScreenGallery = true
            }
    }

    // MARK: - Helpers
    private func toggleCompleted() {
        var updated = item
        updated.completed.toggle()

        if updated.completed {
            updated.dueDate = Date()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            updated.dueDate = nil
        }

        Task {
            await bucketListViewModel.addOrUpdateItem(updated, postViewModel: postViewModel)
        }
    }

    private func bindingForName() -> Binding<String> {
        Binding<String>(
            get: {
                print("📌 ItemRowView likeCount for \(item.name): \(item.likedBy.count), likedBy: \(item.likedBy.count)")
                return item.name
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                var edited = item
                edited.name = newValue

                if !trimmed.isEmpty {
                    Task {
                        await bucketListViewModel.addOrUpdateItem(edited, postViewModel: postViewModel)
                    }
                }
                item = edited
            }
        )
    }

    private func handleOnSubmit() {
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            onEmptyNameLostFocus?()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }

    init(
        item: Binding<ItemModel>,
        newlyCreatedItemID: UUID?,
        onEmptyNameLostFocus: (() -> Void)?,
        onNavigateToDetail: (() -> Void)?,
        focusedItemID: FocusState<UUID?>.Binding
    ) {
        self._item = item
        self.newlyCreatedItemID = newlyCreatedItemID
        self.onEmptyNameLostFocus = onEmptyNameLostFocus
        self.onNavigateToDetail = onNavigateToDetail
        self.focusedItemID = focusedItemID
    }
}

// MARK: - Preview
struct ItemRowView_Previews: PreviewProvider {
    @FocusState static var previewFocusID: UUID?

    static var previews: some View {
        let sampleItem = ItemModel(
            userId: "testUser",
            name: "Sample Bucket List Item",
            description: "Go skydiving over the Grand Canyon.",
            dueDate: Date(),
            location: Location(latitude: 37.7749, longitude: -122.4194, address: "San Francisco"),
            completed: true,
            imageUrls: [
                "https://via.placeholder.com/400",
                "https://via.placeholder.com/401",
                "https://via.placeholder.com/402"
            ],
            likedBy: ["user1", "user2"],
            caption: "This was the most unforgettable day ever!",
            hasPostedAddEvent: true,
            hasPostedCompletion: true,
            hasPostedPhotos: true,
            wasShared: true
        )

        let mockListVM = ListViewModel()
        let previewUser = UserModel(documentId: "testUser", email: "test@example.com", username: "@patrick1")
        mockListVM.seedCachedUser(previewUser, for: "testUser")

        for url in sampleItem.imageUrls {
            if let image = UIImage(systemName: "photo") {
                ImageCache.shared.setImage(image, forKey: url)
            }
        }

        return Group {
            ItemRowView(
                item: .constant(sampleItem),
                newlyCreatedItemID: nil,
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") },
                onNavigateToDetail: { print("Navigate to Detail View") },
                focusedItemID: $previewFocusID
            )
            .environmentObject(mockListVM)
            .environmentObject(UserViewModel())
            .environmentObject(PostViewModel())
            .environmentObject(OnboardingViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Light Mode")

            ItemRowView(
                item: .constant(sampleItem),
                newlyCreatedItemID: nil,
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") },
                onNavigateToDetail: { print("Navigate to Detail View") },
                focusedItemID: $previewFocusID
            )
            .environmentObject(mockListVM)
            .environmentObject(UserViewModel())
            .environmentObject(PostViewModel())
            .environmentObject(OnboardingViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
