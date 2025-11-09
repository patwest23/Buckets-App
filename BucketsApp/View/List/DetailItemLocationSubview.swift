import SwiftUI

struct DetailItemLocationSubview: View {
    @Binding var locationText: String
    let focusBinding: FocusState<DetailItemField?>.Binding
    let suggestions: [LocationSuggestion]
    let isShowingSuggestions: Bool
    let onLocationChange: (String) -> Void
    let onSuggestionTapped: (LocationSuggestion) -> Void
    let onSubmit: () -> Void

    var body: some View {
        DetailSectionCard(title: "Location", systemImage: "mappin.and.ellipse") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter a location", text: $locationText)
                    .focused(focusBinding, equals: .location)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
                    .textContentType(.fullStreetAddress)
                    .submitLabel(.done)
                    .onSubmit(onSubmit)
                    .onChange(of: locationText, initial: false) { _, newValue in
                        onLocationChange(newValue)
                    }
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .systemBackground))
                    )

                if shouldShowSuggestions {
                    suggestionList
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

private extension DetailItemLocationSubview {
    var shouldShowSuggestions: Bool {
        isShowingSuggestions && focusBinding.wrappedValue == .location && !suggestions.isEmpty
    }

    var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button {
                    onSuggestionTapped(suggestion)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title.isEmpty ? suggestion.displayText : suggestion.title)
                            .font(.body)
                            .foregroundColor(.primary)

                        if !suggestion.subtitle.isEmpty && suggestion.title != suggestion.subtitle {
                            Text(suggestion.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)

                if suggestion.id != suggestions.last?.id {
                    Divider()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.2))
        )
    }
}
