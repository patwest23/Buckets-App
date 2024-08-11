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
    @State private var editingIndex: Int?

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

                        if editingIndex == index {
                            TextField("Item Name", text: $viewModel.items[index].name, onCommit: {
                                editingIndex = nil
                            })
                            .foregroundColor(viewModel.items[index].completed ? .gray : .primary)
                            .font(.title3)
                        } else {
                            NavigationLink(destination: DetailItemView(item: $viewModel.items[index])) {
                                Text(viewModel.items[index].name.isEmpty ? "Untitled" : viewModel.items[index].name)
                                    .foregroundColor(viewModel.items[index].completed ? .gray : .primary)
                                    .font(.title3)
                            }
                        }
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

            // Add a new item and immediately start editing it
            viewModel.addItem()
            editingIndex = viewModel.items.count - 1
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

































//    .position(x: UIScreen.main.bounds.width - 70, y: UIScreen.main.bounds.height - 180)










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
