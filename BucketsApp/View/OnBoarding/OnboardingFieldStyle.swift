import SwiftUI

private struct OnboardingFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

extension View {
    func onboardingFieldStyle() -> some View {
        modifier(OnboardingFieldStyle())
    }
}
