import SwiftUI

// MARK: - Vendor Detail Page (Navigation push)
//
// Layout mirrors the web's vendor detail modal: big header with
// VERIFIED pill, 2-column grid of contact fields (contact person /
// email / phone / vat / department), a full-width address row, and
// two user blocks at the bottom for "Added by" + "Verified by".

struct VendorDetailPage: View {
    let vendor: Vendor
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteAlert = false
    @State private var navigateToCreatePO = false
    @State private var navigateToEdit = false
    @State private var navigateToHistory = false
    @State private var isVerifying = false
    @State private var showVerifyError = false

    /// Delete is restricted to the accountant or the vendor's creator
    /// (creator = `addedBy` with a fallback to `userId`, matching the
    /// "Added by me" filter in VendorsScrollableList). Keeps the UI and
    /// server-side authorisation aligned.
    private var canDelete: Bool {
        if appState.currentUser?.isAccountant == true { return true }
        guard let uid = appState.currentUser?.id else { return false }
        return (liveVendor.addedBy ?? liveVendor.userId) == uid
    }

    /// Edit is allowed for accountants and the vendor's own creator.
    /// Same rule as `canDelete` — a user who authored a vendor record
    /// should be able to fix its details; others can only view.
    private var canEdit: Bool { canDelete }

    /// Live copy of the vendor from the ViewModel so the page picks up
    /// the edited values when returning from `VendorFormPage`. Falls
    /// back to the original snapshot if the id isn't in the list.
    private var liveVendor: Vendor {
        appState.vendors.first { $0.id == vendor.id } ?? vendor
    }

    // MARK: - Derived display values

    private var phoneDisplay: String {
        let code = (liveVendor.phone?.countryCode ?? "").trimmingCharacters(in: .whitespaces)
        let number = (liveVendor.phone?.number ?? "").trimmingCharacters(in: .whitespaces)
        if code.isEmpty && number.isEmpty { return "—" }
        if code.isEmpty { return number }
        return "\(code) \(number)"
    }

    private var departmentName: String {
        let key = liveVendor.departmentId ?? ""
        if key.isEmpty { return "—" }
        // Departments are referenced by mongo id; identifier is the
        // backup key the rest of the app uses.
        return DepartmentsData.sorted.first { $0.id == key || $0.identifier == key }?.displayName ?? "—"
    }

    private var addressDisplay: String {
        let text = liveVendor.address?.formatted ?? ""
        return text.isEmpty ? "—" : text
    }

    /// Created-at timestamp from the vendor record (ms). Used as the
    /// "added" date when no dedicated field is available.
    private var addedTimestamp: Int64 {
        liveVendor.createdAt ?? 0
    }

    private var verifiedTimestamp: Int64 {
        liveVendor.verifiedAt ?? 0
    }

    private var addedByUser: AppUser? {
        let id = (liveVendor.addedBy?.isEmpty == false) ? liveVendor.addedBy! : (liveVendor.userId ?? "")
        return UsersData.byId[id]
    }

    private var verifiedByUser: AppUser? {
        UsersData.byId[liveVendor.verifiedBy ?? ""]
    }

    /// Map the server's `terms` key (net_30, due_on_receipt, …) back
    /// to its human-readable label so detail view and form stay in
    /// sync with a single source of truth. Falls back to showing the
    /// raw key if the mapping doesn't know about it.
    private var termsDisplay: String {
        guard let raw = liveVendor.terms, !raw.isEmpty else { return "—" }
        let map: [String: String] = [
            "due_on_receipt": "Due on Receipt",
            "net_7": "Net 7", "net_15": "Net 15", "net_30": "Net 30",
            "net_45": "Net 45", "net_60": "Net 60", "net_90": "Net 90",
            "cod": "Cash on Delivery", "prepaid": "Prepaid"
        ]
        return map[raw] ?? raw
    }

    /// `true` when the vendor record has any banking information — a
    /// primary field or at least one "additional detail" row. Drives
    /// whether the BANK DETAILS block is rendered at all.
    private var hasBankDetails: Bool {
        guard let b = liveVendor.bankDetails else { return false }
        return !b.isEmpty
    }

    // Marked deprecated so the three iOS-13-compat hidden NavigationLinks
    // (`NavigationLink(destination:isActive:label:)`) don't trip the
    // iOS-16 deprecation warning. Project deployment target is iOS 13,
    // so we have to keep using the legacy programmatic-navigation
    // pattern. When the target is bumped to iOS 16, replace these with
    // `.navigationDestination(isPresented:)` and remove this attribute.
    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
        var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    vendorHeader
                    contactGrid
                    if liveVendor.verified || !(liveVendor.departmentId ?? "").isEmpty || addedByUser != nil {
                        Divider()
                    }
                    addressBlock
                    if hasBankDetails {
                        Divider()
                        bankDetailsBlock
                    }
                    if addedByUser != nil || verifiedByUser != nil {
                        Divider()
                        userBlocks
                    }

                    // Edit button — only visible when the viewer can
                    // mutate the vendor (accountant or creator, same
                    // rule as delete). History has been moved to the
                    // nav bar's top-right corner.
                    if canEdit {
                        Button(action: { navigateToEdit = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil").font(.system(size: 13))
                                Text("Edit Vendor").font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.goldDark)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.bgSurface).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldDark.opacity(0.3), lineWidth: 1))
                        }
                    }

                    // Mark Verified — accountant-only, only when not yet verified
                    if appState.currentUser?.isAccountant == true && !liveVendor.verified {
                        Button(action: {
                            isVerifying = true
                            appState.verifyVendor(liveVendor.id ?? "") { success in
                                isVerifying = false
                                if !success { showVerifyError = true }
                            }
                        }) {
                            HStack(spacing: 6) {
                                if isVerifying {
                                    ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "checkmark.seal.fill").font(.system(size: 13))
                                }
                                Text(isVerifying ? "Verifying…" : "Mark Verified")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(isVerifying
                                ? Color(red: 0.05, green: 0.15, blue: 0.42).opacity(0.5)
                                : Color(red: 0.05, green: 0.15, blue: 0.42))
                            .cornerRadius(10)
                        }
                        .disabled(isVerifying)
                    }

                    // Create PO button
                    Button(action: {
                        appState.editingPO = nil
                        appState.resumeDraft = nil
                        appState.prefilledVendorId = liveVendor.id
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

            // Hidden NavigationLink to push the Edit Vendor form
            // (VendorFormPage in edit mode — pre-fills from the live
            // vendor record).
            NavigationLink(
                destination: VendorFormPage(vendor: liveVendor).environmentObject(appState),
                isActive: $navigateToEdit
            ) { EmptyView() }
            .hidden()

            // Hidden NavigationLink to push the Vendor History page.
            NavigationLink(
                destination: VendorHistoryPage(
                    vendorId: liveVendor.id ?? "",
                    vendorLabel: liveVendor.name ?? "Vendor"
                ).environmentObject(appState),
                isActive: $navigateToHistory
            ) { EmptyView() }
            .hidden()
        }
        .navigationBarTitle(Text(liveVendor.name ?? ""), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            },
            // History lives in the top-right corner — an icon-only
            // trigger that's always accessible from the nav bar while
            // the user is scrolling the body content.
            trailing: Button(action: { navigateToHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.goldDark)
            }
            .accessibility(label: Text("Vendor history"))
        )
        .alert(isPresented: $showDeleteAlert) {
            Alert(title: Text("Delete Vendor?"), message: Text("This cannot be undone."),
                  primaryButton: .destructive(Text("Delete")) {
                      appState.deleteVendor(liveVendor.id ?? "")
                      presentationMode.wrappedValue.dismiss()
                  },
                  secondaryButton: .cancel())
        }
        .alert(isPresented: $showVerifyError) {
            Alert(title: Text("Verification Failed"),
                  message: Text("Could not mark this vendor as verified. Please try again."),
                  dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Header (name + verified pill)

    private var vendorHeader: some View {
        HStack(spacing: 10) {
            Text((liveVendor.name ?? "").isEmpty ? "—" : (liveVendor.name ?? ""))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(2)
            if liveVendor.verified {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                    Text("VERIFIED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
            } else {
                HStack(spacing: 3) {
                    Circle().fill(Color.gray).frame(width: 6, height: 6)
                    Text("NON-VERIFIED").font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 2-column contact grid

    private var contactGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                iconField(icon: "person", label: "CONTACT PERSON",
                          value: (liveVendor.contactPerson ?? "").isEmpty ? "—" : (liveVendor.contactPerson ?? ""))
                iconField(icon: "envelope", label: "EMAIL",
                          value: (liveVendor.email ?? "").isEmpty ? "—" : (liveVendor.email ?? ""),
                          mono: false)
            }
            HStack(alignment: .top, spacing: 16) {
                iconField(icon: "phone", label: "PHONE", value: phoneDisplay, mono: true)
                iconField(icon: "checkmark.shield",
                          label: "VAT NUMBER",
                          value: (liveVendor.vatNumber ?? "").isEmpty ? "—" : (liveVendor.vatNumber ?? ""),
                          mono: true)
            }
            HStack(alignment: .top, spacing: 16) {
                iconField(icon: "person", label: "DEPARTMENT", value: departmentName)
                iconField(icon: "briefcase",
                          label: "COMPANY TYPE",
                          value: (liveVendor.companyType ?? "").isEmpty ? "—" : (liveVendor.companyType ?? ""))
            }
            // Terms sits alone on its own row so the value has room to
            // breathe — "Cash on Delivery" / "Due on Receipt" otherwise
            // wrap awkwardly next to the department name.
            if let t = liveVendor.terms, !t.isEmpty {
                HStack(alignment: .top, spacing: 16) {
                    iconField(icon: "calendar", label: "TERMS", value: termsDisplay)
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
            }
        }
    }

    // MARK: - Bank Details (full width)

    private var bankDetailsBlock: some View {
        let b = liveVendor.bankDetails
        // Two-column grid of primary fields — blank entries render as
        // "—" so the table shape stays consistent.
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "building.columns")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.goldDark)
                Text("BANK DETAILS")
                    .font(.system(size: 11, weight: .bold)).tracking(0.8)
                    .foregroundColor(.goldDark)
            }
            HStack(alignment: .top, spacing: 16) {
                iconField(icon: "banknote",
                          label: "BANK NAME",
                          value: nonEmpty(b?.bankName))
                iconField(icon: "person",
                          label: "ACCOUNT HOLDER",
                          value: nonEmpty(b?.accountHolderName))
            }
            HStack(alignment: .top, spacing: 16) {
                iconField(icon: "number",
                          label: "ACCOUNT NUMBER",
                          value: nonEmpty(b?.accountNumber), mono: true)
                iconField(icon: "number.square",
                          label: "SORT CODE",
                          value: nonEmpty(b?.sortCode), mono: true)
            }
            HStack(alignment: .top, spacing: 16) {
                iconField(icon: "globe",
                          label: "IBAN CODE",
                          value: nonEmpty(b?.ibanCode), mono: true)
                iconField(icon: "shield",
                          label: "SWIFT CODE",
                          value: nonEmpty(b?.swiftCode), mono: true)
            }
            // Additional details (title / description rows) appear
            // beneath the primary grid, one compact row each.
            if let extras = b?.additionalDetails, !extras.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(extras.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text((row.title ?? "").uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary).tracking(0.5)
                                Text(nonEmpty(row.description))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    /// Small helper — returns the trimmed string or "—" when empty.
    private func nonEmpty(_ s: String?) -> String {
        let t = (s ?? "").trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "—" : t
    }

    // MARK: - Address (full width)

    private var addressBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ADDRESS")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Text(addressDisplay)
                    .font(.system(size: 13)).foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Added by / Verified by

    private var userBlocks: some View {
        HStack(alignment: .top, spacing: 16) {
            userBlock(label: "ADDED BY", user: addedByUser, timestamp: addedTimestamp, verified: false)
            userBlock(label: "VERIFIED BY", user: verifiedByUser, timestamp: verifiedTimestamp, verified: true)
        }
    }

    @ViewBuilder
    private func userBlock(label: String, user: AppUser?, timestamp: Int64, verified: Bool) -> some View {
        if let u = user {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                HStack(spacing: 6) {
                    Image(systemName: verified ? "checkmark.circle.fill" : "person.circle")
                        .font(.system(size: 12))
                        .foregroundColor(verified ? .blue : .secondary)
                    Text(u.fullName ?? "—").font(.system(size: 13, weight: .semibold))
                }
                if !u.displayDesignation.isEmpty {
                    Text(u.displayDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                }
                if timestamp > 0 {
                    Text(FormatUtils.formatDateTime(timestamp))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Hold the column width even when the block is empty so the
            // sibling block stays at 50% width.
            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
        }
    }

    // MARK: - Icon + label + value cell used in the contact grid

    private func iconField(icon: String, label: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(mono ? .system(size: 13, weight: .medium, design: .monospaced)
                               : .system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
