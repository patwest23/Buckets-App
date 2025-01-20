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
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject var listViewModel: ListViewModel  // So we can access item counts

    // The boolean to show/hide the picker
    @State private var isPickerPresented = false
    @State private var selectedImageItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {

                // MARK: - Profile Image + Name
                Button(action: {
                    isPickerPresented = true
                }) {
                    if let imageData = onboardingViewModel.profileImageData,
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
                .buttonStyle(.plain)
                .photosPicker(
                    isPresented: $isPickerPresented,
                    selection: $selectedImageItem,
                    matching: .images
                )
                .onChange(of: selectedImageItem) { newItem in
                    loadProfileImage(newItem)
                }

                // User’s name below the profile image
                if let userName = onboardingViewModel.user?.name, !userName.isEmpty {
                    Text(userName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)  // Text color set to black
                } else {
                    Text("Username")
                        .font(.title2)
                        .foregroundColor(.gray)
                }

                // MARK: - Emoji-based Item Counts
                HStack(spacing: 60) {
                    VStack {
                        Text("🪣")
                            .font(.headline)
                        Text("x")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    VStack {
                        Text("✅")
                            .font(.headline)
                        Text("\(listViewModel.items.filter { $0.completed }.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    VStack {
                        Text("❌")
                            .font(.headline)
                        let completedCount = listViewModel.items.filter { $0.completed }.count
                        Text("\(listViewModel.items.count - completedCount)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, 8)

                // MARK: - Account Settings (with Emoji)
                VStack(spacing: 10) {
                    // Left-aligned links with emojis and no borders
                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink("✉️ Update Email", destination: UpdateEmailView())
                            .foregroundColor(.black)  // Set text color to black
                            .buttonStyle(PlainButtonStyle()) // Remove border
                        NavigationLink("🔑 Reset Password", destination: ResetPasswordView())
                            .foregroundColor(.black)  // Set text color to black
                            .buttonStyle(PlainButtonStyle()) // Remove border
                        NavigationLink("🔒 Update Password", destination: UpdatePasswordView())
                            .foregroundColor(.black)  // Set text color to black
                            .buttonStyle(PlainButtonStyle()) // Remove border
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .padding(.vertical, 8)

                    // Centered "Log Out" button with a door emoji 🚪
                    HStack {
                        Spacer()
                        Button("🚪 Log Out", role: .destructive) {
                            Task {
                                await onboardingViewModel.signOut()
                            }
                        }
                        .foregroundColor(.black)  // Set text color to black
                        Spacer()
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(radius: 2)
                .onAppear {
                    onboardingViewModel.checkIfUserIsAuthenticated()
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Optionally remove or replace nav bar title
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
        }
    }

    // MARK: - Load Profile Image
    private func loadProfileImage(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        Task {
            do {
                if let data = try await newItem.loadTransferable(type: Data.self) {
                    // Upload to Firebase Storage and update Firestore
                    await onboardingViewModel.updateProfileImage(with: data)
                }
            } catch {
                print("Error loading image data: \(error)")
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock environment objects
        let mockOnboardingVM = OnboardingViewModel()
        let mockListVM = ListViewModel()
        mockListVM.items = [
            ItemModel(userId: "abc", name: "Bucket 1", completed: false),
            ItemModel(userId: "abc", name: "Bucket 2", completed: true)
        ]

        return ProfileView()
            .environmentObject(mockOnboardingVM)
            .environmentObject(mockListVM)
    }
}









