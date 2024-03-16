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
        NavigationView {
            VStack {
                // Profile Image Button
                Button(action: {
                    isImagePickerPresented = true
                }) {
                    profileImageButton
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $isImagePickerPresented) {
                    PhotosPicker(selection: $selectedImageItem, matching: .images, photoLibrary: .shared()) {}
                }
                .onChange(of: selectedImageItem) { newItem in
                    loadProfileImage(newItem)
                }

                // Rest of your view content...
                List {
                    Section(header: Text("Account Settings")) {
                        navigationLinkButton("Update Email", destination: UpdateEmailView())
                        navigationLinkButton("Reset Password", destination: ResetPasswordView())
                        navigationLinkButton("Update Password", destination: UpdatePasswordView())

                        Button("Log Out", role: .destructive) {
                            viewModel.signOut()
                        }
                    }
                }
                .listStyle(GroupedListStyle())
                .onAppear {
                    viewModel.checkIfUserIsAuthenticated()
                }
            }
        }
        .environmentObject(viewModel) // Provide the environment object here
    }

    private var profileImageButton: some View {
        if let imageData = viewModel.profileImageData, let image = UIImage(data: imageData) {
            return AnyView(
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 4))
                    .shadow(radius: 10)
            )
        } else {
            return AnyView(
                Image(systemName: "person.crop.circle.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundColor(.gray)
            )
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
        ProfileView().environmentObject(OnboardingViewModel())
    }
}











