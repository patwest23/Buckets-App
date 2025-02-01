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
    
    /// The current item ID that is expanded in the parent view. Only one row can be open at a time.
    @Binding var expandedItemId: UUID?
    
    /// Navigate to DetailItemView
    let onNavigateToDetail: (() -> Void)?
    
    /// Called if the user collapses the row while the item name is still empty.
    let onEmptyNameLostFocus: (() -> Void)?
    
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // MARK: - Computed State
    
    /// Determines if this row is expanded by comparing `expandedItemId` to the current item ID.
    private var isExpanded: Bool {
        expandedItemId == item.id
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1) Top Row
            HStack(spacing: 12) {
                // a) Completion Toggle
                Button {
                    toggleCompleted()
                } label: {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(.borderless)
                
                // b) Editable multiline TextField (iOS 16+), fallback for older iOS
                if #available(iOS 16.0, *) {
                    TextField(
                        "",
                        text: Binding(
                            get: { item.name },
                            set: { updateItemName($0) }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(1...5) // up to 5 lines
                    .padding(.vertical, 8)
                } else {
                    // Fallback: single-line if iOS < 16
                    TextField(
                        "",
                        text: Binding(
                            get: { item.name },
                            set: { updateItemName($0) }
                        )
                    )
                    .padding(.vertical, 8)
                }
                
                Spacer()
                
                // c) Expand/Collapse Button
                Button {
                    withAnimation {
                        toggleRowExpansion()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .imageScale(.medium)
                }
                .buttonStyle(.borderless)
                
                // d) Navigate-to-Detail Button
                Button {
                    onNavigateToDetail?()
                } label: {
                    Image(systemName: "chevron.right")
                        .imageScale(.medium)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
            
            // 2) Drop-down details (only if expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    
                    // a) Location
                    if let address = item.location?.address, !address.isEmpty {
                        HStack {
                            Image(systemName: "mappin")
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // b) Creation Date
                    HStack {
                        Image(systemName: "calendar")
                        Text("Created: \(formattedDate(item.creationDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // c) Completed Date (if any)
                    if let dueDate = item.dueDate {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                            Text("Completed: \(formattedDate(dueDate))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // d) Image Carousel (TabView) if there are images
                    if !item.imageUrls.isEmpty {
                        TabView {
                            ForEach(item.imageUrls, id: \.self) { urlStr in
                                if let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 200)
                                                .cornerRadius(10)
                                                .clipped()
                                        case .failure:
                                            // Show a placeholder or just nothing
                                            Color.gray
                                                .frame(height: 200)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    // Invalid URL
                                    Color.gray
                                        .frame(height: 200)
                                }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle())
                        .frame(height: 200)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: isExpanded) { newValue in
            // If the row collapses and the name is empty, call onEmptyNameLostFocus
            if !newValue {
                let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedName.isEmpty {
                    onEmptyNameLostFocus?()
                } else {
                    saveItem()
                }
            }
        }
    }
}

// MARK: - Private Helpers
extension ItemRowView {
    
    /// Toggle the completed state in the item model
    private func toggleCompleted() {
        var updated = item
        updated.completed.toggle()
        bucketListViewModel.addOrUpdateItem(updated)
    }
    
    /// Update the item name
    private func updateItemName(_ newName: String) {
        var updated = item
        updated.name = newName
        bucketListViewModel.addOrUpdateItem(updated)
    }
    
    /// Save the item (called when user collapses after editing)
    private func saveItem() {
        bucketListViewModel.addOrUpdateItem(item)
    }
    
    /// Toggle expansion for single-row logic
    private func toggleRowExpansion() {
        if isExpanded {
            expandedItemId = nil
        } else {
            expandedItemId = item.id
        }
    }
    
    /// Format optional date to a short, readable string
    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}


struct ItemRowView_Previews: PreviewProvider {
    
    /// A reusable container to preview one `ItemRowView` instance
    struct PreviewContainer: View {
        @State private var item: ItemModel
        
        @State private var expandedItemId: UUID?
        
        /// Determines if we start with the row "focused" (expanded).
        let initiallyFocused: Bool
        
        /// Focus state for the text field (optional, if you want to auto-focus in the preview).
        @FocusState private var isRowFocused: Bool
        
        init(initiallyFocused: Bool) {
            self.initiallyFocused = initiallyFocused
            // Provide a sample item
            _item = State(initialValue: ItemModel(
                userId: "testUser",
                name: "Sample Bucket List Item",
                description: "This is a longer description of the item.",
                completed: false,
                imageUrls: [
                    "https://via.placeholder.com/400",
                    "https://via.placeholder.com/400"
                ]
            ))
        }
        
        var body: some View {
            VStack(spacing: 20) {
                Text("ItemRowView Preview")
                    .font(.headline)
                    .padding()
                
                // Our ItemRowView under test
                ItemRowView(
                    item: $item, expandedItemId: $expandedItemId,
                    onNavigateToDetail: {
                        print("Navigating to detail for item: \(item.name)")
                    },
                    onEmptyNameLostFocus: {
                        // This closure is called if the user collapses the row and the name is empty.
                        print("Name is empty - (Mock) would confirm deletion or auto-delete.")
                    }
                )
                .environmentObject(ListViewModel())       // Provide a real or mock list VM
                .environmentObject(OnboardingViewModel()) // Provide a real or mock onboarding VM
                .focused($isRowFocused)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            // Focus the row if 'initiallyFocused' is true
            .onAppear {
                if initiallyFocused {
                    isRowFocused = true
                }
            }
        }
    }
    
    // MARK: - Multiple Preview States
    static var previews: some View {
        Group {
            // 1) Collapsed / Light Mode
            PreviewContainer(initiallyFocused: false)
                .previewDisplayName("Collapsed (Light Mode)")
                .preferredColorScheme(.light)
                .previewLayout(.sizeThatFits)
                .padding()
            
            // 2) Expanded / Dark Mode
            PreviewContainer(initiallyFocused: true)
                .previewDisplayName("Expanded (Dark Mode)")
                .preferredColorScheme(.dark)
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}






























