//
//  FollowingView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/25/25.
//

import SwiftUI

struct FollowingView: View {
    @ObservedObject var userViewModel: UserViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(userViewModel.user?.following ?? [], id: \.self) { userId in
                    if let user = userViewModel.allUsers.first(where: { $0.id == userId }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .foregroundColor(.blue)

                            VStack(alignment: .leading) {
                                Text(user.username)
                                    .font(.headline)
                                Text(user.name)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Button("Unfollow") {
                                Task {
                                    await userViewModel.unfollow(user)
                                    await userViewModel.loadAllUsers()
                                    await userViewModel.loadCurrentUser()
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
                    await userViewModel.loadCurrentUser()
                    await userViewModel.loadAllUsers()
                }
            }
        }
    }
}

#Preview {
    FollowingView(userViewModel: UserViewModel())
}
