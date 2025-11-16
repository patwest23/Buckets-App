import SwiftUI

struct ProfileAvatarView: View {
    let imageURL: URL?
    let placeholderSystemImage: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))

            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.accentColor)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
                .frame(width: size, height: size)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    private var placeholder: some View {
        Image(systemName: placeholderSystemImage)
            .resizable()
            .scaledToFit()
            .padding(size * 0.2)
            .foregroundColor(.accentColor)
    }
}

#Preview {
    VStack(spacing: 24) {
        ProfileAvatarView(
            imageURL: URL(string: "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=400&q=80"),
            placeholderSystemImage: "person.circle",
            size: 72
        )
        ProfileAvatarView(
            imageURL: nil,
            placeholderSystemImage: "person.circle.fill",
            size: 72
        )
    }
    .padding()
}
