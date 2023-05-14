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

    var body: some View {
        HStack {
            Button(action: {
                onCompleted(!item.completed)
            }) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.completed ? Color("AccentColor") : .gray)
            }
            .buttonStyle(BorderlessButtonStyle())

            Text(item.name)
                .strikethrough(item.completed)

            Spacer()
        }
    }
}

struct ItemRow_Previews: PreviewProvider {
    static let item = ItemModel(id: UUID(), image: Image(systemName: "pencil.circle.fill"), name: "Example Item", description: "An example item description", completed: false)
    
    static var previews: some View {
        ItemRow(item: item) { _ in }
            .previewLayout(.sizeThatFits)
            .padding()
    }
}



