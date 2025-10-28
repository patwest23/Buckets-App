import SwiftUI
import UIKit

struct SignUpView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var confirmPassword: String = ""
    @State private var agreedToTerms = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSubmitting = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case username
        case email
        case password
        case confirmPassword
    }

    private var usernameBinding: Binding<String> {
        Binding(
            get: { username },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: " ", with: "")

                if trimmed.isEmpty {
                    username = ""
                } else {
                    let sanitized = trimmed.replacingOccurrences(of: "@", with: "")
                    username = "@" + sanitized
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    VStack(alignment: .leading, spacing: 18) {
                        TextField("@username", text: usernameBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .username)
                            .onboardingFieldStyle()

                        TextField("Email", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .email)
                            .onboardingFieldStyle()

                        SecureField("Password", text: $viewModel.password)
                            .focused($focusedField, equals: .password)
                            .onboardingFieldStyle()

                        SecureField("Confirm password", text: $confirmPassword)
                            .focused($focusedField, equals: .confirmPassword)
                            .onboardingFieldStyle()
                    }

                    termsSection

                    Button(action: signUp) {
                        ZStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                Text("Create account")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .background(signUpButtonBackground)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .disabled(!agreedToTerms || isSubmitting)

                    divider

                    googleButton
                }
                .padding(28)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Create account")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Sign Up", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            username = viewModel.username
        }
        .onChange(of: viewModel.isAuthenticated, initial: false) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to Buckets")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Create an account to build your bucket list, add photos, and track your personal achievements.")
                .foregroundColor(.secondary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $agreedToTerms) {
                HStack(spacing: 4) {
                    Text("I agree to the")
                    Button(action: openTermsAndConditions) {
                        Text("Terms and Conditions")
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            .font(.footnote)
            .foregroundColor(.secondary)
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

    private var signUpButtonBackground: Color {
        (!agreedToTerms || isSubmitting) ? Color.accentColor.opacity(0.4) : Color.accentColor
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

    private func signUp() {
        guard validateInput() else {
            showErrorAlert = true
            return
        }

        isSubmitting = true
        Task { @MainActor in
            viewModel.username = username
            await viewModel.createUser()

            isSubmitting = false
            if viewModel.isAuthenticated {
                dismiss()
            } else if let message = viewModel.errorMessage {
                errorMessage = message
                showErrorAlert = true
            }
        }
    }

    private func validateInput() -> Bool {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            errorMessage = "Please choose a username."
            return false
        }

        let withoutPrefix: String
        if trimmedUsername.hasPrefix("@") {
            withoutPrefix = String(trimmedUsername.dropFirst())
        } else {
            withoutPrefix = trimmedUsername
        }

        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !withoutPrefix.isEmpty,
              withoutPrefix.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            errorMessage = "Usernames must start with @ and include only letters, numbers, periods, underscores, or hyphens."
            return false
        }

        username = "@" + withoutPrefix

        guard !viewModel.email.isEmpty, isValidEmail(viewModel.email) else {
            errorMessage = "Please enter a valid email address."
            return false
        }

        guard !viewModel.password.isEmpty, viewModel.password.count >= 6 else {
            errorMessage = "Passwords must be at least 6 characters long."
            return false
        }

        guard viewModel.password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return false
        }

        guard agreedToTerms else {
            errorMessage = "Please agree to the terms and conditions."
            return false
        }

        return true
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    private func openTermsAndConditions() {
        if let url = URL(string: "https://www.bucketsapp.com/") {
            UIApplication.shared.open(url)
        }
    }
}

#if DEBUG
struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(OnboardingViewModel())
    }
}
#endif

private struct OnboardingFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

extension View {
    func onboardingFieldStyle() -> some View {
        modifier(OnboardingFieldStyle())
    }
}
