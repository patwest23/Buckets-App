//
//  FollowingView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/25/25.
//

//import SwiftUI
//
//struct FollowingView: View {
//    @EnvironmentObject var followViewModel: FollowViewModel
//
//
//    var body: some View {
//        NavigationView {
//            List {
//                ForEach(followViewModel.followingUsers) { user in
//                    FollowingRow(user: user, onUnfollow: {
//                        Task {
//                            await followViewModel.unfollowUser(user)
//                        }
//                    })
//                }
//            }
//            .navigationTitle("Following")
//            .task {
//                await followViewModel.loadFollowingUsers()
//            }
//        }
//    }
//}
//
//struct FollowingRow: View {
//    var user: UserModel
//    var onUnfollow: () -> Void
//
//    var body: some View {
//        HStack(spacing: 12) {
//            if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
//                AsyncImage(url: url) { phase in
//                    switch phase {
//                    case .empty:
//                        ProgressView()
//                            .frame(width: 40, height: 40)
//                    case .success(let image):
//                        image
//                            .resizable()
//                            .scaledToFill()
//                            .frame(width: 40, height: 40)
//                            .clipShape(Circle())
//                    case .failure(_):
//                        Image(systemName: "person.crop.circle.fill")
//                            .resizable()
//                            .scaledToFill()
//                            .frame(width: 40, height: 40)
//                            .clipShape(Circle())
//                            .foregroundColor(.blue)
//                    @unknown default:
//                        Image(systemName: "person.crop.circle.fill")
//                            .resizable()
//                            .scaledToFill()
//                            .frame(width: 40, height: 40)
//                            .clipShape(Circle())
//                            .foregroundColor(.blue)
//                    }
//                }
//            } else {
//                Image(systemName: "person.crop.circle.fill")
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 40, height: 40)
//                    .clipShape(Circle())
//                    .foregroundColor(.blue)
//            }
//
//            VStack(alignment: .leading) {
//                Text(user.username ?? "Unknown")
//                    .font(.headline)
//                Text(user.name ?? "")
//                    .font(.subheadline)
//                    .foregroundColor(.gray)
//            }
//
//            Spacer()
//
//            Button("Unfollow", action: onUnfollow)
//                .foregroundColor(.red)
//        }
//        .padding(.vertical, 4)
//    }
//}
