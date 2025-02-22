//
//  FullScreenCarouselView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 2/9/25.
//

import SwiftUI

struct FullScreenCarouselView: View {
    let imageUrls: [String]
    
    // The item name to show at top-left
    let itemName: String
    
    // Optional location & completion date to show at bottom
    let location: String?
    let dateCompleted: Date?
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var listViewModel: ListViewModel
    
    // Helper for date formatting
    private var formattedDate: String? {
        guard let dateCompleted = dateCompleted else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dateCompleted)
    }
    
    var body: some View {
        ZStack {
            // 1) Main TabView of images
            TabView {
                ForEach(imageUrls, id: \.self) { urlStr in
                    if let uiImage = listViewModel.imageCache[urlStr] {
                        // Zoomable image
                        PinchZoomImage(
                            image: Image(uiImage: uiImage)
                                .resizable()
                        )
//                        .padding(.horizontal, 20)
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
            
            // 2) Top-Right: Dismiss (X) button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
            
            // 3) Top-Left: Checkmark + item name
            VStack {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text(itemName)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                // <-- Add a top padding to bring it down
                .padding(.top, 50)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
            
            // 4) Bottom: Location + Date
            VStack {
                Spacer()
                // Show only if location or date exist
                if let location = location, !location.isEmpty, let dateStr = formattedDate {
                    HStack(spacing: 20) {
                        // Location
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                            Text(location)
                        }
                        // Date Completed
                        HStack {
                            Image(systemName: "calendar")
                            Text(dateStr)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.bottom, 30)
                }
                // If you want to handle “location but no date”
                // or “date but no location,” handle it with if/else logic:
                else if let location = location, !location.isEmpty {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text(location)
                    }
                    .foregroundColor(.white)
                    .padding(.bottom, 30)
                }
                else if let dateStr = formattedDate {
                    HStack {
                        Image(systemName: "calendar")
                        Text(dateStr)
                    }
                    .foregroundColor(.white)
                    .padding(.bottom, 30)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Preview
struct FullScreenCarouselView_Previews: PreviewProvider {
    static var previews: some View {
        // 1) Create a mock ListViewModel and populate imageCache
        let mockListVM = ListViewModel()
        
        // Provide some placeholder UIImage for each URL key
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
        
        // 3) Use a date for example
        let sampleDate = Date()
        
        return Group {
            // Light mode: location + date
            FullScreenCarouselView(
                imageUrls: sampleUrls,
                itemName: "Visit Tokyo",
                location: "Shinjuku, Tokyo",
                dateCompleted: sampleDate
            )
            .environmentObject(mockListVM)
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode - Location + Date")
            
            // Dark mode: location only, no date
            FullScreenCarouselView(
                imageUrls: sampleUrls,
                itemName: "Visit Tokyo",
                location: "Shibuya Crossing",
                dateCompleted: nil
            )
            .environmentObject(mockListVM)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode - Location Only")
        }
    }
}
