//
//  TagUsersViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/9/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class TagUserViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var captionText: String = ""                 // E.g., the user’s typed text with “@mention”
    @Published var mentionSuggestions: [UserModel] = []     // Displayed as an autocomplete list
    @Published var taggedUserIds: [String] = []             // Final list of tagged user IDs
    
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    /// The user ID of the currently authenticated user
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    init() {
        print("[TagUserViewModel] init.")
    }
    
    deinit {
        print("[TagUserViewModel] deinit.")
    }
    
    // MARK: - Handle Text Changes
    /// Call this whenever the user’s caption text changes. It looks for a pattern like
    /// "@somePartialName" at the end of the string and performs a Firestore query.
    func handleCaptionChange(_ newText: String) {
        self.captionText = newText
        
        // 1) Extract the last “word” or partial text the user typed
        //    If you want more advanced logic, parse the entire text for multiple “@” mentions.
        guard let lastWord = newText.split(separator: " ").last else {
            mentionSuggestions = []
            return
        }
        
        // 2) Check if the last word starts with "@"
        if lastWord.hasPrefix("@") {
            // Remove the leading “@” to get “somePartialName”
            let queryText = String(lastWord.dropFirst())
            
            // If empty (just typed “@”), or too short, you might not query yet
            guard queryText.count > 0 else {
                mentionSuggestions = []
                return
            }
            
            // 3) Perform an async mention search
            Task {
                await searchUsernames(matching: queryText)
            }
        } else {
            // If user typed text without “@” => clear suggestions
            mentionSuggestions = []
        }
    }
    
    // MARK: - Search for Usernames
    /// Query Firestore for usernames that match (or start with) `queryText`.
    /// Firestore doesn’t support partial string matching easily, so you may do equality or “startAt” logic.
    /// For a real partial match, you might maintain a custom index or use a 3rd-party solution.
    private func searchUsernames(matching queryText: String) async {
        do {
            // Very simple approach: exact match
            let snap = try await db.collection("users")
                .whereField("username", isEqualTo: "@\(queryText)")
                .getDocuments()
            
            var results = [UserModel]()
            for doc in snap.documents {
                if let user = try? doc.data(as: UserModel.self),
                   let userId = user.id,
                   userId != currentUserId {
                    results.append(user)
                }
            }
            
            // If you want “startsWith” logic, consider:
            //   .order(by: "username")
            //   .start(at: ["@\(queryText)"])
            //   .end(at: ["@\(queryText)\u{f8ff}"])
            // or store a “username_lowercase” field for case-insensitive queries, etc.
            
            self.mentionSuggestions = results
        } catch {
            print("[TagUserViewModel] searchUsernames error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Select Suggestion
    /// When the user taps on a suggestion, we can replace the partial “@xxx” in the caption
    /// with the full mention, or just keep the mention in text. We also store the userId in `taggedUserIds`.
    func selectSuggestion(_ user: UserModel) {
        guard let userId = user.id else { return }
        
        // 1) We add the userId to `taggedUserIds` so we know who was tagged
        if !taggedUserIds.contains(userId) {
            taggedUserIds.append(userId)
        }
        
        // 2) Optionally, replace the last “@xxx” substring in `captionText` with the user’s username
        if let lastWordRange = captionText.range(of: "@[A-Za-z0-9_]*", options: .regularExpression) {
            // This is a simplistic example. Real code might parse for the exact substring
            // that matches what they typed. You might store the partial so you can do a direct replace.
            let replacement = user.username ?? "@???"  // e.g. “@alice”
            captionText.replaceSubrange(lastWordRange, with: replacement)
        }
        
        // 3) Clear suggestions now that we picked someone
        mentionSuggestions = []
    }
    
    // MARK: - Send Notifications to Tagged Users
    /// This is a simplistic approach— e.g., we write to /users/<taggedUserId>/notifications
    /// with a doc that references the post or item. Real apps often use Cloud Functions
    /// or FCM for push notifications.
    func notifyTaggedUsers(postId: String) async {
        guard !taggedUserIds.isEmpty else { return }
        
        do {
            for taggedId in taggedUserIds {
                let notifRef = db.collection("users")
                    .document(taggedId)
                    .collection("notifications")
                    .document()
                
                // Example structure
                let data: [String: Any] = [
                    "title": "You were mentioned!",
                    "message": "Check out this post: \(postId)",
                    "timestamp": FieldValue.serverTimestamp()
                ]
                
                try await notifRef.setData(data)
            }
            
            print("[TagUserViewModel] notifyTaggedUsers => wrote notifications for \(taggedUserIds.count) user(s).")
        } catch {
            print("[TagUserViewModel] notifyTaggedUsers error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // Optional: remove a tag
    func removeTag(_ userId: String) {
        taggedUserIds.removeAll { $0 == userId }
    }
}
