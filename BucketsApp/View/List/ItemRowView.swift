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
    @Binding var isEditing: Bool
    @FocusState private var isFocused: Bool
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

                // Editable text field for item name (Left aligned)
                TextField("Item Name", text: $item.name)
                    .foregroundColor(item.completed ? .gray : .primary)
                    .font(.title3)
                    .focused($isFocused)
                    .disabled(!isEditing) // Only editable in edit mode
                    .onChange(of: isEditing) { newValue in
                        // Automatically focus when editing starts
                        if newValue {
                            isFocused = true
                        } else {
                            isFocused = false
                        }
                    }
            }

            // Displaying selected images in a larger carousel (TabView)
            if !item.imagesData.isEmpty {
                TabView {
                    ForEach(Array(item.imagesData.enumerated()), id: \.offset) { index,  imageData in
                        if let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()  // Scale to fill the entire frame
                                .frame(maxWidth: .infinity, maxHeight: 400) // Extend to the full width of the screen
                                .cornerRadius(10)
                                .clipped() // Clip the overflowing content
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 400) // Match the image height
                .edgesIgnoringSafeArea(.horizontal) // Extend to the edges of the screen
            }
        }
        .padding(.vertical, 10)
    }
}

struct ItemRowView_Previews: PreviewProvider {
    @State static var item = ItemModel(
        name: "Example Item",
        description: "An example item description",
        imagesData: [
            UIImage(systemName: "photo")!.jpegData(compressionQuality: 1.0)!,
            UIImage(systemName: "photo.fill")!.jpegData(compressionQuality: 1.0)!,
            UIImage(systemName: "photo.on.rectangle.angled")!.jpegData(compressionQuality: 1.0)!
        ]
    )
    @State static var isEditing = true

    static var previews: some View {
        NavigationView {
            ItemRowView(item: $item, isEditing: $isEditing)
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Item Row Preview with Images")
        }
    }
}






























