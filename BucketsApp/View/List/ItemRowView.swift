//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    @Binding var item: ItemModel
    @Binding var showImages: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    item.completed.toggle()
                }) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .font(.title2)
                        .foregroundColor(item.completed ? Color("AccentColor") : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())

                TextField("Item Name", text: $item.name)
                    .foregroundColor(item.completed ? .gray : .primary)
                    .font(.title3)
            }

            // Conditionally display the image based on the showImages binding
            if showImages, let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(20)
            }
        }
    }
}

struct ItemRowView_Previews: PreviewProvider {
    @State static var showImages = true

    static var previews: some View {
        let item = ItemModel(name: "Example Item", description: "An example item description")
        
        return ItemRowView(
            item: .constant(item),
            showImages: .constant(true)
        )
        .previewLayout(.sizeThatFits)
        .padding()
        .previewDisplayName("Item Row Preview")
    }
}









