//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    @ObservedObject var viewModel: ItemRowViewModel
    @Binding var isEditing: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Toggle completion status
                Button(action: {
                    Task {
                        await viewModel.toggleCompleted() // Async Firestore update
                    }
                }) {
                    Image(systemName: viewModel.item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .font(.title2)
                        .foregroundColor(viewModel.item.completed ? Color.accentColor : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())

                // Navigation link to DetailItemView
                NavigationLink(destination: DetailItemView(item: Binding(
                    get: { viewModel.item },
                    set: { updatedItem in
                        Task {
                            await viewModel.updateItemInFirestore(item: updatedItem) // Pass updatedItem
                        }
                    }
                ))) {
                    Text(viewModel.item.name.isEmpty ? "Untitled Item" : viewModel.item.name)
                        .foregroundColor(viewModel.item.completed ? .gray : .primary)
                        .font(.title3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Display photo carousel if images exist
            if !viewModel.item.imageUrls.isEmpty {
                TabView {
                    ForEach(viewModel.item.imageUrls, id: \.self) { imageUrl in
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
}































