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
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewModel.items.indices, id: \.self) { index in
                        ItemRowView(item: $viewModel.items[index])
                            .padding(.horizontal)
                            .background(Color(UIColor.systemBackground).cornerRadius(10).shadow(radius: 5))
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()

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
