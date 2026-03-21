import SwiftUI

struct RejectSheetView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    @State private var showError = false
    @State private var isSubmitting = false

    private var reasonEmpty: Bool {
        appState.rejectReason.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rejecting \(appState.rejectTarget?.poNumber ?? "this PO"). Please provide a reason.")
                    .font(.system(size: 12)).foregroundColor(.secondary)
                Text("REASON *")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(showError && reasonEmpty ? .red : .secondary)
                TextField("Enter rejection reason...", text: $appState.rejectReason)
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(showError && reasonEmpty ? Color.red : Color.borderColor))
                if showError && reasonEmpty {
                    Text("Rejection reason is required").font(.system(size: 10)).foregroundColor(.red)
                }
                Spacer()
            }.padding()
            .navigationBarTitle(Text("Reject PO"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    appState.rejectTarget = nil; appState.rejectReason = ""
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Reject") {
                    if reasonEmpty {
                        showError = true
                        return
                    }
                    guard !isSubmitting else { return }
                    isSubmitting = true
                    appState.rejectPO()
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.red)
            )
        }
    }
}
