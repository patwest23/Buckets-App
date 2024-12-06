//
//  BucketsApp.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI
import Firebase

@main
struct BucketsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject var bucketListViewModel = ListViewModel()
    @StateObject var onboardingViewModel = OnboardingViewModel()

    var body: some Scene {
        WindowGroup {
            if onboardingViewModel.isAuthenticated {
                MainTabView()
                    .environmentObject(bucketListViewModel)
                    .environmentObject(onboardingViewModel)
                    .onAppear {
                        // Debugging logs
                        print("Authenticated user: \(onboardingViewModel.email)")
                    }
            } else {
                OnboardingView()
                    .environmentObject(onboardingViewModel)
                    .onAppear {
                        // Debugging logs
                        print("Unauthenticated user loading onboarding")
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
        print("Firebase configured successfully.")
        return true
    }
}




