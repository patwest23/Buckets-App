//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    @Binding var item: ItemModel
    
    // We’ll always show “detailed” (images) if the item has image URLs.
    let onNavigateToDetail: (() -> Void)?
    let onEmptyNameLostFocus: (() -> Void)?
    
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    /// Tracks whether we’re showing the full-screen image carousel
    @State private var showFullScreenGallery = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // 1) Top row: Completion toggle + multiline name + detail button
            HStack(spacing: 12) {
                // a) Completion Toggle
                Button(action: toggleCompleted) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(.borderless)
                
                // b) Editable multiline TextField
                if #available(iOS 16.0, *) {
                    TextField(
                        "",
                        text: Binding(
                            get: { item.name },
                            set: { updateItemName($0) }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(1...5)
                } else {
                    // Fallback for older iOS
                    TextField(
                        "",
                        text: Binding(
                            get: { item.name },
                            set: { updateItemName($0) }
                        )
                    )
                }
                
                Spacer()
                
                // c) Navigate-to-Detail Button
                Button {
                    onNavigateToDetail?()
                } label: {
                    Image(systemName: "chevron.right")
                        .imageScale(.medium)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
            
            // 2) GeometryReader-based carousel if there are images
            if !item.imageUrls.isEmpty {
                HStack {
                    Spacer()
                    
                    GeometryReader { geo in
                        // Let’s clamp the carousel size to something reasonable
                        let sideLength = min(geo.size.width * 0.9, 500)
                        
                        TabView {
                            ForEach(item.imageUrls, id: \.self) { urlStr in
                                if let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: sideLength, height: sideLength)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .padding(4)
                                        case .success(let loadedImage):
                                            loadedImage
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: sideLength, height: sideLength)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .padding(4)
                                        case .failure:
                                            Color.gray
                                                .frame(width: sideLength, height: sideLength)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .padding(4)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    // If the URL is invalid
                                    Color.gray
                                        .frame(width: sideLength, height: sideLength)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .padding(4)
                                }
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(width: geo.size.width, height: sideLength)
                        .onTapGesture {
                            showFullScreenGallery = true
                        }
                        .fullScreenCover(isPresented: $showFullScreenGallery) {
                            FullScreenCarouselView(imageUrls: item.imageUrls)
                        }
                    }
                    .frame(height: 400) // optional: controls the overall vertical space
                                        // you can remove or adjust this as you prefer
                    
                    Spacer()
                }
            }
        }
        // 3) Blank-name detection & saving
        .onChange(of: item.name) { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                onEmptyNameLostFocus?()
            } else {
                bucketListViewModel.addOrUpdateItem(item)
            }
        }
    }
}

// MARK: - Private Helpers
extension ItemRowView {
    private func toggleCompleted() {
        var updated = item
        updated.completed.toggle()
        updated.dueDate = updated.completed ? Date() : nil
        bucketListViewModel.addOrUpdateItem(updated)
    }
    
    private func updateItemName(_ newName: String) {
        var updated = item
        updated.name = newName
        bucketListViewModel.addOrUpdateItem(updated)
    }
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
                "https://via.placeholder.com/600"
            ]
        )
        
        return ItemRowView(
            item: .constant(sampleItem),
            // Removed `showDetailed` parameter
            onNavigateToDetail: { print("Navigate detail!") },
            onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
        )
        .environmentObject(ListViewModel())
        .environmentObject(OnboardingViewModel())
        .previewLayout(.sizeThatFits)
        .padding()
    }
}






























