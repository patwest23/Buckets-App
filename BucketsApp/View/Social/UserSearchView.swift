//
//  UserSearchView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI

struct UserSearchView: View {
    /// We’ll accept a view model as a parameter
    @ObservedObject var vm: UserSearchViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                TextField("Search by @username or Name", text: $vm.searchText, onCommit: {
                    Task {
                        await vm.searchUsers()
                    }
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                
                // Search results + suggested
                List {
                    Section(header: Text("Search Results")) {
                        ForEach(vm.searchResults) { user in
                            HStack(spacing: 12) {
                                // PROFILE IMAGE
                                userProfileImage(for: user.profileImageUrl)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                
                                // USERNAME + DISPLAY NAME
                                VStack(alignment: .leading) {
                                    Text(user.username ?? "No username")
                                    Text(user.name ?? "No name")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // FOLLOW BUTTON
                                Button("Follow") {
                                    Task {
                                        await vm.followUser(user)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Suggested")) {
                        ForEach(vm.suggestedUsers) { user in
                            HStack(spacing: 12) {
                                // PROFILE IMAGE
                                userProfileImage(for: user.profileImageUrl)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                
                                // USERNAME + DISPLAY NAME
                                VStack(alignment: .leading) {
                                    Text(user.username ?? "No username")
                                    Text(user.name ?? "No name")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // FOLLOW BUTTON
                                Button("Follow") {
                                    Task {
                                        await vm.followUser(user)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .onAppear {
                    Task {
                        await vm.loadSuggestedUsers()
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
    
    /// Helper view builder for profile images
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
            // If profileImageUrl is nil or invalid => default icon
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFill()
        }
    }
}

struct UserSearchView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a mock or real view model
        UserSearchView(vm: MockUserSearchViewModel())
            .previewDisplayName("Mock Search View")
    }
}
