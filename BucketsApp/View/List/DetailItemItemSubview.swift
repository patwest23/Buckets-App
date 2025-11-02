import SwiftUI

struct DetailItemItemSubview: View {
    @Binding var titleText: String
    let focusBinding: FocusState<DetailItemField?>.Binding
    let bindingForCompletion: Binding<Bool>
    let creationDate: Date
    let completionDate: Date
    let isCompleted: Bool
    let formatDate: (Date?) -> String
    let onTitleChange: (String) -> Void
    let onSubmitTitle: () -> Void
    let onCreationDateTapped: () -> Void
    let onCompletionDateTapped: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            titleCard
            statusCard
            datesCard
        }
    }

    private var titleCard: some View {
        DetailSectionCard(title: "Title", systemImage: "pencil") {
            TextField("Title", text: $titleText)
                .focused(focusBinding, equals: .title)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .submitLabel(.done)
                .onSubmit(onSubmitTitle)
                .onChange(of: titleText, initial: false) { _, newValue in
                    onTitleChange(newValue)
                }
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )
        }
    }

    private var statusCard: some View {
        DetailSectionCard(title: "Status", systemImage: "checkmark.circle") {
            Toggle(isOn: bindingForCompletion) {
                Text("Completed")
                    .font(.body)
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
    }

    private var datesCard: some View {
        DetailSectionCard(title: "Dates", systemImage: "calendar") {
            VStack(spacing: 12) {
                Button(action: onCreationDateTapped) {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(formatDate(creationDate))
                            .foregroundColor(.accentColor)
                    }
                    .font(.body)
                }
                .buttonStyle(.plain)

                Divider()

                Button(action: onCompletionDateTapped) {
                    HStack {
                        Text("Completed")
                        Spacer()
                        let dateStr = isCompleted
                            ? formatDate(completionDate)
                            : "--"
                        Text(dateStr)
                            .foregroundColor(isCompleted ? .accentColor : .secondary)
                    }
                    .font(.body)
                }
                .buttonStyle(.plain)
                .disabled(!isCompleted)
                .opacity(isCompleted ? 1 : 0.5)
            }
        }
    }
}
