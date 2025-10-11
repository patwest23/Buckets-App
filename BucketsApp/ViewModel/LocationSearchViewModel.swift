//
//  LocationSearchViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 7/19/25.
//

import Foundation
import MapKit

class LocationSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var queryFragment = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []

    private var searchCompleter: MKLocalSearchCompleter

    override init() {
        searchCompleter = MKLocalSearchCompleter()
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = .address
    }

    @MainActor
    func updateQuery(_ query: String) {
        queryFragment = query
        searchCompleter.queryFragment = query
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.searchResults = self.searchCompleter.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ Location autocomplete failed:", error.localizedDescription)
        }
    }
}
