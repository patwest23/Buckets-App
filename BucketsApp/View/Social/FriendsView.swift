//
//  FriendsView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/12/25.
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var viewModel: FriendsViewModel
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Following")) {
                    if viewModel.followingUsers.isEmpty {
                        Text("You're not following anyone yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.followingUsers) { user in
                            Text(user.username ?? "Unknown")
                        }
                    }
                }

                Section(header: Text("Followers")) {
                    if viewModel.followerUsers.isEmpty {
                        Text("You don't have any followers yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.followerUsers) { user in
                            Text(user.username ?? "Unknown")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Friends")
            .task {
                await viewModel.loadFriendsData()
                viewModel.startListeningToFriendChanges()
            }
        }
    }
}
