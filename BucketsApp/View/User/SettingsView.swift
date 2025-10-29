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
    @State private var isDeletingAccount = false
    @State private var alertMessage: String?
    @State private var showDeleteConfirmation = false

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
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                    }
                    .disabled(isDeletingAccount)

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
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                    }
                    .disabled(isDeletingAccount)

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
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                    }
                    .disabled(isDeletingAccount)

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
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                    }
                    .disabled(isDeletingAccount)

                    settingsActionButton(
                        title: isDeletingAccount ? "Deleting account…" : "Delete account",
                        subtitle: "Permanently remove your data. This action cannot be undone.",
                        role: .destructive,
                        titleColor: .red,
                        subtitleColor: Color.red.opacity(0.7),
                        chevronColor: isDeletingAccount ? .clear : .red,
                        borderColor: Color.red.opacity(0.25)
                    ) {
                        guard !isDeletingAccount else { return }
                        showDeleteConfirmation = true
                    }
                    .disabled(isDeletingAccount)
                    .overlay(alignment: .trailing) {
                        if isDeletingAccount {
                            ProgressView()
                                .tint(.red)
                                .padding(.trailing, 24)
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
        .confirmationDialog(
            "Are you sure you want to delete account?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                performAccountDeletion()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Account", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            onboardingViewModel.checkIfUserIsAuthenticated()
        }
        .onChange(of: onboardingViewModel.errorMessage, initial: false) { _, message in
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

    private func settingsActionButton(
        title: String,
        subtitle: String,
        role: ButtonRole? = nil,
        titleColor: Color = .primary,
        subtitleColor: Color = .secondary,
        chevronColor: Color = .secondary,
        backgroundColor: Color = Color(.systemBackground),
        borderColor: Color = Color(.systemGray4),
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundColor(titleColor)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(subtitleColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(chevronColor)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
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
        .disabled(isSigningOut || isDeletingAccount)
    }

    private var signOutButtonBackground: Color {
        (isSigningOut || isDeletingAccount) ? Color.accentColor.opacity(0.4) : Color.accentColor
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
        guard !isSigningOut && !isDeletingAccount else { return }

        isSigningOut = true
        Task { @MainActor in
            await onboardingViewModel.signOut()
            isSigningOut = false
            if onboardingViewModel.isAuthenticated {
                alertMessage = onboardingViewModel.errorMessage
            }
        }
    }

    private func performAccountDeletion() {
        guard !isDeletingAccount else { return }

        isDeletingAccount = true
        Task { @MainActor in
            let result = await onboardingViewModel.deleteAccount()
            isDeletingAccount = false

            switch result {
            case .success(let message):
                userViewModel.clearCachedData()
                alertMessage = message
            case .failure(let error):
                alertMessage = error.localizedDescription
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


