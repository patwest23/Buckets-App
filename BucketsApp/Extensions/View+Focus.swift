//
//  View+Focus.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 3/24/24.
//

import SwiftUI

/// Used to manage focus in a `List` view
enum Focusable: Hashable {
    case none
    case row(id: UUID?)
}

extension View {
    /// Mirror changes between an @Published variable (typically in your View Model) and
    /// an @FocusedState variable in a view
    func sync<T: Equatable>(_ field1: Binding<T>, _ field2: FocusState<T>.Binding ) -> some View {
        self
            .onChange(of: field1.wrappedValue) { field2.wrappedValue = $0 }
            .onChange(of: field2.wrappedValue) { field1.wrappedValue = $0 }
    }
}
