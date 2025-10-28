//
//  UpdateUserNameView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 2/2/25.
//

import SwiftUI

struct UpdateUserNameView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newUserName: String = ""
    @State private var confirmUserName: String = ""
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    @State private var shouldDismissAfterAlert = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case username
        case confirm
    }

    private var usernameBinding: Binding<String> {
        Binding(
            get: { newUserName },
            set: { newValue in
                newUserName = sanitizedUsername(from: newValue)
            }
        )
    }

    private var confirmBinding: Binding<String> {
        Binding(
            get: { confirmUserName },
            set: { newValue in
                confirmUserName = sanitizedUsername(from: newValue)
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                VStack(alignment: .leading, spacing: 18) {
                    TextField("@username", text: usernameBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .username)
                        .onboardingFieldStyle()

                    TextField("Confirm username", text: confirmBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .confirm)
                        .onboardingFieldStyle()
                }

                Button(action: updateUserName) {
                    ZStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            Text("Update username")
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

                Text("Usernames can include letters, numbers, periods, underscores, or hyphens.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Update username")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Update username", isPresented: alertBinding) {
            Button("OK", role: .cancel) {
                if shouldDismissAfterAlert {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            if newUserName.isEmpty {
                newUserName = sanitizedUsername(from: userViewModel.user?.name ?? userViewModel.user?.username ?? "")
                confirmUserName = newUserName
            }
            focusedField = .username
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Refresh your handle")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Update how other Buckets users see you across shared lists and activity feeds.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var primaryButtonBackground: Color {
        isButtonDisabled ? Color.accentColor.opacity(0.4) : Color.accentColor
    }

    private var isButtonDisabled: Bool {
        isSubmitting || newUserName.isEmpty || confirmUserName.isEmpty
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

    private func sanitizedUsername(from value: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")

        guard !trimmed.isEmpty else { return "" }

        let withoutPrefix = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let filtered = withoutPrefix.unicodeScalars.filter { allowedCharacters.contains($0) }
        let sanitized = String(String.UnicodeScalarView(filtered))

        return sanitized.isEmpty ? "" : "@" + sanitized
    }

    private func updateUserName() {
        guard !isButtonDisabled else { return }

        let trimmedUsername = newUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirm = confirmUserName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty else {
            alertMessage = "Please enter a username."
            return
        }

        guard trimmedUsername == trimmedConfirm else {
            alertMessage = "Usernames do not match."
            return
        }

        isSubmitting = true
        focusedField = nil

        Task { @MainActor in
            await userViewModel.updateUserName(to: trimmedUsername)

            isSubmitting = false

            if userViewModel.showErrorAlert, let error = userViewModel.errorMessage {
                alertMessage = error
                userViewModel.showErrorAlert = false
            } else {
                userViewModel.errorMessage = nil
                alertMessage = "Username updated successfully."
                shouldDismissAfterAlert = true
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct UpdateUserNameView_Previews: PreviewProvider {
    static var previews: some View {
        let mockUserVM = UserViewModel()
        
        return Group {
            // Light Mode
            NavigationStack {
                UpdateUserNameView()
                    .environmentObject(mockUserVM)
            }
            .previewDisplayName("UpdateUserNameView - Light")

            // Dark Mode
            NavigationStack {
                UpdateUserNameView()
                    .environmentObject(mockUserVM)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("UpdateUserNameView - Dark")
        }
    }
}
#endif
