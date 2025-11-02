import SwiftUI
import PhotosUI
import UIKit

struct DetailItemPhotosSubview: View {
    @ObservedObject var imagePickerViewModel: ImagePickerViewModel
    let isCompleted: Bool
    let imageUrls: [String]

    var body: some View {
        DetailSectionCard(title: "Photos", systemImage: "photo.on.rectangle") {
            VStack(alignment: .leading, spacing: 12) {
                PhotosPicker(
                    selection: $imagePickerViewModel.imageSelections,
                    maxSelectionCount: 3,
                    matching: .images
                ) {
                    HStack {
                        Label("Select Photos", systemImage: "plus")
                            .labelStyle(.titleAndIcon)
                        Spacer()
                        if hasImages {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.body)
                }
                .disabled(!isCompleted)
                .opacity(isCompleted ? 1 : 0.4)

                if !isCompleted {
                    Text("Mark as completed to attach photos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if hasImages {
                    photoGridRow
                }
            }
        }
    }

    private var hasImages: Bool {
        !imagePickerViewModel.uiImages.isEmpty || !imageUrls.isEmpty
    }

    @ViewBuilder
    private var photoGridRow: some View {
        if !imagePickerViewModel.uiImages.isEmpty {
            photoGrid(uiImages: imagePickerViewModel.uiImages)
        } else if !imageUrls.isEmpty {
            photoGrid(urlStrings: imageUrls)
        }
    }

    private func photoGrid(uiImages: [UIImage]) -> some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
            ForEach(uiImages, id: \.self) { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .cornerRadius(6)
                    .clipped()
            }
        }
    }

    private func photoGrid(urlStrings: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
            ForEach(urlStrings, id: \.self) { urlStr in
                if let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .cornerRadius(6)
                                .clipped()
                        default:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
}
