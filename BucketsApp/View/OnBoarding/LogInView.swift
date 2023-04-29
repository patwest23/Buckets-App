//
//  LoginView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI

struct LogInView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack {
            Text("Log In")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            Button(action: {
                if validateInput() {
                    // Add your log-in logic here
                } else {
                    showErrorAlert = true
                }
            }) {
                Text("Log In")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(/*@START_MENU_TOKEN@*/Color("AccentColor")/*@END_MENU_TOKEN@*/)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
        }
        .padding(.top)
    }

    private func validateInput() -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return false
        }

        return true
    }
}

struct LogInView_Previews: PreviewProvider {
    static var previews: some View {
        LogInView()
    }
}
