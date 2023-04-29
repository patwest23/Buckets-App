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
        ZStack {

            VStack(spacing: 40) {
                Spacer()

                Text("Welcome to the rest of your life")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40.0)
                
                Text("Create, complete, and share your bucket list")
                    .font(.headline)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40.0)

                Image("Image1")
                    .resizable()
                    .frame(width: 100, height: 100)


                Spacer()

                Button(action: {
                    showSignUp.toggle()
                }) {
                    Text("Sign Up")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
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
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .shadow(radius: 10)
                }
                .sheet(isPresented: $showLogIn) {
                     LogInView()
                }

                NavigationLink(destination: ListView()) {
                    Text("Go to My List")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .shadow(radius: 10)
                }

                Spacer()
            }
        }
        .environmentObject(bucketListViewModel)
    }
}


struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
