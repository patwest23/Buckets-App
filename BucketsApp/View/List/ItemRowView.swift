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
    @State private var showFullScreenGallery = false

    private let cardCornerRadius: CGFloat = 12
    private let cardPadding: CGFloat = 8
    private let cardShadowRadius: CGFloat = 4
    private let spacing: CGFloat = 6
    private let imageHeight: CGFloat = 240
    private let controlCornerRadius: CGFloat = 10
    private let controlHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            topRow
            carouselView
            iconsRow
            captionRow
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1), radius: cardShadowRadius, x: 0, y: 2)
        )
        // Removed blue outline overlay when selected
        .contentShape(Rectangle())
        .onAppear {
            print("[ItemRowView] onAppear: \(item.name) (id: \(item.id)) wasShared: \(item.wasShared)")
            // Autofocus if this is the newly created item
            if item.id == newlyCreatedItemID {
                focusedItemID.wrappedValue = item.id
            }
            Task {
                await bucketListViewModel.prefetchImages(for: item)
            }
        }
        .onChange(of: bucketListViewModel.allImageUrls(for: item)) {
            Task {
                await bucketListViewModel.prefetchImages(for: item)
            }
        }
    }

    private var topRow: some View {
        HStack(spacing: 12) {
            Button(action: toggleCompleted) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundColor(item.completed ? .accentColor : .gray)
                    .frame(width: controlHeight, height: controlHeight)
                    .background(
                        RoundedRectangle(cornerRadius: controlCornerRadius)
                            .fill(Color(UIColor.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: controlCornerRadius)
                            .stroke(item.completed ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.completed ? "Mark item as incomplete" : "Mark item as complete")

            TextField("", text: bindingForName(), onCommit: handleOnSubmit)
                .font(.subheadline)
                .foregroundColor(.primary)
                .focused(focusedItemID, equals: item.id)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: controlCornerRadius)
                        .fill(Color(UIColor.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: controlCornerRadius)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onNavigateToDetail?()
            } label: {
                Image(systemName: "chevron.right")
                    .imageScale(.medium)
                    .foregroundColor(.accentColor)
                    .frame(width: controlHeight, height: controlHeight)
                    .background(
                        RoundedRectangle(cornerRadius: controlCornerRadius)
                            .fill(Color(UIColor.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: controlCornerRadius)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 4)
                }
            }
        }
    }

    private var iconsRow: some View {
        Group {
            if item.completed {
                HStack(spacing: 12) {
                    if item.wasShared {
                        Image(systemName: "megaphone.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if item.likedBy.count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("\(item.likedBy.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Checkmark badge with formatted dueDate
                    if item.completed {
                        Label {
                            Text(formatDate(item.dueDate ?? Date()))
                                .font(.caption)
                                .foregroundColor(.green)
                        } icon: {
                            Image(systemName: "checkmark.seal")
                                .foregroundColor(.green)
                        }
                    }
                    if let location = item.location?.address, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.purple)
                                .font(.caption)
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var captionRow: some View {
        Group {
            if item.completed, let caption = item.caption, !caption.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(bucketListViewModel.userCache[item.userId]?.username ?? "@\(item.userId.prefix(6))") \(caption)")
                        .font(.caption)
                        .fontWeight(.regular)
                }
                .foregroundColor(.primary)
                .padding(.top, 2)
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
    // MARK: - Init
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
        mockListVM.userCache["testUser"] = UserModel(documentId: "testUser", email: "test@example.com", username: "@patrick1")

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






























