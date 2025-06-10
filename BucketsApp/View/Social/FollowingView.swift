//
//  FollowingView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/25/25.
//

import SwiftUI

struct FollowingView: View {
    @EnvironmentObject var followViewModel: FollowViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(followViewModel.following, id: \.self) { userId in
                    let matchedUser = followViewModel.allUsers.first(where: { $0.id == userId })
                    if let user = matchedUser {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .foregroundColor(.blue)

                            VStack(alignment: .leading) {
                                Text(user.username ?? "Unknown")
                                    .font(.headline)
                                Text(user.name ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Button("Unfollow") {
                                Task {
                                    await followViewModel.unfollowUser(user)
                                    await followViewModel.loadFollowingUsers()
                                }
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Following")
            .onAppear {
                Task {
                    await followViewModel.loadFollowingUsers()
                }
            }
        }
    }
}
