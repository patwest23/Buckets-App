import SwiftUI

struct FriendListView: View {
    @EnvironmentObject var socialViewModel: SocialViewModel

    @State private var selectedTab: FriendListTab = .followers
    @State private var searchText: String = ""

    init(initialTab: FriendListTab = .followers) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        List {
            Section {
                searchField
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section(header: Text("Connections")) {
                let users = socialViewModel.filteredUsers(for: selectedTab, searchText: searchText)

                if users.isEmpty {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "person.2.circle",
                        description: Text("Try another search or explore new people to follow.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color(.systemGroupedBackground))
                } else {
                    ForEach(users) { user in
                        FriendRow(user: user) {
                            socialViewModel.toggleFollow(user)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Friends")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Filter", selection: $selectedTab) {
                    ForEach(FriendListTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search followers", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct FriendRow: View {
    let user: SocialUser
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: user.avatarSystemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .foregroundColor(.accentColor)
                .padding(6)
                .background(Circle().fill(Color(.secondarySystemBackground)))

            VStack(alignment: .leading, spacing: 4) {
                NavigationLink {
                    UserListView(user: user)
                } label: {
                    Text(user.username)
                        .font(.headline)
                }
                .buttonStyle(.plain)

                Text(user.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onToggle) {
                Text(user.isFollowing ? "Following" : "Follow")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(user.isFollowing ? Color(.systemGray5) : Color.accentColor)
                    )
                    .foregroundColor(user.isFollowing ? .primary : .white)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

struct FriendListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FriendListView(initialTab: .following)
                .environmentObject(SocialViewModel())
        }
    }
}
