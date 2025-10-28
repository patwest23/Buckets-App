import SwiftUI

struct LogInView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var alertMessage: String?
    @State private var showResetPrompt = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    VStack(alignment: .leading, spacing: 18) {
                        TextField("Email", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .email)
                            .onboardingFieldStyle()

                        SecureField("Password", text: $viewModel.password)
                            .focused($focusedField, equals: .password)
                            .onboardingFieldStyle()
                    }

                    Button(action: signIn) {
                        ZStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text("Sign in")
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
                    .disabled(isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)

                    VStack(alignment: .leading, spacing: 12) {
                        Button("Forgot password?") {
                            Task { @MainActor in await resetPassword() }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)

                        Button("Use Face ID / Touch ID") {
                            Task { @MainActor in await viewModel.loginWithBiometrics() }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                    .font(.footnote)

                    divider

                    googleButton
                }
                .padding(28)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Sign in", isPresented: alertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .alert("Reset password", isPresented: $showResetPrompt) {
                Button("Send reset link", role: .destructive) {
                    Task { @MainActor in await resetPassword() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It looks like the password is incorrect. Would you like to receive a reset link?"
                )
            }
        }
        .onChange(of: viewModel.isAuthenticated, initial: false) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome back")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sign in to review your bucket list, check off progress, and stay motivated.")
                .foregroundColor(.secondary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))

            Text("or")
                .font(.footnote)
                .foregroundColor(.secondary)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))
        }
    }

    private var googleButton: some View {
        Button {
            viewModel.signInWithGoogle()
        } label: {
            HStack(spacing: 12) {
                Image("google_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text("Continue with Google")
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var primaryButtonBackground: Color {
        (isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
            ? Color.accentColor.opacity(0.4)
            : Color.accentColor
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

    private func signIn() {
        guard !viewModel.email.isEmpty, !viewModel.password.isEmpty else {
            alertMessage = "Please enter your email and password."
            return
        }

        isLoading = true
        Task { @MainActor in
            await viewModel.signIn()
            isLoading = false

            if viewModel.isAuthenticated {
                dismiss()
            } else if let message = viewModel.errorMessage {
                let lowercased = message.lowercased()
                if lowercased.contains("wrong password") || lowercased.contains("invalid password") {
                    alertMessage = nil
                    showResetPrompt = true
                } else {
                    alertMessage = message
                }
            }
        }
    }

    private func resetPassword() async {
        guard !viewModel.email.isEmpty else {
            await MainActor.run {
                alertMessage = "Enter your email address above and try again."
            }
            return
        }

        let result = await viewModel.resetPassword(for: viewModel.email)
        await MainActor.run {
            switch result {
            case .success(let message):
                alertMessage = message
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
            showResetPrompt = false
        }
    }
}

#if DEBUG
struct LogInView_Previews: PreviewProvider {
    static var previews: some View {
        LogInView()
            .environmentObject(OnboardingViewModel())
    }
}
#endif
