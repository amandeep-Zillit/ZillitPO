import SwiftUI

// MARK: - Vendor Detail Page (Navigation push)

struct VendorDetailPage: View {
    let vendor: Vendor
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteAlert = false
    @State private var navigateToCreatePO = false

    /// Delete is restricted to the accountant or the vendor's creator
    /// (creator = `addedBy` with a fallback to `userId`, matching the
    /// "Added by me" filter in VendorsScrollableList). Keeps the UI and
    /// server-side authorisation aligned.
    private var canDelete: Bool {
        if appState.currentUser?.isAccountant == true { return true }
        guard let uid = appState.currentUser?.id else { return false }
        return (vendor.addedBy ?? vendor.userId) == uid
    }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Vendor header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.gold.opacity(0.2)).frame(width: 44, height: 44)
                            Text(String((vendor.name ?? "").prefix(1)).uppercased())
                                .font(.system(size: 18, weight: .bold)).foregroundColor(.goldDark)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vendor.name ?? "").font(.system(size: 18, weight: .bold))
                            HStack(spacing: 4) {
                                Circle().fill(vendor.verified ? Color.green : Color.gray).frame(width: 6, height: 6)
                                Text(vendor.verified ? "Verified" : "Non-Verified")
                                    .font(.system(size: 11)).foregroundColor(vendor.verified ? .green : .secondary)
                            }
                        }
                        Spacer()
                    }.padding(14).background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Details card
                    VStack(alignment: .leading, spacing: 0) {
                        detailRow(label: "Contact Person", value: vendor.contactPerson ?? "")
                        Divider()
                        detailRow(label: "Email", value: vendor.email ?? "")
                        Divider()
                        detailRow(label: "Phone", value: "\(vendor.phone?.countryCode ?? "") \(vendor.phone?.number ?? "")")
                        Divider()
                        detailRow(label: "Address", value: (vendor.address?.formatted ?? "").isEmpty ? "—" : vendor.address?.formatted ?? "")
                        if let vat = vendor.vatNumber, !vat.isEmpty {
                            Divider()
                            detailRow(label: "VAT Number", value: vat)
                        }
                    }.background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Create PO button
                    Button(action: {
                        appState.editingPO = nil
                        appState.resumeDraft = nil
                        appState.prefilledVendorId = vendor.id
                        navigateToCreatePO = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.badge.plus").font(.system(size: 13, weight: .semibold))
                            Text("Create PO for this Vendor").font(.system(size: 14, weight: .bold))
                        }.foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.gold).cornerRadius(10)
                    }

                    // Delete button — only for accountant or the vendor's creator.
                    if canDelete {
                        Button(action: { showDeleteAlert = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash").font(.system(size: 13))
                                Text("Delete Vendor").font(.system(size: 14, weight: .medium))
                            }.foregroundColor(.red).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.bgSurface).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
                        }
                    }
                }.padding(16)
            }

            // Hidden NavigationLink to push Create PO page
            NavigationLink(
                destination: POFormPage().environmentObject(appState),
                isActive: $navigateToCreatePO
            ) { EmptyView() }
            .hidden()
        }
        .navigationBarTitle(Text(vendor.name ?? ""), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .alert(isPresented: $showDeleteAlert) {
            Alert(title: Text("Delete Vendor?"), message: Text("This cannot be undone."),
                  primaryButton: .destructive(Text("Delete")) {
                      appState.deleteVendor(vendor.id)
                      presentationMode.wrappedValue.dismiss()
                  },
                  secondaryButton: .cancel())
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
            Text(value).font(.system(size: 13)).foregroundColor(.primary)
            Spacer()
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }
}
