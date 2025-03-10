//
//  FeedRowView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct FeedRowView: View {
    let post: PostModel
    
    let onLike: () -> Void
    let onComment: () -> Void
    
    // Convert the optional date into a string if `post.itemCompleted == true`
    private var completedDateString: String? {
        guard post.itemCompleted, let date = post.itemDueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var body: some View {
        ZStack {
            // Carousel-like TabView
            if post.itemImageUrls.isEmpty {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 300)
                    .overlay(Text("No images").foregroundColor(.gray))
            } else {
                TabView {
                    ForEach(post.itemImageUrls, id: \.self) { urlStr in
                        FeedRowImageView(urlStr: urlStr)
                            .frame(height: 300)
                            .clipped()
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 300)
            }
            
            // Top-left overlay: checkmark + item name
            VStack {
                HStack {
                    if post.itemCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    Text(post.itemName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                Spacer()
            }
            
            // Bottom overlay: date, location, caption, and action buttons
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    
                    // Date & location row
                    HStack {
                        if let dateStr = completedDateString {
                            HStack {
                                Image(systemName: "calendar")
                                Text(dateStr)
                            }
                            .foregroundColor(.white)
                        }
                        Spacer()
                        if let loc = post.itemLocation, let address = loc.address, !address.isEmpty {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text(address)
                            }
                            .foregroundColor(.white)
                        }
                    }
                    
                    // caption
                    if let caption = post.caption, !caption.isEmpty {
                        Text(caption)
                            .foregroundColor(.white)
                    }
                    
                    // Like/Comment row
                    HStack {
                        Button(action: onLike) {
                            Image(systemName: "heart")
                            Text("Like (\(post.likedBy?.count ?? 0))")
                        }
                        .foregroundColor(.white)
                        
                        Button(action: onComment) {
                            Image(systemName: "bubble.left")
                            Text("Comment")
                        }
                        .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color.black.opacity(0.3))
            }
        }
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct FeedRowImageView: View {
    let urlStr: String
    
    var body: some View {
        AsyncImage(url: URL(string: urlStr)) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure(_):
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            @unknown default:
                EmptyView()
            }
        }
        .clipped()
    }
}
