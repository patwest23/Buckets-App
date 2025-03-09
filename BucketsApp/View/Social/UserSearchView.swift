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
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.username ?? "No username")
                                    Text(user.name ?? "No name")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
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
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.username ?? "No username")
                                    Text(user.name ?? "No name")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
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
}

struct UserSearchView_Previews: PreviewProvider {
    static var previews: some View {
        UserSearchView(vm: MockUserSearchViewModel())
            .previewDisplayName("Mock Search View")
    }
}
