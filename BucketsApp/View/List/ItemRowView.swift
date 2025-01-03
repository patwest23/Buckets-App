//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel

    let item: ItemModel
    @Binding var isEditing: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Toggle completion status
                Button(action: {
                    Task {
                        await toggleCompleted()
                    }
                }) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .font(.title2)
                        .foregroundColor(item.completed ? .accentColor : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())

                // Navigation link to DetailItemView
                NavigationLink(
                    destination: DetailItemView(
                        item: Binding(
                            get: { itemFromList ?? item },
                            set: { updatedItem in
                                Task {
                                    await updateItemInFirestore(updatedItem)
                                }
                            }
                        )
                    )
                ) {
                    Text(item.name.isEmpty ? "Untitled Item" : item.name)
                        .foregroundColor(item.completed ? .gray : .primary)
                        .font(.title3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Display photo carousel if images exist
            if !item.imageUrls.isEmpty {
                TabView {
                    ForEach(item.imageUrls, id: \.self) { imageUrl in
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: 300)
                                .cornerRadius(20)
                                .clipped()
                        } placeholder: {
                            ProgressView() // Show loading indicator
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 300)
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Private Helpers

    /// Looks up the latest version of this item from the ListViewModel’s items,
    /// in case it has been updated in memory already.
    private var itemFromList: ItemModel? {
        listViewModel.items.first { $0.id == item.id }
    }

    /// Toggles the `completed` property in Firestore using `ListViewModel`.
    private func toggleCompleted() async {
        guard let userId = onboardingViewModel.user?.id else { return }
        var updatedItem = itemFromList ?? item
        updatedItem.completed.toggle()
        await listViewModel.addOrUpdateItem(updatedItem, userId: userId)
    }

    /// Updates the item in Firestore with any new changes (e.g., name, details).
    private func updateItemInFirestore(_ updatedItem: ItemModel) async {
        guard let userId = onboardingViewModel.user?.id else { return }
        await listViewModel.addOrUpdateItem(updatedItem, userId: userId)
    }
}































