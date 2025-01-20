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

                    // App Icon or Logo
                    Image("Image2")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 60, maxHeight: 60)
                        .padding()

                    Spacer()
                    
                    // Main Title
                    Text("What do you want to do before you die?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40.0)

                    Spacer()

                    // Buttons for Sign Up and Log In
                    VStack(spacing: 20) {
                        Button(action: {
                            showSignUp.toggle()
                        }) {
                            Text("✍️ Sign Up")
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.white)
                                .foregroundColor(.black)
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
                            Text("🪵 Log In")
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.white)
                                .foregroundColor(.black)
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
            .background(Color.white)  // Ensure background is consistent
        }
        .navigationBarHidden(true)  // Hide navigation bar for a cleaner look
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(OnboardingViewModel()) // Use mock or real view model for preview
    }
}
