//
//  PhotosPickerView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/23/23.
//

import PhotosUI
import SwiftUI

struct PhotosPickerView: View {
    @State private var selectedItems = [PhotosPickerItem]()
    @State private var selectedImages = [Image]()

    private let gridItems = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: gridItems, spacing: 10) {
                    ForEach(0..<selectedImages.count, id: \.self) { i in
                        selectedImages[i]
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width/5 - 20, height: UIScreen.main.bounds.width/5 - 20)
                            .cornerRadius(10)
                    }
                }
            }

            VStack {
                Spacer()
                PhotosPicker("Select images", selection: $selectedItems, maxSelectionCount: 5, matching: .images)
                    .frame(maxWidth: 200)
//                    .padding()
                Spacer()
            }
            .background(Color.white.opacity(0.8))
            .onChange(of: selectedItems) { _ in
                Task {
                    selectedImages.removeAll()

                    for item in selectedItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data) {
                                let image = Image(uiImage: uiImage)
                                selectedImages.append(image)
                            }
                        }
                    }
                }
            }
        }
    }
}


struct PhotosPickerView_Previews: PreviewProvider {
    static var previews: some View {
        PhotosPickerView()
    }
}
