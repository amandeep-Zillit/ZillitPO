import SwiftUI

struct POFormPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    private var editingPO: PurchaseOrder? { appState.editingPO }
    private var resumeDraft: PurchaseOrder? { appState.resumeDraft }
    private var prefilledVendorId: String? { appState.prefilledVendorId }

    private var title: String {
        if editingPO != nil { return "Edit PO" }
        if resumeDraft != nil { return "Resume Draft" }
        return "Create PO"
    }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            POFormView(
                editingPO: editingPO,
                resumeDraft: resumeDraft,
                prefilledVendorId: prefilledVendorId,
                onBack: {
                    appState.editingPO = nil
                    appState.resumeDraft = nil
                    appState.showCreatePO = false
                    appState.prefilledVendorId = nil
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .navigationBarTitle(Text(title), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: {
                appState.editingPO = nil
                appState.resumeDraft = nil
                appState.showCreatePO = false
                appState.prefilledVendorId = nil
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
    }
}
