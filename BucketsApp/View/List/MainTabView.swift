//
//  MainTabView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 11/30/24.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // List Tab
            NavigationStack {
                ListView()
            }
            .tabItem {
                Label("List", systemImage: "list.bullet")
            }

            // Profile Tab
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }

            // Settings Tab
//            NavigationStack {
//                SettingsView()
//            }
//            .tabItem {
//                Label("Settings", systemImage: "gearshape")
//            }
        }
    }
}
