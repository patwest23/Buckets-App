//
//  ImagePicker.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/14/23.
//

import SwiftUI
import PhotosUI

struct PhotoAlbumView: View {
    @State private var isPresentingPhotoPicker = false
    @State private var selectedAssets: [PHAssetResource] = []
    
    var body: some View {
        NavigationView {
            VStack {
                Button(action: {
                    isPresentingPhotoPicker.toggle()
                }) {
                    Text("Select Photos")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
                
                if !selectedAssets.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(selectedAssets, id: \.localIdentifier) { asset in
                                PhotoView(asset: asset)
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("No Photos Selected")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            }
            .navigationBarTitle("Photo Album")
        }
        .sheet(isPresented: $isPresentingPhotoPicker) {
            PhotoPickerView(selectedAssets: $selectedAssets)
        }
    }
}

struct PhotoPickerView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var selectedAssets: [PHAssetResource]
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 10
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: PHPickerViewControllerDelegate {
        let parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.selectedAssets.removeAll()
            
            for result in results {
                if let assetIdentifier = result.assetIdentifier {
                    let resources = PHAssetResource.assetResources(for: result.asset)
                    if let assetResource = resources.first {
                        parent.selectedAssets.append(assetResource)
                    }
                }
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct PhotoView: View {
    let asset: PHAssetResource
    
    var body: some View {
        if let imageData = getAssetImageData(),
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .cornerRadius(8)
        } else {
            Color.gray
        }
    }
    
    private func getAssetImageData() -> Data? {
        let manager = PHAssetResourceManager.default()
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        
        var imageData: Data?
        manager.requestData(for: asset, options: options) { (data, _, _) in
            imageData = data
        }
        





