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

    @EnvironmentObject var bucketListViewModel: ListViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var hasAutoFocused = false
    @State private var showFullScreenGallery = false

    private let cardCornerRadius: CGFloat = 12
    private let cardPadding: CGFloat = 8
    private let cardShadowRadius: CGFloat = 4
    private let spacing: CGFloat = 6
    private let imageHeight: CGFloat = 240

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                // MARK: - Top Row
                HStack(spacing: 8) {
                    Button(action: toggleCompleted) {
                        Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                            .imageScale(.large)
                            .foregroundColor(item.completed ? .accentColor : .gray)
                    }
                    .buttonStyle(.borderless)

                    TextField(
                        "",
                        text: bindingForName(),
                        onCommit: handleOnSubmit
                    )
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .focused($isTextFieldFocused)

                    Spacer()

                    Button {
                        onNavigateToDetail?()
                    } label: {
                        Image(systemName: "chevron.right")
                            .imageScale(.medium)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }

                // MARK: - Info Row (removed for MVP)

                // MARK: - Carousel Images (if completed + has images)
                if item.completed, !item.allImageUrls.isEmpty {
                    TabView {
                        ForEach(item.allImageUrls, id: \.self) { urlStr in
                            if let uiImage = bucketListViewModel.imageCache[urlStr] {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: imageHeight)
                                    .clipped()
                                    .onTapGesture {
                                        showFullScreenGallery = true
                                    }
                            } else {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                    ProgressView()
                                }
                                .frame(height: imageHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 8)
                    .fullScreenCover(isPresented: $showFullScreenGallery) {
                        FullScreenCarouselView(
                            imageUrls: item.allImageUrls,
                            itemName: item.name,
                            location: item.location?.address,
                            dateCompleted: item.dueDate
                        )
                        .environmentObject(bucketListViewModel)
                    }
                }

                // MARK: - Likes Row (if posted and liked)
                if item.completed, let likeCount = item.likeCount, likeCount > 0 {
                    Text("❤️ \(likeCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                // MARK: - Caption Row (if posted with caption)
                if item.completed, let caption = item.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                }
            }
            .padding(cardPadding)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.1), radius: cardShadowRadius, x: 0, y: 2)
            )
            // Removed blue outline overlay when selected
            .contentShape(Rectangle())

            // MARK: - Overlay Icons
            HStack(spacing: -10) {
                if item.hasPostedCompletion || item.hasPostedAddEvent || item.hasPostedPhotos {
                    Image(systemName: "megaphone.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Circle().fill(Color.white))
                        .shadow(radius: 1)
                }

                if let likeCount = item.likeCount, likeCount > 0 {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Circle().fill(Color.white))
                        .shadow(radius: 1)
                }
                if item.wasRecentlyLiked {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(6)
                        .background(Circle().fill(Color.white))
                        .shadow(radius: 1)
                }
                // Add more icons here if needed
            }
            .offset(x: 10, y: -10)
        }
        .onAppear {
            Task {
                await bucketListViewModel.prefetchImages(for: item)
            }

            if !hasAutoFocused, item.id == newlyCreatedItemID {
                DispatchQueue.main.async {
                    isTextFieldFocused = true
                }
                hasAutoFocused = true
            }
        }
        .onChange(of: item.allImageUrls) {
            Task {
                await bucketListViewModel.prefetchImages(for: item)
            }
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
            await bucketListViewModel.addOrUpdateItem(updated)
        }
    }

    private func bindingForName() -> Binding<String> {
        Binding<String>(
            get: { item.name },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                var edited = item
                edited.name = newValue

                if !trimmed.isEmpty {
                    Task {
                        await bucketListViewModel.addOrUpdateItem(edited)
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
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct ItemRowView_Previews: PreviewProvider {
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
            likeCount: 42,
            caption: "This was the most unforgettable day ever!",
            hasPostedAddEvent: true,
            hasPostedCompletion: true,
            hasPostedPhotos: true
        )
        
        let mockListVM = ListViewModel()
        
        for url in sampleItem.imageUrls {
            mockListVM.imageCache[url] = UIImage(systemName: "photo")!
        }

        return Group {
            // 1) Light Mode
            ItemRowView(
                item: .constant(sampleItem),
                newlyCreatedItemID: nil,
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") },
                onNavigateToDetail: { print("Navigate to Detail View") }
            )
            .environmentObject(mockListVM)
            .environmentObject(OnboardingViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Light Mode")
            
            // 2) Dark Mode
            ItemRowView(
                item: .constant(sampleItem),
                newlyCreatedItemID: nil,
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") },
                onNavigateToDetail: { print("Navigate to Detail View") }
            )
            .environmentObject(mockListVM)
            .environmentObject(OnboardingViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}






























