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
            // Decide which view to show based on whether the user is authenticated
            if onboardingViewModel.isAuthenticated {
                NavigationView {
                    ListView()
                }
                .environmentObject(bucketListViewModel)
            } else {
                OnboardingView()
                    .environmentObject(onboardingViewModel)
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("configure firebase check")
        return true
    }
}



