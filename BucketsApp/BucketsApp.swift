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
    @StateObject var userViewModel = UserViewModel()

    var body: some Scene {
        WindowGroup {
            if onboardingViewModel.isAuthenticated {
                NavigationStack {
                    ListView()
                        .environmentObject(bucketListViewModel)
                        .environmentObject(onboardingViewModel)
                        .environmentObject(userViewModel)
                        .onAppear {
                            Task {
                                // Load profile image asynchronously after successful login
                                await onboardingViewModel.loadProfileImage()
                            }
                        }
                }
            } else {
                OnboardingView()
                    .environmentObject(onboardingViewModel)
                    .environmentObject(bucketListViewModel)
                    .environmentObject(userViewModel)
                    .onAppear {
                        // Could add any additional logic for unauthenticated state here
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
        FirebaseApp.configure()
        
        if let options = FirebaseApp.app()?.options {
            print("Firebase configured with options: \(options)")
        } else {
            print("Failed to configure Firebase.")
        }

        // Optional Firestore configuration
        let db = Firestore.firestore()
        let settings = db.settings
        
        // Example of customizing cache size
        let persistentCache = PersistentCacheSettings()
        // persistentCache.sizeBytes = 10_485_760 // For example, 10MB
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



