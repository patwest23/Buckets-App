//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

enum ItemRowDisplayMode: String {
    case simple
    case detailed
}

struct ItemRowView: View {
    @Binding var item: ItemModel

    /// The newly created item, if any, so we know if we should auto-focus this row
    let newlyCreatedItemID: UUID?

    /// Called when user taps the chevron (Detail nav)
    let onNavigateToDetail: (() -> Void)?

    /// Called if user finalizes editing with blank name => parent can delete
    let onEmptyNameLostFocus: (() -> Void)?

    /// Notifies the parent when the inline text field gains or loses focus.
    /// This lets screens such as `ListView` show contextual controls (e.g. a
    /// “Done” button) only while a row is actively being edited.
    let onFocusChange: ((Bool) -> Void)?

    let displayMode: ItemRowDisplayMode

    @EnvironmentObject var bucketListViewModel: ListViewModel

    // Track focus for the TextField
    @FocusState private var isTextFieldFocused: Bool

    // Ensures we only auto-focus *once*
    @State private var hasAutoFocused = false

    // Layout constants
    private let cardCornerRadius: CGFloat = 12
    private let cardPadding: CGFloat = 8
    private let cardShadowRadius: CGFloat = 4
    private let imageCellSize: CGFloat = 80
    private let spacing: CGFloat = 6

    @State private var showFullScreenGallery = false
    @State private var selectedImageIndex = 0

    var body: some View {
        let pendingImages = bucketListViewModel.pendingLocalImages[item.id] ?? []
        let pendingToDisplay = Array(pendingImages.prefix(3))
        let remainingSlots = max(0, 3 - pendingToDisplay.count)
        let remoteUrlsToDisplay = Array(item.imageUrls.prefix(remainingSlots))

        HStack(alignment: .top, spacing: 8) {
            Button(action: toggleCompleted) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundColor(item.completed ? .accentColor : .gray)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 6) {
                TextField(
                    "",
                    text: bindingForName(),
                    onCommit: handleOnSubmit
                )
                .font(.subheadline)
                .foregroundColor(.primary)
                .focused($isTextFieldFocused)

                if displayMode == .detailed {
                    let completionText = completionDescription
                    let locationText = locationDescription

                    if completionText != nil || locationText != nil {
                        HStack(spacing: 8) {
                            if let completionText {
                                Text(completionText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let locationText {
                                Text(locationText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if hasImages(pendingToDisplay: pendingToDisplay, remoteUrls: remoteUrlsToDisplay) {
                        imageGrid(
                            pendingAll: pendingImages,
                            pendingToDisplay: pendingToDisplay,
                            remoteDisplay: remoteUrlsToDisplay,
                            remoteAll: item.imageUrls
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if isTextFieldFocused {
                Button {
                    isTextFieldFocused = false
                    onNavigateToDetail?()
                } label: {
                    Image(systemName: "chevron.right")
                        .imageScale(.medium)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1),
                        radius: cardShadowRadius, x: 0, y: 2)
        )
        .contentShape(Rectangle())

        // Only auto-focus once, if row is newly created
        .onAppear {
            guard !hasAutoFocused else { return }

            if item.id == newlyCreatedItemID {
                DispatchQueue.main.async {
                    isTextFieldFocused = true
                }
                hasAutoFocused = true
            }
        }
        .onChange(of: isTextFieldFocused, initial: false) { _, newValue in
            onFocusChange?(newValue)
        }
    }
}

extension ItemRowView {
    init(
        item: Binding<ItemModel>,
        newlyCreatedItemID: UUID?,
        displayMode: ItemRowDisplayMode,
        onNavigateToDetail: (() -> Void)? = nil,
        onEmptyNameLostFocus: (() -> Void)? = nil,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self._item = item
        self.newlyCreatedItemID = newlyCreatedItemID
        self.displayMode = displayMode
        self.onNavigateToDetail = onNavigateToDetail
        self.onEmptyNameLostFocus = onEmptyNameLostFocus
        self.onFocusChange = onFocusChange
    }
}

// MARK: - Private Helpers
extension ItemRowView {

    /// Toggle completed => updates Firestore
    private func toggleCompleted() {
        var updated = item
        updated.completed.toggle()

        if updated.completed {
            updated.dueDate = Date()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            updated.dueDate = nil
            bucketListViewModel.clearLocalAttachments(for: updated.id)
        }

        bucketListViewModel.addOrUpdateItem(updated)
    }

    /// Binding that updates `item.name` if non-empty; if user types "" => not removed
    /// automatically. The parent can remove it on “Done” or if user hits Return/Submit => blank => calls `onEmptyNameLostFocus()`.
    private func bindingForName() -> Binding<String> {
        Binding<String>(
            get: {
                item.name
            },
            set: { newValue in
                var edited = item
                edited.name = newValue

                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                if !trimmed.isEmpty {
                    bucketListViewModel.addOrUpdateItem(edited)
                }

                item = edited
            }
        )
    }

    /// Called when user presses Return => if name is blank, parent can handle deletion
    private func handleOnSubmit() {
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            onEmptyNameLostFocus?()
        }
    }

    private var locationDescription: String? {
        guard item.completed,
              let location = item.location else { return nil }
        if let address = location.address, !address.isEmpty {
            return address
        }
        return nil
    }

    private var completionDescription: String? {
        guard item.completed,
              let date = item.dueDate else { return nil }
        return ItemRowView.dateFormatter.string(from: date)
    }

    private func hasImages(pendingToDisplay: [UIImage], remoteUrls: [String]) -> Bool {
        !pendingToDisplay.isEmpty || !remoteUrls.isEmpty
    }

    @ViewBuilder
    private func imageGrid(
        pendingAll: [UIImage],
        pendingToDisplay: [UIImage],
        remoteDisplay: [String],
        remoteAll: [String]
    ) -> some View {
        let columns = Array(
            repeating: GridItem(.fixed(imageCellSize), spacing: spacing),
            count: 3
        )

        let gridImages = makeCarouselImages(
            pendingToDisplay: pendingToDisplay,
            remoteUrls: remoteDisplay
        )

        let carouselImages = makeCarouselImages(
            pendingToDisplay: pendingAll,
            remoteUrls: remoteAll
        )

        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(Array(gridImages.enumerated()), id: \.offset) { gridIndex, imageSource in
                gridThumbnail(for: imageSource)
                    .onTapGesture {
                        selectedImageIndex = mapGridIndexToCarouselIndex(
                            gridIndex: gridIndex,
                            pendingDisplayCount: pendingToDisplay.count,
                            pendingAllCount: pendingAll.count
                        )
                        showFullScreenGallery = true
                    }
            }
        }
        .fullScreenCover(isPresented: $showFullScreenGallery) {
            FullScreenCarouselView(
                images: carouselImages,
                initialIndex: selectedImageIndex,
                itemName: item.name,
                isCompleted: item.completed,
                location: locationDescription,
                dateCompleted: item.dueDate
            )
            .environmentObject(bucketListViewModel)
        }
    }

    private func makeCarouselImages(
        pendingToDisplay: [UIImage],
        remoteUrls: [String]
    ) -> [CarouselImageSource] {
        let localImages = pendingToDisplay.map { CarouselImageSource.local($0) }
        let remoteImages = remoteUrls.map { CarouselImageSource.remote($0) }
        return localImages + remoteImages
    }

    private func mapGridIndexToCarouselIndex(
        gridIndex: Int,
        pendingDisplayCount: Int,
        pendingAllCount: Int
    ) -> Int {
        if gridIndex < pendingDisplayCount {
            return gridIndex
        }

        let remoteGridIndex = gridIndex - pendingDisplayCount
        return pendingAllCount + remoteGridIndex
    }

    @ViewBuilder
    private func gridThumbnail(for imageSource: CarouselImageSource) -> some View {
        switch imageSource {
        case .local(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: imageCellSize, height: imageCellSize)
                .cornerRadius(8)
                .clipped()
        case .remote(let urlStr):
            if let uiImage = bucketListViewModel.imageCache[urlStr] {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageCellSize, height: imageCellSize)
                    .cornerRadius(8)
                    .clipped()
            } else {
                ProgressView()
                    .frame(width: imageCellSize, height: imageCellSize)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - Preview
struct ItemRowView_Previews: PreviewProvider {
    static var previews: some View {

        let sampleItem = ItemModel(
            userId: "testUser",
            name: "Sample Bucket List Item",
            dueDate: Date(),
            location: Location(latitude: 37.7749, longitude: -122.4194, address: "San Francisco"),
            completed: true,
            imageUrls: [
                "https://via.placeholder.com/400",
                "https://via.placeholder.com/600",
                "https://via.placeholder.com/800"
            ]
        )

        return Group {
            ItemRowView(
                item: .constant(sampleItem),
                newlyCreatedItemID: nil,
                displayMode: .simple,
                onNavigateToDetail: { print("Navigate detail!") },
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
            )
            .environmentObject(ListViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Simple")

            ItemRowView(
                item: .constant(sampleItem),
                newlyCreatedItemID: nil,
                displayMode: .detailed,
                onNavigateToDetail: { print("Navigate detail!") },
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
            )
            .environmentObject(ListViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Detailed")
        }
    }
}
