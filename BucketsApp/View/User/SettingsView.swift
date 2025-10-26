//
//  SettingsView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 2/16/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject var userViewModel: UserViewModel

    @State private var showUsernameSheet = false
    @State private var showEmailSheet = false
    @State private var showResetPasswordSheet = false
    @State private var showUpdatePasswordSheet = false

    @State private var isSigningOut = false
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                VStack(spacing: 16) {
                    settingsActionButton(
                        title: "Update username",
                        subtitle: "Choose a fresh display name for your bucket list."
                    ) {
                        showUsernameSheet = true
                    }
                    .sheet(isPresented: $showUsernameSheet) {
                        NavigationStack {
                            UpdateUserNameView()
                                .environmentObject(userViewModel)
                        }
                    }

                    settingsActionButton(
                        title: "Update email",
                        subtitle: "Keep your contact address current."
                    ) {
                        showEmailSheet = true
                    }
                    .sheet(isPresented: $showEmailSheet) {
                        NavigationStack {
                            UpdateEmailView()
                                .environmentObject(onboardingViewModel)
                        }
                    }

                    settingsActionButton(
                        title: "Reset password",
                        subtitle: "Send a secure reset link to your inbox."
                    ) {
                        showResetPasswordSheet = true
                    }
                    .sheet(isPresented: $showResetPasswordSheet) {
                        NavigationStack {
                            ResetPasswordView()
                                .environmentObject(onboardingViewModel)
                        }
                    }

                    settingsActionButton(
                        title: "Update password",
                        subtitle: "Create a stronger password for your account."
                    ) {
                        showUpdatePasswordSheet = true
                    }
                    .sheet(isPresented: $showUpdatePasswordSheet) {
                        NavigationStack {
                            UpdatePasswordView()
                                .environmentObject(onboardingViewModel)
                        }
                    }
                }

                signOutButton
            }
            .padding(28)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Account", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            onboardingViewModel.checkIfUserIsAuthenticated()
        }
        .onChange(of: onboardingViewModel.errorMessage) { message in
            guard let message else { return }
            alertMessage = message
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account settings")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Manage how you sign in and keep your profile information up to date.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settingsActionButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var signOutButton: some View {
        Button(action: signOut) {
            ZStack {
                if isSigningOut {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    Text("Sign out")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
        }
        .buttonStyle(.plain)
        .background(signOutButtonBackground)
        .foregroundColor(.white)
        .cornerRadius(14)
        .disabled(isSigningOut)
    }

    private var signOutButtonBackground: Color {
        isSigningOut ? Color.accentColor.opacity(0.4) : Color.accentColor
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    alertMessage = nil
                }
            }
        )
    }

    private func signOut() {
        guard !isSigningOut else { return }

        isSigningOut = true
        Task {
            await onboardingViewModel.signOut()
            await MainActor.run {
                isSigningOut = false
                if onboardingViewModel.isAuthenticated {
                    alertMessage = onboardingViewModel.errorMessage
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockOnboardingVM = OnboardingViewModel()
        let mockUserVM = UserViewModel()
        
        NavigationStack {
            SettingsView()
                .environmentObject(mockOnboardingVM)
                .environmentObject(mockUserVM)
        }
        .previewDisplayName("SettingsView Preview")
    }
}
#endif


