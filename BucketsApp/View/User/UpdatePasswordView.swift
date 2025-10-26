//
//  UpdatePasswordView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 1/13/24.
//

import SwiftUI

struct UpdatePasswordView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    @State private var shouldDismissAfterAlert = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case current
        case new
        case confirm
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                VStack(alignment: .leading, spacing: 18) {
                    SecureField("Current password", text: $currentPassword)
                        .focused($focusedField, equals: .current)
                        .onboardingFieldStyle()

                    SecureField("New password", text: $newPassword)
                        .focused($focusedField, equals: .new)
                        .onboardingFieldStyle()

                    SecureField("Confirm new password", text: $confirmPassword)
                        .focused($focusedField, equals: .confirm)
                        .onboardingFieldStyle()
                }

                Button(action: updatePassword) {
                    ZStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            Text("Update password")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                }
                .buttonStyle(.plain)
                .background(primaryButtonBackground)
                .foregroundColor(.white)
                .cornerRadius(14)
                .disabled(isButtonDisabled)

                Text("Use at least 6 characters with a mix of numbers, letters, and symbols for the strongest protection.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Update password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Update password", isPresented: alertBinding) {
            Button("OK", role: .cancel) {
                if shouldDismissAfterAlert {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            focusedField = .current
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strengthen your security")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Re-authenticate with your current password and choose a new one to keep your account protected.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var primaryButtonBackground: Color {
        isButtonDisabled ? Color.accentColor.opacity(0.4) : Color.accentColor
    }

    private var isButtonDisabled: Bool {
        isSubmitting || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    alertMessage = nil
                    shouldDismissAfterAlert = false
                }
            }
        )
    }

    private func updatePassword() {
        guard !isButtonDisabled else { return }

        let trimmedCurrent = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNew = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedNew == trimmedConfirm else {
            alertMessage = "Passwords do not match."
            return
        }

        guard trimmedNew.count >= 6 else {
            alertMessage = "Passwords must be at least 6 characters long."
            return
        }

        isSubmitting = true
        focusedField = nil

        Task {
            do {
                let message = try await viewModel.updatePassword(
                    currentPassword: trimmedCurrent,
                    newPassword: trimmedNew
                )

                await MainActor.run {
                    isSubmitting = false
                    alertMessage = message
                    shouldDismissAfterAlert = true
                    currentPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    alertMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct UpdatePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = OnboardingViewModel()
        
        return Group {
            // Light Mode
            NavigationStack {
                UpdatePasswordView()
                    .environmentObject(mockViewModel)
            }
            .previewDisplayName("UpdatePasswordView - Light Mode")

            // Dark Mode
            NavigationStack {
                UpdatePasswordView()
                    .environmentObject(mockViewModel)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("UpdatePasswordView - Dark Mode")
        }
    }
}
#endif


