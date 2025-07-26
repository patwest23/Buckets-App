
import SwiftUI

struct ListContainerView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var bucketListViewModel: ListViewModel
    @EnvironmentObject var postViewModel: PostViewModel

    @State private var isAnyTextFieldActive: Bool = false
    @State private var focusedItemID: UUID?

    var body: some View {
        NavigationStack {
            ListView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Bucket List")
                    .font(.headline)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if isAnyTextFieldActive {
                    Button("Done") {
                        UIApplication.shared.endEditing()
                        isAnyTextFieldActive = false
                        focusedItemID = nil
                    }
                    .font(.headline)
                    .foregroundColor(.accentColor)
                } else {
                    Button {
                        // showProfileView = true
                    } label: {
                        HStack(spacing: 8) {
                            Text(userViewModel.user?.username?.isEmpty == false
                                 ? userViewModel.user!.username!
                                 : "@User")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button {
                        // showFeed = true
                    } label: {
                        Image(systemName: "house.fill")
                    }

                    Spacer()

                    Button {
                        // Trigger add action
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }

                    Spacer()

                    Button {
                        // showFriends = true
                    } label: {
                        Image(systemName: "person.2.fill")
                    }
                }
                .padding(.top, 4)
            }

            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.endEditing()
                        focusedItemID = nil
                    }
                }
            }
        }
    }
}
