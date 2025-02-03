//
//  UpdateUserNameView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 2/2/25.
//

import SwiftUI

struct UpdateUserNameView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    
    @State private var newUserName: String = ""
    @State private var confirmUserName: String = ""
    @State private var updateMessage: String = ""
    @State private var showAlert: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: - New Username Input
                TextField("🆕 New Username (@JohnDoe)", text: $newUserName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal)
                
                // MARK: - Confirm New Username Input
                TextField("🔒 Confirm New Username", text: $confirmUserName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal)
                
                Spacer()
                
                // MARK: - Update Username Button
                Button {
                    Task { await updateUserName() }
                } label: {
                    Text("✅ Update Username")
                        // If form is valid => accentColor, else red
                        .foregroundColor(isFormValid ? .accentColor : .red)
                        .frame(maxWidth: .infinity)
                        .fontWeight(.bold)
                        .padding()
                        // Use system background that adapts to Light/Dark
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .disabled(!isFormValid)
                .padding(.horizontal)
                
            }
            .padding()
            // Base layer that adapts to Light/Dark
            .background(Color(uiColor: .systemBackground))
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Username Update"),
                    message: Text(updateMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .background(Color(uiColor: .systemBackground))
        .padding()
    }
    
    // MARK: - Validation
    private var isFormValid: Bool {
        !newUserName.isEmpty && !confirmUserName.isEmpty
    }
    
    // MARK: - Update Username Logic
    private func updateUserName() async {
        guard newUserName == confirmUserName else {
            showError("Usernames do not match.")
            return
        }
        // Optionally ensure it starts with "@"
        guard newUserName.hasPrefix("@") else {
            showError("Username must start with @.")
            return
        }
        
        // Attempt to update the username
        await userViewModel.updateUserName(to: newUserName)
        
        // If there's an error
        if let error = userViewModel.errorMessage, userViewModel.showErrorAlert {
            showError(error)
        } else {
            // Show success
            showSuccess("Username updated successfully!")
        }
    }
    
    // MARK: - Helper Methods
    private func showSuccess(_ message: String) {
        updateMessage = message
        showAlert = true
    }
    
    private func showError(_ message: String) {
        updateMessage = message
        showAlert = true
    }
}

// MARK: - Preview
#if DEBUG
struct UpdateUserNameView_Previews: PreviewProvider {
    static var previews: some View {
        let mockUserVM = UserViewModel()
        
        return Group {
            // Light Mode
            NavigationView {
                UpdateUserNameView()
                    .environmentObject(mockUserVM)
            }
            .previewDisplayName("UpdateUserNameView - Light")
            
            // Dark Mode
            NavigationView {
                UpdateUserNameView()
                    .environmentObject(mockUserVM)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("UpdateUserNameView - Dark")
        }
    }
}
#endif
