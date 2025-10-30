//
//  DetailItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/1/24.
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import UIKit

@MainActor
struct DetailItemView: View {
    // MARK: - Stored identifiers
    let itemID: UUID

    // MARK: - Environment
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Local item state
    @State private var currentItem: ItemModel

    // MARK: - Photos
    @StateObject private var imagePickerVM = ImagePickerViewModel()

    // MARK: - Sheets & Alerts
    @State private var showDateCreatedSheet = false
    @State private var showDateCompletedSheet = false
    @State private var showDeleteAlert = false

    // MARK: - Dates
    @State private var creationDate: Date
    @State private var completionDate: Date

    // MARK: - Focus & text
    private enum Field: Hashable { case title, location }
    @FocusState private var focusedField: Field?

    @State private var titleText: String
    @State private var locationText: String
    @State private var lastSavedTitle: String
    @State private var lastSavedLocation: String
    @State private var lastSavedCreationDate: Date
    @State private var lastSavedCompletionDate: Date?
    @State private var lastSavedCompleted: Bool
    @State private var skipSaveOnDisappear = false

    // MARK: - Init
    init(item: ItemModel) {
        self.itemID = item.id
        _currentItem = State(initialValue: item)
        let initialLocation = item.location?.address ?? ""
        let initialCompletionDate = item.dueDate ?? item.creationDate
        _titleText = State(initialValue: item.name)
        _locationText = State(initialValue: initialLocation)
        _lastSavedTitle = State(initialValue: item.name)
        _lastSavedLocation = State(initialValue: initialLocation)
        _creationDate = State(initialValue: item.creationDate)
        _completionDate = State(initialValue: initialCompletionDate)
        _lastSavedCreationDate = State(initialValue: item.creationDate)
        _lastSavedCompletionDate = State(initialValue: item.dueDate)
        _lastSavedCompleted = State(initialValue: item.completed)
    }

    // MARK: - View
    var body: some View {
        ScrollView {
            scrollContent
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { navigationToolbar }
        .sheet(isPresented: $showDateCreatedSheet) { creationDateSheet }
        .sheet(isPresented: $showDateCompletedSheet) { completionDateSheet }
        .alert("Delete Item?", isPresented: $showDeleteAlert, actions: deleteAlertActions, message: deleteAlertMessage)
        .onChange(of: imagePickerVM.imageSelections, initial: false, perform: handleImageSelectionChange(_:))
        .onChange(of: imagePickerVM.uiImages, initial: true, perform: handleUIImageChange(_:))
        .onAppear(perform: refreshCurrentItemFromList)
        .onChange(of: bucketListViewModel.items, initial: false) { _, _ in refreshCurrentItemFromList() }
        .onChange(of: creationDate, initial: false, perform: handleCreationDateChange(_:))
        .onChange(of: completionDate, initial: false, perform: handleCompletionDateChange(_:))
        .onDisappear(perform: commitOnDisappear)
        .onChange(of: focusedField, initial: false, perform: handleFocusChange(_:))
    }

    private var scrollContent: some View {
        VStack(spacing: 20) {
            titleCard
            statusCard
            photosCard
            datesCard
            locationCard
            deleteCard
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { cancelButton }
        ToolbarItem(placement: .confirmationAction) { doneButton }
        ToolbarItemGroup(placement: .keyboard) { keyboardToolbarContent }
    }

    private var cancelButton: some View {
        Button("Cancel", action: cancelEdits)
    }

    private var doneButton: some View {
        Button("Done", action: commitAndDismiss)
            .font(.headline)
    }

    private var keyboardToolbarContent: some View {
        Spacer()
        Button("Done") {
            focusedField = nil
        }
        .font(.headline)
    }

    @ViewBuilder
    private var creationDateSheet: some View {
        datePickerSheet(
            title: "Set Created Date",
            date: creationDateBinding
        ) {
            showDateCreatedSheet = false
        }
    }

    @ViewBuilder
    private var completionDateSheet: some View {
        if currentItem.completed {
            datePickerSheet(
                title: "Set Completion Date",
                date: completionDateBinding
            ) {
                showDateCompletedSheet = false
            }
        }
    }

    private func deleteAlertActions() -> some View {
        Group {
            Button("Delete", role: .destructive, action: handleDelete)
            Button("Cancel", role: .cancel, action: {})
        }
    }

    private func deleteAlertMessage() -> some View {
        Text("This cannot be undone. You will lose “\(currentItem.name)” permanently.")
    }

    private func handleDelete() {
        let item = currentItem
        Task { @MainActor in
            await bucketListViewModel.deleteItem(item)
        }
        skipSaveOnDisappear = true
        dismiss()
    }

    private func handleImageSelectionChange(_ newSelections: [PhotosPickerItem]) {
        Task { @MainActor in await uploadPickedImages(newSelections) }
    }

    private func handleUIImageChange(_ newImages: [UIImage]) {
        bucketListViewModel.updatePendingImages(newImages, for: currentItem.id)
    }

    private func handleCreationDateChange(_ newValue: Date) {
        guard currentItem.creationDate != newValue else { return }
        currentItem.creationDate = newValue
        lastSavedCreationDate = newValue
        bucketListViewModel.addOrUpdateItem(currentItem)
    }

    private func handleCompletionDateChange(_ newValue: Date) {
        guard currentItem.completed else { return }
        guard currentItem.dueDate != newValue else { return }
        currentItem.dueDate = newValue
        lastSavedCompletionDate = newValue
        bucketListViewModel.addOrUpdateItem(currentItem)
    }

    private func commitOnDisappear() {
        guard !skipSaveOnDisappear else { return }
        commitEdits()
    }

    private func handleFocusChange(_ newValue: Field?) {
        if newValue != .title {
            saveTitle()
        }
        if newValue != .location {
            saveLocation()
        }
    }
}

// MARK: - Private helpers
private extension DetailItemView {
    func refreshCurrentItemFromList() {
        if let updatedItem = bucketListViewModel.items.first(where: { $0.id == itemID }) {
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
    }

    func uploadPickedImages(_ selections: [PhotosPickerItem]) async {
        guard currentItem.completed else { return }
        guard let user = onboardingViewModel.user else { return }
        guard let userId = user.id else {
            print("[DetailItemView] No valid user.id!")
            return
        }

        var newUrls: [String] = []
        var uploadedImagePairs: [(url: String, image: UIImage)] = []
        let storageRef = Storage.storage().reference()
            .child("users/\(userId)/item-\(currentItem.id.uuidString)")

        for pickerItem in selections {
            do {
                if let data = try await pickerItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data),
                   let imageData = uiImage.jpegData(compressionQuality: 0.8) {

                    let uniqueName = UUID().uuidString + ".jpg"
                    let imageRef = storageRef.child(uniqueName)
                    try await imageRef.putDataAsync(imageData)
                    let downloadURL = try await imageRef.downloadURL()
                    let absoluteString = downloadURL.absoluteString
                    newUrls.append(absoluteString)
                    uploadedImagePairs.append((url: absoluteString, image: uiImage))
                }
            } catch {
                print("[DetailItemView] uploadPickedImages error:", error.localizedDescription)
            }
        }

        guard !newUrls.isEmpty else { return }

        var updatedUrls = currentItem.imageUrls
        for url in newUrls where !updatedUrls.contains(url) {
            updatedUrls.append(url)
        }

        if updatedUrls.count > 3 {
            updatedUrls = Array(updatedUrls.suffix(3))
        }

        currentItem.imageUrls = updatedUrls
        bucketListViewModel.addOrUpdateItem(currentItem)
        bucketListViewModel.updatePendingImages([], for: currentItem.id)

        for pair in uploadedImagePairs {
            bucketListViewModel.imageCache[pair.url] = pair.image
        }

        imagePickerVM.imageSelections = []
        imagePickerVM.uiImages = []
    }

    func saveTitle() {
        let newValue = titleText
        guard newValue != lastSavedTitle else { return }
        currentItem.name = newValue
        bucketListViewModel.addOrUpdateItem(currentItem)
        lastSavedTitle = newValue
    }

    func saveLocation() {
        let trimmed = locationText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            if !lastSavedLocation.isEmpty {
                currentItem.location = nil
                bucketListViewModel.addOrUpdateItem(currentItem)
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
        bucketListViewModel.addOrUpdateItem(currentItem)
        lastSavedLocation = trimmed
    }

    func commitEdits() {
        saveTitle()
        saveLocation()
    }

    func commitAndDismiss() {
        focusedField = nil
        commitEdits()
        bucketListViewModel.updatePendingImages([], for: currentItem.id)
        skipSaveOnDisappear = true
        dismiss()
    }

    func cancelEdits() {
        focusedField = nil
        revertToLastSavedState()
        bucketListViewModel.updatePendingImages([], for: currentItem.id)
        skipSaveOnDisappear = true
        dismiss()
    }

    func revertToLastSavedState() {
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

    var bindingForCompletion: Binding<Bool> {
        Binding(get: {
            currentItem.completed
        }, set: { newValue in
            currentItem.completed = newValue
            lastSavedCompleted = newValue
            if newValue {
                let resolvedDate: Date
                if let savedCompletionDate = lastSavedCompletionDate {
                    resolvedDate = savedCompletionDate
                } else if completionDate != lastSavedCreationDate {
                    resolvedDate = completionDate
                } else {
                    resolvedDate = Date()
                }
                currentItem.dueDate = resolvedDate
                completionDate = resolvedDate
                lastSavedCompletionDate = resolvedDate
            } else {
                currentItem.dueDate = nil
                lastSavedCompletionDate = nil
            }
            bucketListViewModel.addOrUpdateItem(currentItem)
            if !newValue {
                bucketListViewModel.updatePendingImages([], for: currentItem.id)
            }
        })
    }

    func formatDate(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func datePickerSheet(
        title: String,
        date: Binding<Date>,
        onDismiss: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(title)
                    .font(.title3)
                    .padding(.top)

                DatePicker("", selection: date, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Button("Done") {
                    onDismiss()
                }
                .font(.headline)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(350)])
    }

    var creationDateBinding: Binding<Date> {
        Binding(
            get: { currentItem.creationDate },
            set: { newValue in
                currentItem.creationDate = newValue
                bucketListViewModel.addOrUpdateItem(currentItem)
            }
        )
    }

    var completionDateBinding: Binding<Date> {
        Binding(
            get: { currentItem.dueDate ?? Date() },
            set: { newValue in
                currentItem.dueDate = newValue
                bucketListViewModel.addOrUpdateItem(currentItem)
            }
        )
    }

    @ViewBuilder
    var photoGridRow: some View {
        if !imagePickerVM.uiImages.isEmpty {
            photoGrid(uiImages: imagePickerVM.uiImages)
        } else if !currentItem.imageUrls.isEmpty {
            photoGrid(urlStrings: currentItem.imageUrls)
        }
    }

    func photoGrid(uiImages: [UIImage]) -> some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
            ForEach(uiImages, id: \.self) { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .cornerRadius(6)
                    .clipped()
            }
        }
    }

    func photoGrid(urlStrings: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
            ForEach(urlStrings, id: \.self) { urlStr in
                if let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .cornerRadius(6)
                                .clipped()
                        default:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }

    var titleCard: some View {
        detailCard(title: "Title", systemImage: "pencil") {
            TextField("Title", text: $titleText)
                .focused($focusedField, equals: .title)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
                .onChange(of: titleText, initial: false) { _, newValue in
                    currentItem.name = newValue
                }
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )
        }
    }

    var statusCard: some View {
        detailCard(title: "Status", systemImage: "checkmark.circle") {
            Toggle(isOn: bindingForCompletion) {
                Text("Completed")
                    .font(.body)
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
    }

    var photosCard: some View {
        detailCard(title: "Photos", systemImage: "photo.on.rectangle") {
            VStack(alignment: .leading, spacing: 12) {
                PhotosPicker(
                    selection: $imagePickerVM.imageSelections,
                    maxSelectionCount: 3,
                    matching: .images
                ) {
                    HStack {
                        Label("Select Photos", systemImage: "plus")
                            .labelStyle(.titleAndIcon)
                        Spacer()
                        if !imagePickerVM.uiImages.isEmpty || !currentItem.imageUrls.isEmpty {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.body)
                }
                .disabled(!currentItem.completed)
                .opacity(currentItem.completed ? 1 : 0.4)

                if !currentItem.completed {
                    Text("Mark as completed to attach photos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !imagePickerVM.uiImages.isEmpty || !currentItem.imageUrls.isEmpty {
                    photoGridRow
                }
            }
        }
    }

    var datesCard: some View {
        detailCard(title: "Dates", systemImage: "calendar") {
            VStack(spacing: 12) {
                Button {
                    showDateCreatedSheet = true
                } label: {
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

                Button {
                    if currentItem.completed {
                        showDateCompletedSheet = true
                    }
                } label: {
                    HStack {
                        Text("Completed")
                        Spacer()
                        let dateStr = currentItem.completed
                            ? formatDate(completionDate)
                            : "--"
                        Text(dateStr)
                            .foregroundColor(currentItem.completed ? .accentColor : .secondary)
                    }
                    .font(.body)
                }
                .buttonStyle(.plain)
                .disabled(!currentItem.completed)
                .opacity(currentItem.completed ? 1 : 0.5)
            }
        }
    }

    var locationCard: some View {
        detailCard(title: "Location", systemImage: "mappin.and.ellipse") {
            TextField("Enter a location", text: $locationText)
                .focused($focusedField, equals: .location)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .textContentType(.fullStreetAddress)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
                .onChange(of: locationText, initial: false) { _, newValue in
                    if currentItem.location != nil || !newValue.isEmpty {
                        var loc = currentItem.location ?? Location(latitude: 0, longitude: 0, address: nil)
                        loc.address = newValue.isEmpty ? nil : newValue
                        currentItem.location = newValue.isEmpty ? nil : loc
                    }
                }
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )
        }
    }

    var deleteCard: some View {
        detailCard(title: "", systemImage: "trash") {
            Button {
                showDeleteAlert = true
            } label: {
                Text("Delete Item")
                    .font(.body)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    func detailCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !title.isEmpty {
                Label(title, systemImage: systemImage)
                    .font(.headline)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}
