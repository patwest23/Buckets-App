//
//  SettingsView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 2/16/25.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    
    // Each sheet for the account-update screens
    @State private var showUsernameSheet = false
    @State private var showEmailSheet = false
    @State private var showResetPasswordSheet = false
    @State private var showUpdatePasswordSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                
                VStack(alignment: .leading, spacing: 12) {
                    
                    // 1) "Update Username"
                    Button("📝 Update Username") {
                        showUsernameSheet = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showUsernameSheet) {
                        UpdateUserNameView()
                            .environmentObject(userViewModel)
                    }
                    
                    // 2) "Update Email"
                    Button("✉️ Update Email") {
                        showEmailSheet = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showEmailSheet) {
                        UpdateEmailView()
                            .environmentObject(onboardingViewModel)
                    }
                    
                    // 3) "Reset Password"
                    Button("🔑 Reset Password") {
                        showResetPasswordSheet = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showResetPasswordSheet) {
                        ResetPasswordView()
                            .environmentObject(onboardingViewModel)
                    }
                    
                    // 4) "Update Password"
                    Button("🔒 Update Password") {
                        showUpdatePasswordSheet = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                    .sheet(isPresented: $showUpdatePasswordSheet) {
                        UpdatePasswordView()
                            .environmentObject(onboardingViewModel)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(10)
                .shadow(radius: 5)
                
                // Log Out button
                HStack {
                    Spacer()
                    Button("🚪 Log Out", role: .destructive) {
                        Task {
                            await onboardingViewModel.signOut()
                        }
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .fontWeight(.bold)
                    .padding()
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    Spacer()
                }
                
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground))
        .navigationBarTitle("Settings", displayMode: .inline)
        .onAppear {
            onboardingViewModel.checkIfUserIsAuthenticated()
        }
    }
}

// MARK: - Preview
#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockOnboardingVM = OnboardingViewModel()
        let mockUserVM = UserViewModel()
        
        NavigationView {
            SettingsView()
                .environmentObject(mockOnboardingVM)
                .environmentObject(mockUserVM)
        }
        .previewDisplayName("SettingsView Preview")
    }
}
#endif


