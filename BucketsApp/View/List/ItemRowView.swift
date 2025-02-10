//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    @Binding var item: ItemModel
    
    let onNavigateToDetail: (() -> Void)?
    let onEmptyNameLostFocus: (() -> Void)?
    
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showFullScreenGallery = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // 1) Top row (completion, name, detail nav)
            HStack(spacing: 12) {
                Button(action: toggleCompleted) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(.borderless)
                
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
                    TextField(
                        "",
                        text: Binding(
                            get: { item.name },
                            set: { updateItemName($0) }
                        )
                    )
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
            
            // 2) Image carousel if images exist
            if !item.imageUrls.isEmpty {
                HStack {
                    Spacer()
                    
                    TabView {
                        ForEach(item.imageUrls, id: \.self) { urlStr in
                            if let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(Color.secondary.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    case .success(let loadedImage):
                                        loadedImage
                                            .resizable()
                                            .scaledToFill()
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    case .failure:
                                        Color.gray
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                // Invalid URL => gray placeholder
                                Color.gray
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    // Constrain the carousel to at most 500 wide, and keep a square aspect ratio.
                    .frame(maxWidth: 500)
                    .aspectRatio(1, contentMode: .fit)
                    .onTapGesture {
                        showFullScreenGallery = true
                    }
                    .fullScreenCover(isPresented: $showFullScreenGallery) {
                        FullScreenCarouselView(imageUrls: item.imageUrls)
                    }
                    
                    Spacer()
                }
            }
        }
        // 3) Watch for blank name
        .onChange(of: item.name) { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                onEmptyNameLostFocus?()
            } else {
                bucketListViewModel.addOrUpdateItem(item)
            }
        }
    }
    
    // MARK: - Helpers
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






























