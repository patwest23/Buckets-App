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
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView {
                ForEach(imageUrls, id: \.self) { urlStr in
                    if let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let loadedImage):
                                // Convert the "AsyncImage phase success" into a SwiftUI Image
                                // Then wrap it with PinchZoomImage
                                PinchZoomImage(image:
                                    loadedImage
                                        .resizable() // Ensure it's resizable
                                )
                                .background(Color.black) // black background
                                .ignoresSafeArea()
                                
                            case .failure:
                                Color.gray
                                    .ignoresSafeArea()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        // Invalid URL => gray background
                        Color.gray
                            .ignoresSafeArea()
                    }
                }
            }
            .tabViewStyle(.page)
            .background(Color.black)
            .ignoresSafeArea()
            
            // Dismiss button (X) in the top-right corner
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}
