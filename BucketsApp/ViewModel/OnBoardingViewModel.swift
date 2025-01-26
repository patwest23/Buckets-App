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

@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The user's email and password, used for sign in/up.
    @Published var email: String = ""
    @Published var password: String = ""
    
    /// Indicates if the user is currently signed in.
    @Published var isAuthenticated: Bool = false
    
    /// Holds the user's profile image as `Data`. You can convert it to a UIImage in the UI.
    @Published var profileImageData: Data?
    
    /// The user doc from Firestore. See `UserModel` for fields (e.g. name, email).
    @Published var user: UserModel?
    
    /// Error messaging for UI alerts.
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    
    // MARK: - Firebase References
    
    private let storage = Storage.storage()
    private let firestore = Firestore.firestore()
    private let profileImagePath = "profile_images"
    
    /// If you want to listen to changes in the user doc in real-time, keep a reference to the listener.
    private var userDocListener: ListenerRegistration?
    
    /// Convenience computed property
        var userId: String? {
            user?.id
        }
    
    // MARK: - Initializer
    
    init() {
        checkIfUserIsAuthenticated()
    }
    
    deinit {
        // If we have a real-time listener for user doc, remove it to avoid memory leaks.
        userDocListener?.remove()
    }
    
    // MARK: - Authentication State Check
    
    /// Check current authentication status on app launch or ViewModel init.
    func checkIfUserIsAuthenticated() {
        Task {
            if let currentUser = Auth.auth().currentUser {
                isAuthenticated = true
                await fetchUserDocument(userId: currentUser.uid)
                await loadProfileImage()
            } else {
                print("[OnboardingViewModel] No authenticated user found.")
                isAuthenticated = false
            }
        }
    }
    
    /// Validates that a user session exists. If not, sets `isAuthenticated = false`
    /// and returns `false`.
    func validateAuthSession() -> Bool {
        guard Auth.auth().currentUser != nil else {
            self.isAuthenticated = false
            handleError(NSError(
                domain: "AuthError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User session expired."]
            ))
            return false
        }
        return true
    }
    
    // MARK: - Sign In / Sign Out
    
    /// Sign in with email and password
    func signIn() async {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            await fetchUserDocument(userId: authResult.user.uid)
            await loadProfileImage()
        } catch {
            handleError(error)
        }
    }
    
    /// Sign out the current user
    func signOut() async {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            // Optionally remove any snapshot listeners
            userDocListener?.remove()
            clearState()
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Create User
    
    /// Create a new user with email/password
    func createUser() async {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            
            // Create Firestore doc for the new user
            await createUserDocument(userId: authResult.user.uid)
            
            // Fetch user doc to populate `user` property
            await fetchUserDocument(userId: authResult.user.uid)
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Real-Time User Doc Listener (Optional)
    
    /// Listens to changes on the user doc in real-time. If you need to keep
    /// the `user` updated automatically, call this after sign-in or create-user.
    func startListeningToUserDocument(userId: String) {
        userDocListener?.remove() // remove previous if any
        
        let docRef = firestore.collection("users").document(userId)
        userDocListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("[OnboardingViewModel] Error listening to user doc: \(error.localizedDescription)")
                self.handleError(error)
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                print("[OnboardingViewModel] User doc not found or removed.")
                return
            }
            
            do {
                self.user = try snapshot.data(as: UserModel.self)
                print("[OnboardingViewModel] User doc updated in real-time.")
            } catch {
                self.handleError(error)
            }
        }
    }
    
    /// Stop listening to user doc changes.
    func stopListeningToUserDocument() {
        userDocListener?.remove()
        userDocListener = nil
    }
    
    // MARK: - Password Reset
    
    /// Send a password reset email
    func resetPassword(for email: String) async -> Result<String, Error> {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return .success("A link to reset your password has been sent to \(email).")
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Update Email
    
    /// Update the authenticated user's email
    func updateEmail(newEmail: String) async -> Result<String, Error> {
        guard let currentUser = Auth.auth().currentUser else {
            return .failure(
                NSError(domain: "AuthError", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No user is logged in."])
            )
        }
        
        do {
            // 1) Send an email verification before updating the email.
            try await currentUser.sendEmailVerification(beforeUpdatingEmail: newEmail)
            
            // 2) Update the email field in Firestore.
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
            
            // 3) Update local state
            self.email = newEmail
            
            // 4) Prompt user to verify new email
            return .success("Verification sent to \(newEmail). Once verified, your email will be updated.")
            
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Update Password
    
    /// Update the authenticated user's password
    func updatePassword(currentPassword: String, newPassword: String) async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(
                domain: "AuthError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No user is logged in."]
            )
        }
        
        // Re-auth the user
        let credential = EmailAuthProvider.credential(
            withEmail: currentUser.email ?? "",
            password: currentPassword
        )
        try await currentUser.reauthenticate(with: credential)
        
        // Update password
        try await currentUser.updatePassword(to: newPassword)
        return "Password updated successfully."
    }
    
    // MARK: - Profile Image Management
    
    /// Update the profile image in Firebase Storage
    // Ensure your function is still @MainActor (or a method in @MainActor class)
    func updateProfileImage(with data: Data?) async {
        profileImageData = data
        guard let currentUser = Auth.auth().currentUser, let data = data else { return }
        
        let storageRef = storage.reference().child("\(profileImagePath)/\(currentUser.uid).jpg")
        do {
            // 1) Upload data
            try await storageRef.putDataAsync(data)
            
            // 2) Retrieve downloadURL
            let downloadURL = try await storageRef.downloadURL()
            
            // 3) Use a [String : String] dictionary (Sendable).
            let updates: [String: String] = ["profileImageUrl": downloadURL.absoluteString]
            
            // 4) Firestore accepts [String: Any], but [String: String] is compatible
            //    with the Swift Concurrency checks.
            try await firestore
                .collection("users")
                .document(currentUser.uid)
                .updateData(updates)
            
            print("[OnboardingViewModel] Profile image uploaded, Firestore updated.")
            
        } catch {
            handleError(error)
        }
    }
    
    /// Load the profile image from Firebase Storage
    func loadProfileImage() async {
        guard let currentUser = Auth.auth().currentUser else {
            print("[OnboardingViewModel] No user signed in.")
            return
        }
        
        let storageRef = storage.reference().child("\(profileImagePath)/\(currentUser.uid).jpg")
        do {
            // Download up to 5 MB
            let data = try await storageRef.getDataAsync(maxSize: 5 * 1024 * 1024)
            profileImageData = data
            print("[OnboardingViewModel] Profile image loaded successfully.")
        } catch {
            print("[OnboardingViewModel] Error loading profile image: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Firestore Integration
    
    /// Create a new Firestore document for the user
    private func createUserDocument(userId: String) async {
        let userDoc = firestore.collection("users").document(userId)
        do {
            try await userDoc.setData([
                "email": email,
                "createdAt": Date()
                // Add other default fields as needed
            ])
            print("[OnboardingViewModel] User document created successfully.")
        } catch {
            handleError(error)
        }
    }
    
    /// Fetch the Firestore document for the user (one-time) using Codable
    func fetchUserDocument(userId: String) async {
        let userDoc = firestore.collection("users").document(userId)
        do {
            let snapshot = try await userDoc.getDocument()
            guard snapshot.exists else {
                print("[OnboardingViewModel] No user document found. Creating a new one...")
                await createUserDocument(userId: userId)
                return
            }
            self.user = try snapshot.data(as: UserModel.self)
            print("[OnboardingViewModel] User document fetched successfully.")
            
        } catch DecodingError.dataCorrupted(let context) {
            print("[OnboardingViewModel] Decoding error: \(context.debugDescription)")
            handleError(DecodingError.dataCorrupted(context))
        } catch DecodingError.keyNotFound(let key, let context) {
            print("[OnboardingViewModel] Key '\(key)' not found, \(context.debugDescription)")
            handleError(DecodingError.keyNotFound(key, context))
        } catch DecodingError.typeMismatch(let type, let context) {
            print("[OnboardingViewModel] Type mismatch for type '\(type)', \(context.debugDescription)")
            handleError(DecodingError.typeMismatch(type, context))
        } catch DecodingError.valueNotFound(let value, let context) {
            print("[OnboardingViewModel] Value '\(value)' not found, \(context.debugDescription)")
            handleError(DecodingError.valueNotFound(value, context))
        } catch {
            print("[OnboardingViewModel] Error fetching/decoding user doc: \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showErrorAlert = true
        print("[OnboardingViewModel] Error: \(error.localizedDescription)")
    }
    
    private func clearErrorState() {
        errorMessage = nil
        showErrorAlert = false
    }
    
    /// Clears out all fields, e.g., when the user signs out or you want a fresh state.
    private func clearState() {
        print("[OnboardingViewModel] Clearing state...")
        email = ""
        password = ""
        profileImageData = nil
        user = nil
        errorMessage = nil
        showErrorAlert = false
        isAuthenticated = false
    }
}
