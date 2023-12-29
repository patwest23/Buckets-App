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
        VStack (alignment: .leading) {
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
            }
            
            if let imageData = item.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(20)
            } else {
                Text("") // Display text when no image is available
                                    .font(.system(size: 16)) // Adjust font size as needed
                                    .foregroundColor(.gray)
                /*
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(10)
                    .foregroundColor(.gray)
                 */
            }
        }
    }
}


struct ItemRow_Previews: PreviewProvider {
    static var previews: some View {
        let item = ItemModel(id: UUID(), name: "Example Item", description: "An example item description", completed: false)
        
        return ItemRow(item: item) { completed in
            // Do something with completed
        }
        .environmentObject(ListViewModel())
        .previewLayout(.fixed(width: 300, height: 80))
        .padding()
        .previewDisplayName("Item Row")
    }
}


