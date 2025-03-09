//
//  PostItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct PostItemView: View {
    @StateObject private var viewModel = PostViewModel()
    
    var body: some View {
        VStack {
            // Some UI to select the bucket list item from user’s list
            // or pass it in as a parameter
            
            TextField("Caption...", text: $viewModel.caption)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // Button to tag friends
            Button("Tag Friends") {
                // Present a TagUsersView or similar
            }
            
            Button(action: {
                viewModel.postItem()
            }) {
                Text("Post")
            }
            .disabled(viewModel.isPosting)
        }
        .padding()
    }
}
