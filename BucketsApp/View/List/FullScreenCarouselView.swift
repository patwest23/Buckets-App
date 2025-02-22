//
//  FullScreenCarouselView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 2/9/25.
//

import SwiftUI

struct FullScreenCarouselView: View {
    let imageUrls: [String]
    let itemName: String
    
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var listViewModel: ListViewModel
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            
            // 1) Main TabView of images
            TabView {
                ForEach(imageUrls, id: \.self) { urlStr in
                    if let uiImage = listViewModel.imageCache[urlStr] {
                        VStack {
                            PinchZoomImage(
                                image: Image(uiImage: uiImage)
                                    .resizable()
                            )
                            .padding(.horizontal, 20)
                        }
                        .background(Color.black)
                        .ignoresSafeArea()
                    } else {
                        // Placeholder
                        VStack {
                            ProgressView("Loading image...")
                                .foregroundColor(.white)
                                .padding()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .ignoresSafeArea()
                    }
                }
            }
            .tabViewStyle(.page)
            .background(Color.black)
            .ignoresSafeArea()
            
            // 2) Dismiss button (X) in the top-right corner
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .padding()
            }
        }
        // 3) Overlay the item name + checkmark at the bottom in white
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    
                    Text(itemName)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.bottom, 30)  // extra spacing from the bottom edge
            }
        )
    }
}

// MARK: - Preview
struct FullScreenCarouselView_Previews: PreviewProvider {
    static var previews: some View {
        // 1) Create a mock ListViewModel and populate imageCache
        let mockListVM = ListViewModel()
        
        // Here we’re using SF Symbols as placeholders, but you can load actual UIImage data if you prefer
        if let sfSymbol = UIImage(systemName: "photo") {
            mockListVM.imageCache["https://example.com/image1"] = sfSymbol
            mockListVM.imageCache["https://example.com/image2"] = sfSymbol
            mockListVM.imageCache["https://example.com/image3"] = sfSymbol
        }
        
        // 2) Provide an array of 3 URLs that match the keys in imageCache
        let sampleUrls = [
            "https://example.com/image1",
            "https://example.com/image2",
            "https://example.com/image3"
        ]
        
        // 3) Preview in both Light & Dark mode (though the text is always white now)
        return Group {
            // Light mode
            FullScreenCarouselView(
                imageUrls: sampleUrls,
                itemName: "Visit Tokyo"
            )
            .environmentObject(mockListVM)
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
            
            // Dark mode
            FullScreenCarouselView(
                imageUrls: sampleUrls,
                itemName: "Visit Tokyo"
            )
            .environmentObject(mockListVM)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
