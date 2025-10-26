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
            ZStack {
                BucketTheme.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: BucketTheme.mediumSpacing) {
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
                    .padding(.horizontal, BucketTheme.mediumSpacing)
                    .padding(.top, BucketTheme.mediumSpacing)

                    List {
                        switch selectedTab {
                        case .explore:
                            exploreSection(explore, isQueryEmpty: isQueryEmpty)
                        case .following:
                            followingSection(following, isQueryEmpty: isQueryEmpty)
                        case .followers:
                            followersSection(followers, isQueryEmpty: isQueryEmpty)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .listRowBackground(Color.clear)
                    .searchable(text: $viewModel.searchText, prompt: "Search users")
                    .onChange(of: viewModel.searchText, initial: false) {
                        viewModel.handleSearchChange()
                    }
                }
            }
            .bucketToolbarBackground()
            .navigationTitle("Friends")
            .refreshable {
                await viewModel.loadFriendsData(showLoadingIndicator: false)
                await viewModel.loadAllUsers(showLoadingIndicator: false)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading users...")
                        .padding(BucketTheme.mediumSpacing)
                        .background(BucketTheme.surface(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                                .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                        )
                        .shadow(color: BucketTheme.shadow(for: colorScheme), radius: 10, x: 0, y: 6)
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

    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    private func exploreSection(_ users: [UserModel], isQueryEmpty: Bool) -> some View {
        if users.isEmpty {
            emptyState(message: isQueryEmpty ? "No users to explore." : "No users found.", showSpinner: viewModel.isSearchingRemotely)
        } else {
            ForEach(users) { user in
                userRow(for: user)
            }
        }
    }

    @ViewBuilder
    private func followingSection(_ users: [UserModel], isQueryEmpty: Bool) -> some View {
        if users.isEmpty {
            emptyState(message: isQueryEmpty ? "You're not following anyone yet." : "No matches in your following.", showSpinner: false)
        } else {
            ForEach(users) { user in
                userRow(for: user)
            }
        }
    }

    @ViewBuilder
    private func followersSection(_ users: [UserModel], isQueryEmpty: Bool) -> some View {
        if users.isEmpty {
            emptyState(message: isQueryEmpty ? "You don't have any followers yet." : "No matches in your followers.", showSpinner: false)
        } else {
            ForEach(users) { user in
                userRow(for: user)
            }
        }
    }

    @ViewBuilder
    private func emptyState(message: String, showSpinner: Bool) -> some View {
        VStack(spacing: BucketTheme.smallSpacing) {
            if showSpinner {
                ProgressView()
            }
            Text(message)
                .font(.callout)
                .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BucketTheme.largeSpacing)
        .bucketCard()
        .listRowInsets(EdgeInsets(top: BucketTheme.smallSpacing, leading: BucketTheme.mediumSpacing, bottom: BucketTheme.smallSpacing, trailing: BucketTheme.mediumSpacing))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func userRow(for user: UserModel) -> some View {
        let isFollowing = viewModel.isUserFollowed(user)
        HStack(spacing: BucketTheme.mediumSpacing) {
            userProfileImage(for: user)
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username ?? user.name ?? "Unknown")
                    .font(.headline)
                if let name = user.name, !(user.username ?? "").contains(name) {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                }
            }
            Spacer()
            Group {
                if isFollowing {
                    Button {
                        Task { await viewModel.unfollow(user) }
                    } label: {
                        Text("Unfollow")
                    }
                    .buttonStyle(BucketSecondaryButtonStyle())
                } else {
                    Button {
                        Task { await viewModel.follow(user) }
                    } label: {
                        Text("Follow")
                    }
                    .buttonStyle(BucketPrimaryButtonStyle())
                }
            }
            .frame(width: 110)
        }
        .bucketCard()
        .listRowInsets(EdgeInsets(top: BucketTheme.smallSpacing, leading: BucketTheme.mediumSpacing, bottom: BucketTheme.smallSpacing, trailing: BucketTheme.mediumSpacing))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
