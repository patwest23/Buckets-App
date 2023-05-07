//
//  MultiImagePickerView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/7/23.
//

import SwiftUI
import PhotosUI

struct MultiImagePickerView: View {
    @StateObject var imagePicker = ImagePicker()
    let columns = [GridItem(.adaptive(minimum: 100))]
    var body: some View {
        VStack {
            
            PhotosPicker(selection: $imagePicker.imageSelections,
                         maxSelectionCount: 10,
                         matching: .images,
                         photoLibrary: .shared()) {
                Image(systemName: "photo.on.rectangle.angled")
                    .imageScale(.large)
            }

            if !imagePicker.images.isEmpty {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(0..<imagePicker.images.count, id: \.self) { index in
                            imagePicker.images[index]
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                        }
                    }
                }
            } else {
                Text("Tap the menu bar button to select multiple photos.")
            }
        }
        .padding()
    }
}

struct MultiImagePickerView_Previews: PreviewProvider {
    static var previews: some View {
        MultiImagePickerView()
    }
}




