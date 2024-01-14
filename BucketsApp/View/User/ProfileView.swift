//
//  ProfileView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/13/23.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if viewModel.isAuthenticated {
                    Text("Welcome, \(viewModel.email)")
                        .font(.headline)

                    Section(header: Text("Account Settings")) {
                        navigationLinkButton("Update Email", destination: UpdateEmailView())
                        navigationLinkButton("Reset Password", destination: ResetPasswordView())
                        navigationLinkButton("Update Password", destination: UpdatePasswordView())
                        
                        Button("Log Out", role: .destructive) {
                            viewModel.signOut()
                        }
                    }
                } else {
                    Text("Not logged in")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Profile")
            .listStyle(GroupedListStyle())
            .onAppear {
                viewModel.checkIfUserIsAuthenticated()
            }
        }
    }

    @ViewBuilder
    private func navigationLinkButton<T: View>(_ title: String, destination: T) -> some View {
        NavigationLink(value: title) {
            Text(title)
        }
        .navigationDestination(for: String.self) { value in
            if value == title {
                destination
            }
        }
    }
}




struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView().environmentObject(OnboardingViewModel())
    }
}

