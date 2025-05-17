//
//  FollowingListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/17/25.
//

import SwiftUI

struct FollowingListView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var followedUsers: [UserModel] = []

    var body: some View {
        List {
            if followedUsers.isEmpty {
                Text("You aren't following anyone yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(followedUsers) { user in
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
        .navigationTitle("Following")
        .onAppear {
            Task {
                await loadFollowedUsers()
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

    private func loadFollowedUsers() async {
        guard let followingIDs = userViewModel.user?.following else { return }
        let users = await userViewModel.fetchUsers(withIDs: followingIDs)
        await MainActor.run {
            self.followedUsers = users
        }
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
        following: ["user_123", "user_456"]
    )
    return NavigationStack {
        FollowingListView()
            .environmentObject(mockUserVM)
    }
}
