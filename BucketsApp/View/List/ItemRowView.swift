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
    
    /// Whether to show detailed info (location, dates, images) inline
    let showDetailed: Bool
    
    /// Called when the user taps to navigate to DetailItemView
    let onNavigateToDetail: (() -> Void)?
    
    /// Called if the user’s name is empty after editing
    let onEmptyNameLostFocus: (() -> Void)?
    
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            
            // 1) Top row: toggle + multiline name + detail button
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
            
            // 2) Additional fields if showDetailed
            if showDetailed {
                VStack(alignment: .leading, spacing: 2) {
                    
                    // a) Location
                    if let address = item.location?.address, !address.isEmpty {
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "mappin")
                                .foregroundColor(.gray)
                            Text(address)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // b) Creation & optional completed date
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                        Text(
                            formattedDate(item.creationDate) +
                            (item.completed ? " - \(formattedDate(item.dueDate))" : "")
                        )
                        .foregroundColor(.gray)
                    }
                    
                    // c) Image Carousel if any
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
                                                .scaledToFit()
                                                .colorMultiply(.gray)
                                                .frame(maxWidth: .infinity)
                                                .cornerRadius(8)
                                                .padding(.horizontal, 4)
                                        case .failure:
                                            Color.gray.frame(height: 150)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    Color.gray.frame(height: 150)
                                }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle())
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                    }
                }
                .font(.footnote)        // smaller text
                .padding(.leading, 30)  // indent detail area
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
    
    /// Toggle completed state. If marking complete, set item.dueDate = now; else clear it.
    private func toggleCompleted() {
        var updated = item
        if !updated.completed {
            // Marking item as complete
            updated.completed = true
            updated.dueDate = Date()
        } else {
            // Marking item as incomplete
            updated.completed = false
            updated.dueDate = nil
        }
        bucketListViewModel.addOrUpdateItem(updated)
    }
    
    /// Update item name
    private func updateItemName(_ newName: String) {
        var updated = item
        updated.name = newName
        bucketListViewModel.addOrUpdateItem(updated)
    }
    
    /// Format optional Date for display
    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "--" }
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
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






























