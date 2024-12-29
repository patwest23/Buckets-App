//
//  BucketsApp.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

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
                        Task {
                            // Load profile image asynchronously after login
                            do {
                                await onboardingViewModel.loadProfileImage()
                            } catch {
                                print("Failed to load profile image: \(error)")
                            }
                        }
                        print("Authenticated user: \(onboardingViewModel.email)")
                    }
            } else {
                OnboardingView()
                    .environmentObject(onboardingViewModel)
                    .onAppear {
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
        if let options = FirebaseApp.app()?.options {
            print("Firebase configured with options: \(options)")
        } else {
            print("Failed to configure Firebase.")
        }
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("App entered background.")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("App will enter foreground.")
    }
}




