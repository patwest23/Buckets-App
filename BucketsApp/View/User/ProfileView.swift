//
//  ProfileView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/13/23.
//


import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var isImagePickerPresented = false
    @State private var selectedImageItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all) // Set the entire background to white

            VStack {
                // Profile Image Button
                Button(action: {
                    isImagePickerPresented = true
                }) {
                    if let imageData = viewModel.profileImageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: 4))
                            .shadow(radius: 10)
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $isImagePickerPresented) {
                    PhotosPicker(selection: $selectedImageItem, matching: .images, photoLibrary: .shared()) {}
                }
                .onChange(of: selectedImageItem) { newItem in
                    loadProfileImage(newItem)
                }

                // Account Settings List
                List {
                        navigationLinkButton("Update Email", destination: UpdateEmailView())
                        navigationLinkButton("Reset Password", destination: ResetPasswordView())
                        navigationLinkButton("Update Password", destination: UpdatePasswordView())

                        Button("Log Out", role: .destructive) {
                            viewModel.signOut()
                        }
                }
                .background(Color.white) // Ensure the list background is white
                .onAppear {
                    viewModel.checkIfUserIsAuthenticated()
                }
            }
            .padding()
        }
    }

    private func loadProfileImage(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        Task {
            do {
                if let data = try await newItem.loadTransferable(type: Data.self) {
                    viewModel.updateProfileImage(with: data)
                }
            } catch {
                print("Error loading image data: \(error)")
            }
        }
    }

    @ViewBuilder
    private func navigationLinkButton<T: View>(_ title: String, destination: T) -> some View {
        NavigationLink(destination: destination) {
            Text(title)
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(MockOnboardingViewModel())
    }
}









