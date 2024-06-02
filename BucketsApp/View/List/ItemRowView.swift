//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    @Binding var item: ItemModel
    @FocusState.Binding var focusedItemID: Focusable?
    @Binding var showImages: Bool

    var body: some View {
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
                .focused($focusedItemID, equals: .row(id: item.id!))
                .onSubmit {
                    focusedItemID = Focusable.none
                }

            if let imageData = item.imageData, showImages {
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                        .cornerRadius(5)
                }
            }
        }
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
































