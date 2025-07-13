//
//  FriendsView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/12/25.
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var viewModel: FriendsViewModel
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.followingUsers.isEmpty &&
                   viewModel.followerUsers.isEmpty &&
                   viewModel.allUsers.isEmpty {
                    ProgressView("Loading users...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // --- Explore Section
                        Section(header: Text("Explore")) {
                            let explore = viewModel.exploreUsers(searchText)
                            if explore.isEmpty {
                                Text("No users to explore.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(explore, id: \.documentId) { user in
                                    userRow(for: user)
                                }
                            }
                        }

                        // --- Following Section
                        Section(header: Text("Following")) {
                            let following = viewModel.filteredFollowing(searchText)
                            if following.isEmpty {
                                Text("You're not following anyone yet.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(following) { user in
                                    userRow(for: user)
                                }
                            }
                        }

                        // --- Followers Section
                        Section(header: Text("Followers")) {
                            let followers = viewModel.filteredFollowers(searchText)
                            if followers.isEmpty {
                                Text("You don't have any followers yet.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(followers) { user in
                                    userRow(for: user)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Friends")
            .task {
                await viewModel.loadFriendsData()
                await viewModel.loadAllUsers()
                viewModel.startListeningToFriendChanges()
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                EmptyView()
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .searchable(text: $searchText, prompt: "Search users")
    }
    
    @ViewBuilder
    private func userRow(for user: UserModel) -> some View {
        HStack {
            userProfileImage(for: user)
            Text(user.username ?? "Unknown")
            Spacer()
            Button {
                if viewModel.isUserFollowed(user) {
                    Task {
                        await viewModel.unfollow(user)
                    }
                } else {
                    Task {
                        await viewModel.follow(user)
                    }
                }
            } label: {
                Text(viewModel.isUserFollowed(user) ? "Unfollow" : "Follow")
                    .foregroundColor(viewModel.isUserFollowed(user) ? .red : .blue)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
    
    @ViewBuilder
    private func userProfileImage(for user: UserModel) -> some View {
        if let urlString = user.profileImageUrl,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 40, height: 40)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                case .failure:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
        }
    }
    
    private func userMatchesSearch(_ user: UserModel, _ query: String) -> Bool {
        if query.isEmpty { return true }
        let lower = query.lowercased()
        return user.name?.lowercased().contains(lower) == true ||
               user.username?.lowercased().contains(lower) == true
    }

    private func sortUsers(_ lhs: UserModel, _ rhs: UserModel, with query: String) -> Bool {
        guard !query.isEmpty else { return false }
        let lower = query.lowercased()
        let lhsScore = (lhs.name?.lowercased().contains(lower) == true ? 1 : 0) +
                       (lhs.username?.lowercased().contains(lower) == true ? 1 : 0)
        let rhsScore = (rhs.name?.lowercased().contains(lower) == true ? 1 : 0) +
                       (rhs.username?.lowercased().contains(lower) == true ? 1 : 0)
        return lhsScore > rhsScore
    }
}

#if DEBUG
struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockVM = FriendsViewModel()
        
        // Sample users
        let user1 = UserModel(documentId: "1", email: "alice@test.com", profileImageUrl: nil, name: "Alice", username: "@alice")
        var user2 = UserModel(documentId: "2", email: "bob@test.com", profileImageUrl: nil, name: "Bob", username: "@bob")
        user2.isFollowed = true
        let user3 = UserModel(documentId: "3", email: "charlie@test.com", profileImageUrl: nil, name: "Charlie", username: "@charlie")
        
        // Assign test data
        mockVM.allUsers = [user1, user2]
        mockVM.followingUsers = [user2]
        mockVM.followerUsers = [user3]
        
        return FriendsView()
            .environmentObject(mockVM)
    }
}
#endif
