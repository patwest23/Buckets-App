//
//  UpdateEmailView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 1/13/24.
//

import SwiftUI

struct UpdateEmailView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    @State private var newEmail: String = ""
    @State private var updateMessage: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: - Email Input Field
                TextField("✉️ Enter New Email Address", text: $newEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Spacer()

                // MARK: - Update Email Button
                HStack {
                    Button {
                        Task { await updateEmail() }
                    } label: {
                        Text("✅ Update Email")
                            // If email is empty => .gray, else .accentColor
                            .foregroundColor(newEmail.isEmpty ? .gray : .accentColor)
                            .frame(maxWidth: .infinity)
                            .fontWeight(.bold)
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                    .disabled(newEmail.isEmpty) // disable if email is empty
                    .padding(.horizontal)
                }

            }
            .padding()
            // Use system background for the entire screen
            .background(Color(uiColor: .systemBackground))
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Email Update"),
                    message: Text(updateMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .background(Color(uiColor: .systemBackground)) // Another layer if you prefer
        .padding()
    }

    // MARK: - Helper Functions

    private func updateEmail() async {
        guard !newEmail.isEmpty else {
            showError("Please enter a valid email address.")
            return
        }

        let result = await viewModel.updateEmail(newEmail: newEmail)
        DispatchQueue.main.async {
            switch result {
            case .success(let message):
                showSuccess(message)
            case .failure(let error):
                showError(error.localizedDescription)
            }
        }
    }

    private func showError(_ message: String) {
        updateMessage = message
        showAlert = true
    }

    private func showSuccess(_ message: String) {
        updateMessage = message
        showAlert = true
    }
}

// MARK: - Preview
#if DEBUG
struct UpdateEmailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = OnboardingViewModel()
        
        return Group {
            // Light Mode
            NavigationView {
                UpdateEmailView()
                    .environmentObject(mockViewModel)
            }
            .previewDisplayName("UpdateEmailView - Light")
            
            // Dark Mode
            NavigationView {
                UpdateEmailView()
                    .environmentObject(mockViewModel)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("UpdateEmailView - Dark")
        }
    }
}
#endif
