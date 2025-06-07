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
    @State private var showUsernameSetup = false
    
    // Detect whether we’re in Light or Dark mode
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 40) {
                    
                    // MARK: - App Icon or Logo
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 60, maxHeight: 60)
                        .foregroundColor(.accentColor)
                        .padding()
                    
                    Spacer()
                    
                    // MARK: - Main Title
                    Text("What do you want to do before you die?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary) // adapt to Light/Dark
                        .padding(.horizontal, 40.0)
                    
                    Spacer()
                    
                    // MARK: - Buttons (Sign Up & Log In)
                    VStack(spacing: 20) {
                        
                        // Sign Up Button
                        Button(action: {
                            showSignUp.toggle()
                        }) {
                            Text("✍️ Sign Up")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                // Condition: White in light mode, .secondarySystemBackground in dark mode
                                .background(buttonBackgroundColor)
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .sheet(isPresented: $showSignUp) {
                            SignUpView()
                                .environmentObject(onboardingViewModel)
                        }
                        
                        // Log In Button
                        Button(action: {
                            showLogIn.toggle()
                        }) {
                            Text("🪵 Log In")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                // Same dynamic background
                                .background(buttonBackgroundColor)
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .sheet(isPresented: $showLogIn) {
                            LogInView()
                                .environmentObject(onboardingViewModel)
                        }
                        
                        // MARK: - Google Sign-In Button
                        Button(action: {
                            onboardingViewModel.signInWithGoogle(completion: { success in
                                if success && onboardingViewModel.username.isEmpty {
                                    showUsernameSetup = true
                                }
                            })
                        }) {
                            HStack {
                                Image("google_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)

                                Text("Sign in with Google")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(buttonBackgroundColor)
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        }
                        .sheet(isPresented: $showUsernameSetup) {
                            UsernameSetupView()
                                .environmentObject(onboardingViewModel)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
            // Overall background color adapts to Light/Dark
            .background(Color(uiColor: .systemBackground))
            .navigationBarHidden(true)
        }
    }
    
    /// Computed property to pick the button background color:
    /// White in Light Mode, .secondarySystemBackground in Dark Mode
    private var buttonBackgroundColor: Color {
        colorScheme == .dark
        ? Color(uiColor: .secondarySystemBackground)
        : Color.white
    }
}

// MARK: - Preview
#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = OnboardingViewModel()

        return Group {
            // Light Mode
            NavigationStack {
                OnboardingView()
                    .environmentObject(mockViewModel)
            }
            .previewDisplayName("OnboardingView - Light Mode")

            // Dark Mode
            NavigationStack {
                OnboardingView()
                    .environmentObject(mockViewModel)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("OnboardingView - Dark Mode")
        }
    }
}
#endif
