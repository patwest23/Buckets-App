//
//  FollowingView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/25/25.
//

import SwiftUI

struct User: Identifiable {
    let id = UUID()
    let profileImageName: String
    let username: String
    let name: String
}

struct FollowingView: View {
    let followedUsers: [User] = [
        User(profileImageName: "person.circle.fill", username: "johndoe", name: "John Doe"),
        User(profileImageName: "person.circle.fill", username: "janedoe", name: "Jane Doe"),
        User(profileImageName: "person.circle.fill", username: "alice123", name: "Alice Smith")
    ]

    var body: some View {
        NavigationView {
            List(followedUsers) { user in
                HStack(spacing: 12) {
                    Image(systemName: user.profileImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text(user.username)
                            .font(.headline)
                        Text(user.name)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Following")
        }
    }
}

#Preview {
    FollowingView()
}
