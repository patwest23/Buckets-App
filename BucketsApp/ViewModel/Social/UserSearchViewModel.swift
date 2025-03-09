//
//  UserSearchViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI
import Combine

class UserSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [UserModel] = []
    
    func searchUsers() {
        // Query your backend for users matching `searchText`
        // On success, assign to self.searchResults
    }
    
    func followUser(_ user: UserModel) {
        // Update current user’s “following” list in DB
    }
    
    func unfollowUser(_ user: UserModel) {
        // Update current user’s “following” list in DB
    }
}
