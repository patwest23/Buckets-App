//
//  FullScreenCarouselView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 2/9/25.
//

import SwiftUI

struct FullScreenCarouselView: View {
    let imageUrls: [String]
    @Environment(\.dismiss) var dismiss
    
    // We read from the view model’s `imageCache`.
    @EnvironmentObject var listViewModel: ListViewModel
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView {
                ForEach(imageUrls, id: \.self) { urlStr in
                    // 1) Check if this URL is in the cache
                    if let uiImage = listViewModel.imageCache[urlStr] {
                        // 2) Display the pinch-zoom image from the cached UIImage
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
                        // 3) Fallback if not in cache => show a placeholder or color
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
            
            // Dismiss button (X) in the top-right corner
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}
