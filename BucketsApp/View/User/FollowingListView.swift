//
//  FollowingListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/17/25.
//

import SwiftUI


struct FollowingListView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var followingUsers: [UserModel] = []

    var body: some View {
        List {
            if followingUsers.isEmpty {
                Text("You're not following anyone yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(followingUsers) { user in
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

                        Button(role: .destructive) {
                            Task {
                                await userViewModel.unfollowUser(user)
                                await userViewModel.loadCurrentUser()
                                await loadFollowingUsers()
                            }
                        } label: {
                            Text("Unfollow")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Following")
        
        .onAppear {
            Task {
                await userViewModel.loadCurrentUser()
                print("[FollowingListView] onAppear triggered")
                followingUsers = await userViewModel.loadFollowingUsers()
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

    private func loadFollowingUsers() async {
        print("[FollowingListView] loadFollowingUsers triggered")
        guard let followingIDs = userViewModel.user?.following else { return }
        var loadedUsers: [UserModel] = []

        for uid in followingIDs {
            if let user = try? await userViewModel.fetchUser(with: uid) {
                loadedUsers.append(user)
            }
        }

        print("[FollowingListView] Loaded followingUsers count: \(loadedUsers.count)")

        await MainActor.run {
            self.followingUsers = loadedUsers
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
