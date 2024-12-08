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
            Color.white.edgesIgnoringSafeArea(.all) // Set background to white

            VStack(spacing: 20) {
                // Profile Image Button
                Button(action: {
                    isImagePickerPresented = true
                }) {
                    if let imageData = viewModel.profileImageData,
                       let image = UIImage(data: imageData) {
                        Image(uiImage: cropToCircle(image: image))
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
                    loadAndCropProfileImage(newItem)
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
                .onAppear {
                    viewModel.checkIfUserIsAuthenticated()
                }
            }
            .padding()
        }
    }

    /// Load and crop the selected image into a circular shape
    private func loadAndCropProfileImage(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        Task {
            do {
                if let data = try await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    // Crop to circle and update the profile image
                    let croppedImage = cropToCircle(image: image)
                    if let croppedData = croppedImage.jpegData(compressionQuality: 1.0) {
                        viewModel.updateProfileImage(with: croppedData)
                    }
                }
            } catch {
                print("Error loading image data: \(error)")
            }
        }
    }

    /// Crop the image to a circular shape
    private func cropToCircle(image: UIImage) -> UIImage {
        let squareImage = cropToSquare(image: image) // Crop to square first
        let size = squareImage.size

        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let rect = CGRect(origin: .zero, size: size)

        // Clip the context to a circle
        UIBezierPath(ovalIn: rect).addClip()
        squareImage.draw(in: rect)

        let circularImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return circularImage ?? squareImage
    }

    /// Crop the image to a square shape
    private func cropToSquare(image: UIImage) -> UIImage {
        let size = min(image.size.width, image.size.height)
        let originX = (image.size.width - size) / 2
        let originY = (image.size.height - size) / 2
        let cropRect = CGRect(x: originX, y: originY, width: size, height: size)

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
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









