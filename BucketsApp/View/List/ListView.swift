//
//  ListView.swift
//  BucketsApp
//
//  Created by Patrick Westerkamp on 4/10/23.
//

import SwiftUI
import PhotosUI

struct ListView: View {
    @EnvironmentObject var viewModel: ListViewModel
    
    @FocusState private var focusedItemID: UUID?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.items.indices, id: \.self) { index in
                    HStack {
                        Button(action: {
                            viewModel.items[index].completed.toggle()
                        }) {
                            Image(systemName: viewModel.items[index].completed ? "checkmark.circle.fill" : "circle")
                                .imageScale(.large)
                                .font(.title2)
                                .foregroundColor(viewModel.items[index].completed ? Color("AccentColor") : .gray)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        TextField("New Item", text: $viewModel.items[index].name)
                            .focused($focusedItemID, equals: viewModel.items[index].id)
                            .foregroundColor(viewModel.items[index].completed ? .gray : .primary)
                            .font(.title3)
                            .onSubmit {
                                focusedItemID = nil
                            }
                        
                        NavigationLink(destination: DetailItemView(item: $viewModel.items[index])) {
                            EmptyView() // NavigationLink is hidden, the TextField handles navigation
                        }
                        .frame(width: 0)
                        .opacity(0)
                    }
                }
                .onDelete { indexSet in
                    viewModel.deleteItems(at: indexSet)
                }
                .listRowSeparatorTint(.clear)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // optionsMenu
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    profileNavigationLink
                }
            }
            .navigationTitle("Buckets")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(addButton, alignment: .bottomTrailing)
        }
    }

    private var profileNavigationLink: some View {
        NavigationLink(destination: ProfileView()) {
            Image(systemName: "person.crop.circle")
        }
    }

    private var addButton: some View {
        Button(action: {
            // Trigger haptic feedback
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()

            // Only add a new item if the list is empty or the last item is not empty
            if viewModel.items.isEmpty || !(viewModel.items.last?.name.isEmpty ?? true) {
                let newItem = ItemModel(name: "")
                viewModel.items.append(newItem)
                focusedItemID = newItem.id
            }
        }) {
            ZStack {
                Circle()
                    .frame(width: 60, height: 60)
                    .shadow(color: .gray, radius: 10, x: 0, y: 5)
                
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}

struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        ListView()
            .environmentObject(ListViewModel())
            .environmentObject(OnboardingViewModel())
    }
}











//    private var optionsMenu: some View {
//        Menu {
//            Toggle(isOn: $viewModel.hideCompleted) {
//                Label(viewModel.hideCompleted ? "Show Completed" : "Hide Completed", systemImage: "checkmark.circle")
//            }
//            Toggle(isOn: $viewModel.showImages) {
//                Label(viewModel.showImages ? "Hide Images" : "Show Images", systemImage: "photo")
//            }
//            Button("Edit List") {
//                // Placeholder for future feature
//            }
//        } label: {
//            Image(systemName: "ellipsis.circle")
//        }
//        .onChange(of: $viewModel.hideCompleted) { _ in
//            viewModel.sortItems()
//        }
//        .onChange(of: viewModel.showImages) { _ in
//            // Handle showImages change if needed
//        }
//    }
