//
//  FullScreenCarouselView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 2/9/25.
//

import SwiftUI

struct FullScreenCarouselView: View {
    let images: [CarouselImageSource]
    let itemName: String
    let isCompleted: Bool
    let location: String?
    let dateCompleted: Date?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var listViewModel: ListViewModel
    @Environment(\.colorScheme) private var colorScheme

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var selectedIndex: Int

    private let dragDismissThreshold: CGFloat = 120

    init(
        images: [CarouselImageSource],
        initialIndex: Int = 0,
        itemName: String,
        isCompleted: Bool,
        location: String?,
        dateCompleted: Date?
    ) {
        self.images = images
        self.itemName = itemName
        self.isCompleted = isCompleted
        self.location = location
        self.dateCompleted = dateCompleted

        if images.isEmpty {
            _selectedIndex = State(initialValue: 0)
        } else {
            let boundedIndex = min(max(initialIndex, 0), images.count - 1)
            _selectedIndex = State(initialValue: boundedIndex)
        }
    }

    private var dynamicBackground: Color {
        colorScheme == .dark ? .black : .white
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var subtitleColor: Color { .secondary }

    private var formattedDate: String? {
        guard let dateCompleted else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dateCompleted)
    }

    var body: some View {
        let dragGesture = DragGesture()
            .updating($dragTranslation) { value, state, _ in
                state = max(value.translation.height, 0)
            }
            .onEnded { value in
                if value.translation.height > dragDismissThreshold {
                    dismiss()
                }
            }

        ZStack(alignment: .top) {
            dynamicBackground
                .ignoresSafeArea()

            if !images.isEmpty {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, imageSource in
                        carouselContent(for: imageSource)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No images available")
                        .foregroundColor(.secondary)
                        .font(.headline)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundColor(isCompleted ? .accentColor : .gray)
                        .alignmentGuide(.top) { $0[.top] }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(itemName)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(textColor)
                            .multilineTextAlignment(.leading)

                        if formattedDate != nil || (location?.isEmpty == false) {
                            HStack(spacing: 8) {
                                if let formattedDate {
                                    Text(formattedDate)
                                        .font(.caption)
                                        .foregroundColor(subtitleColor)
                                }

                                if let location, !location.isEmpty {
                                    Text(location)
                                        .font(.caption)
                                        .foregroundColor(subtitleColor)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 52)
        }
        .offset(y: dragTranslation)
        .opacity(opacity(for: dragTranslation))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: dragTranslation)
        .gesture(dragGesture)
    }

    @ViewBuilder
    private func carouselContent(for source: CarouselImageSource) -> some View {
        switch source {
        case .local(let uiImage):
            PinchZoomImage(
                image: Image(uiImage: uiImage)
                    .resizable()
            )
            .background(dynamicBackground)
            .ignoresSafeArea()
        case .remote(let urlStr):
            if let cached = listViewModel.imageCache[urlStr] {
                PinchZoomImage(
                    image: Image(uiImage: cached)
                        .resizable()
                )
                .background(dynamicBackground)
                .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    ProgressView("Loading image...")
                    Text("Pull down to close")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(dynamicBackground)
                .ignoresSafeArea()
            }
        }
    }

    private func opacity(for translation: CGFloat) -> Double {
        let distance = min(abs(translation), 200)
        return Double(1 - (distance / 400))
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
        let sampleImages: [CarouselImageSource] = [
            .remote("https://example.com/image1"),
            .remote("https://example.com/image2"),
            .remote("https://example.com/image3")
        ]
        
        // 3) Use a date for example
        let sampleDate = Date()
        
        return Group {
            // Light mode: location + date
            FullScreenCarouselView(
                images: sampleImages,
                itemName: "Visit Tokyo",
                isCompleted: true,
                location: "Shinjuku, Tokyo",
                dateCompleted: sampleDate
            )
            .environmentObject(mockListVM)
            .preferredColorScheme(ColorScheme.light)
            .previewDisplayName("Light Mode - Location + Date")
            
            // Dark mode: location only, no date
            FullScreenCarouselView(
                images: sampleImages,
                itemName: "Visit Tokyo",
                isCompleted: false,
                location: "Shibuya Crossing",
                dateCompleted: nil
            )
            .environmentObject(mockListVM)
            .preferredColorScheme(ColorScheme.dark)
            .previewDisplayName("Dark Mode - Location Only")
        }
    }
}
