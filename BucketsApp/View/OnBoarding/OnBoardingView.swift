//
//  OnBoardingView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/9/23.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject var bucketListViewModel = ListViewModel()
    @State private var showSignUp = false
    @State private var showLogIn = false

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 40) {
                    Spacer()

                    Image("Image2")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 100, maxHeight: 100)
                    
                    Spacer()
                    
                    Text("What do you want to do before you die?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40.0)

                    Spacer()

                    HStack(spacing: 20) {
                        Button(action: {
                            showSignUp.toggle()
                        }) {
                            Text("Sign Up")
                                .fontWeight(.bold)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 10)
                        }
                        .sheet(isPresented: $showSignUp) {
                            SignUpView()
                        }

                        Button(action: {
                            showLogIn.toggle()
                        }) {
                            Text("Log In")
                                .fontWeight(.bold)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 10)
                        }
                        .sheet(isPresented: $showLogIn) {
                            LogInView()
                        }
                    }

                    NavigationLink(destination: ListView().environmentObject(bucketListViewModel)) {
                        Text("Go to My List")
                            .fontWeight(.bold)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 10)
                    }

                    Spacer()
                }
            }
            .environmentObject(bucketListViewModel)
        }
    }
}


struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
