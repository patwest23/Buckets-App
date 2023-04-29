//
//  RegistrationView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI

struct SignUpView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var agreedToTerms = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack {
            Text("Sign Up")
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

                SecureField("Confirm Password", text: $confirmPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                HStack {
                    Text("I agree to the")
                    Text("Terms and Conditions")
                        .foregroundColor(.blue)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "https://yourwebsite.com/terms-and-conditions") {
                                UIApplication.shared.open(url)
                            }
                        }
                    
                    Toggle(" ", isOn: $agreedToTerms)
                }
                .font(.caption)
            }
            .padding(.horizontal)

            Button(action: {
                if validateInput() {
                    // Add your sign-up logic here
                } else {
                    showErrorAlert = true
                }
            }) {
                Text("Sign Up")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(/*@START_MENU_TOKEN@*/Color("AccentColor")/*@END_MENU_TOKEN@*/)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .disabled(!agreedToTerms)
            .opacity(agreedToTerms ? 1.0 : 0.5)
            .alert(isPresented: $showErrorAlert) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
        }
        .padding(.top)
    }

    private func validateInput() -> Bool {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields."
            return false
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return false
        }

        return true
    }
}





struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
    }
}
