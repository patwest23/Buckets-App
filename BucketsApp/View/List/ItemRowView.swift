//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    @Binding var item: ItemModel
    
    // Allow auto-focus if row is newly created
    let newlyCreatedItemID: UUID?

    
    /// Called when user taps the chevron => detail navigation
    let onNavigateToDetail: (() -> Void)?
    
    /// Called if user eventually finalizes a blank name => parent can delete
    let onEmptyNameLostFocus: (() -> Void)?
    
    @EnvironmentObject var bucketListViewModel: ListViewModel
    
    // Layout / styling
    private let cardCornerRadius: CGFloat = 12
    private let cardPadding: CGFloat = 8
    private let cardShadowRadius: CGFloat = 4
    private let imageCellSize: CGFloat = 80
    private let spacing: CGFloat = 6
    
    @State private var showFullScreenGallery = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // MARK: - Top Row
            HStack(spacing: 8) {
                // 1) Checkmark: toggle completion
                Button(action: toggleCompleted) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(.borderless)
                
                // 2) Always-editable TextField
                TextField("", text: bindingForName())
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 3) Chevron => detail
                Button {
                    onNavigateToDetail?()
                } label: {
                    Image(systemName: "chevron.right")
                        .imageScale(.medium)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            
            // MARK: - Images if completed
            if item.completed, !item.imageUrls.isEmpty {
                let columns = Array(repeating: GridItem(.fixed(imageCellSize), spacing: spacing),
                                    count: 3)
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(item.imageUrls, id: \.self) { urlStr in
                        if let uiImage = bucketListViewModel.imageCache[urlStr] {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: imageCellSize, height: imageCellSize)
                                .cornerRadius(8)
                                .clipped()
                                .onTapGesture {
                                    showFullScreenGallery = true
                                }
                        } else {
                            ProgressView()
                                .frame(width: imageCellSize, height: imageCellSize)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
                .fullScreenCover(isPresented: $showFullScreenGallery) {
                    FullScreenCarouselView(
                        imageUrls: item.imageUrls,
                        itemName: item.name,
                        location: nil,
                        dateCompleted: nil
                    )
                    .environmentObject(bucketListViewModel)
                }
            }
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1),
                        radius: cardShadowRadius, x: 0, y: 2)
        )
        .contentShape(Rectangle()) // Make entire area tappable, if desired
    }
}

// MARK: - Private Helpers
extension ItemRowView {
    
    private func toggleCompleted() {
        var updated = item
        updated.completed.toggle()
        
        if updated.completed {
            updated.dueDate = Date()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            updated.dueDate = nil
        }
        
        bucketListViewModel.addOrUpdateItem(updated)
    }
    
    /// Binding that updates the item name if non-empty.
    /// If the user types `""`, we do **not** remove immediately—
    /// the parent can remove it on “Done” or `.onSubmit`.
    private func bindingForName() -> Binding<String> {
        Binding<String>(
            get: { item.name },
            set: { newValue in
                var edited = item
                edited.name = newValue
                
                // If user typed something => update Firestore
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    bucketListViewModel.addOrUpdateItem(edited)
                }
                
                // Keep local item updated so UI reflects typed text
                item = edited
            }
        )
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
            // 1) Light Mode
            ItemRowView(
                item: .constant(sampleItem),
                newlyCreatedItemID: nil,  // or some UUID if you want to test auto-focus
                onNavigateToDetail: { print("Navigate detail!") },
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
            )
            .environmentObject(ListViewModel())
            .environmentObject(OnboardingViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Light Mode")
            
            // 2) Dark Mode
            ItemRowView(
                item: .constant(sampleItem),
                newlyCreatedItemID: nil,  // or UUID()
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






























