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
    // MARK: - We store just the item ID
    let itemID: UUID
    
    // MARK: - Environment & Observed
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.presentationMode) private var presentationMode
    
    // The current item pulled from listViewModel, or a fallback if not found
    @State private var currentItem: ItemModel
    
    // Photos
    @StateObject private var imagePickerVM = ImagePickerViewModel()
    
    // Sheets & Alerts
    @State private var showDateCreatedSheet = false
    @State private var showDateCompletedSheet = false
    @State private var showDeleteAlert = false
    
    // Focus
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isLocationFocused: Bool

    @State private var titleText: String
    @State private var locationText: String
    @State private var lastSavedTitle: String
    @State private var lastSavedLocation: String
    
    // MARK: - Init
    init(item: ItemModel) {
        // We'll store itemID for re-fetching, start with 'currentItem' = item
        self.itemID = item.id
        _currentItem = State(initialValue: item)
        let initialLocation = item.location?.address ?? ""
        _titleText = State(initialValue: item.name)
        _locationText = State(initialValue: initialLocation)
        _lastSavedTitle = State(initialValue: item.name)
        _lastSavedLocation = State(initialValue: initialLocation)
    }
    
    var body: some View {
        Form {
            // ===== SECTION 1: Title & Completed
            Section {
                // Title
                TextField("Title", text: $titleText)
                    .focused($isTitleFocused)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(false)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { saveTitle() }
                    .onChange(of: titleText) { newValue in
                        currentItem.name = newValue
                    }
                    .onChange(of: isTitleFocused) { isFocused in
                        if !isFocused {
                            saveTitle()
                        }
                    }
            } header: {
                Label("Title", systemImage: "pencil")
                    .font(.headline)
            }

            Section {
                Toggle(isOn: bindingForCompletion) {
                    Text("Completed")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            } header: {
                Label("Status", systemImage: "checkmark.circle")
                    .font(.headline)
            }
            
            // ===== SECTION 2: Photos
            Section {
                // "Select Photos" row
                PhotosPicker(
                    selection: $imagePickerVM.imageSelections,
                    maxSelectionCount: 3,
                    matching: .images
                ) {
                    HStack {
                        Text("📸  Select Photos")
                        Spacer()
                        
                        // 1) Evaluate references in a local let
                        let hasImages = !imagePickerVM.uiImages.isEmpty || !currentItem.imageUrls.isEmpty
                        if hasImages {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .disabled(!currentItem.completed)
                
                // 2) Another local let for the grid if needed
                let showGrid = !imagePickerVM.uiImages.isEmpty || !currentItem.imageUrls.isEmpty
                if showGrid {
                    photoGridRow
                }
            }
            
            // ===== SECTION 3: Dates
            Section {
                // Created row => tap => date sheet
                Button {
                    showDateCreatedSheet = true
                } label: {
                    HStack {
                        Text("📅 Created").font(.headline)
                        Spacer()
                        Text(formatDate(currentItem.creationDate))
                            .foregroundColor(.accentColor)
                    }
                }
                .buttonStyle(.plain)
                
                // Completed row => only if completed
                Button {
                    if currentItem.completed {
                        showDateCompletedSheet = true
                    }
                } label: {
                    HStack {
                        Text("📅 Completed").font(.headline)
                        Spacer()
                        let dateStr = currentItem.completed
                            ? formatDate(currentItem.dueDate)
                            : "--"
                        Text(dateStr)
                            .foregroundColor(currentItem.completed ? .accentColor : .gray)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!currentItem.completed)
            }
            
            // ===== SECTION 4: Location
            Section {
                TextField("Enter a location", text: $locationText)
                    .focused($isLocationFocused)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(false)
                    .textInputAutocapitalization(.words)
                    .textContentType(.fullStreetAddress)
                    .submitLabel(.done)
                    .onSubmit { saveLocation() }
                    .onChange(of: locationText) { newValue in
                        if currentItem.location != nil || !newValue.isEmpty {
                            var loc = currentItem.location ?? Location(latitude: 0, longitude: 0, address: nil)
                            loc.address = newValue.isEmpty ? nil : newValue
                            currentItem.location = newValue.isEmpty ? nil : loc
                        }
                    }
                    .onChange(of: isLocationFocused) { isFocused in
                        if !isFocused {
                            saveLocation()
                        }
                    }
            } header: {
                Label("Location", systemImage: "mappin.and.ellipse")
                    .font(.headline)
            }

            // ===== SECTION 5: Delete
            Section {
                Button {
                    showDeleteAlert = true
                } label: {
                    Text("Delete")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }
                .listRowBackground(Color.red.opacity(0.2))
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        
        // "Done" if title or location fields are focused
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isTitleFocused || isLocationFocused {
                    Button("Done") {
                        hideKeyboard()
                    }
                    .font(.headline)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
                .font(.headline)
            }
        }
        
        // Created date sheet
        .sheet(isPresented: $showDateCreatedSheet) {
            datePickerSheet(
                title: "Set Created Date",
                date: Binding(
                    get: { currentItem.creationDate },
                    set: { newValue in
                        currentItem.creationDate = newValue
                        bucketListViewModel.addOrUpdateItem(currentItem)
                    }
                )
            ) {
                showDateCreatedSheet = false
            }
        }
        // Completed date sheet
        .sheet(isPresented: $showDateCompletedSheet) {
            if currentItem.completed {
                datePickerSheet(
                    title: "Set Completion Date",
                    date: Binding(
                        get: { currentItem.dueDate ?? Date() },
                        set: { newValue in
                            currentItem.dueDate = newValue
                            bucketListViewModel.addOrUpdateItem(currentItem)
                        }
                    )
                ) {
                    showDateCompletedSheet = false
                }
            }
        }
        
        // Delete confirmation
        .alert("Delete Item?",
               isPresented: $showDeleteAlert,
               actions: {
                   Button("Delete", role: .destructive) {
                       Task {
                           await bucketListViewModel.deleteItem(currentItem)
                       }
                       presentationMode.wrappedValue.dismiss()
                   }
                   Button("Cancel", role: .cancel) {}
               },
               message: {
                   Text("This cannot be undone. You will lose “\(currentItem.name)” permanently.")
               })
        
        // Upload images if user picks them
        .onChange(of: imagePickerVM.imageSelections) { oldValue, newValue in
            Task {
                await uploadPickedImages(newValue)
            }
        }
        
        // Refresh the item from ListView whenever we appear
        .onAppear {
            refreshCurrentItemFromList()
        }
        .onChange(of: bucketListViewModel.items) { _ in
            refreshCurrentItemFromList()
        }
    }
}

// MARK: - Private Helpers
extension DetailItemView {
    
    /// Refresh currentItem from the listViewModel, if present
    private func refreshCurrentItemFromList() {
        if let updatedItem = bucketListViewModel.items.first(where: { $0.id == itemID }) {
            self.currentItem = updatedItem
            lastSavedTitle = updatedItem.name
            if !isTitleFocused {
                titleText = updatedItem.name
            }
            let updatedAddress = updatedItem.location?.address ?? ""
            lastSavedLocation = updatedAddress
            if !isLocationFocused {
                locationText = updatedAddress
            }
        }
    }
    
    /// Upload newly picked images => Firebase => update item’s imageUrls => update Firestore
    private func uploadPickedImages(_ selections: [PhotosPickerItem]) async {
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

        for pair in uploadedImagePairs {
            bucketListViewModel.imageCache[pair.url] = pair.image
        }
    }

    private func saveTitle() {
        let newValue = titleText
        guard newValue != lastSavedTitle else { return }
        currentItem.name = newValue
        bucketListViewModel.addOrUpdateItem(currentItem)
        lastSavedTitle = newValue
    }

    private func saveLocation() {
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

    /// Binding for the completion toggle
    private var bindingForCompletion: Binding<Bool> {
        Binding(get: {
            currentItem.completed
        }, set: { newValue in
            currentItem.completed = newValue
            currentItem.dueDate = newValue ? Date() : nil
            bucketListViewModel.addOrUpdateItem(currentItem)
        })
    }
    
    /// Hide keyboard
    private func hideKeyboard() {
        let wasTitleFocused = isTitleFocused
        let wasLocationFocused = isLocationFocused

        UIApplication.shared.endEditing()

        if wasTitleFocused {
            saveTitle()
        }

        if wasLocationFocused {
            saveLocation()
        }

        isTitleFocused = false
        isLocationFocused = false
    }
    
    /// Format date or “--”
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func datePickerSheet(
        title: String,
        date: Binding<Date>,
        onDismiss: @escaping () -> Void
    ) -> some View {
        NavigationView {
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
    
    /// Photo grid row
    @ViewBuilder
    private var photoGridRow: some View {
        // Show local picks first if we want
        if !imagePickerVM.uiImages.isEmpty {
            photoGrid(uiImages: imagePickerVM.uiImages)
        } else if !currentItem.imageUrls.isEmpty {
            photoGrid(urlStrings: currentItem.imageUrls)
        }
    }
    
    private func photoGrid(uiImages: [UIImage]) -> some View {
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
    
    private func photoGrid(urlStrings: [String]) -> some View {
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
}

//import SwiftUI
//import PhotosUI
//import FirebaseStorage
//
//struct DetailItemView: View {
//    // MARK: - Local Copy
//    @State private var localItem: ItemModel
//    
//    // MARK: - Environment
//    @EnvironmentObject var bucketListViewModel: ListViewModel
//    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
//    @Environment(\.presentationMode) private var presentationMode
//    
//    // MARK: - Local States
//    @StateObject private var imagePickerVM = ImagePickerViewModel()
//    
//    @State private var showDateCreatedSheet = false
//    @State private var showDateCompletedSheet = false
//    
//    @State private var isUploading = false
//    @State private var showDeleteAlert = false
//    
//    // Only keep focus states for name + notes
//    @FocusState private var isNameFocused: Bool
//    @FocusState private var isNotesFocused: Bool
//    
//    // Styling constants
//    private let cardCornerRadius: CGFloat = 12
//    private let cardShadowRadius: CGFloat = 4
//    
//    // MARK: - Init
//    init(item: ItemModel) {
//        _localItem = State(initialValue: item)
//    }
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 16) {
//                
//                // 1) Title + Completed
//                rowCard {
//                    basicInfoRow
//                }
//                
//                // 2) Photos
//                rowCard {
//                    photosRow
//                }
//                
//                // 3) Date Created
//                rowCard {
//                    dateCreatedRow
//                }
//                
//                // 4) Date Completed
//                rowCard {
//                    dateCompletedRow
//                }
//                
//                // 5) Location
//                rowCard {
//                    locationRow
//                }
//                
//                // 6) Description
//                rowCard {
//                    descriptionRow
//                }
//            }
//            .padding(.bottom, 100)  // extra space above keyboard
//        }
//        .scrollDismissesKeyboardIfAvailable()
//        .navigationBarTitleDisplayMode(.inline)
//        
//        // Show a "Done" toolbar button if name or notes text field is focused
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                if isNameFocused || isNotesFocused {
//                    Button("Done") {
//                        hideKeyboard()
//                    }
//                    .foregroundColor(.accentColor)
//                }
//            }
//        }
//        
//        // Pinned Delete button
//        .safeAreaInset(edge: .bottom) {
//            deleteButton
//        }
//        
//        // Delete alert
//        .alert("Delete Item?",
//               isPresented: $showDeleteAlert,
//               actions: {
//                   Button("Delete", role: .destructive) {
//                       Task {
//                           await bucketListViewModel.deleteItem(localItem)
//                           bucketListViewModel.items.removeAll { $0.id == localItem.id }
//                       }
//                       presentationMode.wrappedValue.dismiss()
//                   }
//                   Button("Cancel", role: .cancel) {}
//               },
//               message: {
//                   Text("This cannot be undone. You will lose “\(localItem.name)” permanently.")
//               })
//        
//        // If user picks images => store them locally (no immediate Firestore)
//        .onChange(of: imagePickerVM.uiImages) { _, newImages in
//            if !newImages.isEmpty {
//                localItem.imageUrls.removeAll()
//            }
//        }
//        // Commit changes on nav back
//        .onDisappear {
//            commitChanges()
//        }
//    }
//}
//
//// MARK: - Row Cards
//extension DetailItemView {
//    private func rowCard<Content: View>(
//        @ViewBuilder content: @escaping () -> Content
//    ) -> some View {
//        VStack(alignment: .leading, spacing: 8) {
//            content()
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: cardCornerRadius)
//                .fill(Color(UIColor.secondarySystemGroupedBackground))
//                .shadow(color: .black.opacity(0.1),
//                        radius: cardShadowRadius, x: 0, y: 2)
//        )
//        .padding(.horizontal)
//    }
//}
//
//// MARK: - Rows
//extension DetailItemView {
//    
//    // 1) Basic info row (title + checkmark)
//    fileprivate var basicInfoRow: some View {
//        HStack(spacing: 10) {
//            // Completed toggle (no button style)
//            Button {
//                localItem.completed.toggle()
//                localItem.dueDate = localItem.completed ? Date() : nil
//            } label: {
//                Image(systemName: localItem.completed ? "checkmark.circle.fill" : "circle")
//                    .imageScale(.large)
//                    .foregroundColor(localItem.completed ? .accentColor : .gray)
//            }
//            
//            // Title Field
//            if #available(iOS 16.0, *) {
//                TextField("Untitled",
//                          text: Binding(get: { localItem.name },
//                                        set: { localItem.name = $0 }),
//                          axis: .vertical)
//                .lineLimit(1...3)
//                .foregroundColor(localItem.completed ? .gray : .primary)
//                .focused($isNameFocused)
//            } else {
//                TextField("Untitled",
//                          text: Binding(get: { localItem.name },
//                                        set: { localItem.name = $0 }))
//                .foregroundColor(localItem.completed ? .gray : .primary)
//                .focused($isNameFocused)
//            }
//        }
//    }
//    
//    // 2) Photos row: "Select Photos" + images
//    fileprivate var photosRow: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            if localItem.completed {
//                PhotosPicker(
//                    selection: $imagePickerVM.imageSelections,
//                    maxSelectionCount: 3,
//                    matching: .images
//                ) {
//                    Text("📸   Select Photos")
//                        .font(.headline)
//                }
//                
//                if !imagePickerVM.uiImages.isEmpty {
//                    photoGrid(uiImages: imagePickerVM.uiImages)
//                } else if !localItem.imageUrls.isEmpty {
//                    photoGrid(urlStrings: localItem.imageUrls)
//                }
//            } else {
//                Text("📸   Complete this item first to attach photos.")
//                    .foregroundColor(.gray)
//                    .font(.subheadline)
//            }
//        }
//    }
//    
//    // 3) Date Created: small "Edit" button => sheet
//    fileprivate var dateCreatedRow: some View {
//        HStack(spacing: 10) {
//            Text("📅   Created:")
//                .font(.headline)
//            
//            Spacer()
//            Text(formatDate(localItem.creationDate))
//                .foregroundColor(.accentColor)
//            
//            Button("Edit") {
//                showDateCreatedSheet = true
//            }
//            .font(.subheadline)
//            .padding(.horizontal, 6)
//            .padding(.vertical, 4)
//            .background(Color.accentColor.opacity(0.2))
//            .cornerRadius(6)
//        }
//        .sheet(isPresented: $showDateCreatedSheet) {
//            datePickerSheet(
//                title: "Set Created Date",
//                date: Binding(
//                    get: { localItem.creationDate },
//                    set: { localItem.creationDate = $0 }
//                )
//            ) {
//                showDateCreatedSheet = false
//            }
//        }
//    }
//    
//    // 4) Date Completed: small "Edit" button => sheet
//    fileprivate var dateCompletedRow: some View {
//        HStack(spacing: 10) {
//            Text("📅   Completed:")
//                .font(.headline)
//            
//            Spacer()
//            let dateStr = localItem.completed ? formatDate(localItem.dueDate) : "--"
//            Text(dateStr)
//                .foregroundColor(localItem.completed ? .accentColor : .gray)
//            
//            // Only show if completed
//            if localItem.completed {
//                Button("Edit") {
//                    showDateCompletedSheet = true
//                }
//                .font(.subheadline)
//                .padding(.horizontal, 6)
//                .padding(.vertical, 4)
//                .background(Color.accentColor.opacity(0.2))
//                .cornerRadius(6)
//            }
//        }
//        .sheet(isPresented: $showDateCompletedSheet) {
//            if localItem.completed {
//                datePickerSheet(
//                    title: "Set Completion Date",
//                    date: Binding(
//                        get: { localItem.dueDate ?? Date() },
//                        set: { localItem.dueDate = $0 }
//                    )
//                ) {
//                    showDateCompletedSheet = false
//                }
//            } else {
//                EmptyView()
//            }
//        }
//    }
//    
//    // 5) Location row => no focus state
//    fileprivate var locationRow: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("📍   Location")
//                .font(.headline)
//            
//            // No .focused($isLocationFocused)
//            TextField(
//                "Enter location...",
//                text: Binding(
//                    get: { localItem.location?.address ?? "" },
//                    set: {
//                        var loc = localItem.location ?? Location(latitude: 0, longitude: 0, address: "")
//                        loc.address = $0
//                        localItem.location = loc
//                    }
//                )
//            )
//            .textFieldStyle(.roundedBorder)
//            .disableAutocorrection(false)
//            .autocapitalization(.none)
//        }
//    }
//    
//    // 6) Description => focus for notes if you want
//    fileprivate var descriptionRow: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("📝   Caption")
//                .font(.headline)
//            
//            TextEditor(
//                text: Binding(
//                    get: { localItem.description ?? "" },
//                    set: { localItem.description = $0 }
//                )
//            )
//            .frame(minHeight: 80)
//            .focused($isNotesFocused)
//        }
//    }
//}
//
//// MARK: - Delete Button
//extension DetailItemView {
//    private var deleteButton: some View {
//        Button(role: .destructive) {
//            showDeleteAlert = true
//        } label: {
//            Text("Delete")
//                .font(.headline)
//                .frame(maxWidth: .infinity)
//                .padding()
//                .background(Color.red.opacity(0.1))
//                .cornerRadius(8)
//                .padding(.horizontal)
//                .padding(.bottom, 8)
//        }
//    }
//}
//
//// MARK: - Firestore & Helpers
//extension DetailItemView {
//    /// Called once when user leaves screen => do the final Firestore update
//    private func commitChanges() {
//        Task {
//            bucketListViewModel.addOrUpdateItem(localItem)
//        }
//    }
//    
//    /// Hide the keyboard, no commit
//    private func hideKeyboard() {
//        isNameFocused = false
//        isNotesFocused = false
//        // No locationFocus at all
//    }
//    
//    /// Format Date or "--"
//    private func formatDate(_ date: Date?) -> String {
//        guard let date else { return "--" }
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        return formatter.string(from: date)
//    }
//    
//    /// Date picker sheet used by Created/Completed rows
//    private func datePickerSheet(
//        title: String,
//        date: Binding<Date>,
//        onDismiss: @escaping () -> Void
//    ) -> some View {
//        VStack(spacing: 20) {
//            Text(title)
//                .font(.title3)
//                .padding(.top)
//            
//            DatePicker("", selection: date, displayedComponents: .date)
//                .datePickerStyle(.wheel)
//                .labelsHidden()
//            
//            Button("Done") {
//                onDismiss()
//            }
//            .font(.headline)
//            .padding(.bottom, 20)
//        }
//        .presentationDetents([.height(350)])
//    }
//}
//
//// MARK: - Photo Grids
//extension DetailItemView {
//    private func photoGrid(uiImages: [UIImage]) -> some View {
//        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
//            ForEach(uiImages, id: \.self) { img in
//                Image(uiImage: img)
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 80, height: 80)
//                    .cornerRadius(6)
//                    .clipped()
//            }
//        }
//    }
//    
//    private func photoGrid(urlStrings: [String]) -> some View {
//        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
//            ForEach(urlStrings, id: \.self) { urlStr in
//                if let url = URL(string: urlStr) {
//                    AsyncImage(url: url) { phase in
//                        switch phase {
//                        case .empty:
//                            ProgressView()
//                        case .success(let image):
//                            image
//                                .resizable()
//                                .scaledToFill()
//                                .frame(width: 80, height: 80)
//                                .cornerRadius(6)
//                                .clipped()
//                        default:
//                            EmptyView()
//                        }
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - iOS16 Keyboard Dismiss
//fileprivate extension View {
//    @ViewBuilder
//    func scrollDismissesKeyboardIfAvailable() -> some View {
//        if #available(iOS 16.0, *) {
//            self.scrollDismissesKeyboard(.interactively)
//        } else {
//            self
//        }
//    }
//}

#if DEBUG
struct DetailItemView_Previews: PreviewProvider {
    static var previews: some View {
        // 1) Create mock environment objects
        let mockOnboardingVM = OnboardingViewModel()
        let mockListVM = ListViewModel()
        
        // 2) Create a sample ItemModel with placeholder images
        let sampleItem = ItemModel(
            userId: "previewUser",
            name: "Sample Bucket List Item",
            description: "Short description for preview...",
            dueDate: Date().addingTimeInterval(86400 * 3), // 3 days in the future
            location: Location(latitude: 37.7749, longitude: -122.4194, address: "San Francisco"),
            completed: true,
            creationDate: Date().addingTimeInterval(-86400), // 1 day ago
            imageUrls: [
                "https://via.placeholder.com/300",
                "https://via.placeholder.com/300",
                "https://via.placeholder.com/300"
            ]
        )
        
        // 3) Pass the plain sampleItem to DetailItemView in each preview
        return Group {
            DetailItemView(item: sampleItem)
                .environmentObject(mockOnboardingVM)
                .environmentObject(mockListVM)
                .previewDisplayName("DetailItemView - Light Mode")

            DetailItemView(item: sampleItem)
                .environmentObject(mockOnboardingVM)
                .environmentObject(mockListVM)
                .preferredColorScheme(.dark)
                .previewDisplayName("DetailItemView - Dark Mode")
        }
    }
}
#endif














