//
//  BucketsApp.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/8/23.
//

import SwiftUI

@main
struct BucketsApp: App {
    @StateObject var bucketListViewModel = ListViewModel()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ListView()
            }
            .environmentObject(bucketListViewModel)
        }
    }
}


