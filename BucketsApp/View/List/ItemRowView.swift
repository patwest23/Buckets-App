//
//  ItemRow.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/11/23.
//


import SwiftUI

struct ItemRowView: View {
    @Binding var item: ItemModel
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Button(action: {
                item.completed.toggle()
            }) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.completed ? .green : .gray)
                    .font(.title3)
            }
            TextField("Item Name", text: $item.name)
                .focused($isFocused)
        }
        .padding()
    }
}

struct ItemRow_Previews: PreviewProvider {
    static var previews: some View {
        let item = ItemModel(name: "Example Item", description: "An example item description")
        
        return ItemRowView(item: .constant(item))
    }
}






//import SwiftUI
//
//struct ItemRow: View {
//    var bucketListViewModel: ListViewModel
//    @State private var showingAddItemView = false
//    @State private var showingEditItemView = false
//    @State private var selectedItem: ItemModel?
//    var item: ItemModel
//    var onCompleted: (Bool) -> Void
//    @Binding var showImages: Bool  // Binding to control image visibility
//
//    init(bucketListViewModel: ListViewModel, item: ItemModel, onCompleted: @escaping (Bool) -> Void, showImages: Binding<Bool>) {
//        self.bucketListViewModel = bucketListViewModel
//        self.item = item
//        self.onCompleted = onCompleted
//        self._showImages = showImages
//    }
//
//    var body: some View {
//        VStack (alignment: .leading) {
//            HStack {
//                Button(action: {
//                    onCompleted(!item.completed)
//                }) {
//                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
//                        .imageScale(.large)
//                        .font(.title2)
//                        .foregroundColor(item.completed ? Color("AccentColor") : .gray)
//                }
//                .buttonStyle(BorderlessButtonStyle())
//
//                Text(item.name)
//                    .foregroundColor(item.completed ? .gray : .primary)
//                    .font(.title3)
//            }
//
//            // Conditionally display the image based on the showImages binding
//            if showImages, let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
//                Image(uiImage: uiImage)
//                    .resizable()
//                    .scaledToFit()
//                    .cornerRadius(20)
//            }
//        }
//    }
//}
//
//struct ItemRow_Previews: PreviewProvider {
//    @State static var showImages = true // Mock state for image visibility
//
//    static var previews: some View {
//        // Create a sample item with nil imageData
//        let item = ItemModel(id: UUID(), name: "Example Item", description: "An example item description", completed: false)
//        let viewModel = ListViewModel()
//
//        return ItemRow(
//            bucketListViewModel: viewModel,
//            item: item,
//            onCompleted: { _ in },
//            showImages: $showImages
//        )
//        .environmentObject(viewModel)
//        .previewLayout(.fixed(width: 300, height: 80))
//        .padding()
//        .previewDisplayName("Item Row Preview")
//    }
//}





