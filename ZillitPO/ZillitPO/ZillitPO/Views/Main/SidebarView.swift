import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                if let u = appState.currentUser {
                    Section(header: Text("Current User")) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Color.gold.opacity(0.2)).frame(width: 36, height: 36)
                                Text(u.initials).font(.system(size: 13, weight: .bold)).foregroundColor(.goldDark)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(u.fullName).font(.system(size: 15, weight: .semibold))
                                Text(u.displayDesignation).font(.system(size: 12)).foregroundColor(.secondary)
                                Text(u.displayDepartment).font(.system(size: 11, weight: .medium)).foregroundColor(.blue)
                            }
                        }
                    }
                }
                Section(header: Text("Switch User")) {
                    ForEach(UsersData.allUsers, id: \.id) { user in
                        Button(action: {
                            appState.switchUser(user.id)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(user.fullName).font(.system(size: 14)).foregroundColor(.primary)
                                    Text(user.displayDepartment).font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                Spacer()
                                if user.id == appState.userId {
                                    Image(systemName: "checkmark").foregroundColor(.goldDark)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle(Text("Zillit Coda"), displayMode: .inline)
            .navigationBarItems(leading: Button("Done") { presentationMode.wrappedValue.dismiss() })
        }
    }
}
