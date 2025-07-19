//
//  LocationSearchViewModel.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 7/19/25.
//

import Foundation
import MapKit

@MainActor
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

    func updateQuery(_ query: String) {
        queryFragment = query
        searchCompleter.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("❌ Location autocomplete failed:", error.localizedDescription)
    }
}
