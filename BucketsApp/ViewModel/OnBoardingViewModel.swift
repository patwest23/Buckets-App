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
    
    /// A username property (optional usage).
    /// If you no longer need any username in your app, you can remove this, too.
    @Published var username: String = "" {
        didSet {
            if !username.isEmpty && !username.hasPrefix("@") {
                username = "@" + username
            }
        }
    }
    
    /// Whether the user is currently signed in.
    @Published var isAuthenticated: Bool = false

    /// Indicates that the authenticated user must create a username before
    /// proceeding to the main experience (used for Google sign-in flows).
    @Published var requiresUsernameSetup: Bool = false
    
    /// Holds the user’s profile image data (loaded from or to Firebase Storage).
    @Published var profileImageData: Data?
    
    /// The user document from Firestore (see `UserModel`).
    @Published var user: UserModel?
    
    /// Error messaging for UI alerts.
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false

    /// An identifier that allows the onboarding flow to reset its navigation state.
    @Published var onboardingViewID = UUID()

    /// Represents the various states of loading the authenticated user's profile.
    enum ProfileLoadingState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    /// Tracks the loading state for the current user's profile document.
    @Published var profileLoadingState: ProfileLoadingState = .idle

    /// Optional human-readable message describing why profile loading failed.
    @Published var profileLoadingErrorMessage: String?
    
    // MARK: - Firebase
    private let storage = Storage.storage()
    private let firestore = Firestore.firestore()
    private var userDocListener: ListenerRegistration?

    /// Timeout task used to guard against an infinite loading state when fetching the profile document.
    private var profileLoadTimeoutTask: Task<Void, Never>?
    
    /// Convenience property for the user doc ID (matching Auth UID).
    var userId: String? {
        user?.id
    }
    
    // MARK: - Initialization
    init() {
        checkIfUserIsAuthenticated()
    }
    
    deinit {
        userDocListener?.remove()
        profileLoadTimeoutTask?.cancel()
    }
    
    // MARK: - Check Auth State
    
    func checkIfUserIsAuthenticated() {
        Task {
            if let currentUser = Auth.auth().currentUser {
                isAuthenticated = true
                profileLoadingErrorMessage = nil
                profileLoadingState = .loading
                startProfileLoadTimeout()
                print("[OnboardingViewModel] Already signed in with UID:", currentUser.uid)

                await fetchUserDocument(userId: currentUser.uid)
                await loadProfileImage()
            } else {
                print("[OnboardingViewModel] No authenticated user found.")
                isAuthenticated = false
                profileLoadingState = .idle
                cancelProfileLoadTimeout()
            }
        }
    }
    
    func validateAuthSession() -> Bool {
        guard Auth.auth().currentUser != nil else {
            self.isAuthenticated = false
            self.profileLoadingState = .idle
            cancelProfileLoadTimeout()
            handleError(NSError(domain: "AuthError",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "User session expired."]))
            return false
        }
        return true
    }

    // MARK: - Profile Loading Helpers

    private func startProfileLoadTimeout() {
        profileLoadTimeoutTask?.cancel()
        profileLoadTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 8_000_000_000) // 8 seconds
            } catch {
                return
            }

            guard let self else { return }
            if !Task.isCancelled,
               self.user == nil,
               self.profileLoadingState == .loading {
                self.profileLoadingState = .failed
                if self.profileLoadingErrorMessage == nil {
                    self.profileLoadingErrorMessage = "We're having trouble loading your profile right now."
                }
            }
        }
    }

    private func cancelProfileLoadTimeout() {
        profileLoadTimeoutTask?.cancel()
        profileLoadTimeoutTask = nil
    }

    func retryProfileLoad() {
        guard let currentUser = Auth.auth().currentUser else {
            profileLoadingState = .failed
            profileLoadingErrorMessage = "Your session has expired. Please sign in again."
            return
        }

        profileLoadingErrorMessage = nil
        profileLoadingState = .loading
        startProfileLoadTimeout()

        Task { [weak self] in
            await self?.fetchUserDocument(userId: currentUser.uid)
            await self?.loadProfileImage()
        }
    }
    
    // MARK: - Google Sign-In
    
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            handleError(NSError(
                domain: "MissingGoogleClientID",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing Google ClientID in Firebase config."]
            ))
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController
        else {
            handleError(NSError(
                domain: "UIError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Unable to find rootViewController."]
            ))
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleError(error)
                return
            }
            
            guard let user = result?.user else {
                // handle error
                return
            }

            let idTokenString = user.idToken?.tokenString ?? ""
            let accessTokenString = user.accessToken.tokenString
            
            if idTokenString.isEmpty || accessTokenString.isEmpty {
                // handle error
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idTokenString,
                accessToken: accessTokenString
            )
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    self.handleError(error)
                    return
                }
                
                guard let authUser = authResult?.user else {
                    self.handleError(NSError(
                        domain: "AuthError",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "No Auth user found after Google sign-in."]
                    ))
                    return
                }
                
                self.isAuthenticated = true
                self.clearErrorState()
                self.profileLoadingErrorMessage = nil
                self.profileLoadingState = .loading
                self.startProfileLoadTimeout()

                Task {
                    let userDocRef = self.firestore.collection("users").document(authUser.uid)

                    do {
                        let snapshot = try await userDocRef.getDocument()

                        if snapshot.exists {
                            if let userEmail = authUser.email {
                                try await userDocRef.setData(["email": userEmail], merge: true)
                            }
                        } else {
                            let email = authUser.email ?? self.email
                            await self.createUserDocument(
                                userId: authUser.uid,
                                emailOverride: email,
                                usernameOverride: nil
                            )
                        }
                    } catch {
                        self.handleError(error)
                    }

                    await self.fetchUserDocument(userId: authUser.uid)
                    await self.loadProfileImage()

                    print("[OnboardingViewModel] Google sign-in success. UID:", authUser.uid)
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
            profileLoadingErrorMessage = nil
            profileLoadingState = .loading
            startProfileLoadTimeout()

            print("[OnboardingViewModel] signIn success. Auth UID:", authResult.user.uid)
            
            // Store credentials in Keychain for Face/Touch ID
            storeCredentialsInKeychain()
            
            if let actualEmail = authResult.user.email {
                let userDocRef = firestore.collection("users").document(authResult.user.uid)
                try await userDocRef.setData(["email": actualEmail], merge: true)
            }
            
            await fetchUserDocument(userId: authResult.user.uid)
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
            cancelProfileLoadTimeout()

            // Optionally remove from Keychain
            KeychainHelper.shared.deleteValue(for: "email")
            KeychainHelper.shared.deleteValue(for: "password")

        } catch {
            handleError(error)
            profileLoadingState = .failed
            profileLoadingErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Account Deletion

    func deleteAccount() async -> Result<String, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            let error = NSError(
                domain: "AuthError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No user is logged in."]
            )
            handleError(error)
            return .failure(error)
        }

        let userId = currentUser.uid

        do {
            userDocListener?.remove()
            userDocListener = nil

            try await deleteUserRelatedData(for: userId)

            do {
                try await currentUser.delete()
            } catch {
                let processedError = processedDeleteAccountError(error)
                handleError(processedError)
                return .failure(processedError)
            }

            KeychainHelper.shared.deleteValue(for: "email")
            KeychainHelper.shared.deleteValue(for: "password")

            clearState()
            clearErrorState()

            return .success("Your account has been deleted.")
        } catch {
            let processedError = processedDeleteAccountError(error)
            handleError(processedError)
            return .failure(processedError)
        }
    }

    private func deleteUserRelatedData(for userId: String) async throws {
        try await deleteUserItemsCollection(for: userId)
        try await firestore.collection("users").document(userId).delete()
        try await deleteProfileImage(for: userId)
    }

    private func deleteUserItemsCollection(for userId: String) async throws {
        let itemsCollection = firestore
            .collection("users")
            .document(userId)
            .collection("items")

        while true {
            let snapshot = try await itemsCollection.limit(to: 100).getDocuments()
            guard !snapshot.isEmpty else { break }

            let batch = firestore.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }

            try await batch.commit()

            if snapshot.documents.count < 100 {
                break
            }
        }
    }

    private func deleteProfileImage(for userId: String) async throws {
        let profileImageRef = storage.reference()
            .child("users/\(userId)/profile_images/\(userId).jpg")

        do {
            try await profileImageRef.delete()
        } catch {
            let nsError = error as NSError
            if nsError.domain == StorageErrorDomain,
               StorageErrorCode(rawValue: nsError.code) == .objectNotFound {
                return
            }
            throw error
        }
    }

    private func processedDeleteAccountError(_ error: Error) -> Error {
        let nsError = error as NSError
        if nsError.domain == AuthErrorDomain,
           let errorCode = AuthErrorCode(rawValue: nsError.code)?.code,
           errorCode == .requiresRecentLogin {
            return NSError(
                domain: nsError.domain,
                code: nsError.code,
                userInfo: [
                    NSLocalizedDescriptionKey: "For security reasons, please sign in again before deleting your account."
                ]
            )
        }
        return error
    }
    
    // MARK: - Create User
    
    func createUser() async {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            profileLoadingErrorMessage = nil
            profileLoadingState = .loading
            startProfileLoadTimeout()

            print("[OnboardingViewModel] createUser success. UID:", authResult.user.uid)
            
            // Store credentials in Keychain if you want Face ID next time
            storeCredentialsInKeychain()
            
            await createUserDocument(userId: authResult.user.uid)
            await fetchUserDocument(userId: authResult.user.uid)

        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Real-Time Listener
    
    func startListeningToUserDocument(userId: String) {
        userDocListener?.remove()
        
        let docRef = firestore.collection("users").document(userId)
        userDocListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[OnboardingViewModel] Error listening to user doc:", error.localizedDescription)
                self.handleError(error)
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                print("[OnboardingViewModel] User doc not found or removed.")
                return
            }
            
            do {
                self.user = try snapshot.data(as: UserModel.self)
                print("[OnboardingViewModel] Real-time update. user.id =", self.user?.id ?? "nil")
                self.username = self.user?.username ?? ""
                self.evaluateUsernameRequirement(userId: userId)
                self.profileLoadingState = .loaded
                self.profileLoadingErrorMessage = nil
                self.cancelProfileLoadTimeout()
            } catch {
                self.profileLoadingState = .failed
                self.profileLoadingErrorMessage = error.localizedDescription
                self.cancelProfileLoadTimeout()
                self.handleError(error)
            }
        }
    }
    
    func stopListeningToUserDocument() {
        userDocListener?.remove()
        userDocListener = nil
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
        profileImageData = data
        guard let currentUser = Auth.auth().currentUser, let data = data else { return }
        
        let storageRef = storage.reference()
            .child("users/\(currentUser.uid)/profile_images/\(currentUser.uid).jpg")
        do {
            try await storageRef.putDataAsync(data)
            let downloadURL = try await storageRef.downloadURL()
            
            let updates: [String: String] = ["profileImageUrl": downloadURL.absoluteString]
            try await firestore
                .collection("users")
                .document(currentUser.uid)
                .updateData(updates)
            
            print("[OnboardingViewModel] Profile image uploaded + Firestore updated.")
        } catch {
            handleError(error)
        }
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
    
    func createUserDocument(
        userId: String,
        emailOverride: String? = nil,
        usernameOverride: String? = nil
    ) async {
        let userDoc = firestore.collection("users").document(userId)
        do {
            var docData: [String: Any] = [
                "email": emailOverride ?? email,
                "createdAt": Date()
            ]

            if let normalized = normalizedUsername(from: usernameOverride ?? username) {
                docData["username"] = normalized
                username = normalized
                requiresUsernameSetup = false
            }

            try await userDoc.setData(docData)
            print("[OnboardingViewModel] User document created at /users/\(userId).")
        } catch {
            profileLoadingState = .failed
            profileLoadingErrorMessage = error.localizedDescription
            cancelProfileLoadTimeout()
            handleError(error)
        }
    }

    func fetchUserDocument(userId: String) async {
        profileLoadingState = .loading
        profileLoadingErrorMessage = nil
        startProfileLoadTimeout()
        let userDoc = firestore.collection("users").document(userId)
        do {
            let snapshot = try await userDoc.getDocument()
            guard snapshot.exists else {
                print("[OnboardingViewModel] No user document found at /users/\(userId). Creating new doc.")
                let emailOverride = Auth.auth().currentUser?.email ?? email
                await createUserDocument(userId: userId, emailOverride: emailOverride, usernameOverride: nil)
                requiresUsernameSetup = true
                await fetchUserDocument(userId: userId)
                return
            }

            self.user = try snapshot.data(as: UserModel.self)
            print("[OnboardingViewModel] User doc fetched. user?.id =", self.user?.id ?? "nil")
            username = self.user?.username ?? ""
            evaluateUsernameRequirement(userId: userId)
            startListeningToUserDocument(userId: userId)
            profileLoadingState = .loaded
            cancelProfileLoadTimeout()

            if self.user?.id == userId {
                print("[OnboardingViewModel] Matches Auth UID:", userId)
            } else {
                print("[OnboardingViewModel] Warning: doc ID mismatch. docID =", self.user?.id ?? "nil",
                      "AuthUID =", userId)
            }
            
        } catch {
            print("[OnboardingViewModel] Error fetching/decoding user doc:", error.localizedDescription)
            profileLoadingState = .failed
            profileLoadingErrorMessage = error.localizedDescription
            cancelProfileLoadTimeout()
            handleError(error)
        }
    }
    
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
        username = ""
        profileImageData = nil
        user = nil
        errorMessage = nil
        showErrorAlert = false
        isAuthenticated = false
        requiresUsernameSetup = false
        onboardingViewID = UUID()
        profileLoadingState = .idle
        profileLoadingErrorMessage = nil
        cancelProfileLoadTimeout()
    }

    private func evaluateUsernameRequirement(userId: String) {
        if let existingUsername = user?.username,
           !existingUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requiresUsernameSetup = false
        } else {
            requiresUsernameSetup = true
            print("[OnboardingViewModel] User \(userId) requires username setup.")
        }
    }

    private func normalizedUsername(from rawValue: String?) -> String? {
        guard let rawValue = rawValue else { return nil }

        var trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            trimmed.removeFirst()
        }

        // Remove spaces inside the username
        trimmed = trimmed.replacingOccurrences(of: " ", with: "")

        guard !trimmed.isEmpty else { return nil }

        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        if trimmed.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return nil
        }

        return "@" + trimmed
    }

    private func isUsernameAvailable(_ username: String, excluding userId: String) async throws -> Bool {
        let snapshot = try await firestore
            .collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments()

        return snapshot.documents.allSatisfy { $0.documentID == userId }
    }

    func saveUsername(_ proposedUsername: String) async -> Result<Void, Error> {
        guard let normalized = normalizedUsername(from: proposedUsername) else {
            return .failure(NSError(
                domain: "InvalidUsername",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Please choose a username that begins with @ and contains only letters, numbers, periods, underscores, or hyphens."]
            ))
        }

        guard let currentUser = Auth.auth().currentUser else {
            return .failure(NSError(
                domain: "AuthError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "You must be signed in to save a username."]
            ))
        }

        do {
            let isAvailable = try await isUsernameAvailable(normalized, excluding: currentUser.uid)
            guard isAvailable else {
                return .failure(NSError(
                    domain: "UsernameUnavailable",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "That username is already taken. Please try a different one."]
                ))
            }

            try await firestore
                .collection("users")
                .document(currentUser.uid)
                .setData([
                    "username": normalized,
                    "updatedAt": Date()
                ], merge: true)

            username = normalized
            if user != nil {
                user?.username = normalized
            }
            requiresUsernameSetup = false
            clearErrorState()

            return .success(())
        } catch {
            return .failure(error)
        }
    }
}

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
