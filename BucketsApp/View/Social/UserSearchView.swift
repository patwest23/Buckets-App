import SwiftUI

struct UserSearchView: View {
    @ObservedObject var vm: UserSearchViewModel
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                TextField("Search by username or Name", text: $vm.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .onChange(of: vm.searchText) { newVal in
                        Task {
                            await vm.searchUsers()
                        }
                    }
                
                // Results
                List {
                    Section(header: Text("Search Results")) {
                        ForEach(vm.searchResults) { user in
                            userRow(for: user)
                        }
                    }
                    
                    Section(header: Text("Suggested")) {
                        ForEach(vm.suggestedUsers) { user in
                            userRow(for: user)
                        }
                    }

                    if vm.searchText.isEmpty && vm.searchResults.isEmpty && vm.suggestedUsers.isEmpty {
                        Section(header: Text("Explore")) {
                            ForEach(vm.allUsers) { user in
                                userRow(for: user)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .task {
                    await vm.loadSuggestedUsers()
                    await vm.loadAllUsers()
                    await MainActor.run {
                        isSearchFocused = true
                    }
                }
            }
            .navigationTitle("Find Friends")
            .alert("Error", isPresented: Binding<Bool>(
                get: { vm.errorMessage != nil },
                set: { _ in vm.errorMessage = nil }
            ), actions: {}) {
                Text(vm.errorMessage ?? "")
            }
        }
    }
    
    @ViewBuilder
    private func userProfileImage(for urlString: String?) -> some View {
        if let urlString = urlString,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_):
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

    @ViewBuilder
    private func userRow(for user: UserModel) -> some View {
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
            
            Button(user.isFollowed ? "Following" : "Follow") {
                if !user.isFollowed {
                    Task {
                        await vm.followUser(user)
                    }
                }
            }
            .disabled(user.isFollowed)
        }
    }
}

struct UserSearchView_Previews: PreviewProvider {
    static var previews: some View {
        let mockVM = UserSearchViewModel()
        mockVM.searchResults = [
            UserModel(
                id: "user_123",
                email: "test@example.com",
                createdAt: Date(),
                profileImageUrl: nil,
                name: "Test User",
                username: "@test"
            )
        ]
        return UserSearchView(vm: mockVM)
            .previewDisplayName("Mock Search View")
    }
}
