//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRow: View {
    var item: ItemModel
    var onCompleted: (Bool) -> Void
    @Binding var showImages: Bool  // Binding to control image visibility
    var onEdit: () -> Void // Action for editing the item

    var body: some View {
        VStack (alignment: .leading) {
            HStack {
                Button(action: {
                    onCompleted(!item.completed)
                }) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .font(.title2)
                        .foregroundColor(item.completed ? Color("AccentColor") : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())

                Text(item.name)
                    .foregroundColor(item.completed ? .gray : .primary)
                    .font(.title3)
                
                // Show edit button when tapped
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
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





struct ItemRow_Previews: PreviewProvider {
    @State static var showImages = true // Mock state for image visibility

    static var previews: some View {
        // Create a sample item with nil imageData
        let item = ItemModel(name: "Example Item", description: "An example item description", completed: false)

        return ItemRow(item: item, onCompleted: { completed in
            // Do something with completed
        }, showImages: $showImages) {
            // Handle editing action
        }
        .environmentObject(ListViewModel())
        .previewLayout(.fixed(width: 300, height: 80))
        .padding()
        .previewDisplayName("Item Row Preview")
    }
}




