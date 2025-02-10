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
import GoogleSignIn  // <-- Import Google Sign-In
import FirebaseCore

@MainActor
final class OnboardingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The user’s email and password (for authentication).
    @Published var email: String = ""
    @Published var password: String = ""
    
    /// The user’s chosen handle (e.g., "john123" or "@john123").
    /// Automatically ensures an "@" prefix.
    @Published var username: String = "" {
        didSet {
            // If the user typed something, ensure the string starts with "@"
            if !username.isEmpty && !username.hasPrefix("@") {
                username = "@" + username
            }
        }
    }
    
    /// Whether the user is currently signed in.
    @Published var isAuthenticated: Bool = false
    
    /// Holds the user’s profile image data (loaded from or to Firebase Storage).
    @Published var profileImageData: Data?
    
    /// The user document from Firestore (see `UserModel`).
    @Published var user: UserModel?
    
    /// Error messaging for UI alerts.
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    
    // MARK: - Firebase
    private let storage = Storage.storage()
    private let firestore = Firestore.firestore()
    private let profileImagePath = "profile_images"
    
    private var userDocListener: ListenerRegistration?
    
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
    }
    
    // MARK: - Check Auth State
    
    func checkIfUserIsAuthenticated() {
        Task {
            if let currentUser = Auth.auth().currentUser {
                isAuthenticated = true
                print("[OnboardingViewModel] Already signed in with UID:", currentUser.uid)
                
                await fetchUserDocument(userId: currentUser.uid)
                await loadProfileImage()
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
        
    func signInWithGoogle() {
        // 1) Get the Firebase clientID
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            handleError(NSError(
                domain: "MissingGoogleClientID",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing Google ClientID in Firebase config."]
            ))
            return
        }
        
        // 2) Create Google Sign-In configuration
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        // 3) Determine where to present the sign-in UI
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
        
        // 4) Begin sign-in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            // a) Check for an immediate error
            if let error = error {
                self.handleError(error)
                return
            }
            
            // b) Validate user
            guard let user = result?.user else {
                // handle error
                return
            }

            // c) If user.idToken is non-optional:
            let idToken = user.idToken              // GIDToken
            let accessToken = user.accessToken      // GIDAccessToken

            // d) Extract the strings
            let idTokenString = idToken!.tokenString
            let accessTokenString = accessToken.tokenString

            // e) Check if empty
            if idTokenString.isEmpty || accessTokenString.isEmpty {
                // handle error
                return
            }

            // f) Build credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idTokenString,
                accessToken: accessTokenString
            )
            
            // f) Sign in to Firebase
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
                
                // g) Update Firestore user doc + load profile
                Task {
                    if let userEmail = authUser.email {
                        let userDocRef = self.firestore.collection("users").document(authUser.uid)
                        do {
                            // If you want to store Google’s displayName:
                            // let googleName = user.profile?.name ?? "GoogleUser"
                            
                            try await userDocRef.setData([
                                "email": userEmail
                                // "name": googleName
                            ], merge: true)
                        } catch {
                            self.handleError(error)
                        }
                    }
                    
                    await self.fetchUserDocument(userId: authUser.uid)
                    await self.loadProfileImage()
                    
                    print("[OnboardingViewModel] Google sign-in success. UID:", authUser.uid)
                }
            }
        }
    }
    
    // MARK: - Username Availability
    
    /// Checks if a particular username is already used by querying Firestore.
    func isUsernameUsed(_ username: String) async -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        
        do {
            // Query for "username" rather than "name"
            let snapshot = try await firestore
                .collection("users")
                .whereField("username", isEqualTo: trimmed)
                .getDocuments()
            
            return !snapshot.documents.isEmpty
        } catch {
            print("[OnboardingViewModel] Error checking username:", error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Sign In / Out
    
    func signIn() async {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            
            print("[OnboardingViewModel] signIn success. Auth UID:", authResult.user.uid)
            
            // 1) Ensure Firestore doc has up-to-date "email"
            if let actualEmail = authResult.user.email {
                let userDocRef = firestore.collection("users").document(authResult.user.uid)
                try await userDocRef.setData(["email": actualEmail], merge: true)
            }
            
            // 2) Load user doc
            await fetchUserDocument(userId: authResult.user.uid)
            
            // 3) Load profile image
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
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Create User
    
    /// Creates a new user in Firebase Auth, then calls `createUserDocument(...)`
    /// to store the doc in Firestore. Finally, fetches the doc into `self.user`.
    func createUser() async {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            isAuthenticated = true
            clearErrorState()
            
            print("[OnboardingViewModel] createUser success. UID:", authResult.user.uid)
            
            // 1) Create doc in /users/<AuthUID>
            await createUserDocument(userId: authResult.user.uid)
            
            // 2) Fetch doc to populate `user`
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
            } catch {
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
        
        let storageRef = storage.reference().child("\(profileImagePath)/\(currentUser.uid).jpg")
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
        
        let storageRef = storage.reference().child("\(profileImagePath)/\(currentUser.uid).jpg")
        do {
            let data = try await storageRef.getDataAsync(maxSize: 5 * 1024 * 1024)
            profileImageData = data
            print("[OnboardingViewModel] Profile image loaded.")
        } catch {
            print("[OnboardingViewModel] Error loading profile image:", error.localizedDescription)
        }
    }
    
    // MARK: - Firestore Integration
    
    private func createUserDocument(userId: String) async {
        let userDoc = firestore.collection("users").document(userId)
        do {
            let docData: [String: Any] = [
                "email": email,
                "createdAt": Date(),
                // store the “@” handle as “username” in Firestore
                "username": username
            ]
            
            try await userDoc.setData(docData)
            print("[OnboardingViewModel] User document created at /users/\(userId).")
        } catch {
            handleError(error)
        }
    }
    
    func fetchUserDocument(userId: String) async {
        let userDoc = firestore.collection("users").document(userId)
        do {
            let snapshot = try await userDoc.getDocument()
            guard snapshot.exists else {
                print("[OnboardingViewModel] No user document found at /users/\(userId). Creating new doc.")
                await createUserDocument(userId: userId)
                return
            }
            
            self.user = try snapshot.data(as: UserModel.self)
            print("[OnboardingViewModel] User doc fetched. user?.id =", self.user?.id ?? "nil")
            
            if self.user?.id == userId {
                print("[OnboardingViewModel] Matches Auth UID:", userId)
            } else {
                print("[OnboardingViewModel] Warning: doc ID mismatch. docID =", self.user?.id ?? "nil",
                      "AuthUID =", userId)
            }
            
        } catch {
            print("[OnboardingViewModel] Error fetching/decoding user doc:", error.localizedDescription)
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
    }
}
