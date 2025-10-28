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
            VStack(alignment: .leading, spacing: 32) {
                header

                VStack(spacing: 20) {
                    profileHeader
                    profileMeta
                }
                .padding(24)
                .background(cardBackground)
                .overlay(cardBorder)

                statsDashboard
            }
            .padding(28)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your profile")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Update your avatar and keep an eye on how your bucket list is progressing.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 18) {
            // Tappable profile image
            Button {
                isPickerPresented = true
            } label: {
                if let data = onboardingViewModel.profileImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 3)
                        )
                        .shadow(color: cardShadowColor, radius: 6, x: 0, y: 3)
                } else {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            // Photos picker for changing profile image
            .photosPicker(
                isPresented: $isPickerPresented,
                selection: $selectedImageItem,
                matching: .images
            )
            .onChange(of: selectedImageItem, initial: false) { _, newValue in
                loadProfileImage(newValue)
            }
            
            // Username or placeholder
            Group {
                if let handle = onboardingViewModel.user?.username, !handle.isEmpty {
                    Text(handle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    Text("Username")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Username")
        }
    }

    private var profileMeta: some View {
        VStack(spacing: 8) {
            if let email = onboardingViewModel.user?.email {
                labeledDetail(title: "Email", value: email)
            }

            if let memberSince = onboardingViewModel.user?.createdAt {
                let formatted = DateFormatter.localizedString(from: memberSince, dateStyle: .medium, timeStyle: .none)
                labeledDetail(title: "Member since", value: formatted)
            }

            Button(action: { isPickerPresented = true }) {
                Text("Update profile photo")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
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
        
        return VStack(alignment: .leading, spacing: 20) {
            Text("Bucket list snapshot")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    metricBlock(title: "Total", value: totalCount)

                    divider

                    metricBlock(title: "Completed", value: completedCount)

                    divider

                    metricBlock(title: "Open", value: incompleteCount)
                }

                divider

                if completedCount == 0 {
                    Text("No items completed yet")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    VStack(spacing: 4) {
                        Text("Days since last completion")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Text("\(daysSinceLastCompletion)")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
            .background(cardBackground)
            .overlay(cardBorder)
        }
    }

    private func metricBlock(title: String, value: Int) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)

            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .kerning(1.2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(width: 1)
    }

    private func labeledDetail(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer(minLength: 16)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(Color(.systemGray4), lineWidth: 1)
    }
}

// MARK: - Private Helpers
extension ProfileView {
    private func loadProfileImage(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        Task { @MainActor in
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








