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
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var postViewModel: PostViewModel

    let onboardingViewModel: OnboardingViewModel

    @State private var isPickerPresented = false
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var navigationPath = NavigationPath()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: BucketTheme.largeSpacing) {
                    profileHeader
                    statsDashboard
                }
                .padding(.horizontal, BucketTheme.mediumSpacing)
                .padding(.vertical, BucketTheme.largeSpacing)
            }
            .background { BucketTheme.backgroundGradient(for: colorScheme).ignoresSafeArea() }
            .bucketToolbarBackground()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(onboardingViewModel: onboardingViewModel)
                            .environmentObject(userViewModel)
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(BucketIconButtonStyle())
                }
            }
            .task {
                await postViewModel.loadPosts()
                await userViewModel.loadCurrentUser()
                await userViewModel.loadProfileImage()
            }
            .navigationDestination(isPresented: .constant(false)) {
                EmptyView()
            }
        }
    }
}

// MARK: - Subviews
extension ProfileView {
    private var profileHeader: some View {
        VStack(spacing: BucketTheme.mediumSpacing) {
            Button { isPickerPresented = true } label: {
                profileImage
            }
            .buttonStyle(.plain)
            .photosPicker(isPresented: $isPickerPresented, selection: $selectedImageItem, matching: .images)
            .onChange(of: selectedImageItem, initial: false) { _, newValue in
                loadProfileImage(newValue)
            }

            Text(displayName)
                .font(.title2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .bucketCard()
    }

    private var profileImage: some View {
        Group {
            if let data = userViewModel.profileImageData,
               !data.isEmpty,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let urlString = userViewModel.user?.profileImageUrl,
                      let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable()
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                    @unknown default:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
            }
        }
        .frame(width: 140, height: 140)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(BucketTheme.border(for: colorScheme), lineWidth: 2)
        )
        .shadow(color: BucketTheme.shadow(for: colorScheme), radius: 12, x: 0, y: 6)
    }

    private var displayName: String {
        if let username = userViewModel.user?.username, !username.isEmpty {
            return username
        }
        return userViewModel.user?.name ?? "@User"
    }

    private var statsDashboard: some View {
        let totalCount = listViewModel.items.count
        let completedCount = listViewModel.items.filter { $0.completed }.count
        let incompleteCount = totalCount - completedCount
        let lastCompletedDate = listViewModel.items
            .filter { $0.completed }
            .compactMap { $0.dueDate ?? $0.creationDate }
            .max()
        let daysSinceLastCompletion: Int = {
            guard let lastDate = lastCompletedDate else { return 0 }
            let components = Calendar.current.dateComponents([.day], from: lastDate, to: Date())
            return max(0, components.day ?? 0)
        }()
        let followingCount = (userViewModel.user?.following ?? []).count
        let followersCount = (userViewModel.user?.followers ?? []).count

        return VStack(spacing: BucketTheme.mediumSpacing) {
            HStack(spacing: BucketTheme.mediumSpacing) {
                statCard(emoji: "📦", title: "Total", value: totalCount)
                statCard(emoji: "✅", title: "Completed", value: completedCount)
                statCard(emoji: "🚧", title: "Incomplete", value: incompleteCount)
            }

            if completedCount == 0 {
                Text("No items completed yet! Keep going ✨")
                    .font(.callout)
                    .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
            } else {
                statCard(emoji: "⏰", title: "Days Since Complete", value: daysSinceLastCompletion)
            }

            NavigationLink(destination: FriendsView()) {
                HStack(spacing: BucketTheme.mediumSpacing) {
                    statCard(emoji: "👫", title: "Friends", value: followingCount + followersCount)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .bucketCard()
    }

    private func statCard(emoji: String, title: String, value: Int) -> some View {
        VStack(spacing: BucketTheme.smallSpacing) {
            Text(emoji)
                .font(.title2)
            Text("\(value)")
                .font(.title3.weight(.bold))
            Text(title)
                .font(.footnote)
                .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BucketTheme.mediumSpacing)
        .background(
            RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                .fill(BucketTheme.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
        )
    }
}

extension ProfileView {
    private func loadProfileImage(_ newItem: PhotosPickerItem?) {
        guard let newItem else { return }
        Task {
            do {
                if let data = try await newItem.loadTransferable(type: Data.self) {
                    await userViewModel.updateProfileImage(with: data)
                }
            } catch {
                print("Error loading image data: \(error)")
            }
        }
    }
}
