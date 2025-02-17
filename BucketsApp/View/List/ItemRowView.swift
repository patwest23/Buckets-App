//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    @Binding var item: ItemModel
    
    /// The stable width measured by the parent (ListView).
    let rowWidth: CGFloat
    
    let onNavigateToDetail: (() -> Void)?
    let onEmptyNameLostFocus: (() -> Void)?
    
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showFullScreenGallery = false
    
    // Grid constants
    private let columnsCount = 3
    private let spacing: CGFloat = 8
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // 1) Top row: completion toggle + multiline name + detail nav
            HStack(spacing: 12) {
                Button(action: toggleCompleted) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(.borderless)
                
                // Editable multiline TextField
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
                    TextField("", text: Binding(
                        get: { item.name },
                        set: { updateItemName($0) }
                    ))
                }
                
                Spacer()
                
                Button {
                    onNavigateToDetail?()
                } label: {
                    Image(systemName: "chevron.right")
                        .imageScale(.medium)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
            
            // 2) If completed + has images => show grid
            if item.completed, !item.imageUrls.isEmpty {
                let totalSpacing = spacing * CGFloat(columnsCount - 1)
                let cellSize = (rowWidth - totalSpacing) / CGFloat(columnsCount)
                
                // Build a 3-col LazyVGrid
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: columnsCount),
                    spacing: spacing
                ) {
                    ForEach(item.imageUrls, id: \.self) { urlStr in
                        if let uiImage = bucketListViewModel.imageCache[urlStr] {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: cellSize, height: cellSize)
                                .cornerRadius(8)
                                .clipped()
                                .onTapGesture {
                                    showFullScreenGallery = true
                                }
                        } else {
                            // Placeholder
                            ProgressView()
                                .frame(width: cellSize, height: cellSize)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(8)
                        }
                    }
                }
                .fullScreenCover(isPresented: $showFullScreenGallery) {
                    FullScreenCarouselView(imageUrls: item.imageUrls)
                        .environmentObject(bucketListViewModel)
                }
            }
        }
        // 3) Blank-name detection
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
                "https://via.placeholder.com/600",
                "https://via.placeholder.com/800"
            ]
        )
        
        return Group {
            // Example Light Mode
            ItemRowView(
                item: .constant(sampleItem),
                rowWidth: 375, // Provide a fixed row width for preview
                onNavigateToDetail: { print("Navigate detail!") },
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
            )
            .environmentObject(ListViewModel())
            .environmentObject(OnboardingViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Light Mode")
            
            // Example Dark Mode
            ItemRowView(
                item: .constant(sampleItem),
                rowWidth: 375, // Same row width
                onNavigateToDetail: { print("Navigate detail!") },
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
            )
            .environmentObject(ListViewModel())
            .environmentObject(OnboardingViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}






























