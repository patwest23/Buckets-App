//
//  LocationSearchFieldView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 7/26/25.
//

import SwiftUI
import MapKit

struct LocationSearchFieldView: View {
    @Binding var query: String
    let results: [MKLocalSearchCompletion]
    let onSelect: (MKLocalSearchCompletion) -> Void
    var focus: FocusState<DetailItemField?>.Binding
    var onFocusChange: ((Bool) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var isFocused: Bool {
        focus.wrappedValue == .location
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BucketTheme.smallSpacing) {
            HStack(spacing: BucketTheme.smallSpacing) {
                Text("📍")
                    .font(.title3)
                TextField("Add location...", text: $query)
                    .font(.body)
                    .submitLabel(.done)
                    .focused(focus, equals: .location)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(.horizontal, BucketTheme.mediumSpacing)
                    .padding(.vertical, BucketTheme.smallSpacing + 4)
                    .background(BucketTheme.surface(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                            .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                    )
                    .onChange(of: isFocused, initial: false) { _, newValue in
                        onFocusChange?(newValue)
                    }
                    .contentShape(Rectangle())
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focus.wrappedValue = .location
            }

            if !results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                        Button {
                            onSelect(result)
                            focus.wrappedValue = nil
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.callout.weight(.semibold))
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(BucketTheme.subtleText(for: colorScheme))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, BucketTheme.smallSpacing)
                        }
                        .buttonStyle(.plain)
                        if index < results.count - 1 {
                            Divider()
                                .overlay(BucketTheme.border(for: colorScheme))
                        }
                    }
                }
                .padding(.horizontal, BucketTheme.mediumSpacing)
                .padding(.vertical, BucketTheme.smallSpacing)
                .background(BucketTheme.surface(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BucketTheme.smallRadius, style: .continuous)
                        .stroke(BucketTheme.border(for: colorScheme), lineWidth: BucketTheme.lineWidth)
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focus.wrappedValue = .location
        }
    }
}
