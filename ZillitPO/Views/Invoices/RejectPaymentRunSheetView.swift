import SwiftUI

// MARK: - Reject Payment Run Sheet

struct RejectPaymentRunSheetView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var showError = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgBase.edgesIgnoringSafeArea(.all)
                VStack(alignment: .leading, spacing: 16) {
                    if let run = appState.rejectPaymentRunTarget {
                        Text("Reject \(run.number ?? "")").font(.system(size: 15, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reason for rejection").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                        TextField("Enter reason…", text: $appState.rejectPaymentRunReason)
                            .font(.system(size: 14)).padding(10)
                            .background(Color.bgSurface).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(showError ? Color.red : Color.borderColor, lineWidth: 1))
                        if showError { Text("Reason is required").font(.system(size: 11)).foregroundColor(.red) }
                    }
                    Spacer()
                }.padding()
            }
            .navigationBarTitle(Text("Reject Payment Run"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    appState.showRejectPaymentRunSheet = false
                    appState.rejectPaymentRunReason = ""
                }.foregroundColor(.goldDark),
                trailing: Button("Reject") {
                    if appState.rejectPaymentRunReason.trimmingCharacters(in: .whitespaces).isEmpty {
                        showError = true; return
                    }
                    showError = false
                    appState.rejectPaymentRun()
                }.foregroundColor(.red).font(.system(size: 16, weight: .bold))
            )
        }
    }
}
