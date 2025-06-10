//
//  FollowerView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/25/25.
//

import SwiftUI

struct FollowerView: View {
    @EnvironmentObject var followViewModel: FollowViewModel

    var body: some View {
        List {
            ForEach(followViewModel.followers, id: \.followerId) { follow in
                if let user = followViewModel.allUsers.first(where: { $0.id == follow.followerId }) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: user.profileImageUrl ?? "")) { phase in
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
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading) {
                            Text(user.username ?? "No username")
                                .fontWeight(.semibold)
                            Text(user.name ?? "No name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Followers")
    }
}

#if DEBUG
@MainActor
struct FollowerView_Previews: PreviewProvider {
    static var previews: some View {
        let mockVM = FollowViewModel()
        mockVM.followers = [
            FollowModel(id: "f1", followerId: "user_1", followingId: "currentUser", timestamp: Date()),
            FollowModel(id: "f2", followerId: "user_2", followingId: "currentUser", timestamp: Date())
        ]
        mockVM.allUsers = [
            UserModel(
                id: "user_1",
                email: "user1@example.com",
                createdAt: Date(),
                profileImageUrl: nil,
                name: "Alice Wonderland",
                username: "@alice"
            ),
            UserModel(
                id: "user_2",
                email: "user2@example.com",
                createdAt: Date(),
                profileImageUrl: nil,
                name: "Bob Builder",
                username: "@bob"
            )
        ]
        return NavigationStack {
            FollowerView()
                .environmentObject(mockVM)
        }
        .previewDisplayName("FollowerView Preview")
    }
}
#endif
