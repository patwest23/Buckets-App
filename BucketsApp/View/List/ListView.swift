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
    
    var body: some View {
        List {
            ForEach(viewModel.items.indices, id: \.self) { index in
                ItemRowView(item: $viewModel.items[index])
                    .id(viewModel.items[index].id ?? UUID()) // Assuming ItemModel's id is UUID
            }
            .onDelete { indexSet in
                viewModel.deleteItems(at: indexSet) // Removed $
            }
            .listRowSeparatorTint(.clear)
        }



        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                //optionsMenu
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                profileNavigationLink
            }
        }
        .navigationTitle("Buckets")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(addButton, alignment: .bottomTrailing)
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

    private var profileNavigationLink: some View {
        NavigationLink(destination: ProfileView()) {
            Image(systemName: "person.crop.circle")
        }
    }

    private var addButton: some View {
        Button(action: {
            if viewModel.items.isEmpty || !(viewModel.items.last?.name.isEmpty ?? true) {
                viewModel.items.append(ItemModel(name: ""))
            }
        }) {
            Image(systemName: "plus.circle")
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
