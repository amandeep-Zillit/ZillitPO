import SwiftUI

struct POEditFormPage: View {
    let editingPO: PurchaseOrder
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            POFormView(
                editingPO: editingPO,
                resumeDraft: nil,
                prefilledVendorId: nil,
                onBack: {
                    // Pop back to the detail page after update
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .navigationBarTitle(Text("Edit PO"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
    }
}

// MARK: - Detail Row
