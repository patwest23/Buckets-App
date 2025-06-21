//
//  OnBoardingViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/15/23.
//

import Foundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import GoogleSignIn
import FirebaseCore
import LocalAuthentication
import Security

@MainActor
final class OnboardingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The user’s email and password (for authentication).
    @Published var email: String = ""
    @Published var password: String = ""
    
    
    /// Whether the user is currently signed in.
    @Published var isAuthenticated: Bool = false
    
    /// Holds the user’s profile image data (loaded from or to Firebase Storage).
    @Published var profileImageData: Data?
    
    
    /// Whether to prompt for a username after Google sign-in if missing.
    @Published var shouldPromptUsername: Bool = false
    /// The username input (used after onboarding, if needed).
    @Published var username: String = ""
    
    /// Error messaging for UI alerts.
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    
    // MARK: - Firebase
    private let storage = Storage.storage()
    private let firestore = Firestore.firestore()
    private var userDocListener: ListenerRegistration?
    
    
    // MARK: - Initialization
    init() {
        checkIfUserIsAuthenticated()
    }
    
    deinit {
        userDocListener?.remove()
    }
    
    // MARK: - Check Auth State
    
    func checkIfUserIsAuthenticated() {
        Task {
            if let currentUser = Auth.auth().currentUser {
                isAuthenticated = true
                print("[OnboardingViewModel] Already signed in with UID:", currentUser.uid)
                // Profile image loading is now handled by UserViewModel.
            } else {
                print("[OnboardingViewModel] No authenticated user found.")
                isAuthenticated = false
            }
        }
    }
    
    func validateAuthSession() -> Bool {
        guard Auth.auth().currentUser != nil else {
            self.isAuthenticated = false
            handleError(NSError(domain: "AuthError",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "User session expired."]))
            return false
        }
        return true
    }
    
    // MARK: - Google Sign-In

    func signInWithGoogle(completion: @escaping (Bool) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            handleError(NSError(
                domain: "MissingGoogleClientID",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing Google ClientID in Firebase config."]
            ))
            completion(false)
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            handleError(NSError(
                domain: "UIError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Unable to find rootViewController."]
            ))
            completion(false)
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.handleError(error)
                completion(false)
                return
            }

            guard let user = result?.user else {
                completion(false)
                return
            }

            let idTokenString = user.idToken?.tokenString ?? ""
            let accessTokenString = user.accessToken.tokenString

            if idTokenString.isEmpty || accessTokenString.isEmpty {
                completion(false)
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idTokenString,
                accessToken: accessTokenString
            )

            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    self.handleError(error)
                    completion(false)
                    return
                }

                guard let authUser = authResult?.user else {
                    self.handleError(NSError(
                        domain: "AuthError",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "No Auth user found after Google sign-in."]
                    ))
                    completion(false)
                    return
                }

                self.isAuthenticated = true
                self.clearErrorState()

                Task {
                    if let userEmail = authUser.email {
                        let userDocRef = self.firestore.collection("users").document(authUser.uid)
                        do {
                            try await userDocRef.setData(["email": userEmail], merge: true)
                        } catch {
                            self.handleError(error)
                            completion(false)
                            return
                        }
                    }

                    await self.loadProfileImage()

                    print("[OnboardingViewModel] Google sign-in success. UID:", authUser.uid)
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Sign In / Out
    
    func signIn() async {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            
            print("[OnboardingViewModel] signIn success. Auth UID:", authResult.user.uid)
            
            // Store credentials in Keychain for Face/Touch ID
            storeCredentialsInKeychain()
            
            if let actualEmail = authResult.user.email {
                let userDocRef = firestore.collection("users").document(authResult.user.uid)
                try await userDocRef.setData(["email": actualEmail], merge: true)
            }
            
            await loadProfileImage()
            
        } catch {
            handleError(error)
        }
    }
    
    func signOut() async {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            userDocListener?.remove()
            clearState()
            
            // Optionally remove from Keychain
            KeychainHelper.shared.deleteValue(for: "email")
            KeychainHelper.shared.deleteValue(for: "password")
            
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Create User
    
    func createUser(using userViewModel: UserViewModel) async {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            
            print("[OnboardingViewModel] createUser success. UID:", authResult.user.uid)
            shouldPromptUsername = true
            
            // Store credentials in Keychain if you want Face ID next time
            storeCredentialsInKeychain()
            
            await userViewModel.createUserDocument(userId: authResult.user.uid, email: authResult.user.email ?? "")
            await userViewModel.updateUserName(to: self.username)
            
        } catch {
            handleError(error)
        }
    }
    
    
    // MARK: - Password Reset
    
    func resetPassword(for email: String) async -> Result<String, Error> {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return .success("A link to reset your password was sent to \(email).")
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Update Email
    
    func updateEmail(newEmail: String) async -> Result<String, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return .failure(NSError(domain: "AuthError", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No user is logged in."]))
        }
        
        do {
            // Send a verification before updating
            try await currentUser.sendEmailVerification(beforeUpdatingEmail: newEmail)
            
            let userDoc = firestore.collection("users").document(currentUser.uid)
            let dataToUpdate: [String: String] = ["email": newEmail]
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                userDoc.updateData(dataToUpdate) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            
            self.email = newEmail
            return .success("Verification sent to \(newEmail).")
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Update Password
    
    func updatePassword(currentPassword: String, newPassword: String) async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No user is logged in."])
        }
        
        let credential = EmailAuthProvider.credential(
            withEmail: currentUser.email ?? "",
            password: currentPassword
        )
        try await currentUser.reauthenticate(with: credential)
        
        try await currentUser.updatePassword(to: newPassword)
        return "Password updated successfully."
    }
    
    // MARK: - Profile Image
    
    func updateProfileImage(with data: Data?) async {
        // print("[OnboardingViewModel] Deprecated: updateProfileImage is now handled by UserViewModel.")
        print("[OnboardingViewModel] Deprecated: updateProfileImage is now handled by UserViewModel.")
        // Functionality moved to UserViewModel.
    }
    
    func loadProfileImage() async {
        guard let currentUser = Auth.auth().currentUser else {
            print("[OnboardingViewModel] No user signed in.")
            return
        }
        
        let storageRef = storage.reference()
            .child("users/\(currentUser.uid)/profile_images/\(currentUser.uid).jpg")
        do {
            let data = try await storageRef.getDataAsync(maxSize: 5 * 1024 * 1024)
            profileImageData = data
            print("[OnboardingViewModel] Profile image loaded.")
        } catch {
            print("[OnboardingViewModel] Error loading profile image:", error.localizedDescription)
        }
    }
    
    // MARK: - Firestore Integration
    
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showErrorAlert = true
        print("[OnboardingViewModel] Error:", error.localizedDescription)
    }
    
    private func clearErrorState() {
        errorMessage = nil
        showErrorAlert = false
    }
    
    private func clearState() {
        print("[OnboardingViewModel] Clearing state...")
        email = ""
        password = ""
        profileImageData = nil
        errorMessage = nil
        showErrorAlert = false
        isAuthenticated = false
    }
}

// MARK: - Username Availability & Update
// Username management is now handled by UserViewModel.

// MARK: - Biometric Login & Keychain
extension OnboardingViewModel {
    
    /// Call this after a successful manual login if you want
    /// to store credentials for future Face ID / Touch ID.
    func storeCredentialsInKeychain() {
        KeychainHelper.shared.setValue(email, for: "email")
        KeychainHelper.shared.setValue(password, for: "password")
    }
    
    /// Attempt to log in using Face ID / Touch ID:
    ///  1) Retrieve saved email/password from Keychain.
    ///  2) Prompt user for Face ID / Touch ID.
    ///  3) If successful => sign in with stored credentials.
    func loginWithBiometrics() async {
        // 1) Retrieve saved credentials
        guard let storedEmail = KeychainHelper.shared.getValue(for: "email"),
              let storedPassword = KeychainHelper.shared.getValue(for: "password") else {
            print("[OnboardingViewModel] No stored credentials in Keychain. Prompt normal login.")
            return
        }
        
        // 2) LocalAuthentication for Face/Touch ID
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("[OnboardingViewModel] Device does not support biometrics or is not enrolled.")
            return
        }
        
        let reason = "Use Face ID / Touch ID to log in."
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evaluateError in
            Task { @MainActor in
                if success {
                    // 3) Face ID success => sign in with stored credentials
                    self.email = storedEmail
                    self.password = storedPassword
                    await self.signIn()
                } else {
                    if let error = evaluateError {
                        self.handleError(error)
                    } else {
                        print("[OnboardingViewModel] Biometric auth canceled by user.")
                    }
                }
            }
        }
    }
}

// MARK: - Simple Keychain Helper
final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    func setValue(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // Remove old entry if any
        let queryDelete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(queryDelete as CFDictionary)
        
        // Add new entry
        let queryAdd: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlocked
        ]
        SecItemAdd(queryAdd as CFDictionary, nil)
    }
    
    func getValue(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrAccount as String:  key,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    func deleteValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

