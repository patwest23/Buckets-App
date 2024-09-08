//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI
import PhotosUI

struct ItemRowView: View {
    @Binding var item: ItemModel
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Toggle completion status
                Button(action: {
                    item.completed.toggle()
                }) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .font(.title2)
                        .foregroundColor(item.completed ? Color("AccentColor") : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())

                // Navigation to DetailItemView
                NavigationLink(destination: DetailItemView(item: $item)) {
                    TextField("Item Name", text: $item.name)
                        .foregroundColor(item.completed ? .gray : .primary)
                        .font(.title3)
                        .disabled(true) // Disable inline editing
                }
            }

            // Displaying selected images
            if !item.imagesData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(item.imagesData, id: \.self) { imageData in
                            if let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(10)
                                    .onLongPressGesture {
                                        // Add logic for long press to delete the image
                                        if let index = item.imagesData.firstIndex(of: imageData) {
                                            item.imagesData.remove(at: index)
                                        }
                                    }
                            }
                        }
                    }
                }
                .frame(height: 80)
            }

            // PhotosPicker to add images
            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 3, matching: .images) {
                Label("Add Image", systemImage: "photo.on.rectangle")
                    .font(.callout)
                    .foregroundColor(.blue)
            }
            .onChange(of: selectedPhotos) { newItems in
                for newItem in newItems {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                                item.imagesData.append(data)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}

struct ItemRowView_Previews: PreviewProvider {
    @State static var item = ItemModel(name: "Example Item", description: "An example item description")
    
    static var previews: some View {
        ItemRowView(item: .constant(item))
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Item Row Preview")
    }
}









//struct ItemRowView_Previews: PreviewProvider {
//    @State static var showImages = true
//    @State static var focusedItemID: Focusable?
//
//    static var previews: some View {
//        let item = ItemModel(name: "Example Item", description: "An example item description")
//        
//        return ItemRowView(
//            item: .constant(item),
//            focusedItemID: $focusedItemID,
//            showImages: $showImages
//        )
//        .previewLayout(.sizeThatFits)
//        .padding()
//        .previewDisplayName("Item Row Preview")
//    }
//}
































