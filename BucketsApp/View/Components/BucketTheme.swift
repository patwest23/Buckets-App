import SwiftUI

enum BucketTheme {
    static let primary = Color("AccentColor")
    static let secondary = Color("SecondaryAccentColor")
    static let playfulYellow = Color("AccentColor").opacity(0.2)
    static let playfulPurple = Color("SecondaryAccentColor").opacity(0.25)

    static let cornerRadius: CGFloat = 18
    static let smallRadius: CGFloat = 12
    static let lineWidth: CGFloat = 1.0

    static let smallSpacing: CGFloat = 8
    static let mediumSpacing: CGFloat = 16
    static let largeSpacing: CGFloat = 24

    static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let start = colorScheme == .dark
        ? Color.black
        : Color(UIColor.systemGroupedBackground)

        let accent = colorScheme == .dark
        ? primary.opacity(0.3)
        : primary.opacity(0.15)

        let playful = colorScheme == .dark
        ? secondary.opacity(0.2)
        : secondary.opacity(0.12)

        return LinearGradient(
            colors: [start, accent, playful, start],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func background(for colorScheme: ColorScheme) -> some View {
        backgroundGradient(for: colorScheme)
            .ignoresSafeArea()
    }

    static func surface(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.08)
        } else {
            return Color.white.opacity(0.92)
        }
    }

    static func elevatedSurface(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.12)
        } else {
            return Color.white
        }
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.25)
        } else {
            return primary.opacity(0.25)
        }
    }

    static func subtleText(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.7)
        } else {
            return Color.black.opacity(0.55)
        }
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.6) : primary.opacity(0.2)
    }
}

struct BucketBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(BucketTheme.background(for: colorScheme))
    }
}

struct BucketCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(BucketTheme.mediumSpacing)
            .background(BucketTheme.elevatedSurface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous)
                    .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
            )
            .shadow(color: BucketTheme.shadow(for: colorScheme), radius: 12, x: 0, y: 8)
    }
}

struct BucketTextField: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var systemImage: String?
    var emoji: String?

    func body(content: Content) -> some View {
        HStack(spacing: BucketTheme.smallSpacing) {
            if let emoji {
                Text(emoji)
                    .font(.title3)
            }

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BucketTheme.primary)
            }

            content
                .textFieldStyle(.plain)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, BucketTheme.mediumSpacing)
        .padding(.vertical, BucketTheme.smallSpacing + 4)
        .background(BucketTheme.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
        )
    }
}

struct BucketToolbarBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
    }
}

extension View {
    func bucketBackground() -> some View {
        modifier(BucketBackground())
    }

    func bucketCard() -> some View {
        modifier(BucketCard())
    }

    func bucketTextField(systemImage: String? = nil, emoji: String? = nil) -> some View {
        modifier(BucketTextField(systemImage: systemImage, emoji: emoji))
    }

    func bucketToolbarBackground() -> some View {
        modifier(BucketToolbarBackground())
    }
}

struct BucketPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, BucketTheme.mediumSpacing)
            .background(
                RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                BucketTheme.primary.opacity(colorScheme == .dark ? 0.8 : 1.0),
                                BucketTheme.secondary.opacity(colorScheme == .dark ? 0.7 : 0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous)
                    .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
            )
            .opacity(isEnabled ? 1 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct BucketSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, BucketTheme.mediumSpacing)
            .background(
                RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous)
                    .fill(BucketTheme.surface(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: BucketTheme.cornerRadius, style: .continuous)
                    .stroke(BucketTheme.primary.opacity(0.35), lineWidth: BucketTheme.lineWidth)
            )
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct BucketIconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                    .fill(BucketTheme.surface(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                    .stroke(BucketTheme.primary.opacity(0.3), lineWidth: BucketTheme.lineWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
