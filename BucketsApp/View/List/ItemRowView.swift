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
    
    let newlyCreatedItemID: UUID?
    @Binding var editingNameItemID: UUID?
    
    let onNavigateToDetail: (() -> Void)?
    let onEmptyNameLostFocus: (() -> Void)?
    
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showFullScreenGallery = false
    
    // Focus state for inline editing
    @FocusState private var isEditingName: Bool
    
    // Styling constants
    private let cardCornerRadius: CGFloat = 12
    private let cardPadding: CGFloat = 8
    private let cardShadowRadius: CGFloat = 4
    private let imageCellSize: CGFloat = 80
    private let spacing: CGFloat = 6
    
    // Is the row selected?
    private var isSelected: Bool {
        selectedItemID == item.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // MARK: - Top Row (Checkmark + Title or TextField)
            HStack(spacing: 8) {
                // Checkmark
                Button(action: toggleCompleted) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(.borderless)
                
                // If row is selected => show TextField, else read-only
                if isSelected {
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
                    
                    // Chevron only if selected
                    Button {
                        onNavigateToDetail?()
                    } label: {
                        Image(systemName: "chevron.right")
                            .imageScale(.medium)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                } else {
                    // Not selected => read-only title
                    Text(item.name.isEmpty ? "Untitled Item" : item.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            
            // MARK: - Completed-Only Details
            if item.completed {
                
                // Images (if any)
                if !item.imageUrls.isEmpty {
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
                                    // Only allow tapping if row is selected
                                    .onTapGesture {
                                        if isSelected {
                                            showFullScreenGallery = true
                                        }
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
                
                // Date & Location Row
                if hasDate || hasLocation {
                    HStack(spacing: 0) {
                        // Left alignment for date
                        if hasDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(shortDateString(from: item.dueDate!))
                            }
                            // Enough left padding to align with checkmark
                            .padding(.leading, 36)
                        }
                        
                        Spacer()
                        
                        // Center alignment for location
                        if hasLocation {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                Text(item.location?.address ?? "")
                            }
                        }
                        
                        Spacer()
                    }
                    .font(.footnote)
                    .foregroundColor(locationDateColor)
                }
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
        
        // Tapping toggles selection
        .onTapGesture {
            selectedItemID = (isSelected ? nil : item.id)
        }
        
        // If the name changes & is non-empty => update
        .onChange(of: item.name) { _, newVal in
            let trimmed = newVal.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                bucketListViewModel.addOrUpdateItem(item)
            }
        }
        
        // If text field loses focus & name empty => delete
        .onChange(of: isEditingName) { oldVal, newVal in
            if newVal {
                editingNameItemID = item.id
            } else {
                if editingNameItemID == item.id {
                    editingNameItemID = nil
                }
                if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onEmptyNameLostFocus?()
                }
            }
        }
        
        // Newly created => auto-focus
        .onChange(of: isSelected) { _, newVal in
            if newVal, item.id == newlyCreatedItemID {
                isEditingName = true
            }
        }
    }
    
    // MARK: - Computed Props
    private var hasDate: Bool {
        item.dueDate != nil
    }
    private var hasLocation: Bool {
        guard let address = item.location?.address else { return false }
        return !address.isEmpty
    }
    private var locationDateColor: Color {
        colorScheme == .dark ? .white : .gray
    }
    
    // MARK: - Helpers
    private func shortDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func toggleCompleted() {
        var updated = item
        updated.completed.toggle()
        
        if updated.completed {
            updated.dueDate = Date()  // set date if newly completed
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            // item is now incomplete => clear date & hide images
            updated.dueDate = nil
            // If you want to remove images or keep them but hide visually,
            // you can remove them entirely or just keep them.
            // Let's keep them but not show them if incomplete.
        }
        
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






























