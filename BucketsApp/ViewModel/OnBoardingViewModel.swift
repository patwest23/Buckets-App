//
//  OnBoardingViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/15/23.
//

import Foundation
import SwiftUI

class OnboardingViewModel: ObservableObject {
    @Published var showSignUp = false
    @Published var showLogIn = false
    @Published var showListView = false
    
    func signUp() {
        // handle sign up logic
        // if successful, set showListView = true
    }
    
    func logIn() {
        // handle log in logic
        // if successful, set showListView = true
    }
}

