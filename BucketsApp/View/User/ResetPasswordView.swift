//
//  ResetPasswordView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 1/13/24.
//

import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    @State private var shouldDismissAfterAlert = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case email
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                VStack(alignment: .leading, spacing: 18) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .email)
                        .onboardingFieldStyle()
                }

                Button(action: sendResetLink) {
                    ZStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            Text("Send reset link")
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
            }
            .padding(28)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Reset password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset password", isPresented: alertBinding) {
            Button("OK", role: .cancel) {
                if shouldDismissAfterAlert {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            email = viewModel.email
            focusedField = .email
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Forgot your password?")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Enter the email associated with your account and we'll send you a secure reset link.")
                .foregroundColor(.secondary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var primaryButtonBackground: Color {
        isButtonDisabled ? Color.accentColor.opacity(0.4) : Color.accentColor
    }

    private var isButtonDisabled: Bool {
        isSubmitting || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func sendResetLink() {
        guard !isButtonDisabled else { return }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            alertMessage = "Please enter a valid email address."
            return
        }

        isSubmitting = true
        focusedField = nil

        Task { @MainActor in
            let result = await viewModel.resetPassword(for: trimmedEmail)
            isSubmitting = false

            switch result {
            case .success(let message):
                alertMessage = message
                shouldDismissAfterAlert = true
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ResetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = OnboardingViewModel()

        return Group {
            // Light Mode
            NavigationStack {
                ResetPasswordView()
                    .environmentObject(mockViewModel)
            }
            .previewDisplayName("ResetPasswordView - Light Mode")

            // Dark Mode
            NavigationStack {
                ResetPasswordView()
                    .environmentObject(mockViewModel)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("ResetPasswordView - Dark Mode")
        }
    }
}
#endif
