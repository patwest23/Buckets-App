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

    private var isFocused: Bool {
        focus.wrappedValue == .location
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("📍")
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 4) {
                TextField("Add location...", text: $query)
                    .font(.body)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: isFocused ? 2 : 1)
                            .background(Color(.systemBackground))
                    )
                    .submitLabel(.done)
                    .focused(focus, equals: .location)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .onChange(of: isFocused, initial: false) { _, newValue in
                        onFocusChange?(newValue)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focus.wrappedValue = .location
                    }

                if !results.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(results, id: \.self) { result in
                                Button {
                                    onSelect(result)
                                    focus.wrappedValue = nil
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title).bold()
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(8)
                                }
                                .contentShape(Rectangle())
                                Divider()
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .frame(maxHeight: 150)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                focus.wrappedValue = .location
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .onTapGesture {
            focus.wrappedValue = .location
        }
    }
}
