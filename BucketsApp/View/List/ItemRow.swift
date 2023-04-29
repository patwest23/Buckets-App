//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//

import SwiftUI

struct ItemRow: View {
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @State private var showingAddItemView = false
    @State private var showingEditItemView = false
    @State private var selectedItem: ItemModel?
    
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
    static var previews: some View {
        ItemRow(item: ItemModel(id: UUID(), name: "Test Item for the item row!", description: "this is a test", completed: true)) { _ in }
    }
}

