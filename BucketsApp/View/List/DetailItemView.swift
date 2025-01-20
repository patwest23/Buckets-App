//
//  DetailItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/1/24.
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import MapKit  // <-- For MKLocalSearchCompleter

struct DetailItemView: View {
    // MARK: - Bound Item
    @Binding var item: ItemModel

    // MARK: - Environment Objects
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel

    // MARK: - Presentation
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Local States
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showDeleteConfirmation: Bool = false

    // For MapKit autocomplete
    @State private var locationQuery: String = ""
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var completions: [MKLocalSearchCompletion] = []

    // For date picker sheet (single-line display)
    @State private var showDatePickerSheet = false

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Name Field
                    TextField("What do you want to do before you die?", text: $item.name)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: item.name) { _ in updateItem() }

                    // MARK: - Description
                    ZStack(alignment: .topLeading) {
                        if (item.description?.isEmpty ?? true) {
                            Text("Notes")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                        }
                        TextEditor(
                            text: Binding(
                                get: { item.description ?? "" },
                                set: { item.description = $0 }
                            )
                        )
                        .frame(minHeight: 150)
                        .padding(4)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: item.description) { _ in updateItem() }
                    }

                    // MARK: - Single-line Date (Tap => Sheet w/ Wheel Picker)
                    dateCreatedLine

                    // MARK: - Location (MapKit Autocomplete, no label)
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(
                            "Enter location...",
                            text: $locationQuery
                        )
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: locationQuery) { newValue in
                            // Update item.location for custom text
                            updateLocation(to: newValue)
                            // Kick off MapKit autocomplete
                            searchCompleter.queryFragment = newValue
                        }

                        if !completions.isEmpty && !locationQuery.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(completions, id: \.self) { completion in
                                    Text(completion.title)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.2))
                                        .onTapGesture {
                                            // User picked this suggestion
                                            locationQuery = completion.title
                                            updateLocation(to: completion.title)
                                            completions.removeAll()
                                        }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        }
                    }

                    // MARK: - Completed Toggle
                    Toggle("Completed", isOn: $item.completed)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .onChange(of: item.completed) { _ in updateItem() }

                    // MARK: - Photo Grid
                    if item.imageUrls.isEmpty {
                        placeholderView()
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 10
                        ) {
                            ForEach(item.imageUrls, id: \.self) { urlString in
                                if let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .cornerRadius(10)
                                                .clipped()
                                        case .failure:
                                            placeholderImage()
                                        @unknown default:
                                            placeholderImage()
                                        }
                                    }
                                } else {
                                    placeholderImage()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // MARK: - Photos Picker
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 3, matching: .images) {
                        Text("Select Photos")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .onChange(of: selectedPhotos) { selections in
                        handlePhotoSelection(selections)
                    }
                }
                .padding()
            }

            Spacer()

            // MARK: - Delete Button
            Button(action: {
                showDeleteConfirmation = true
            }) {
                Text("Delete")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Item"),
                    message: Text("Are you sure you want to delete this item?"),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteItem()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .background(Color.white)
        .onAppear {
            configureSearchCompleter()
            // Initialize locationQuery from existing item data
            locationQuery = item.location?.address ?? ""
        }
    }

    // MARK: - Single-Line Date View
    private var dateCreatedLine: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Single-line label
            HStack {
                Text("Date Created:")
                    .font(.headline)
                // Show the date in medium style
                Text(formattedDate(item.creationDate))
                    .foregroundColor(.blue)
            }
            .onTapGesture {
                showDatePickerSheet = true
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
        // Present the sheet with a wheel-style date picker
        .sheet(isPresented: $showDatePickerSheet) {
            VStack(spacing: 20) {
                Text("Select Date Created")
                    .font(.title3)
                    .padding(.top)

                DatePicker(
                    "",
                    selection: $item.creationDate,
                    displayedComponents: .date
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .onChange(of: item.creationDate) { _ in
                    updateItem()
                }

                Button("Done") {
                    showDatePickerSheet = false
                }
                .font(.headline)
                .padding(.bottom, 20)
            }
            .presentationDetents([.height(350)]) // iOS 16+ (optional)
        }
    }

    // Helper to format the displayed date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Firestore / Item Updating
    private func updateItem() {
        Task {
            if let userId = onboardingViewModel.user?.id {
                await listViewModel.addOrUpdateItem(item, userId: userId)
            }
        }
    }

    private func deleteItem() {
        Task {
            if let userId = onboardingViewModel.user?.id {
                await listViewModel.deleteItem(item, userId: userId)
                DispatchQueue.main.async {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    // MARK: - Location Update
    private func updateLocation(to newAddress: String) {
        var updatedLocation = item.location ?? Location(latitude: 0, longitude: 0, address: newAddress)
        updatedLocation.address = newAddress
        item.location = updatedLocation
        updateItem()
    }

    // MARK: - Photos Selection
    private func handlePhotoSelection(_ selections: [PhotosPickerItem]) {
        Task {
            guard let userId = onboardingViewModel.user?.id else { return }
            let storageRef = Storage.storage()
                .reference()
                .child("users/\(userId)/images")

            var newUrls: [String] = []
            for (index, selection) in selections.prefix(3).enumerated() {
                do {
                    if let data = try? await selection.loadTransferable(type: Data.self) {
                        let imageRef = storageRef.child("detail-\(item.id.uuidString)-\(index + 1).jpg")
                        _ = try await imageRef.putDataAsync(data)
                        let downloadUrl = try await imageRef.downloadURL()
                        newUrls.append(downloadUrl.absoluteString)
                    }
                } catch {
                    print("Error uploading selected photo: \(error.localizedDescription)")
                }
            }

            if !newUrls.isEmpty {
                item.imageUrls.append(contentsOf: newUrls)
                updateItem()
            }
        }
    }

    // MARK: - MapKit Autocomplete Setup
    private func configureSearchCompleter() {
        // Listen for updates to the searchCompleter
        searchCompleter.delegateears superbowl= AutocompleteDelegate { completions in
            self.completions = completions
        }
        // Optionally adjust .resultTypes, e.g.:
        // searchCompleter.resultTypes = .address
    }

    // MARK: - UI Helpers
    private func placeholderImage() -> some View {
        ZStack {
            Color.white
                .frame(width: 100, height: 100)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
    }

    private func placeholderView() -> some View {
        VStack {
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)

            Text("No Photos Added")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

// MARK: - AutocompleteDelegate
private class AutocompleteDelegate: NSObject, MKLocalSearchCompleterDelegate {
    let onUpdate: ([MKLocalSearchCompletion]) -> Void

    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onUpdate = onUpdate
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
        onUpdate([])
    }
}













