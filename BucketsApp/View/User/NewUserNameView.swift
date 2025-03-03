//
//  NewUserNameView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/1/25.
//

//import SwiftUI
//
//struct NewUserNameView: View {
//    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
//    
//    @State private var newUserName: String = ""
//    @State private var confirmUserName: String = ""
//    @State private var updateMessage: String = ""
//    @State private var showAlert: Bool = false
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                
//                // MARK: - New Username Input
//                TextField("🆕 New Username (@JohnDoe)", text: $newUserName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .autocapitalization(.none)
//                    .disableAutocorrection(true)
//                    .padding(.horizontal)
//                
//                // MARK: - Confirm New Username Input
//                TextField("🔒 Confirm New Username", text: $confirmUserName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .autocapitalization(.none)
//                    .disableAutocorrection(true)
//                    .padding(.horizontal)
//                
//                Spacer()
//                
//                // MARK: - Save Username Button
//                Button {
//                    Task { await saveNewUserName() }
//                } label: {
//                    Text("✅ Save Username")
//                        // If form is valid => accentColor, else red
//                        .foregroundColor(isFormValid ? .accentColor : .red)
//                        .frame(maxWidth: .infinity)
//                        .fontWeight(.bold)
//                        .padding()
//                        // Use system background that adapts to Light/Dark
//                        .background(Color(uiColor: .systemBackground))
//                        .cornerRadius(10)
//                        .shadow(radius: 5)
//                }
//                .disabled(!isFormValid)
//                .padding(.horizontal)
//                
//            }
//            .padding()
//            .background(Color(uiColor: .systemBackground))
//            .alert(isPresented: $showAlert) {
//                Alert(
//                    title: Text("New Username"),
//                    message: Text(updateMessage),
//                    dismissButton: .default(Text("OK"))
//                )
//            }
//        }
//        .background(Color(uiColor: .systemBackground))
//        .padding()
//    }
//    
//    // MARK: - Validation
//    private var isFormValid: Bool {
//        !newUserName.isEmpty && !confirmUserName.isEmpty
//    }
//    
//    // MARK: - Save New Username Logic
//    private func saveNewUserName() async {
//        guard newUserName == confirmUserName else {
//            showError("Usernames do not match.")
//            return
//        }
//        // Optionally ensure it starts with "@"
//        guard newUserName.hasPrefix("@") else {
//            showError("Username must start with @.")
//            return
//        }
//        
//        // Attempt to save the username via the OnboardingViewModel
//        onboardingViewModel.saveNewUsername(newUserName)
//        
//        // Because saveNewUsername runs asynchronously,
//        // wait a moment to see if there's an error from the viewModel.
//        // (In practice, you might observe changes to errorMessage in real-time.)
//        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
//        
//        if let error = onboardingViewModel.errorMessage, onboardingViewModel.showErrorAlert {
//            showError(error)
//        } else {
//            // Show success
//            showSuccess("Username saved successfully!")
//        }
//    }
//    
//    // MARK: - Helper Methods
//    private func showSuccess(_ message: String) {
//        updateMessage = message
//        showAlert = true
//    }
//    
//    private func showError(_ message: String) {
//        updateMessage = message
//        showAlert = true
//    }
//}
