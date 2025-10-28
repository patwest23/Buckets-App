//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

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
    let onFocusChange: ((Bool) -> Void)? = nil
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // MARK: - Top Row
            HStack(spacing: 8) {
                // 1) Checkmark => toggles completion
                Button(action: toggleCompleted) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(.borderless)
                
                // 2) Editable text field
                TextField(
                    "",
                    text: bindingForName(),
                    onCommit: handleOnSubmit
                )
                .font(.subheadline)
                .foregroundColor(.primary)
                .focused($isTextFieldFocused)
                
                Spacer()
                
                // 3) Chevron => detail, only if user is focusing the text field
                if isTextFieldFocused {
                    Button {
                        onNavigateToDetail?()
                    } label: {
                        Image(systemName: "chevron.right")
                            .imageScale(.medium)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            // MARK: - Images (only if completed + has images)
            if item.completed, !item.imageUrls.isEmpty {
                let columns = Array(
                    repeating: GridItem(.fixed(imageCellSize), spacing: spacing),
                    count: 3
                )
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
        .contentShape(Rectangle())
        
        // Only auto-focus once, if row is newly created
        .onAppear {
            // If we've not already auto-focused, and this is the newly created item => focus
            guard !hasAutoFocused else { return }

            if item.id == newlyCreatedItemID {
                // Defer focus to next runloop
                DispatchQueue.main.async {
                    isTextFieldFocused = true
                }
                hasAutoFocused = true
            }
        }
        .onChange(of: isTextFieldFocused) { newValue in
            onFocusChange?(newValue)
        }
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
        }
        
        bucketListViewModel.addOrUpdateItem(updated)
    }
    
    /// Binding that updates `item.name` if non-empty; if user types "" => not removed
    /// automatically. The parent can remove it on “Done” or if user hits Return/Submit => blank => calls `onEmptyNameLostFocus()`.
    private func bindingForName() -> Binding<String> {
        Binding<String>(
            get: { item.name },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                var edited = item
                edited.name = newValue
                
                // If user typed something => update Firestore
                if !trimmed.isEmpty {
                    bucketListViewModel.addOrUpdateItem(edited)
                }
                // Always keep local item so UI matches typed text
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






























