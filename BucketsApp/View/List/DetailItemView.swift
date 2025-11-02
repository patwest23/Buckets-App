//
//  DetailItemView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 6/1/24.
//

import SwiftUI
import PhotosUI

enum DetailItemField: Hashable {
    case title
    case location
}

@MainActor
struct DetailItemView: View {
    // MARK: - Environment
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - View model
    @StateObject private var viewModel: DetailItemViewModel

    // MARK: - Sheets & Alerts
    @State private var showDateCreatedSheet = false
    @State private var showDateCompletedSheet = false
    @State private var showDeleteAlert = false

    // MARK: - Focus & text
    @FocusState private var focusedField: DetailItemField?

    // MARK: - Init
    init(item: ItemModel) {
        _viewModel = StateObject(wrappedValue: DetailItemViewModel(item: item))
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
        .onChange(of: viewModel.imagePickerViewModel.imageSelections, initial: false) { _, newSelections in
            viewModel.handleImageSelectionChange(newSelections)
        }
        .onChange(of: viewModel.imagePickerViewModel.uiImages, initial: true) { _, newImages in
            viewModel.handleUIImageChange(newImages)
        }
        .onAppear {
            viewModel.configureDependencies(bucketListViewModel: bucketListViewModel, onboardingViewModel: onboardingViewModel)
            viewModel.refreshCurrentItemFromList(focusedField: focusedField)
        }
        .onChange(of: bucketListViewModel.items, initial: false) { _, _ in
            viewModel.refreshCurrentItemFromList(focusedField: focusedField)
        }
        .onChange(of: viewModel.creationDate, initial: false) { _, newDate in
            viewModel.handleCreationDateChange(newDate)
        }
        .onChange(of: viewModel.completionDate, initial: false) { _, newDate in
            viewModel.handleCompletionDateChange(newDate)
        }
        .onDisappear(perform: viewModel.commitOnDisappear)
        .onChange(of: focusedField, initial: false) { _, newField in
            viewModel.handleFocusChange(newField)
        }
    }

    private var scrollContent: some View {
        VStack(spacing: 20) {
            DetailItemItemSubview(
                titleText: Binding(
                    get: { viewModel.titleText },
                    set: { viewModel.titleText = $0 }
                ),
                focusBinding: $focusedField,
                bindingForCompletion: viewModel.completionBinding,
                creationDate: viewModel.creationDate,
                completionDate: viewModel.completionDate,
                isCompleted: viewModel.currentItem.completed,
                formatDate: viewModel.formatDate,
                onTitleChange: viewModel.handleTitleChange(_:),
                onSubmitTitle: { focusedField = nil },
                onCreationDateTapped: { showDateCreatedSheet = true },
                onCompletionDateTapped: {
                    if viewModel.currentItem.completed {
                        showDateCompletedSheet = true
                    }
                }
            )

            DetailItemPhotosSubview(
                imagePickerViewModel: viewModel.imagePickerViewModel,
                isCompleted: viewModel.currentItem.completed,
                imageUrls: viewModel.currentItem.imageUrls
            )

            DetailItemLocationSubview(
                locationText: Binding(
                    get: { viewModel.locationText },
                    set: { viewModel.locationText = $0 }
                ),
                focusBinding: $focusedField,
                onLocationChange: viewModel.handleLocationChange(_:),
                onSubmit: { focusedField = nil }
            )

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
        Button("Cancel") {
            focusedField = nil
            viewModel.cancelEdits(dismiss: dismiss)
        }
    }

    private var doneButton: some View {
        Button("Done") {
            focusedField = nil
            viewModel.commitAndDismiss(dismiss: dismiss)
        }
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
            date: viewModel.creationDateBinding
        ) {
            showDateCreatedSheet = false
        }
    }

    @ViewBuilder
    private var completionDateSheet: some View {
        if viewModel.currentItem.completed {
            datePickerSheet(
                title: "Set Completion Date",
                date: viewModel.completionDateBinding
            ) {
                showDateCompletedSheet = false
            }
        }
    }

    private func deleteAlertActions() -> some View {
        Group {
            Button("Delete", role: .destructive) {
                viewModel.handleDelete(dismiss: dismiss)
            }
            Button("Cancel", role: .cancel, action: {})
        }
    }

    private func deleteAlertMessage() -> some View {
        Text("This cannot be undone. You will lose “\(viewModel.currentItem.name)” permanently.")
    }
}

// MARK: - Private helpers
private extension DetailItemView {
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

    var deleteCard: some View {
        DetailSectionCard(title: "", systemImage: "trash") {
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
}
