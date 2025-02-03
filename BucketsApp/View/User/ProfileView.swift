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
    @EnvironmentObject var userViewModel: UserViewModel  // For updating username
    
    @State private var isPickerPresented = false
    @State private var selectedImageItem: PhotosPickerItem?
    
    var body: some View {
        // ScrollView using systemBackground
        ScrollView {
            VStack(spacing: 30) {
                
                // MARK: - Profile Image + Name
                Button {
                    isPickerPresented = true
                } label: {
                    // If user has profile image => show it, else placeholder
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
                // PhotosPicker for changing profile image
                .photosPicker(
                    isPresented: $isPickerPresented,
                    selection: $selectedImageItem,
                    matching: .images
                )
                .onChange(of: selectedImageItem) { newItem in
                    loadProfileImage(newItem)
                }
                
                // User’s name
                if let userName = onboardingViewModel.user?.name, !userName.isEmpty {
                    Text(userName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    Text("Username")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                
                // If you have emoji-based item counts, place them here...
                // ...
                
                // MARK: - Account Settings
                VStack(spacing: 10) {
                    // a) Navigation links
                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink("📝 Update Username", destination: UpdateUserNameView())
                            .foregroundColor(.primary)
                            .buttonStyle(.plain)
                        
                        NavigationLink("✉️ Update Email", destination: UpdateEmailView())
                            .foregroundColor(.primary)
                            .buttonStyle(.plain)
                        
                        NavigationLink("🔑 Reset Password", destination: ResetPasswordView())
                            .foregroundColor(.primary)
                            .buttonStyle(.plain)
                        
                        NavigationLink("🔒 Update Password", destination: UpdatePasswordView())
                            .foregroundColor(.primary)
                            .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // b) Log Out button in the center
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
                // Hide default nav title
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








