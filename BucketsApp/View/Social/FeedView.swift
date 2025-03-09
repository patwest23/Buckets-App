//
//  FeedView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.posts) { post in
                // A simple row for each post
                VStack(alignment: .leading) {
                    Text("Item ID: \(post.itemID)")
                    Text("Posted by: \(post.authorID)")
                    if let caption = post.caption {
                        Text(caption)
                    }
                }
            }
            .navigationTitle("Feed")
            .onAppear {
                viewModel.fetchFeedPosts()
            }
        }
    }
}
