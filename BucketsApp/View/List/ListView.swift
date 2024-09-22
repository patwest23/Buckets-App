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
    @State private var editingIndex: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(viewModel.items.indices, id: \.self) { index in
                    ItemRowView(item: $viewModel.items[index], isEditing: Binding(
                        get: { editingIndex == index },
                        set: { newValue in
                            editingIndex = newValue ? index : nil
                        }
                    ))
//                    .padding(.horizontal)
                    .onTapGesture {
                        editingIndex = (editingIndex == index) ? nil : index
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                profileNavigationLink
            }
        }
        .navigationTitle("Buckets")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(addButton, alignment: .bottomTrailing)
    }

    private var profileNavigationLink: some View {
        NavigationLink(destination: ProfileView()) {
            Image(systemName: "person.crop.circle")
        }
    }

    private var addButton: some View {
        Button(action: {
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()

            viewModel.addItem()
            editingIndex = viewModel.items.count - 1
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
        let mockOnboardingViewModel = MockOnboardingViewModel()
        let mockListViewModel = ListViewModel()

        // Simulate some mock items
        mockListViewModel.items = [
            ItemModel(
                name: "Sample Item 1",
                description: "Description 1",
                imagesData: [
                    UIImage(systemName: "photo")!.jpegData(compressionQuality: 1.0)!,
                    UIImage(systemName: "photo.fill")!.jpegData(compressionQuality: 1.0)!,
                    UIImage(systemName: "photo.on.rectangle.angled")!.jpegData(compressionQuality: 1.0)!
                ]
            ),
            ItemModel(name: "Sample Item 2", description: "Description 2")
        ]
        
        return NavigationView {
            ListView()
                .environmentObject(mockListViewModel)
                .environmentObject(mockOnboardingViewModel) // Use the mock view model here
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .previewDisplayName("List View Preview with Mock Items and Images")
    }
}
