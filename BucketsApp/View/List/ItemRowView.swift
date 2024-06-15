//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRowView: View {
    @Binding var item: ItemModel
    @Binding var focusedItemID: Focusable?

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
                .onTapGesture {
                    focusedItemID = .row(id: item.id!)
                }
                .onSubmit {
                    focusedItemID = .none
                }
        }
        .background(focusedItemID == .row(id: item.id!) ? Color.gray.opacity(0.2) : Color.clear)
    }
}

struct ItemRowView_Previews: PreviewProvider {
    @State static var showImages = true
    @State static var focusedItemID: Focusable?

    static var previews: some View {
        let item = ItemModel(name: "Example Item", description: "An example item description")
        
        return ItemRowView(
            item: .constant(item),
            focusedItemID: $focusedItemID
        )
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
































