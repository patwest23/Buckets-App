//
//  ProfileView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/13/23.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack {
            if viewModel.isAuthenticated {
                // Display user's information
                Text("Welcome, \(viewModel.email)")
                    .font(.title)

                // Add more user details here if needed

                // Log Out button
                Button("Log Out") {
                    viewModel.signOut()
                }
                .padding()
                .foregroundColor(.white)
                .background(Color.red)
                .cornerRadius(8)
            } else {
                Text("Not logged in")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .onAppear {
            viewModel.checkIfUserIsAuthenticated()
        }
    }
}


struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
