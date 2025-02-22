//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    @Binding var item: ItemModel
    @Binding var selectedItemID: UUID?
    
    // The newly created item ID (if any) for auto-focus logic
    let newlyCreatedItemID: UUID?
    
    // **New**: which row is currently editing the name field
    @Binding var editingNameItemID: UUID?
    
    let onNavigateToDetail: (() -> Void)?
    let onEmptyNameLostFocus: (() -> Void)?
    
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showFullScreenGallery = false
    
    // FocusState for text field
    @FocusState private var isEditingName: Bool
    
    private let cardCornerRadius: CGFloat = 12
    private let cardPadding: CGFloat = 8
    private let cardShadowRadius: CGFloat = 4
    
    private let imageCellSize: CGFloat = 80
    private let spacing: CGFloat = 6
    
    private var isSelected: Bool {
        selectedItemID == item.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Top Row
            HStack(spacing: 8) {
                // Checkmark always visible
                Button(action: toggleCompleted) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(.borderless)
                
                if isSelected {
                    // Show text field
                    if #available(iOS 16.0, *) {
                        TextField("", text: $item.name, axis: .vertical)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1...3)
                            .focused($isEditingName)
                    } else {
                        TextField("", text: $item.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Navigate to detail
                    Button {
                        onNavigateToDetail?()
                    } label: {
                        Image(systemName: "chevron.right")
                            .imageScale(.medium)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                } else {
                    // Read-only
                    Text(item.name.isEmpty ? "Untitled Item" : item.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            
            // If completed & selected => show images
            if item.completed, isSelected, !item.imageUrls.isEmpty {
                let columns = Array(repeating: GridItem(.fixed(imageCellSize), spacing: spacing), count: 3)
                
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
                        location: item.location?.address,
                        dateCompleted: item.dueDate
                    )
                    .environmentObject(bucketListViewModel)
                }
            }
            
            // Location & Date
            if item.completed, isSelected, (hasLocation || hasDate) {
                HStack(spacing: 0) {
                    column1View.frame(maxWidth: .infinity)
                    column2View.frame(maxWidth: .infinity)
                    EmptyView().frame(maxWidth: .infinity)
                }
                .font(.footnote)
                .foregroundColor(locationDateColor)
            }
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.1), radius: cardShadowRadius, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedItemID = nil
            } else {
                selectedItemID = item.id
            }
        }
        
        // Keep partial edits if name is non-empty
        .onChange(of: item.name) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                bucketListViewModel.addOrUpdateItem(item)
            }
        }
        
        // If user stops editing & name is empty => delete
        .onChange(of: isEditingName) { oldVal, newVal in
            // Toggle parent's editingNameItemID
            if newVal {
                // Just gained focus => let parent know
                editingNameItemID = item.id
            } else {
                // Lost focus => if parent's editingNameItemID was me, set nil
                if editingNameItemID == item.id {
                    editingNameItemID = nil
                }
                
                // Check if empty => delete
                if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onEmptyNameLostFocus?()
                }
            }
        }
        
        // If I become selected & I'm newlyCreated => auto-focus
        .onChange(of: isSelected) { _, newVal in
            if newVal, item.id == newlyCreatedItemID {
                isEditingName = true
            }
        }
    }
    
    // Column Helpers
    @ViewBuilder
    var column1View: some View {
        if hasLocation {
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                Text(item.location?.address ?? "")
            }
        } else if hasDate {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(shortDateString(from: item.dueDate!))
            }
        }
    }
    
    @ViewBuilder
    var column2View: some View {
        if hasLocationAndDate {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(shortDateString(from: item.dueDate!))
            }
        }
    }
    
    private func toggleCompleted() {
        var updated = item
        updated.completed.toggle()
        updated.dueDate = updated.completed ? Date() : nil
        
        if updated.completed {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        
        bucketListViewModel.addOrUpdateItem(updated)
    }
    
    private var hasLocation: Bool {
        guard let address = item.location?.address else { return false }
        return !address.isEmpty
    }
    private var hasDate: Bool {
        item.completed && item.dueDate != nil
    }
    private var hasLocationAndDate: Bool {
        hasLocation && hasDate
    }
    private var locationDateColor: Color {
        colorScheme == .dark ? .white : .gray
    }
    private func shortDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
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
            // 1) Light Mode - Unselected, not newly created
            ItemRowView(
                item: .constant(sampleItem),
                selectedItemID: .constant(nil),     // Row is NOT selected
                newlyCreatedItemID: nil,           // Not newly created
                editingNameItemID: .constant(nil), // No row is actively editing name
                onNavigateToDetail: { print("Navigate detail!") },
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
            )
            .environmentObject(ListViewModel())
            .environmentObject(OnboardingViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Light Mode - Unselected")
            
            // 2) Dark Mode - Selected + newly created
            ItemRowView(
                item: .constant(sampleItem),
                selectedItemID: .constant(sampleItem.id), // Row is selected
                newlyCreatedItemID: sampleItem.id,        // Pretend it's newly created
                editingNameItemID: .constant(nil),        // Not actively editing in this preview
                onNavigateToDetail: { print("Navigate detail!") },
                onEmptyNameLostFocus: { print("Empty name => auto-delete!") }
            )
            .environmentObject(ListViewModel())
            .environmentObject(OnboardingViewModel())
            .previewLayout(.sizeThatFits)
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode - Selected + Newly Created")
        }
    }
}






























