import SwiftUI
import PhotosUI
import UIKit

@MainActor
final class DetailItemViewModel: ObservableObject {
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
    @Published var skipSaveOnDisappear = false

    // MARK: - Sub view models
    let imagePickerViewModel: ImagePickerViewModel
    private var shouldProcessPickerImages = false

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
        self.imagePickerViewModel = ImagePickerViewModel()
    }

    // MARK: - Configuration
    func configureDependencies(bucketListViewModel: ListViewModel, onboardingViewModel _: OnboardingViewModel) {
        self.bucketListViewModel = bucketListViewModel
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

        Task {
            await bucketListViewModel.stageImagesForUpload(newImages, for: currentItem.id)
            await MainActor.run {
                self.imagePickerViewModel.imageSelections = []
                self.imagePickerViewModel.uiImages = bucketListViewModel.pendingLocalImages[self.currentItem.id] ?? []
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
        }
    }

    func handleTitleChange(_ newValue: String) {
        currentItem.name = newValue
    }

    func handleLocationChange(_ newValue: String) {
        if currentItem.location != nil || !newValue.isEmpty {
            var loc = currentItem.location ?? Location(latitude: 0, longitude: 0, address: nil)
            loc.address = newValue.isEmpty ? nil : newValue
            currentItem.location = newValue.isEmpty ? nil : loc
        }
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
    }

    func updateImagePicker(using pendingImages: [UUID: [UIImage]]) {
        guard !shouldProcessPickerImages else { return }
        if let images = pendingImages[itemID] {
            imagePickerViewModel.uiImages = images
        } else if !imagePickerViewModel.uiImages.isEmpty {
            imagePickerViewModel.uiImages = []
        }
    }
}
