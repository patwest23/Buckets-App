//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI
import PhotosUI

struct ItemRowView: View {
    @ObservedObject var viewModel: ItemRowViewModel // Use the revised view model
    @Binding var isEditing: Bool
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Toggle completion status
                Button(action: {
                    viewModel.toggleCompleted() // Use the view model method
                }) {
                    Image(systemName: viewModel.item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .font(.title2)
                        .foregroundColor(viewModel.item.completed ? Color("AccentColor") : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())

                // Left-align the text with navigation to detail view
                NavigationLink(destination: DetailItemView(item: .constant(viewModel.item))) {
                    Text(viewModel.item.name.isEmpty ? "Untitled Item" : viewModel.item.name)
                        .foregroundColor(viewModel.item.completed ? .gray : .primary)
                        .font(.title3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Displaying selected images in a carousel (TabView)
            if !viewModel.item.imagesData.isEmpty {
                TabView {
                    ForEach(Array(viewModel.item.imagesData.enumerated()), id: \.offset) { _, imageData in
                        if let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: 400)
                                .cornerRadius(20)
                                .clipped()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 400)
                .edgesIgnoringSafeArea(.horizontal)
            }
        }
        .padding(.vertical, 10)
    }
}

//struct ItemRowView_Previews: PreviewProvider {
//    @State static var item = ItemModel(
//        name: "Example Item",
//        description: "An example item description",
//        imagesData: [
//            UIImage(systemName: "photo")!.jpegData(compressionQuality: 1.0)!,
//            UIImage(systemName: "photo.fill")!.jpegData(compressionQuality: 1.0)!,
//            UIImage(systemName: "photo.on.rectangle.angled")!.jpegData(compressionQuality: 1.0)!
//        ]
//    )
//    @State static var isEditing = false
//
//    static var previews: some View {
//        ItemRowView(viewModel: ItemRowViewModel(item: item), isEditing: $isEditing)
//            .previewLayout(.sizeThatFits)
//            .padding()
//            .previewDisplayName("Item Row Preview with Images")
//    }
//}






























