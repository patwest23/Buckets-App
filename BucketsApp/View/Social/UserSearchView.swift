//
//  UserSearchView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct UserSearchView: View {
    @StateObject private var viewModel = UserSearchViewModel()
    
    var body: some View {
        VStack {
            TextField("Search for users...", text: $viewModel.searchText, onCommit: {
                viewModel.searchUsers()
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding()
            
            List(viewModel.searchResults) { user in
                HStack {
                    Text(user.userName)
                    Spacer()
                    // Follow/unfollow button
                    Button("Follow") {
                        viewModel.followUser(user)
                    }
                }
            }
        }
        .navigationTitle("Find Friends")
    }
}
