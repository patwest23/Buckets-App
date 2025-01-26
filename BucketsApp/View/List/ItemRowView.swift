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
    
    /// Callback for navigation to detail view (info button).
    let onNavigateToDetail: (() -> Void)?
    
    /// Called when the user finishes editing the row and the item name is still empty.
    let onEmptyNameLostFocus: (() -> Void)?
    
    // Environment
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // MARK: - Local State
    @State private var isExpanded: Bool = false
    @FocusState private var textFieldIsFocused: Bool  // optional focus binding
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // (1) Top Row
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
                
                // b) Item Name TextField
                TextField(
                    "What do you want to do before you die?",
                    text: Binding(
                        get: { item.name },
                        set: { updateItemName($0) }
                    )
                )
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(8)
                .focused($textFieldIsFocused)
                
                // c) Info button shows only when expanded
                if isExpanded {
                    Button {
                        onNavigateToDetail?()
                    } label: {
                        Image(systemName: "info.circle")
                            .imageScale(.large)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .contentShape(Rectangle())  // Make entire row tappable
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .gray.opacity(isExpanded ? 0.4 : 0.0), radius: 6)
            )
            
            // (2) Drop-down content (only visible when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    
                    // a) Location
                    if let address = item.location?.address, !address.isEmpty {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
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
                    
                    // c) Completion / Due Date
                    if let dueDate = item.dueDate {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                            Text("Completed: \(formattedDate(dueDate))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // d) Image Carousel
                    if !item.imageUrls.isEmpty {
                        TabView {
                            ForEach(item.imageUrls, id: \.self) { url in
                                AsyncImage(url: URL(string: url)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: .infinity, maxHeight: 200)
                                            .cornerRadius(10)
                                            .clipped()
                                    case .failure:
                                        placeholderImage()
                                    @unknown default:
                                        placeholderImage()
                                    }
                                }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle())
                        .frame(height: 400)
                    } else {
                        placeholderImage()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Animate layout changes for expand/collapse
        .animation(.easeInOut, value: isExpanded)
        .padding(.vertical, 4)
        .background(Color.white)
        .onChange(of: isExpanded) { expanded in
            // If the user collapses the row, check if name is empty
            if !expanded {
                let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedName.isEmpty {
                    // Let parent handle deletion or confirmation
                    onEmptyNameLostFocus?()
                } else {
                    // Otherwise, save changes
                    saveItem()
                }
            }
        }
    }
}

// MARK: - Private Helpers
extension ItemRowView {
    
    /// Toggles the `completed` status of the item and updates via the view model.
    private func toggleCompleted() {
        var updatedItem = item
        updatedItem.completed.toggle()
        bucketListViewModel.addOrUpdateItem(updatedItem)
    }
    
    /// Updates the item’s name in the model. Immediately calls view model so changes are saved.
    private func updateItemName(_ newName: String) {
        var updatedItem = item
        updatedItem.name = newName
        bucketListViewModel.addOrUpdateItem(updatedItem)
    }
    
    /// Called when the row collapses (or any other time you want to explicitly force a save).
    private func saveItem() {
        bucketListViewModel.addOrUpdateItem(item)
    }
    
    /// Formats a `Date?` for display. Returns empty string if `nil`.
    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// A placeholder image for empty or failed loads.
    private func placeholderImage() -> some View {
        ZStack {
            Color.gray.opacity(0.1)
                .frame(maxWidth: .infinity, maxHeight: 400)
                .cornerRadius(10)
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.gray)
        }
    }
}


struct ItemRowView_Previews: PreviewProvider {
    
    /// A reusable container to preview one `ItemRowView` instance
    struct PreviewContainer: View {
        @State private var item: ItemModel
        
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
                    item: $item,
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






























