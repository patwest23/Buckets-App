//
//  ProfileView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 5/13/23.
//


import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var isImagePickerPresented = false
    @State private var selectedImageItem: PhotosPickerItem?

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    // Profile Image Button
                    Button(action: {
                        isImagePickerPresented = true
                    }) {
                        if let imageData = viewModel.profileImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
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
                        PhotosPicker(
                            "Select a Profile Picture",
                            selection: $selectedImageItem,
                            matching: .images
                        )
                    }
                    .onChange(of: selectedImageItem) { newItem in
                        loadProfileImage(newItem)
                    }

                    // Account Settings
                    List {
                        NavigationLink("Update Email", destination: UpdateEmailView())
                        NavigationLink("Reset Password", destination: ResetPasswordView())
                        NavigationLink("Update Password", destination: UpdatePasswordView())

                        Button("Log Out", role: .destructive) {
                            Task {
                                await viewModel.signOut()
                            }
                        }
                    }
                    .listStyle(GroupedListStyle())
                    .onAppear {
                        viewModel.checkIfUserIsAuthenticated()
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }

    // MARK: - Load Profile Image (local only)
    private func loadProfileImage(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        Task {
            do {
                if let data = try await newItem.loadTransferable(type: Data.self) {
                    // Upload to Firebase Storage and update Firestore
                    await viewModel.updateProfileImage(with: data)
                }
            } catch {
                print("Error loading image data: \(error)")
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(MockOnboardingViewModel()) // Using mock view model for preview
    }
}









