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
    
    // Styling constants
    private let cardCornerRadius: CGFloat = 12
    private let cardShadowColor = Color.black.opacity(0.1)
    private let cardShadowRadius: CGFloat = 4
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // MARK: - Profile Image + Username
                profileHeader
                
                // MARK: - Stats Dashboard
                statsDashboard
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .navigationBarTitle("Profile", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Hide default nav title text
                EmptyView()
            }
            // Settings gear icon
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView()
                        .environmentObject(onboardingViewModel)
                        .environmentObject(userViewModel)
                } label: {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
    }
}

// MARK: - Subviews
extension ProfileView {
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Tappable profile image
            Button {
                isPickerPresented = true
            } label: {
                if let data = onboardingViewModel.profileImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 4)
                        )
                        .shadow(color: cardShadowColor, radius: 6, x: 0, y: 3)
                } else {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            // Photos picker for changing profile image
            .photosPicker(
                isPresented: $isPickerPresented,
                selection: $selectedImageItem,
                matching: .images
            )
            .onChange(of: selectedImageItem) { oldValue, newValue in
                loadProfileImage(newValue)
            }
            
            // Username or placeholder
            if let handle = onboardingViewModel.user?.username, !handle.isEmpty {
                Text(handle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            } else {
                Text("Username")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Stats Dashboard
    private var statsDashboard: some View {
        let totalCount = listViewModel.items.count
        let completedCount = listViewModel.items.filter { $0.completed }.count
        let incompleteCount = totalCount - completedCount
        
        // Most recent completion date
        let lastCompletedDate = listViewModel.items
            .filter { $0.completed }
            .compactMap { $0.dueDate ?? $0.creationDate }
            .max()
        
        // Days since last completion
        let daysSinceLastCompletion: Int = {
            guard let lastDate = lastCompletedDate else { return 0 }
            let components = Calendar.current.dateComponents([.day], from: lastDate, to: Date())
            return max(0, components.day ?? 0)
        }()
        
        return VStack(spacing: 20) {
            
            // Row: total, completed, incomplete
            HStack(spacing: 16) {
                statCard(emoji: "📦", title: "Total",
                         value: "\(totalCount)", color: .blue)
                statCard(emoji: "✅", title: "Completed",
                         value: "\(completedCount)", color: .green)
                statCard(emoji: "🚧", title: "Incomplete",
                         value: "\(incompleteCount)", color: .orange)
            }
            
            // If no completions yet, show message. Otherwise show "days since last complete."
            if completedCount == 0 {
                Text("No items completed yet!")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                HStack(spacing: 16) {
                    statCard(emoji: "⏰",
                             title: "Days Since Last Complete",
                             value: "\(daysSinceLastCompletion)",
                             color: .purple)
                }
            }
        }
        .padding()
        // "Card" style background
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: 2)
        )
    }
    
    // MARK: - Single Stat Card
    private func statCard(emoji: String,
                          title: String,
                          value: String,
                          color: Color) -> some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.largeTitle)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Private Helpers
extension ProfileView {
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








