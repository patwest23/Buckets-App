//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    // MARK: - Properties
    
    @Binding var item: ItemModel
    
    /// Whether to show detailed info (images, etc.) inline
    let showDetailed: Bool
    
    /// Called when the user taps to navigate to DetailItemView
    let onNavigateToDetail: (() -> Void)?
    
    /// Called if the user’s name is empty after editing
    let onEmptyNameLostFocus: (() -> Void)?
    
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // MARK: - Body
    var body: some View {
        // Use spacing = 0 to remove vertical gaps
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
            // minimal vertical padding around the top row
            .padding(.vertical, 4)
            
            // 2) Additional fields if showDetailed
            if showDetailed {
                
                // (Optional) location or date rows are commented out in your code.
                // Insert them here if you like.
                
                // (c) Image Carousel (if any)
                if !item.imageUrls.isEmpty {
                    TabView {
                        ForEach(item.imageUrls, id: \.self) { urlStr in
                            if let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let loadedImage):
                                        loadedImage
                                            .resizable()
                                            .scaledToFill()
                                            // Make the image fill the entire width
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 600)
                                            .clipped()
                                    case .failure:
                                        Color.gray
                                            .frame(height: 600)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                // If the URL is invalid
                                Color.gray
                                    .frame(height: 600)
                            }
                        }
                    }
                    .tabViewStyle(PageTabViewStyle())
                    .frame(height: 600) // Force the TabView to be 600 points tall
                }
            }
        }
        // 3) Watch for item.name changes
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
    
    /// Toggle the completed state
    private func toggleCompleted() {
        var updated = item
        if !updated.completed {
            updated.completed = true
            updated.dueDate = Date()
        } else {
            updated.completed = false
            updated.dueDate = nil
        }
        bucketListViewModel.addOrUpdateItem(updated)
    }
    
    /// Update the item name
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
        
        return VStack(spacing: 40) {
            // 1) Collapsed style
            ItemRowView(
                item: .constant(sampleItem),
                showDetailed: false,
                onNavigateToDetail: { print("Navigate detail!") },
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
            )
            
            // 2) Detailed style
            ItemRowView(
                item: .constant(sampleItem),
                showDetailed: true,
                onNavigateToDetail: { print("Navigate detail!") },
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
            )
        }
        .environmentObject(ListViewModel())
        .environmentObject(OnboardingViewModel())
        .previewLayout(.sizeThatFits)
        .padding()
    }
}






























