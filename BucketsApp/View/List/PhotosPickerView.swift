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

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack {
                    ForEach(0..<selectedImages.count, id: \.self) { i in
                        selectedImages[i]
                            .resizable()
                            .scaledToFit()
                            .frame(width: 300, height: 300)
                    }
                }
            }
            .toolbar {
                PhotosPicker("Select images", selection: $selectedItems, matching: .images)
            }
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
