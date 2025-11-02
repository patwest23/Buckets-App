import SwiftUI

struct DetailItemLocationSubview: View {
    @Binding var locationText: String
    let focusBinding: FocusState<DetailItemField?>.Binding
    let onLocationChange: (String) -> Void
    let onSubmit: () -> Void

    var body: some View {
        DetailSectionCard(title: "Location", systemImage: "mappin.and.ellipse") {
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
        }
    }
}
