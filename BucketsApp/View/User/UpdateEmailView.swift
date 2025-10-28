//
//  UpdateEmailView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 1/13/24.
//

import SwiftUI

struct UpdateEmailView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newEmail: String = ""
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
                    TextField("New email", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .email)
                        .onboardingFieldStyle()
                }

                Button(action: updateEmail) {
                    ZStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            Text("Update email")
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

                Text("We'll send a verification link to your new email. Confirm it to finish the update.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Update email")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Update email", isPresented: alertBinding) {
            Button("OK", role: .cancel) {
                if shouldDismissAfterAlert {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            newEmail = viewModel.email
            focusedField = .email
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keep your inbox current")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Enter the address you'd like to use for account notifications and security alerts.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var primaryButtonBackground: Color {
        isButtonDisabled ? Color.accentColor.opacity(0.4) : Color.accentColor
    }

    private var isButtonDisabled: Bool {
        isSubmitting || newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func updateEmail() {
        guard !isButtonDisabled else { return }

        let trimmedEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            alertMessage = "Please enter a valid email address."
            return
        }

        isSubmitting = true
        focusedField = nil

        Task { @MainActor in
            let result = await viewModel.updateEmail(newEmail: trimmedEmail)
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
struct UpdateEmailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = OnboardingViewModel()
        
        return Group {
            // Light Mode
            NavigationStack {
                UpdateEmailView()
                    .environmentObject(mockViewModel)
            }
            .previewDisplayName("UpdateEmailView - Light")

            // Dark Mode
            NavigationStack {
                UpdateEmailView()
                    .environmentObject(mockViewModel)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("UpdateEmailView - Dark")
        }
    }
}
#endif
