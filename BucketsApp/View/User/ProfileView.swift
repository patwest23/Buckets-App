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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                
                // MARK: - Profile Image + Username
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
                
                // Show username if set
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
                
                // MARK: - Stats Dashboard
                statsDashboard
                
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground))
        
        // MARK: - Navigation Bar
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView() // Hide default nav title
            }
            // Gear icon that pushes SettingsView
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

// MARK: - Stats Dashboard
extension ProfileView {
    
    private var statsDashboard: some View {
        let totalCount = listViewModel.items.count
        let completedCount = listViewModel.items.filter { $0.completed }.count
        let incompleteCount = totalCount - completedCount
        
        // Find the most recent completed date
        let lastCompletedDate = listViewModel.items
            .filter { $0.completed }
            .compactMap { $0.dueDate ?? $0.creationDate }
            .max()
        
        // Calculate days since last completed item
        // e.g. if user completed something 3 days ago => 3
        let daysSinceLastCompletion: Int = {
            guard let lastDate = lastCompletedDate else { return 0 }
            let components = Calendar.current.dateComponents([.day], from: lastDate, to: Date())
            return max(0, components.day ?? 0)
        }()
        
        return VStack(spacing: 20) {
            
            // Row of 3 stats: total, completed, incomplete
            HStack(spacing: 16) {
                statCard(
                    emoji: "📦",
                    title: "Total",
                    value: "\(totalCount)",
                    color: .blue
                )
                statCard(
                    emoji: "✅",
                    title: "Completed",
                    value: "\(completedCount)",
                    color: .green
                )
                statCard(
                    emoji: "🚧",
                    title: "Incomplete",
                    value: "\(incompleteCount)",
                    color: .orange
                )
            }
            
            // If no completions => show "No items completed yet!"
            if completedCount == 0 {
                Text("No items completed yet!")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                // Show a new row with "Days since last completed"
                HStack(spacing: 16) {
                    statCard(
                        emoji: "⏰",
                        title: "Days Since Last Complete",
                        value: "\(daysSinceLastCompletion)",
                        color: .purple
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
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
        .background(color.opacity(0.15))
        .cornerRadius(8)
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








