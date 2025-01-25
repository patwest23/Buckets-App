//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI

struct ListView: View {
    @EnvironmentObject var viewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel

    @State private var newItem = ItemModel(userId: "", name: "")
    @State private var isAddingNewItem = false
    @State private var isLoading = true
    @State private var showProfileView = false // Controls navigation to ProfileView

    var body: some View {
        NavigationStack {
            ZStack {
                contentView

                addButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .navigationTitle("Bucket List")
            .navigationBarTitleDisplayMode(.large)
            // MARK: - Add custom toolbar items
            .toolbar {
                // User name on the left side
                ToolbarItem(placement: .navigationBarLeading) {
                    if let user = onboardingViewModel.user {
                        Text(user.name ?? "Unknown")
                            .font(.headline)
                    } else {
                        Text("No Name")
                            .font(.headline)
                    }
                }
                // Profile image button on the right side
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Navigate to ProfileView
                        showProfileView = true
                    } label: {
                        profileImageView
                    }
                }
            }
            .onAppear { loadItems() }
            .navigationDestination(isPresented: $isAddingNewItem) {
                DetailItemView(item: $newItem)
                    .onDisappear { handleNewItemSave() }
            }
            // Present ProfileView when showProfileView is true
            .navigationDestination(isPresented: $showProfileView) {
                ProfileView()
                    .environmentObject(onboardingViewModel)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingView
        } else if viewModel.items.isEmpty {
            emptyStateView
        } else {
            itemListView
        }
    }

    private var loadingView: some View {
        ProgressView("")
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(1.5)
            .padding()
    }

    private var emptyStateView: some View {
        Text("No items yet. Tap + to add a new item.")
            .foregroundColor(.gray)
            .font(.headline)
            .multilineTextAlignment(.center)
            .padding()
    }

    private var itemListView: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(viewModel.items, id: \.id) { item in
                    navigationLink(for: item)
                }
            }
            .padding()
        }
    }

    // Profile image in the top-right corner
    private var profileImageView: some View {
        if let data = onboardingViewModel.profileImageData,
           let uiImage = UIImage(data: data) {
            AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            )
        } else {
            AnyView(
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .foregroundColor(.gray)
            )
        }
    }

    // MARK: - NavigationLink for each item
    private func navigationLink(for item: ItemModel) -> some View {
        NavigationLink(
            destination: DetailItemView(
                item: Binding(
                    get: { viewModel.items.first { $0.id == item.id } ?? item },
                    set: { updatedItem in handleItemUpdate(updatedItem) }
                )
            )
        ) {
            ItemRowView(item: item, isEditing: .constant(false))
        }
    }

    // MARK: - Add button
    private var addButton: some View {
        Button(action: {
            newItem = ItemModel(userId: "", name: "")
            isAddingNewItem = true
        }) {
            ZStack {
                Circle()
                    .frame(width: 60, height: 60)
                    .foregroundColor(Color.accentColor)
                    .shadow(color: .gray, radius: 10, x: 0, y: 5)

                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .font(.system(size: 30, weight: .bold))
            }
        }
        .padding()
    }

    // MARK: - Helper Functions

    private func loadItems() {
        Task {
            if let userId = onboardingViewModel.user?.id {
                isLoading = true
                do {
                    // If your ListViewModel.loadItems is 'async throws',
                    // you can do:
                    try await viewModel.loadItems(userId: userId)
                } catch {
                    print("ListView: loadItems() error => \(error.localizedDescription)")
                }
                isLoading = false
            }
        }
    }

    private func handleItemUpdate(_ updatedItem: ItemModel) {
        Task {
            if let userId = onboardingViewModel.user?.id {
                await viewModel.addOrUpdateItem(updatedItem, userId: userId)
            }
        }
    }

    private func handleNewItemSave() {
        Task {
            if let userId = onboardingViewModel.user?.id {
                if !newItem.name.isEmpty {
                    await viewModel.addOrUpdateItem(newItem, userId: userId)
                }
                newItem = ItemModel(userId: "", name: "")
            }
        }
    }
}

struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        // 1) Create sample environment objects
        let sampleListVM = ListViewModel()
        let sampleOnboardingVM = OnboardingViewModel()

        // 2) Populate the ListViewModel with a few items
        sampleListVM.items = [
            ItemModel(
                userId: "testUser1",
                name: "Sample Bucket List Item 1",
                description: "This is a preview description for item 1.",
                creationDate: Date().addingTimeInterval(-86400) // 1 day ago
            ),
            ItemModel(
                userId: "testUser2",
                name: "Sample Bucket List Item 2",
                description: "A second item to show in the preview.",
                completed: true,
                creationDate: Date()
            )
        ]

        // 3) Populate the OnboardingViewModel with a mock user
        sampleOnboardingVM.user = UserModel(
            id: "testUser1",
            email: "sample@example.com",
            createdAt: Date(),
            profileImageUrl: nil,
            name: "@pwesterkamp"
        )

        // 4) (Optional) Provide some placeholder profile image data
        // If you have a local image in your Assets, you can do:
        /*
        if let uiImage = UIImage(named: "ProfilePlaceholder"),
           let data = uiImage.jpegData(compressionQuality: 1.0) {
            sampleOnboardingVM.profileImageData = data
        }
        */

        // 5) Return the `ListView` in the preview
        return ListView()
            .environmentObject(sampleListVM)
            .environmentObject(sampleOnboardingVM)
            // You can add .previewDisplayName(...) to label the preview
    }
}

