//
//  BucketsApp.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore

@main
struct BucketsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject var bucketListViewModel = ListViewModel()
    @StateObject var onboardingViewModel = OnboardingViewModel()
    @StateObject var userViewModel = UserViewModel()
    @StateObject var feedViewModel = FeedViewModel()
    @StateObject var postViewModel = PostViewModel()

    var body: some Scene {
        WindowGroup {
            if !onboardingViewModel.isAuthenticated {
                OnboardingView()
                    .environmentObject(onboardingViewModel)
                    .environmentObject(bucketListViewModel)
                    .environmentObject(userViewModel)
            } else if onboardingViewModel.shouldPromptUsername {
                UsernameSetupView()
                    .environmentObject(onboardingViewModel)
                    .environmentObject(bucketListViewModel)
                    .environmentObject(userViewModel)
            } else {
                NavigationStack {
                    ListView()
                        .environmentObject(bucketListViewModel)
                        .environmentObject(onboardingViewModel)
                        .environmentObject(userViewModel)
                        .environmentObject(feedViewModel)
                        .environmentObject(postViewModel)
                        .onAppear {
                            Task {
                                bucketListViewModel.startListeningToItems()
                                guard let firebaseUser = Auth.auth().currentUser else {
                                    print("[BucketsApp] No authenticated user.")
                                    return
                                }

                                if onboardingViewModel.user == nil {
                                    onboardingViewModel.user = UserModel(
                                        id: firebaseUser.uid,
                                        email: firebaseUser.email ?? "unknown",
                                        createdAt: Date(),
                                        profileImageUrl: nil,
                                        name: nil,
                                        username: nil
                                    )
                                }

                                onboardingViewModel.user?.id = firebaseUser.uid
                                postViewModel.onboardingViewModel = onboardingViewModel

                                await onboardingViewModel.loadProfileImage()
                            }
                        }
                }
            }
        }
    }

    class AppDelegate: NSObject, UIApplicationDelegate {
        func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
        ) -> Bool {
            FirebaseApp.configure()

            if let options = FirebaseApp.app()?.options {
                print("Firebase configured with options: \(options)")
            } else {
                print("Failed to configure Firebase.")
            }

            let db = Firestore.firestore()
            let settings = db.settings
            let persistentCache = PersistentCacheSettings()
            settings.cacheSettings = persistentCache
            db.settings = settings

            return true
        }

        func applicationDidEnterBackground(_ application: UIApplication) {
            print("App entered background.")
        }

        func applicationWillEnterForeground(_ application: UIApplication) {
            print("App will enter foreground.")
        }
    }
}
