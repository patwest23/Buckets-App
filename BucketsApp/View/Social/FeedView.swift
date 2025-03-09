//
//  FeedView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct FeedView: View {
    @StateObject var feedVM = FeedViewModel()
    
    var body: some View {
        NavigationView {
            List(feedVM.posts) { post in
                VStack(alignment: .leading) {
                    Text("Caption: \(post.caption ?? "")")
                    Text("Author: \(post.authorId)")
                    Text("Liked by: \(post.likedBy?.count ?? 0) users")
                    Button("Like/Unlike") {
                        Task {
                            await feedVM.toggleLike(post: post)
                        }
                    }
                }
            }
            .navigationTitle("Your Feed")
            .onAppear {
                Task {
                    await feedVM.fetchFeedPosts()
                }
            }
        }
    }
}
