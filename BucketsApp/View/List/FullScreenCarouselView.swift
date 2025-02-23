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
    
    // Detect light/dark mode
    @Environment(\.colorScheme) private var colorScheme
    
    // Dynamic background: white if light mode, black if dark
    private var dynamicBackground: Color {
        colorScheme == .dark ? .black : .white
    }
    
    // Dynamic foreground for most text/icons
    private var dynamicForeground: Color {
        colorScheme == .dark ? .white : .black
    }
    
    // Checkmark color specifically
    private var checkmarkColor: Color {
        colorScheme == .dark ? .white : .accentColor
    }
    
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
                        .background(dynamicBackground)   // adapt to light/dark
                        .ignoresSafeArea()
                    } else {
                        // Placeholder
                        VStack {
                            ProgressView("Loading image...")
                                .foregroundColor(dynamicForeground)
                                .padding()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(dynamicBackground)
                        .ignoresSafeArea()
                    }
                }
            }
            .tabViewStyle(.page)
            .background(dynamicBackground)
            .ignoresSafeArea()
            
            // 2) Dismiss (X) button, pinned top-right but lowered
            VStack {
                Spacer()
                    .frame(height: 20) // push it down from top somewhat
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(dynamicForeground)
                            .padding(.trailing, 16)
                    }
                }
                Spacer()
            }
            
            // 3) Top-Left: Checkmark + item name, lowered slightly
            VStack {
                Spacer().frame(height: 50) // offset from the top
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(checkmarkColor)  // <-- use accent for light, white for dark
                    Text(itemName)
                        .font(.headline)
                        .foregroundColor(dynamicForeground)
                    Spacer()
                }
                .padding(.leading, 20)
                
                Spacer()
            }
            
            // 4) Bottom: Date on left, Location on right
            // (both optional, appear only if present)
            VStack {
                Spacer()
                HStack {
                    // Date on the left (if present)
                    if let dateStr = formattedDate {
                        HStack {
                            Image(systemName: "calendar")
                            Text(dateStr)
                        }
                        .foregroundColor(dynamicForeground)
                    }
                    Spacer()
                    // Location on the right (if present)
                    if let location = location, !location.isEmpty {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                            Text(location)
                        }
                        .foregroundColor(dynamicForeground)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40) // space above iPhone home indicator
            }
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
