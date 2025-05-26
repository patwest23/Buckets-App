//
//  FollowerView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/25/25.
//

import SwiftUI

struct FollowerView: View {
    let followers: [UserModel]

    var body: some View {
        List(followers) { user in
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
        .navigationTitle("Followers")
    }
}

#if DEBUG
struct FollowerView_Previews: PreviewProvider {
    static var previews: some View {
        FollowerView(followers: [
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
        ])
    }
}
#endif
