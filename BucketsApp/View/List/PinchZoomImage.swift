//
//  PinchZoomImage.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 2/16/25.
//

import SwiftUI

/// A pinch-zoom image that:
///   - Won't zoom below 1.0
///   - Only drags if scale > 1 (so TabView can swipe horizontally at scale=1)
///   - Double-tap resets to default (scale=1, offset=0).
///   - Pinch gestures can start at scale=1 without blocking TabView swipes.
struct PinchZoomImage: View {
    let image: Image
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            
            // 1) Double-tap => reset
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
            
            // 2) Pinch => zoom (always enabled, even at scale=1)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        // Proposed new scale
                        let newScale = lastScale * value
                        // Enforce min=1
                        scale = max(1.0, newScale)
                    }
                    .onEnded { value in
                        let final = lastScale * value
                        lastScale = max(1.0, final)
                        
                        // If ended up at scale=1 => reset offset
                        if lastScale == 1.0 {
                            withAnimation {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            )
            
            // 3) Drag => only if scale > 1
            // use .simultaneousGesture so it can combine with pinch
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        // Allow panning only if zoomed in
                        guard scale > 1 else { return }
                        
                        let dx = lastOffset.width + value.translation.width
                        let dy = lastOffset.height + value.translation.height
                        offset = CGSize(width: dx, height: dy)
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
    }
}
