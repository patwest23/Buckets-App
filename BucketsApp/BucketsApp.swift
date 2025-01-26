//
//  BucketsApp.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI
import Firebase
import FirebaseFirestore

@main
struct BucketsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject var bucketListViewModel = ListViewModel()
    @StateObject var onboardingViewModel = OnboardingViewModel()

    var body: some Scene {
        WindowGroup {
            if onboardingViewModel.isAuthenticated {
                // Show the ListView for authenticated users
                NavigationStack {
                    ListView()
                        .environmentObject(bucketListViewModel)
                        .environmentObject(onboardingViewModel)
                        .onAppear {
                            Task {
                                // Load profile image asynchronously after login
                                await onboardingViewModel.loadProfileImage()
                            }
                            print("Authenticated user: \(onboardingViewModel.email)")
                        }
                }
            } else {
                // Show the OnboardingView if the user isn't authenticated
                OnboardingView()
                    .environmentObject(onboardingViewModel)
                    .environmentObject(bucketListViewModel)
                    .onAppear {
                        print("Unauthenticated user loading onboarding")
                    }
            }
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 1) Configure Firebase
        FirebaseApp.configure()

        // 2) Print some info for debugging
        if let options = FirebaseApp.app()?.options {
            print("Firebase configured with options: \(options)")
        } else {
            print("Failed to configure Firebase.")
        }

        // 3) (Optional) Configure Firestore *once* here
        let db = Firestore.firestore()
        let settings = db.settings
        
        // Example of tweaking the cache
        let persistentCache = PersistentCacheSettings()
        // persistentCache.sizeBytes = 10_485_760 // for example, 10MB
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



