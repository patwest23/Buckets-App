//
//  ProfileView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/13/23.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var isResetPasswordPresented = false
    @State private var isUpdateEmailPresented = false

    var body: some View {
        VStack {
            if viewModel.isAuthenticated {
                Text("Welcome, \(viewModel.email)")
                    .font(.title)

                Button("Update Email") {
                    isUpdateEmailPresented = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)

                Button("Reset Password") {
                    isResetPasswordPresented = true
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)

                Button("Log Out") {
                    viewModel.signOut()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            } else {
                Text("Not logged in")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .sheet(isPresented: $isResetPasswordPresented) {
            // ResetPasswordView() // Create this view for resetting password
        }
        .sheet(isPresented: $isUpdateEmailPresented) {
            // UpdateEmailView() // Create this view for updating email
        }
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
