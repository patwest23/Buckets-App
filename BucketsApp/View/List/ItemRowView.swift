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
    let onNavigateToDetail: (() -> Void)?
    let onEmptyNameLostFocus: (() -> Void)?

    @EnvironmentObject var bucketListViewModel: ListViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var hasAutoFocused = false
    @State private var showFullScreenGallery = false

    private let cardCornerRadius: CGFloat = 12
    private let cardPadding: CGFloat = 8
    private let cardShadowRadius: CGFloat = 4
    private let spacing: CGFloat = 6

    var body: some View {
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

            // MARK: - Info Row: Location (left) + Date (right)
            HStack {
                if let location = item.location?.address, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let date = item.dueDate {
                    Text(formatDate(date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // MARK: - Carousel Images (if completed + has images)
            if item.completed, !item.imageUrls.isEmpty {
                TabView {
                    ForEach(item.imageUrls, id: \.self) { urlStr in
                        if let uiImage = bucketListViewModel.imageCache[urlStr] {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: UIScreen.main.bounds.height / 2.5)
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
                            .frame(height: UIScreen.main.bounds.height / 2.5)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: UIScreen.main.bounds.height / 2.5)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.top, 8)
                .fullScreenCover(isPresented: $showFullScreenGallery) {
                    FullScreenCarouselView(
                        imageUrls: item.imageUrls,
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
        .contentShape(Rectangle())
        .onAppear {
            guard !hasAutoFocused else { return }
            if item.id == newlyCreatedItemID {
                DispatchQueue.main.async {
                    isTextFieldFocused = true
                }
                hasAutoFocused = true
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

        bucketListViewModel.addOrUpdateItem(updated)
    }

    private func bindingForName() -> Binding<String> {
        Binding<String>(
            get: { item.name },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                var edited = item
                edited.name = newValue

                if !trimmed.isEmpty {
                    bucketListViewModel.addOrUpdateItem(edited)
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
                "https://via.placeholder.com/600",
                "https://via.placeholder.com/800"
            ],
            likeCount: 42,
            caption: "This was the most unforgettable day ever!",
            hasBeenPosted: true
        )
        
        let mockListVM = ListViewModel()
        
        // Simulate images being loaded (optional: real image URLs will auto-load with AsyncImage or your caching logic)
        for url in sampleItem.imageUrls {
            mockListVM.imageCache[url] = UIImage(systemName: "photo")!
        }

        return Group {
            // 1) Light Mode
            ItemRowView(
                item: .constant(sampleItem),
                newlyCreatedItemID: nil,
                onNavigateToDetail: { print("Navigate detail!") },
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
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
                onNavigateToDetail: { print("Navigate detail!") },
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
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






























