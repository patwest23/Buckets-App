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
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    
    @State private var isPickerPresented = false
    @State private var selectedImageItem: PhotosPickerItem?
    
    // Each sheet has its own boolean
    @State private var showUsernameSheet = false
    @State private var showEmailSheet = false
    @State private var showResetPasswordSheet = false
    @State private var showUpdatePasswordSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                
                // MARK: - Profile Image + Name
                Button {
                    isPickerPresented = true
                } label: {
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
                
                // Display the user’s username or fallback placeholder
                if let userName = onboardingViewModel.user?.username, !userName.isEmpty {
                    Text(userName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    Text("Username")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                
                // MARK: - Account Settings
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 12) {
                        
                        // 1) "Update Username" => sheet
                        Button("📝 Update Username") {
                            showUsernameSheet = true
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.primary)
                        .sheet(isPresented: $showUsernameSheet) {
                            UpdateUserNameView()
                                .environmentObject(userViewModel)
                        }
                        
                        // 2) "Update Email" => sheet
                        Button("✉️ Update Email") {
                            showEmailSheet = true
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.primary)
                        .sheet(isPresented: $showEmailSheet) {
                            UpdateEmailView()
                                .environmentObject(onboardingViewModel)
                        }
                        
                        // 3) "Reset Password" => sheet
                        Button("🔑 Reset Password") {
                            showResetPasswordSheet = true
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.primary)
                        .sheet(isPresented: $showResetPasswordSheet) {
                            ResetPasswordView()
                                .environmentObject(onboardingViewModel)
                        }
                        
                        // 4) "Update Password" => sheet
                        Button("🔒 Update Password") {
                            showUpdatePasswordSheet = true
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.primary)
                        .sheet(isPresented: $showUpdatePasswordSheet) {
                            UpdatePasswordView()
                                .environmentObject(onboardingViewModel)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // b) Log Out button
                    HStack {
                        Spacer()
                        Button("🚪 Log Out", role: .destructive) {
                            Task {
                                await onboardingViewModel.signOut()
                            }
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .fontWeight(.bold)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(uiColor: .systemBackground))
                .onAppear {
                    onboardingViewModel.checkIfUserIsAuthenticated()
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView() // Hide default nav title
            }
        }
    }
    
    // MARK: - Load Profile Image
    private func loadProfileImage(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        Task {
            do {
                if let data = try await newItem.loadTransferable(type: Data.self) {
                    await onboardingViewModel.updateProfileImage(with: data)
                }
            } catch {
                print("Error loading image data: \(error)")
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let mockOnboardingVM = OnboardingViewModel()
        let mockListVM = ListViewModel()
        let mockUserVM = UserViewModel()
        
        mockListVM.items = [
            ItemModel(userId: "abc", name: "Bucket 1", completed: false),
            ItemModel(userId: "abc", name: "Bucket 2", completed: true)
        ]
        
        return Group {
            // Light Mode
            NavigationView {
                ProfileView()
                    .environmentObject(mockOnboardingVM)
                    .environmentObject(mockListVM)
                    .environmentObject(mockUserVM)
            }
            .previewDisplayName("ProfileView - Light Mode")
            
            // Dark Mode
            NavigationView {
                ProfileView()
                    .environmentObject(mockOnboardingVM)
                    .environmentObject(mockListVM)
                    .environmentObject(mockUserVM)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("ProfileView - Dark Mode")
        }
    }
}
#endif








