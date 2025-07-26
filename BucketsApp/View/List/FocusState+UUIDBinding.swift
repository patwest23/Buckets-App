//
//  FocusState+UUIDBinding.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 7/26/25.
//

import SwiftUI

/// Creates a `Binding<Bool>` that is `true` when the given `FocusState<UUID?>` matches the provided ID.
func bindingForUUIDFocus(_ focusState: FocusState<UUID?>, matching id: UUID) -> Binding<Bool> {
    Binding<Bool>(
        get: { focusState.wrappedValue == id },
        set: { newValue in
            focusState.wrappedValue = newValue ? id : nil
        }
    )
}
