//
//  FollowersListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/17/25.
//

import SwiftUI

struct FollowersListView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var followerUsers: [UserModel] = []

    var body: some View {
        List {
            if followerUsers.isEmpty {
                Text("You don't have any followers yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(followerUsers) { user in
                    HStack(spacing: 12) {
                        userProfileImage(for: user.profileImageUrl)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())

                        VStack(alignment: .leading) {
                            Text(user.username ?? "No username")
                            Text(user.name ?? "No name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Followers")
        .onAppear {
            Task {
                await userViewModel.loadCurrentUser()
                await loadFollowerUsers()
            }
        }
    }

    private func userProfileImage(for urlString: String?) -> some View {
        Group {
            if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "person.crop.circle.fill.badge.exclam")
                            .resizable()
                            .scaledToFill()
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    private func loadFollowerUsers() async {
        guard let followerIDs = userViewModel.user?.followers else { return }
        var loadedUsers: [UserModel] = []

        for uid in followerIDs {
            if let user = try? await userViewModel.fetchUser(with: uid) {
                loadedUsers.append(user)
            }
        }

        followerUsers = loadedUsers
    }
}

#Preview {
    let mockUserVM = UserViewModel()
    mockUserVM.user = UserModel(
        id: "mockUser",
        email: "mock@example.com",
        createdAt: Date(),
        name: "Mock User",
        username: "@mock",
        followers: ["user_123", "user_456"]
    )
    return NavigationStack {
        FollowersListView()
            .environmentObject(mockUserVM)
    }
}

