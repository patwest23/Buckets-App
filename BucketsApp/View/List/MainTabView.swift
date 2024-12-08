//
//  MainTabView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 11/30/24.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject var listViewModel: ListViewModel

    var body: some View {
        TabView {
            // List Tab
            NavigationStack {
                ListView()
                    .environmentObject(listViewModel) // Attach ListViewModel to ListView
            }
            .tabItem {
                Label("List", systemImage: "list.bullet")
            }

            // Profile Tab
            NavigationStack {
                ProfileView()
                    .environmentObject(onboardingViewModel) // Attach OnboardingViewModel to ProfileView
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
    }
}
