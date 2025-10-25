//
//  FriendsView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/12/25.
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var viewModel: FriendsViewModel
    @State private var selectedTab: FriendTab = .following

    enum FriendTab: String, CaseIterable, Identifiable {
        case following = "Following"
        case followers = "Followers"
        case explore = "Explore"

        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            VStack {
                let trimmedQuery = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                let explore = viewModel.exploreUsers
                let following = viewModel.filteredFollowing
                let followers = viewModel.filteredFollowers
                let isQueryEmpty = trimmedQuery.isEmpty

                Picker("", selection: $selectedTab) {
                    ForEach(FriendTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                List {
                    switch selectedTab {
                    case .explore:
                        if explore.isEmpty {
                            if !isQueryEmpty && viewModel.isSearchingRemotely {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .padding(.vertical)
                                    Spacer()
                                }
                            } else if !viewModel.isLoading && !viewModel.isSearchingRemotely {
                                Text(isQueryEmpty ? "No users to explore." : "No users found.")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ForEach(explore) { user in
                                userRow(for: user)
                            }
                        }
                    case .following:
                        if following.isEmpty {
                            if !viewModel.isLoading {
                                Text(isQueryEmpty ? "You're not following anyone yet." : "No matches in your following.")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ForEach(following) { user in
                                userRow(for: user)
                            }
                        }
                    case .followers:
                        if followers.isEmpty {
                            if !viewModel.isLoading {
                                Text(isQueryEmpty ? "You don't have any followers yet." : "No matches in your followers.")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ForEach(followers) { user in
                                userRow(for: user)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $viewModel.searchText, prompt: "Search users")
                .onChange(of: viewModel.searchText, initial: false) {
                    viewModel.handleSearchChange()
                }
            }
            .navigationTitle("Friends")
            .refreshable {
                await viewModel.loadFriendsData(showLoadingIndicator: false)
                await viewModel.loadAllUsers(showLoadingIndicator: false)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading users...")
                        .padding(16)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.isSearchingRemotely {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding()
                        .allowsHitTesting(false)
                }
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
    }
    
    @ViewBuilder
    private func userRow(for user: UserModel) -> some View {
        HStack {
            userProfileImage(for: user)
            Text(user.username ?? user.name ?? "Unknown")
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
}

#if DEBUG
@MainActor
struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = FriendsViewModel()
        vm.isLoading = false
        vm.searchText = ""

        let user1 = UserModel(documentId: "1", email: "alice@test.com", profileImageUrl: "https://randomuser.me/api/portraits/women/1.jpg", name: "Alice", username: "@alice")
        let user2 = UserModel(documentId: "2", email: "bob@test.com", profileImageUrl: "https://randomuser.me/api/portraits/men/2.jpg", name: "Bob", username: "@bob")
        let user3 = UserModel(documentId: "3", email: "charlie@test.com", profileImageUrl: "https://randomuser.me/api/portraits/men/3.jpg", name: "Charlie", username: "@charlie")

        vm.allUsers = [user1, user2]
        vm.followingUsers = [user2]
        vm.followerUsers = [user3]

        return NavigationStack {
            FriendsView()
        }
        .environmentObject(vm)
        .preferredColorScheme(.light)
    }
}
#endif
