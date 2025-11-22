import SwiftUI

struct DetailItemWithSubview: View {
    @Binding var usernames: [String]
    @Binding var inputText: String

    let maxUserCount: Int
    let suggestions: [String]
    let isShowingSuggestions: Bool
    let onTextChange: (String) -> Void
    let onAddUsername: (String) -> Void
    let onRemoveUsername: (String) -> Void

    @FocusState private var isFocused: Bool
    @State private var isDeleteMode = false

    private var hasRoomForMore: Bool {
        usernames.count < maxUserCount
    }

    var body: some View {
        DetailSectionCard(title: "With", systemImage: "person.2") {
            VStack(alignment: .leading, spacing: 14) {
                instructionRow

                usernameChips

                if hasRoomForMore {
                    inputField
                }

                if isShowingSuggestions && !suggestions.isEmpty && hasRoomForMore {
                    suggestionList
                }
            }
        }
    }

    private var instructionRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "at")
                .foregroundColor(.secondary)

            Text("Tag up to \(maxUserCount) friends by @username. Hold a tag to remove it.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var usernameChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(usernames, id: \.self) { username in
                tagChip(for: username)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 2)
    }

    private func tagChip(for username: String) -> some View {
        HStack(spacing: 6) {
            Text(username)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            Capsule()
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .foregroundColor(.secondary.opacity(0.6))
                        )
                )
                .overlay(alignment: .topTrailing) {
                    if isDeleteMode {
                        Button(action: { onRemoveUsername(username) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                    }
                }
                .rotationEffect(isDeleteMode ? .degrees(1.5) : .degrees(0))
                .animation(
                    isDeleteMode
                        ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
                        : .default,
                    value: isDeleteMode
                )
        }
        .contentShape(Rectangle())
        .onLongPressGesture {
            withAnimation { isDeleteMode.toggle() }
        }
    }

    private var inputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("@username", text: $inputText, axis: .vertical)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .keyboardType(.asciiCapable)
                .focused($isFocused)
                .submitLabel(.done)
                .onChange(of: inputText) { _, newValue in
                    onTextChange(newValue)
                }
                .onSubmit(addFromInput)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions.prefix(3), id: \.self) { suggestion in
                Button {
                    onAddUsername(suggestion)
                    inputText = ""
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.accentColor)
                        Text(suggestion)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5), alignment: .bottom
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator))
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        )
    }

    private func addFromInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAddUsername(trimmed)
        inputText = ""
        isFocused = false
    }
}
