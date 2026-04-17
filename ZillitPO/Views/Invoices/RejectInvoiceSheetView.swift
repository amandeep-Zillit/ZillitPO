import SwiftUI

// MARK: - Reject Invoice Sheet View

struct RejectInvoiceSheetView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var isSubmitting = false
    @State private var showError = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgBase.edgesIgnoringSafeArea(.all)
                VStack(alignment: .leading, spacing: 16) {
                    if let inv = appState.rejectInvoiceTarget {
                        Text("Reject invoice \(inv.invoiceNumber ?? "")")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reason for rejection").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                        TextField("Enter reason…", text: $appState.rejectInvoiceReason)
                            .font(.system(size: 14)).padding(10)
                            .background(Color.bgSurface).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(showError ? Color.red : Color.borderColor, lineWidth: 1))
                        if showError {
                            Text("Reason is required").font(.system(size: 11)).foregroundColor(.red)
                        }
                    }
                    Spacer()
                }.padding()
            }
            .navigationBarTitle(Text("Reject Invoice"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    appState.showRejectInvoiceSheet = false
                    appState.rejectInvoiceReason = ""
                }.foregroundColor(.goldDark),
                trailing: Button("Reject") {
                    guard !isSubmitting else { return }
                    if appState.rejectInvoiceReason.trimmingCharacters(in: .whitespaces).isEmpty {
                        showError = true; return
                    }
                    isSubmitting = true; showError = false
                    appState.rejectInvoice()
                }.foregroundColor(.red).font(.system(size: 16, weight: .bold))
            )
        }
    }
}
