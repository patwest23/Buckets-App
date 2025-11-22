import SwiftUI
import PhotosUI
import UIKit
import MapKit

struct LocationSuggestion: Identifiable, Hashable {
    let title: String
    let subtitle: String
    fileprivate let completion: MKLocalSearchCompletion

    var id: String {
        "\(title)|\(subtitle)"
    }

    var displayText: String {
        let cleanedTitle = sanitizedTitle
        let cleanedSubtitle = sanitizedSubtitle
        if cleanedTitle.isEmpty { return cleanedSubtitle }
        if cleanedSubtitle.isEmpty { return cleanedTitle }
        if cleanedSubtitle.localizedCaseInsensitiveContains(cleanedTitle) {
            return cleanedSubtitle
        }
        return "\(cleanedTitle), \(cleanedSubtitle)"
    }

    var primaryText: String {
        let cleanedTitle = sanitizedTitle
        return cleanedTitle.isEmpty ? displayText : cleanedTitle
    }

    var secondaryText: String? {
        let cleanedSubtitle = sanitizedSubtitle
        guard !cleanedSubtitle.isEmpty else { return nil }
        return cleanedSubtitle == primaryText ? nil : cleanedSubtitle
    }

    private var sanitizedTitle: String {
        title.removingUnitedStatesSuffix()
    }

    private var sanitizedSubtitle: String {
        subtitle.removingUnitedStatesSuffix()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LocationSuggestion, rhs: LocationSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class DetailItemViewModel: NSObject, ObservableObject {
    // MARK: - Dependencies
    private var bucketListViewModel: ListViewModel?

    // MARK: - Stored identifiers
    let itemID: UUID

    // MARK: - Published state
    @Published var currentItem: ItemModel
    @Published var titleText: String
    @Published var locationText: String
    @Published var creationDate: Date
    @Published var completionDate: Date
    @Published private(set) var lastSavedTitle: String
    @Published private(set) var lastSavedLocation: String
    @Published private(set) var lastSavedCreationDate: Date
    @Published private(set) var lastSavedCompletionDate: Date?
    @Published private(set) var lastSavedCompleted: Bool
    @Published private(set) var lastSavedSharedWith: [String]
    @Published var sharedWithUsernames: [String]
    @Published var sharedWithText: String = ""
    @Published var sharedWithSuggestions: [String] = []
    @Published var isShowingSharedSuggestions = false
    @Published var skipSaveOnDisappear = false
    @Published var locationSuggestions: [LocationSuggestion] = []
    @Published var isShowingLocationSuggestions = false
    @Published private(set) var personalImageUrls: [String] = []
    @Published private(set) var canEditPhotos: Bool = true

    // MARK: - Sub view models
    let imagePickerViewModel: ImagePickerViewModel
    private var shouldProcessPickerImages = false
    private let searchCompleter: MKLocalSearchCompleter
    private var isApplyingLocationSuggestion = false
    private let maxSharedUsers = 3
    private var socialViewModel: SocialViewModel?

    // MARK: - Init
    init(item: ItemModel) {
        self.itemID = item.id
        self.currentItem = item
        let initialLocation = item.location?.address ?? ""
        let initialCompletionDate = item.dueDate ?? item.creationDate
        self.titleText = item.name
        self.locationText = initialLocation
        self.creationDate = item.creationDate
        self.completionDate = initialCompletionDate
        self.lastSavedTitle = item.name
        self.lastSavedLocation = initialLocation
        self.lastSavedCreationDate = item.creationDate
        self.lastSavedCompletionDate = item.dueDate
        self.lastSavedCompleted = item.completed
        self.lastSavedSharedWith = item.sharedWithUsernames
        self.sharedWithUsernames = item.sharedWithUsernames
        self.imagePickerViewModel = ImagePickerViewModel()
        self.searchCompleter = MKLocalSearchCompleter()
        self.searchCompleter.resultTypes = [.address, .pointOfInterest]
        super.init()
        self.searchCompleter.delegate = self
    }

    // MARK: - Configuration
    func configureDependencies(bucketListViewModel: ListViewModel, onboardingViewModel _: OnboardingViewModel, socialViewModel: SocialViewModel) {
        self.bucketListViewModel = bucketListViewModel
        self.socialViewModel = socialViewModel
        resolveImagePermissions()
        refreshSharedSuggestions()
    }

    // MARK: - Public actions
    func refreshCurrentItemFromList(focusedField: DetailItemField?) {
        guard let bucketListViewModel else { return }
        guard let updatedItem = bucketListViewModel.items.first(where: { $0.id == itemID }) else { return }

        currentItem = updatedItem
        lastSavedTitle = updatedItem.name
        if focusedField != .title {
            titleText = updatedItem.name
        }

        let updatedAddress = updatedItem.location?.address ?? ""
        lastSavedLocation = updatedAddress
        if focusedField != .location {
            locationText = updatedAddress
        }

        sharedWithUsernames = updatedItem.sharedWithUsernames
        if sharedWithText.isEmpty {
            refreshSharedSuggestions()
        }

        resolveImagePermissions()

        if creationDate != updatedItem.creationDate {
            creationDate = updatedItem.creationDate
        }
        lastSavedCreationDate = updatedItem.creationDate

        if let dueDate = updatedItem.dueDate {
            if completionDate != dueDate {
                completionDate = dueDate
            }
        } else if completionDate != updatedItem.creationDate {
            completionDate = updatedItem.creationDate
        }
        lastSavedCompletionDate = updatedItem.dueDate
        lastSavedCompleted = updatedItem.completed
    }

    func handleImageSelectionChange(_ newSelections: [PhotosPickerItem]) {
        shouldProcessPickerImages = !newSelections.isEmpty
    }

    func handleUIImageChange(_ newImages: [UIImage]) {
        guard shouldProcessPickerImages else { return }
        shouldProcessPickerImages = false

        guard currentItem.completed else { return }
        guard let bucketListViewModel else { return }
        guard canEditPhotos else { return }

        currentItem.imageUrls = []

        Task {
            await bucketListViewModel.replaceImages(with: newImages, for: currentItem.id)
            await MainActor.run {
                self.imagePickerViewModel.imageSelections = []
                if newImages.isEmpty {
                    self.imagePickerViewModel.uiImages = []
                } else {
                    self.imagePickerViewModel.uiImages = newImages
                }
            }
        }
    }

    func handleCreationDateChange(_ newValue: Date) {
        guard currentItem.creationDate != newValue else { return }
        currentItem.creationDate = newValue
        lastSavedCreationDate = newValue
        bucketListViewModel?.addOrUpdateItem(currentItem)
    }

    func handleCompletionDateChange(_ newValue: Date) {
        guard currentItem.completed else { return }
        guard currentItem.dueDate != newValue else { return }
        currentItem.dueDate = newValue
        lastSavedCompletionDate = newValue
        bucketListViewModel?.addOrUpdateItem(currentItem)
    }

    func commitOnDisappear() {
        guard !skipSaveOnDisappear else { return }
        commitEdits()
    }

    func handleFocusChange(_ newValue: DetailItemField?) {
        if newValue != .title {
            saveTitle()
        }
        if newValue != .location {
            saveLocation()
            clearLocationSuggestions()
        }
    }

    func handleTitleChange(_ newValue: String) {
        currentItem.name = newValue
    }

    func handleLocationChange(_ newValue: String) {
        guard !isApplyingLocationSuggestion else { return }
        updateLocationSuggestions(for: newValue)
        if currentItem.location != nil || !newValue.isEmpty {
            var loc = currentItem.location ?? Location(latitude: 0, longitude: 0, address: nil)
            loc.address = newValue.isEmpty ? nil : newValue
            currentItem.location = newValue.isEmpty ? nil : loc
        }
    }

    func handleSharedWithChange(_ newValue: String) {
        let normalized = normalizeUsernameInput(newValue)
        sharedWithText = normalized
        refreshSharedSuggestions()
    }

    func addSharedUser(_ rawValue: String) {
        let normalized = normalizedUsername(rawValue)
        guard !normalized.isEmpty else { return }
        guard !sharedWithUsernames.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) else {
            sharedWithText = ""
            refreshSharedSuggestions()
            return
        }
        guard sharedWithUsernames.count < maxSharedUsers else { return }

        sharedWithUsernames.append(normalized)
        currentItem.sharedWithUsernames = sharedWithUsernames
        lastSavedSharedWith = sharedWithUsernames
        bucketListViewModel?.addOrUpdateItem(currentItem)
        sharedWithText = ""
        refreshSharedSuggestions()
    }

    func removeSharedUser(_ username: String) {
        sharedWithUsernames.removeAll { $0.caseInsensitiveCompare(username) == .orderedSame }
        currentItem.sharedWithUsernames = sharedWithUsernames
        lastSavedSharedWith = sharedWithUsernames
        bucketListViewModel?.addOrUpdateItem(currentItem)
        refreshSharedSuggestions()
    }

    func commitAndDismiss(dismiss: DismissAction) {
        commitAndDismiss { dismiss() }
    }

    func commitAndDismiss(dismiss: () -> Void) {
        commitEdits()
        skipSaveOnDisappear = true
        dismiss()
    }

    func cancelEdits(dismiss: DismissAction) {
        cancelEdits { dismiss() }
    }

    func cancelEdits(dismiss: () -> Void) {
        revertToLastSavedState()
        skipSaveOnDisappear = true
        dismiss()
    }

    func handleDelete(dismiss: DismissAction) {
        handleDelete { dismiss() }
    }

    func handleDelete(dismiss: () -> Void) {
        guard let bucketListViewModel else { return }
        let item = currentItem
        Task { @MainActor in await bucketListViewModel.deleteItem(item) }
        skipSaveOnDisappear = true
        dismiss()
    }

    var completionBinding: Binding<Bool> {
        Binding(get: {
            self.currentItem.completed
        }, set: { newValue in
            self.currentItem.completed = newValue
            self.lastSavedCompleted = newValue
            if newValue {
                let resolvedDate: Date
                if let savedCompletionDate = self.lastSavedCompletionDate {
                    resolvedDate = savedCompletionDate
                } else if self.completionDate != self.lastSavedCreationDate {
                    resolvedDate = self.completionDate
                } else {
                    resolvedDate = Date()
                }
                self.currentItem.dueDate = resolvedDate
                self.completionDate = resolvedDate
                self.lastSavedCompletionDate = resolvedDate
            } else {
                self.currentItem.dueDate = nil
                self.lastSavedCompletionDate = nil
            }
            self.bucketListViewModel?.addOrUpdateItem(self.currentItem)
            if !newValue {
                self.bucketListViewModel?.clearLocalAttachments(for: self.currentItem.id)
            }
        })
    }

    var creationDateBinding: Binding<Date> {
        Binding(
            get: { self.currentItem.creationDate },
            set: { newValue in
                self.currentItem.creationDate = newValue
                self.bucketListViewModel?.addOrUpdateItem(self.currentItem)
            }
        )
    }

    var completionDateBinding: Binding<Date> {
        Binding(
            get: { self.currentItem.dueDate ?? Date() },
            set: { newValue in
                self.currentItem.dueDate = newValue
                self.bucketListViewModel?.addOrUpdateItem(self.currentItem)
            }
        )
    }

    func formatDate(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Private helpers
    private func commitEdits() {
        saveTitle()
        saveLocation()
        saveSharedWith()
    }

    private func resolveImagePermissions() {
        guard let bucketListViewModel else { return }
        let isOwner = bucketListViewModel.isOwnedByCurrentUser(currentItem)
        canEditPhotos = isOwner

        if isOwner {
            personalImageUrls = currentItem.imageUrls
        } else {
            personalImageUrls = currentItem.sharedImageUrls
        }
    }

    private func saveTitle() {
        let newValue = titleText
        guard newValue != lastSavedTitle else { return }
        currentItem.name = newValue
        bucketListViewModel?.addOrUpdateItem(currentItem)
        lastSavedTitle = newValue
    }

    private func saveLocation() {
        let trimmed = locationText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            if !lastSavedLocation.isEmpty {
                currentItem.location = nil
                bucketListViewModel?.addOrUpdateItem(currentItem)
                lastSavedLocation = ""
            }
            if locationText != trimmed {
                locationText = ""
            }
            return
        }

        var existingLocation = currentItem.location ?? Location(latitude: 0, longitude: 0, address: nil)
        if trimmed == lastSavedLocation { return }
        existingLocation.address = trimmed
        currentItem.location = existingLocation
        locationText = trimmed
        bucketListViewModel?.addOrUpdateItem(currentItem)
        lastSavedLocation = trimmed
    }

    private func revertToLastSavedState() {
        currentItem.name = lastSavedTitle
        titleText = lastSavedTitle

        if lastSavedLocation.isEmpty {
            currentItem.location = nil
        } else {
            var location = currentItem.location ?? Location(latitude: 0, longitude: 0, address: nil)
            location.address = lastSavedLocation
            currentItem.location = location
        }
        locationText = lastSavedLocation

        currentItem.creationDate = lastSavedCreationDate
        creationDate = lastSavedCreationDate

        currentItem.completed = lastSavedCompleted
        if let savedCompletionDate = lastSavedCompletionDate {
            currentItem.dueDate = savedCompletionDate
            completionDate = savedCompletionDate
        } else {
            currentItem.dueDate = nil
            completionDate = lastSavedCreationDate
        }

        sharedWithUsernames = lastSavedSharedWith
        currentItem.sharedWithUsernames = lastSavedSharedWith
        sharedWithText = ""
        refreshSharedSuggestions()
    }

    func updateImagePicker(using pendingImages: [UUID: [UIImage]]) {
        guard !shouldProcessPickerImages else { return }
        if let images = pendingImages[itemID] {
            imagePickerViewModel.uiImages = images
        } else if !imagePickerViewModel.uiImages.isEmpty {
            imagePickerViewModel.uiImages = []
        }
    }

    private func updateLocationSuggestions(for query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            clearLocationSuggestions()
            return
        }
        searchCompleter.queryFragment = trimmed
    }

    private func clearLocationSuggestions() {
        locationSuggestions = []
        isShowingLocationSuggestions = false
        searchCompleter.queryFragment = ""
    }

    func handleLocationSuggestionTapped(_ suggestion: LocationSuggestion) {
        isApplyingLocationSuggestion = true
        clearLocationSuggestions()
        Task {
            let request = MKLocalSearch.Request(completion: suggestion.completion)
            let search = MKLocalSearch(request: request)
            let response = try? await search.start()
            let mapItem = response?.mapItems.first
            await MainActor.run {
                self.applyLocationSuggestion(suggestion, mapItem: mapItem)
            }
        }
    }

    @MainActor
    private func applyLocationSuggestion(_ suggestion: LocationSuggestion, mapItem: MKMapItem?) {
        defer { isApplyingLocationSuggestion = false }
        let displayText = (mapItem?.placemark.title ?? suggestion.displayText).removingUnitedStatesSuffix()
        let coordinate = mapItem?.placemark.coordinate

        var location = currentItem.location ?? Location(latitude: 0, longitude: 0, address: nil)
        if let coordinate {
            location.latitude = coordinate.latitude
            location.longitude = coordinate.longitude
        }
        location.address = displayText
        currentItem.location = location
        locationText = displayText
        clearLocationSuggestions()
        saveLocation()
    }

    private func saveSharedWith() {
        guard sharedWithUsernames != lastSavedSharedWith else { return }
        currentItem.sharedWithUsernames = sharedWithUsernames
        bucketListViewModel?.addOrUpdateItem(currentItem)
        lastSavedSharedWith = sharedWithUsernames
    }

    private func refreshSharedSuggestions() {
        guard let socialViewModel else {
            sharedWithSuggestions = []
            isShowingSharedSuggestions = false
            return
        }

        let query = sharedWithText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            sharedWithSuggestions = Array(socialViewModel.following.map { $0.username }.prefix(3))
            isShowingSharedSuggestions = !sharedWithSuggestions.isEmpty
            return
        }

        let lowercasedQuery = query.lowercased()
        let results = socialViewModel.following
            .map { $0.username }
            .filter { username in
                username.lowercased().contains(lowercasedQuery)
            }
            .filter { candidate in
                !sharedWithUsernames.contains { $0.caseInsensitiveCompare(candidate) == .orderedSame }
            }
        sharedWithSuggestions = Array(results.prefix(3))
        isShowingSharedSuggestions = !sharedWithSuggestions.isEmpty
    }

    private func normalizeUsernameInput(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = trimmed.replacingOccurrences(of: " ", with: "")
        if sanitized.isEmpty { return "" }
        if sanitized.hasPrefix("@") { return sanitized }
        return "@" + sanitized
    }

    private func normalizedUsername(_ value: String) -> String {
        var normalized = normalizeUsernameInput(value)
        if normalized.count <= 1 { return "" }
        if normalized.count > 30 {
            normalized = String(normalized.prefix(30))
        }
        return normalized
    }
}

extension DetailItemViewModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let suggestions = completer.results.map { LocationSuggestion(title: $0.title, subtitle: $0.subtitle, completion: $0) }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.locationSuggestions = Array(suggestions.prefix(5))
            self.isShowingLocationSuggestions = !self.locationSuggestions.isEmpty
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError _: Error) {
        Task { @MainActor [weak self] in
            self?.clearLocationSuggestions()
        }
    }
}

private extension String {
    func removingUnitedStatesSuffix() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: "[,\\s]*United States$", options: [.regularExpression, .caseInsensitive]) else {
            return trimmed
        }
        let cleaned = trimmed.replacingCharacters(in: range, with: "")
        return cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ",")))
    }
}
