//
//  ProfilePostEditView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/4/25.
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseAuth

struct ProfilePostEditView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var post: PostModel
    @State private var caption: String
    @StateObject private var imagePickerVM = ImagePickerViewModel()
    @State private var showDeleteAlert = false

    init(post: PostModel) {
        _post = State(initialValue: post)
        _caption = State(initialValue: post.caption ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Editable caption field
                TextField("Edit caption...", text: $caption)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                // Photo picker
                photoPickerView

                // Image grid
                if !post.itemImageUrls.isEmpty {
                    photoGridRow
                }

                // Save changes
                Button("💾 Save Changes") {
                    Task {
                        post.caption = caption
                        await postViewModel.addOrUpdatePost(post: post)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)

                // Delete
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text("🗑️ Delete Post")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .alert("Are you sure?", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        Task {
                            await postViewModel.deletePost(post)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            .padding()
        }
        .navigationTitle("Edit Post")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            imagePickerVM.onImagesLoaded = {
                Task {
                    let uploadedUrls = await imagePickerVM.uploadImages(
                        userId: userViewModel.user?.id ?? "",
                        itemId: post.itemId
                    )
                    post.itemImageUrls = uploadedUrls
                    print("✅ Updated post with image URLs:", post.itemImageUrls)
                    await postViewModel.addOrUpdatePost(post: post)
                }
            }
        }
    }

    private var photoPickerView: some View {
        let isUploading = imagePickerVM.isUploading
        return PhotosPicker(
            selection: $imagePickerVM.selectedItems,
            maxSelectionCount: 3,
            matching: .images
        ) {
            HStack {
                Text("📸 Add Photos")
                if isUploading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .disabled(isUploading)
    }

    private var photoGridRow: some View {
        let urls = post.itemImageUrls
        let imageSize: CGFloat = (UIScreen.main.bounds.width - 64) / 3
        return HStack(spacing: 8) {
            ForEach(urls, id: \.self) { urlStr in
                if let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: imageSize, height: imageSize)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: imageSize, height: imageSize)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .clipped()
                        default:
                            EmptyView()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfilePostEditView(post: .mockData.first!)
        .environmentObject(UserViewModel())
        .environmentObject(PostViewModel())
}
