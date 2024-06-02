//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI
import PhotosUI

struct ListView: View {
    @EnvironmentObject var viewModel: ListViewModel
    @FocusState private var focusedItemID: Focusable?

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.items.indices, id: \.self) { index in
                    ItemRowView(item: $viewModel.items[index], focusedItemID: $focusedItemID, showImages: $viewModel.showImages)
                        .focused($focusedItemID, equals: .row(id: viewModel.items[index].id!))
                }
                .onDelete { indexSet in
                    viewModel.deleteItems(at: indexSet)
                }
                .listRowSeparatorTint(.clear)
            }
            .navigationTitle("Buckets")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(addButton, alignment: .bottomTrailing)
        }
        .onChange(of: focusedItemID) { newValue in
            viewModel.focusedItemID = newValue
        }
    }

    private var addButton: some View {
        Button(action: {
            let newItem = ItemModel(name: "")
            viewModel.items.append(newItem)
            focusedItemID = .row(id: newItem.id ?? UUID())
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
        }) {
            ZStack {
                Circle()
                    .frame(width: 60, height: 60)
                    .shadow(color: .gray, radius: 10, x: 0, y: 5)
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}

struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        ListView()
            .environmentObject(ListViewModel())
            .environmentObject(OnboardingViewModel())
    }
}

























//    .position(x: UIScreen.main.bounds.width - 70, y: UIScreen.main.bounds.height - 180)










//    private var optionsMenu: some View {
//        Menu {
//            Toggle(isOn: $viewModel.hideCompleted) {
//                Label(viewModel.hideCompleted ? "Show Completed" : "Hide Completed", systemImage: "checkmark.circle")
//            }
//            Toggle(isOn: $viewModel.showImages) {
//                Label(viewModel.showImages ? "Hide Images" : "Show Images", systemImage: "photo")
//            }
//            Button("Edit List") {
//                // Placeholder for future feature
//            }
//        } label: {
//            Image(systemName: "ellipsis.circle")
//        }
//        .onChange(of: $viewModel.hideCompleted) { _ in
//            viewModel.sortItems()
//        }
//        .onChange(of: viewModel.showImages) { _ in
//            // Handle showImages change if needed
//        }
//    }
