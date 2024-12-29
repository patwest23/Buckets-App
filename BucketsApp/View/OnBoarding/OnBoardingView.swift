//
//  OnBoardingView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/9/23.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var showSignUp = false
    @State private var showLogIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 40) {
                    Spacer()

                    // App Icon or Logo
                    Image("Image2")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 120, maxHeight: 120)
                        .shadow(radius: 5)

                    Spacer()

                    // Main Title
                    Text("What do you want to do before you die?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40.0)

                    Spacer()

                    // Buttons for Sign Up and Log In
                    HStack(spacing: 20) {
                        Button(action: {
                            showSignUp.toggle()
                        }) {
                            Text("Sign Up")
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .sheet(isPresented: $showSignUp) {
                            SignUpView()
                                .environmentObject(onboardingViewModel) // Pass environment object
                        }

                        Button(action: {
                            showLogIn.toggle()
                        }) {
                            Text("Log In")
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .sheet(isPresented: $showLogIn) {
                            LogInView()
                                .environmentObject(onboardingViewModel) // Pass environment object
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(OnboardingViewModel()) // Use mock or real view model for preview
    }
}
