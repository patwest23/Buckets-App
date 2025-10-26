import SwiftUI

struct UsernameSetupView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var username: String = ""
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    @FocusState private var usernameIsFocused: Bool

    private var bindingUsername: Binding<String> {
        Binding(
            get: { username },
            set: { newValue in
                let trimmed = newValue
                    .trimmingCharacters(in: .whitespacesAndNewlines)
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
            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Finish setting up")
                        .font(.headline)
                        .foregroundColor(.accentColor)

                    Text("Choose a username")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Pick a unique handle to represent you in Buckets. You can change it later from your profile settings.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    TextField("@username", text: bindingUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.default)
                        .focused($usernameIsFocused)
                        .onboardingFieldStyle()

                    Text("Usernames must start with @ and can include letters, numbers, periods, underscores, or hyphens.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Button(action: saveUsername) {
                    ZStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("Save username")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                }
                .buttonStyle(.plain)
                .background(buttonBackgroundColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(isSubmitting || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            username = onboardingViewModel.username
            if username.isEmpty {
                usernameIsFocused = true
            }
        }
        .alert("Username", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func saveUsername() {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Please enter a username before continuing."
            return
        }

        isSubmitting = true
        Task {
            let result = await onboardingViewModel.saveUsername(username)
            await MainActor.run {
                isSubmitting = false
                switch result {
                case .success:
                    break
                case .failure(let error):
                    alertMessage = error.localizedDescription
                }
            }
        }
    }

    private var buttonBackgroundColor: Color {
        let isDisabled = isSubmitting || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isDisabled ? Color.accentColor.opacity(0.4) : Color.accentColor
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
}

#if DEBUG
struct UsernameSetupView_Previews: PreviewProvider {
    static var previews: some View {
        UsernameSetupView()
            .environmentObject(OnboardingViewModel())
    }
}
#endif
