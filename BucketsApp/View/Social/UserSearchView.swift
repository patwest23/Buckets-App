import FirebaseAuth
import SwiftUI

struct UserSearchView: View {
    @ObservedObject var vm: UserSearchViewModel
    // Search and focus state removed for Explore-only section
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("Explore")) {
                        ForEach(vm.allUsers) { user in
                            userRow(for: user)
                        }
                    }
                }
                .listStyle(.plain)
                .onAppear {
                    Task {
                        await vm.loadAllUsers()
                    }
                }
            }
            .navigationTitle("Find Friends")
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { _ in DispatchQueue.main.async { vm.errorMessage = nil } }
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
        mockVM.allUsers = [
            UserModel(
                id: "user_123",
                email: "test@example.com",
                createdAt: Date(),
                profileImageUrl: nil,
                name: "Test User",
                username: "@test",
                isFollowed: false
            )
        ]
        return UserSearchView(vm: mockVM)
            .previewDisplayName("Mock Search View")
    }
}
