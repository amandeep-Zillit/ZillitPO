import SwiftUI

struct RejectSheetView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rejecting \(appState.rejectTarget?.poNumber ?? "this PO"). Please provide a reason.")
                    .font(.system(size: 12)).foregroundColor(.secondary)
                Text("REASON *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                TextField("Enter rejection reason...", text: $appState.rejectReason)
                    .padding(10).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor))
                Spacer()
            }.padding()
            .navigationBarTitle(Text("Reject PO"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { appState.rejectTarget = nil; appState.rejectReason = ""; presentationMode.wrappedValue.dismiss() },
                trailing: Button("Reject") { appState.rejectPO(); presentationMode.wrappedValue.dismiss() }
                    .disabled(appState.rejectReason.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundColor(.red)
            )
        }
    }
}
