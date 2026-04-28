import SwiftUI
import WebKit
import UIKit

// MARK: - PO Detail Page (Navigation push destination)

struct PODetailPage: View {
    let po: PurchaseOrder
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var navigateToHistory = false
    @State private var navigateToQueries = false
    @State private var showActionsMenu = false   // iOS 13 fallback trigger

    /// Live PO from appState (refreshed after edits), falling back to the original snapshot
    private var livePO: PurchaseOrder {
        appState.purchaseOrders.first(where: { $0.id == po.id }) ?? po
    }

    private var poLabel: String {
        (livePO.poNumber ?? "").isEmpty ? "PO" : (livePO.poNumber ?? "")
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        PODetailContentView(po: livePO, onClose: { presentationMode.wrappedValue.dismiss() })
            .environmentObject(appState)
            .onAppear { appState.refreshPO(po.id ?? "") }
            .navigationBarTitle(Text(livePO.poNumber ?? ""), displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        Text("Back").font(.system(size: 16))
                    }.foregroundColor(.goldDark)
                },
                trailing: trailingMenu
            )
            // Hidden NavigationLinks + iOS 13 dropdown fallback.
            .background(
                ZStack {
                    NavigationLink(
                        destination: POHistoryPage(poId: livePO.id ?? "", poLabel: poLabel).environmentObject(appState),
                        isActive: $navigateToHistory
                    ) { EmptyView() }.frame(width: 0, height: 0).hidden()
                    NavigationLink(
                        destination: POQueriesPage(poId: livePO.id ?? "", poLabel: poLabel).environmentObject(appState),
                        isActive: $navigateToQueries
                    ) { EmptyView() }.frame(width: 0, height: 0).hidden()

                    if #available(iOS 14.0, *) { EmptyView() }
                    else {
                        Color.clear
                            .appDropdownMenu(
                                isPresented: $showActionsMenu,
                                items: [
                                    .action("Query", systemImage: "text.bubble") { navigateToQueries = true },
                                    .action("History", systemImage: "clock.arrow.circlepath") { navigateToHistory = true }
                                ]
                            )
                            .frame(width: 0, height: 0)
                    }
                }
            )
    }

    /// Trailing nav-bar trigger. iOS 14+ uses native `Menu`; iOS 13 falls
    /// back to the reusable `appDropdownMenu` modifier triggered below.
    @ViewBuilder
    private var trailingMenu: some View {
        if #available(iOS 14.0, *) {
            Menu {
                Button { navigateToQueries = true } label: { Label("Query", systemImage: "text.bubble") }
                Button { navigateToHistory = true } label: { Label("History", systemImage: "clock.arrow.circlepath") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.goldDark)
            }
            .accessibility(label: Text("More actions"))
        } else {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { showActionsMenu.toggle() }
            }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.goldDark)
            }
            .accessibility(label: Text("More actions"))
        }
    }
}

// MARK: - PO Detail Content View (shared content)

struct PODetailContentView: View {
    let po: PurchaseOrder
    var onClose: () -> Void
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToPDF = false
    @State private var navigateToEdit = false
    @State private var pdfData: Data?
    @State private var isLoadingPDF = false
    @State private var pdfError: String?
    @State private var pdfTask: URLSessionDataTask?
    /// IDs of line items currently expanded in the collapsible line-items
    /// card. Default: collapsed — each row shows just description + amount
    /// until tapped.
    @State private var expandedLineItems: Set<String> = []
    // Post / Close action state (accountant-only)
    @State private var showPostConfirm = false
    @State private var showCloseSheet  = false
    @State private var closeReason     = ""
    @State private var closeEffectiveDate = Date()
    @State private var actionErrorMessage: String?
    @State private var isPosting = false
    @State private var isClosing = false

    /// Aggregate VAT across line items
    private var vatSummary: (totalVat: Double, grossTotal: Double, label: String) {
        if (po.lineItems ?? []).isEmpty {
            let result = VATHelpers.calcVat(po.netAmount ?? 0, treatment: po.vatTreatment ?? "pending")
            return (result.vatAmount, result.gross, VATHelpers.vatLabel(po.vatTreatment ?? "pending"))
        }
        var totalVat = 0.0; var grossTotal = 0.0
        var treatments = Set<String>()
        for li in po.lineItems ?? [] {
            let result = VATHelpers.calcVat((li.quantity ?? 0) * (li.unitPrice ?? 0), treatment: li.vatTreatment ?? "pending")
            totalVat += result.vatAmount; grossTotal += result.gross
            treatments.insert(li.vatTreatment ?? "pending")
        }
        let label: String
        if totalVat > 0 {
            label = "20% Standard Rate"
        } else {
            label = "Pending"
        }
        return (totalVat, grossTotal, label)
    }
    private var vis: ApprovalVisibility {
        let c = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId, amount: po.totalAmount)
            ?? ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId)
        guard let c = c
        else { return ApprovalVisibility(visible: true, canApprove: false, nextTier: nil, totalTiers: 0, approvedCount: 0, isCreator: false) }
        return ApprovalHelpers.getVisibility(po: po, config: c, userId: appState.userId)
    }
    private var isCreator: Bool { po.userId == appState.userId }
    private var canEdit: Bool { isCreator && ![.approved, .posted, .acctEntered].contains(po.poStatus) }

    /// Accountant-only lifecycle permissions (Apr 2026 web parity).
    /// `canPost`  — APPROVED / ACCT_ENTERED → POSTED (publishes the PO).
    /// `canClose` — POSTED → CLOSED (archives once goods are received).
    private var isAccountant: Bool { appState.currentUser?.isAccountant == true }
    private var canPost: Bool  { isAccountant && [.approved, .acctEntered].contains(po.poStatus) }
    private var canClose: Bool { isAccountant && po.poStatus == .posted }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // ── Header: PO# + description + status ──
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(po.poNumber ?? "")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.goldDark)
                            Spacer()
                            statusValueView
                        }
                        Text((po.description ?? "").isEmpty ? "No description" : po.description ?? "")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // ── Vendor + Delivery Address, stacked one-per-row
                    //    (full width). The 14pt horizontal padding matches
                    //    the inner padding of the Line Items card below,
                    //    so the details text visually lines up with the
                    //    line items text.
                    VStack(alignment: .leading, spacing: 16) {
                        labelledBlock(label: "VENDOR") {
                            VStack(alignment: .leading, spacing: 2) {
                                Text((po.vendor ?? "").isEmpty ? "—" : (po.vendor ?? ""))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !(po.vendorAddress ?? "").isEmpty {
                                    Text(po.vendorAddress ?? "")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        labelledBlock(label: "DELIVERY ADDRESS") {
                            deliveryAddressBlock
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)

                    Divider().padding(.horizontal, 14)

                    // ── 2-column grid of key facts — inset 14pt to line up
                    //    with the Line Items card text below.
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            labelledBlock(label: "AMOUNT (GROSS)") {
                                Text(FormatUtils.formatCurrency(vatSummary.grossTotal, code: po.currency ?? "GBP"))
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            labelledBlock(label: "CURRENCY") {
                                Text((po.currency ?? "").isEmpty ? "—" : (po.currency ?? ""))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        HStack(alignment: .top, spacing: 16) {
                            labelledBlock(label: "EFFECTIVE DATE") {
                                // `formatTimestamp` returns "—" for nil/0.
                                Text(FormatUtils.formatTimestamp(po.effectiveDate))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            }
                            labelledBlock(label: "DELIVERY DATE") {
                                Text(FormatUtils.formatTimestamp(po.deliveryDate))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            }
                        }
                        HStack(alignment: .top, spacing: 16) {
                            labelledBlock(label: "DEPARTMENT") {
                                Text((po.department ?? "").isEmpty ? "—" : (po.department ?? ""))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            labelledBlock(label: "CREATED BY") {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(UsersData.byId[po.userId ?? ""]?.fullName ?? "—")
                                        .font(.system(size: 13, weight: .semibold))
                                    if let desg = UsersData.byId[po.userId ?? ""]?.displayDesignation, !desg.isEmpty {
                                        Text(desg).font(.system(size: 11)).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)

                    // ── Notes ──
                    if !(po.notes ?? "").isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            Text(po.notes ?? "").font(.system(size: 12)).foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.bgSurface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    // ── Rejection reason ──
                    if po.poStatus == .rejected, let reason = po.rejectionReason, !reason.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundColor(.red)
                            Text(reason).font(.system(size: 12)).foregroundColor(.red)
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.05)).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 1))
                    }

                    // ── Line Items (the only card on the page). Each row is
                    //    collapsed by default — tapping it toggles the
                    //    details (exp type / account / dept / qty × price /
                    //    VAT). Collapsed rows show just description + amount.
                    if !(po.lineItems ?? []).isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("LINE ITEMS")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)

                            // Column headings — aligned with the collapsible
                            // row layout (chevron slot + description column
                            // on the left, right-aligned amount column).
                            HStack(alignment: .center, spacing: 10) {
                                // Reserve the same width the chevron glyph takes
                                // inside `collapsibleLineItem` so "DESCRIPTION"
                                // sits directly over each row's description text.
                                Color.clear.frame(width: 12, height: 1)
                                Text("DESCRIPTION")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary).tracking(0.5)
                                Spacer(minLength: 8)
                                Text("AMOUNT")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary).tracking(0.5)
                            }
                            .padding(.horizontal, 14).padding(.bottom, 6)
                            Divider()

                            ForEach(Array((po.lineItems ?? []).enumerated()), id: \.element.id) { idx, li in
                                collapsibleLineItem(li, currency: po.currency ?? "GBP")
                                if idx < (po.lineItems ?? []).count - 1 {
                                    Divider().padding(.leading, 14)
                                }
                            }

                            // Totals footer — when VAT is applied we break
                            // it out (Net + VAT + Gross), otherwise show just
                            // Gross Total. Net is derived as gross − VAT.
                            Divider()
                            totalsFooter
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(Color.bgRaised)
                        }
                        .background(Color.bgSurface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    // ── Last Updated By — mirrors web's bottom-left footer block ──
                    if let stampedUser = lastUpdatedUser {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("LAST UPDATED BY")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            Text(stampedUser.fullName ?? "—").font(.system(size: 14, weight: .semibold))
                            if !stampedUser.displayDesignation.isEmpty {
                                Text(stampedUser.displayDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                            }
                            if (po.updatedAt ?? 0) > 0 {
                                Text(FormatUtils.formatTimestamp(po.updatedAt ?? 0))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.bgSurface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    // Approved By
                    if !(po.approvals ?? []).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundColor(.green)
                                Text("APPROVED BY").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                                Spacer()
                            }.padding(.bottom, 2)

                            ForEach((po.approvals ?? []).sorted(by: { ($0.tierNumber ?? 0) < ($1.tierNumber ?? 0) }), id: \.id) { approval in
                                HStack(spacing: 8) {
                                    let user = UsersData.byId[approval.userId ?? ""]
                                    ZStack {
                                        Circle().fill(Color.green.opacity(0.15)).frame(width: 28, height: 28)
                                        Text(String((user?.firstName ?? "?").prefix(1)))
                                            .font(.system(size: 11, weight: .bold)).foregroundColor(.green)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(user?.fullName ?? (approval.userId ?? ""))
                                            .font(.system(size: 13, weight: .medium))
                                        if let desg = user?.displayDesignation, !desg.isEmpty {
                                            Text(desg).font(.system(size: 10)).foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Level \(approval.tierNumber ?? 0)")
                                            .font(.system(size: 9, weight: .semibold)).foregroundColor(.green)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color.green.opacity(0.1)).cornerRadius(3)
                                        if (approval.approvedAt ?? 0) > 0 {
                                            Text(FormatUtils.formatTimestamp(approval.approvedAt ?? 0))
                                                .font(.system(size: 9)).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.bgSurface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    // View PDF button
                    Button(action: { downloadPDF() }) {
                        HStack(spacing: 8) {
                            if isLoadingPDF {
                                ActivityIndicatorView()
                            } else {
                                Image(systemName: "doc.richtext").font(.system(size: 14, weight: .semibold))
                            }
                            Text(isLoadingPDF ? "Generating PDF..." : "View PDF")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(isLoadingPDF ? Color.goldDark.opacity(0.6) : Color.goldDark)
                        .cornerRadius(10)
                    }
                    .disabled(isLoadingPDF)

                    if let error = pdfError {
                        Text(error).font(.system(size: 11)).foregroundColor(.red)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.05)).cornerRadius(8)
                    }

                    // Actions
                    if canEdit || vis.canApprove || canPost || canClose {
                        Divider()
                        // Optional error banner — surfaces server errors
                        // from /post and /close without an alert so the
                        // user can try again with the context still on
                        // screen.
                        if let err = actionErrorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11)).foregroundColor(.red)
                                Text(err).font(.system(size: 11)).foregroundColor(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(8).background(Color.red.opacity(0.06)).cornerRadius(6)
                        }
                        HStack(spacing: 12) {
                            if canEdit {
                                Button(action: { navigateToEdit = true }) {
                                    HStack { Image(systemName: "pencil"); Text("Edit") }.font(.system(size: 13, weight: .semibold)).foregroundColor(.goldDark)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldDark, lineWidth: 1))
                                        .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())
                                Button(action: { appState.deleteTarget = po }) {
                                    HStack { Image(systemName: "trash"); Text("Delete") }.font(.system(size: 13, weight: .semibold)).foregroundColor(.red)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                                        .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())
                            }
                            Spacer()
                            if vis.canApprove {
                                Button(action: { appState.rejectTarget = po; appState.showRejectSheet = true }) {
                                    Text("Reject").font(.system(size: 13, weight: .bold)).foregroundColor(.red)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                                        .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())
                                Button(action: { appState.approvePO(po); onClose() }) {
                                    Text("Approve").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 8).background(Color.green).cornerRadius(8)
                                        .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())
                            }
                            // Post — APPROVED / ACCT_ENTERED → POSTED.
                            if canPost {
                                Button(action: { showPostConfirm = true }) {
                                    HStack(spacing: 4) {
                                        if isPosting { ActivityIndicatorView() }
                                        Image(systemName: "tray.and.arrow.up")
                                        Text(isPosting ? "Posting..." : "Post")
                                    }
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(isPosting ? Color.blue.opacity(0.5) : Color.blue)
                                    .cornerRadius(8).contentShape(Rectangle())
                                }
                                .disabled(isPosting)
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            // Close — POSTED → CLOSED.
                            if canClose {
                                Button(action: {
                                    closeReason = ""
                                    closeEffectiveDate = Date()
                                    showCloseSheet = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "lock")
                                        Text("Close")
                                    }
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(Color.purple).cornerRadius(8)
                                    .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())
                            }
                        }
                    }
                }.padding()
            }

            // Hidden NavigationLink — pushes PDF viewer page
            NavigationLink(
                destination: PDFViewerPage(
                    pdfData: pdfData ?? Data(),
                    fileName: "\((po.poNumber ?? "").isEmpty ? "PO" : po.poNumber ?? "PO").pdf"
                ),
                isActive: $navigateToPDF
            ) { EmptyView() }
            .hidden()

            // Hidden NavigationLink — pushes Edit PO form page
            NavigationLink(
                destination: POEditFormPage(editingPO: po).environmentObject(appState),
                isActive: $navigateToEdit
            ) { EmptyView() }
            .hidden()
        }
        // Post confirmation (native alert keeps it bottom-anchored on
        // iPhone across all iOS versions — no iOS 26 popover issues).
        .alert(isPresented: $showPostConfirm) {
            Alert(
                title: Text("Post this PO?"),
                message: Text("This marks the PO as POSTED and notifies downstream systems. You won't be able to edit it afterwards."),
                primaryButton: .default(Text("Post")) { runPost() },
                secondaryButton: .cancel()
            )
        }
        // Close form sheet — reason + effective date → POST /:id/close.
        .sheet(isPresented: $showCloseSheet) {
            closeSheetContent
        }
    }

    // MARK: - Close PO sheet body
    //
    // Bottom sheet with an effective-closing-date picker and a
    // reason field. Matches the web app's close modal: reason is
    // required-ish (validator allows empty but the UI asks for one).

    @ViewBuilder
    private var closeSheetContent: some View {
        NavigationView {
            Form {
                Section(header: Text("Effective Closing Date")) {
                    if #available(iOS 14.0, *) {
                        DatePicker("", selection: $closeEffectiveDate, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .labelsHidden()
                    } else {
                        DatePicker("", selection: $closeEffectiveDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                Section(header: Text("Reason")) {
                    if #available(iOS 14.0, *) {
                        TextEditor(text: $closeReason)
                            .frame(minHeight: 100)
                    } else {
                        TextField("Why is this PO being closed?", text: $closeReason)
                    }
                }
                if let err = actionErrorMessage {
                    Section {
                        Text(err).font(.system(size: 12)).foregroundColor(.red)
                    }
                }
            }
            .navigationBarTitle("Close PO", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { showCloseSheet = false },
                trailing: Button(action: { runClose() }) {
                    HStack(spacing: 4) {
                        if isClosing { ActivityIndicatorView() }
                        Text(isClosing ? "Closing..." : "Close PO").fontWeight(.semibold)
                    }
                }
                .disabled(isClosing || closeReason.trimmingCharacters(in: .whitespaces).isEmpty)
            )
        }
    }

    /// Fires the POST /:id/post call. On success dismisses the modal;
    /// on failure leaves the detail page open with an error banner.
    private func runPost() {
        guard !isPosting else { return }
        isPosting = true
        actionErrorMessage = nil
        appState.postPO(po) { ok, err in
            isPosting = false
            if ok { onClose() }
            else  { actionErrorMessage = err ?? "Failed to post PO." }
        }
    }

    /// Fires the POST /:id/close call. Mirrors the web app payload:
    /// `reason` required (trimmed), `effective_date` in ms since epoch.
    private func runClose() {
        guard !isClosing else { return }
        let trimmed = closeReason.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isClosing = true
        actionErrorMessage = nil
        let ms = Int64(closeEffectiveDate.timeIntervalSince1970 * 1000)
        appState.closePO(po, reason: trimmed, effectiveDate: ms) { ok, err in
            isClosing = false
            if ok {
                showCloseSheet = false
                onClose()
            } else {
                actionErrorMessage = err ?? "Failed to close PO."
            }
        }
    }

    // MARK: - Helpers: formatted delivery address + last-updated user

    /// Rich delivery-address block showing every field the PO carried:
    /// contact name (bold), full postal address (line1 / line2 / city /
    /// state / postal code / country joined), phone with country code,
    /// and email. Each part is rendered only when present so the block
    /// collapses gracefully for partial addresses.
    @ViewBuilder
    private var deliveryAddressBlock: some View {
        if let d = po.deliveryAddress {
            let addressLines = [d.line1, d.line2, d.city, d.state, d.postalCode, d.country]
                .compactMap { $0 }.filter { !$0.isEmpty }
            let phoneJoined: String = {
                let code = (d.phoneCode ?? "").trimmingCharacters(in: .whitespaces)
                let number = (d.phone ?? "").trimmingCharacters(in: .whitespaces)
                if code.isEmpty && number.isEmpty { return "" }
                if code.isEmpty { return number }
                return "\(code) \(number)"
            }()

            if addressLines.isEmpty && (d.name ?? "").isEmpty && phoneJoined.isEmpty && (d.email ?? "").isEmpty {
                Text("—").font(.system(size: 13)).foregroundColor(.primary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if let name = d.name, !name.isEmpty {
                        Text(name).font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                    }
                    if !addressLines.isEmpty {
                        Text(addressLines.joined(separator: ", "))
                            .font(.system(size: 13)).foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !phoneJoined.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "phone.fill").font(.system(size: 10)).foregroundColor(.secondary)
                            Text(phoneJoined).font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
                        }
                    }
                    if let email = d.email, !email.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill").font(.system(size: 10)).foregroundColor(.secondary)
                            Text(email).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                }
            }
        } else {
            Text("—").font(.system(size: 13)).foregroundColor(.primary)
        }
    }

    /// User behind the most recent mutation — `assignedTo` is the latest
    /// editor on the server, with fallbacks to the raiser then the owner.
    private var lastUpdatedUser: AppUser? {
        let candidate = (po.assignedTo?.isEmpty == false) ? po.assignedTo!
                      : (po.raisedBy?.isEmpty == false)   ? po.raisedBy!
                      : (po.userId ?? "")
        return UsersData.byId[candidate]
    }

    // MARK: - Totals footer (VAT / Gross)
    //
    // When `vatSummary.totalVat > 0` we show the VAT line (with rate
    // label) above the bold Gross Total so users can see how much tax
    // is baked into the gross. Net is derivable from the two but is
    // intentionally not surfaced — the web design only emphasises VAT +
    // Gross. When VAT is 0/Pending, only the Gross Total row is shown.

    @ViewBuilder
    private var totalsFooter: some View {
        let currency = po.currency ?? "GBP"
        let vat = vatSummary.totalVat
        let gross = vatSummary.grossTotal

        if vat > 0.005 {
            VStack(spacing: 6) {
                totalsRow("VAT (\(vatSummary.label))", FormatUtils.formatCurrency(vat, code: currency), bold: false)
                Divider()
                totalsRow("Gross Total", FormatUtils.formatCurrency(gross, code: currency), bold: true)
            }
        } else {
            totalsRow("Gross Total", FormatUtils.formatCurrency(gross, code: currency), bold: true)
        }
    }

    /// Single totals row — label on the left, formatted currency on the
    /// right. Gross rows render larger + goldDark to match the web's
    /// bottom-bar emphasis; net/VAT rows use the regular text colour.
    private func totalsRow(_ label: String, _ value: String, bold: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: bold ? 13 : 12, weight: bold ? .semibold : .regular))
                .foregroundColor(bold ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(.system(size: bold ? 16 : 13, weight: bold ? .bold : .semibold, design: .monospaced))
                .foregroundColor(bold ? .goldDark : .primary)
        }
    }

    // MARK: - Labelled block builder (used by the inline detail sections)
    //
    // Text is left-aligned within each block. Blocks still take
    // `maxWidth: .infinity` so two-up rows (VENDOR | DELIVERY ADDRESS,
    // AMOUNT | CURRENCY, etc.) split the width 50/50 — each half's
    // content reads from the left of its column.
    @ViewBuilder
    private func labelledBlock<Content: View>(label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            content()
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Collapsible line item
    //
    // Collapsed (default): description + amount + chevron, tappable.
    // Expanded: meta rows revealing exp type / account / dept / qty × unit
    // price / VAT. State is kept in `expandedLineItems: Set<String>` on
    // the parent view, keyed by line-item id, so each row toggles
    // independently and state survives list re-renders.

    @ViewBuilder
    private func collapsibleLineItem(_ li: LineItem, currency: String) -> some View {
        let unit = li.unitPrice ?? 0
        let qty = li.quantity ?? 0
        let amount = qty * unit
        let isExpanded = expandedLineItems.contains(li.id ?? "")

        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible) — tap anywhere on the row to toggle.
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if isExpanded { expandedLineItems.remove(li.id ?? "") }
                    else { expandedLineItems.insert(li.id ?? "") }
                }
            }) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    Text((li.description ?? "").isEmpty ? "—" : (li.description ?? ""))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(FormatUtils.formatCurrency(amount, code: currency))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if isExpanded {
                lineItemDetails(li, currency: currency)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// The revealed-on-tap section with the column-style fields.
    @ViewBuilder
    private func lineItemDetails(_ li: LineItem, currency: String) -> some View {
        let unit = li.unitPrice ?? 0
        let qty = li.quantity ?? 0
        let expType = (li.expenditureType ?? "").isEmpty ? "—" : (li.expenditureType ?? "").capitalized
        let account = (li.account ?? "").isEmpty ? "—" : (li.account ?? "")
        let deptName: String = {
            let key = li.department ?? ""
            if key.isEmpty { return "—" }
            return DepartmentsData.sorted.first { $0.id == key || $0.identifier == key }?.displayName ?? key
        }()
        let vatText = VATHelpers.vatLabel(li.vatTreatment ?? "pending")

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                lineItemCell("EXP. TYPE", expType)
                lineItemCell("ACCOUNT", account)
                lineItemCell("DEPT", deptName)
            }

            HStack(alignment: .center, spacing: 8) {
                let qtyStr = qty.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(qty))
                    : String(format: "%.2f", qty)
                Text("Qty \(qtyStr)")
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                Text("×").font(.system(size: 11)).foregroundColor(.secondary)
                Text(FormatUtils.formatCurrency(unit, code: currency))
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                Spacer()
                Text(vatText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.goldDark)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.gold.opacity(0.12)).cornerRadius(3)
            }
        }
        .padding(.horizontal, 14).padding(.top, 2).padding(.bottom, 12)
        // Align the revealed details with the description column (past
        // the leading chevron) so they visually belong to the header row.
        .padding(.leading, 22)
    }

    private func lineItemCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(.system(size: 11, weight: .medium)).foregroundColor(.primary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status Value View

    private var statusValueView: some View {
        let resolvedConfig = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId, amount: po.totalAmount)
            ?? ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId)
        let totalTiers = ApprovalHelpers.getTotalTiers(resolvedConfig)
        let approvedCount = (po.approvals ?? []).count
        let statusColor: Color = {
            if po.poStatus == .rejected { return .red }
            if po.poStatus == .approved || po.poStatus == .posted { return .green }
            if po.poStatus == .pending || po.poStatus == .acctEntered { return .goldDark }
            if po.poStatus == .draft { return .orange }
            return .gray
        }()
        let label: String = {
            if po.poStatus == .pending && totalTiers > 0 {
                return "Pending (\(approvedCount)/\(totalTiers))"
            }
            return po.poStatus.displayName
        }()
        return Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(statusColor.opacity(0.1)).cornerRadius(4)
    }

    // MARK: - Approval Flow Section

    private var approvalFlowSection: some View {
        let cfg = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId, amount: po.totalAmount)
            ?? ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId)
        let totalTiers = ApprovalHelpers.getTotalTiers(cfg)
        let approvedSet = Dictionary(grouping: po.approvals ?? [], by: { $0.tierNumber ?? 0 })

        return Group {
            if totalTiers > 0 {
                VStack(alignment: .leading, spacing: 0) {
                    // Header with pending count
                    HStack {
                        Image(systemName: "person.3.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                        Text("APPROVAL FLOW").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        Spacer()
                        if po.poStatus == .pending {
                            Text("\((po.approvals ?? []).count)/\(totalTiers) Approved")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.goldDark)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.gold.opacity(0.15)).cornerRadius(4)
                        } else if po.poStatus == .approved || po.poStatus == .acctEntered || po.poStatus == .posted {
                            Text("Fully Approved")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.green.opacity(0.1)).cornerRadius(4)
                        } else if po.poStatus == .rejected {
                            Text("Rejected")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.red.opacity(0.1)).cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

                    // Tier rows
                    if let config = cfg {
                        ForEach(1...totalTiers, id: \.self) { tierNum in
                            tierRow(tierNum: tierNum, totalTiers: totalTiers, config: config, approvedSet: approvedSet)
                        }
                    }

                    // Raised by
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.goldDark).frame(width: 22, height: 22)
                            Text(String((UsersData.byId[po.userId ?? ""]?.firstName ?? "?").prefix(1)))
                                .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Raised by").font(.system(size: 9)).foregroundColor(.secondary)
                            Text(UsersData.byId[po.userId ?? ""]?.fullName ?? (po.userId ?? ""))
                                .font(.system(size: 12, weight: .medium))
                        }
                        Spacer()
                        if (po.createdAt ?? 0) > 0 {
                            Text(FormatUtils.formatTimestamp(po.raisedAt ?? po.createdAt ?? 0)).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6).opacity(0.5))
                }
                .background(Color.bgSurface)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func tierRow(tierNum: Int, totalTiers: Int, config: LegacyTierConfig, approvedSet: [Int?: [Approval]]) -> some View {
        let entries = config[String(tierNum)] ?? []
        let tierApprovals = approvedSet[tierNum] ?? []
        let isApproved = !tierApprovals.isEmpty
        let nextTier = ApprovalHelpers.getNextTier(po: po, config: config)
        let isCurrentTier = (nextTier == tierNum) && po.poStatus == .pending
        let isRejected = po.poStatus == .rejected && !isApproved && (nextTier == nil || tierNum >= (nextTier ?? 0))

        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.horizontal, 14)

            HStack(alignment: .top, spacing: 10) {
                // Status indicator
                VStack(spacing: 0) {
                    if tierNum > 1 {
                        Rectangle().fill(isApproved ? Color.green.opacity(0.4) : Color.gray.opacity(0.2))
                            .frame(width: 2, height: 8)
                    }
                    ZStack {
                        Circle()
                            .fill(isApproved ? Color.green : isRejected ? Color.red : isCurrentTier ? Color.goldDark : Color.gray.opacity(0.3))
                            .frame(width: 22, height: 22)
                        if isApproved {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        } else if isRejected {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        } else if isCurrentTier {
                            Image(systemName: "clock").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        } else {
                            Text("\(tierNum)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    if tierNum < totalTiers {
                        Rectangle().fill(isApproved ? Color.green.opacity(0.4) : Color.gray.opacity(0.2))
                            .frame(width: 2, height: 8)
                    }
                }

                // Tier info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Level \(tierNum)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isCurrentTier ? .goldDark : .primary)
                        if isApproved {
                            Text("Approved").font(.system(size: 9, weight: .semibold)).foregroundColor(.green)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.green.opacity(0.1)).cornerRadius(3)
                        } else if isCurrentTier {
                            Text("Awaiting").font(.system(size: 9, weight: .semibold)).foregroundColor(.goldDark)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.gold.opacity(0.15)).cornerRadius(3)
                        } else if isRejected {
                            Text("Rejected").font(.system(size: 9, weight: .semibold)).foregroundColor(.red)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.red.opacity(0.1)).cornerRadius(3)
                        }
                        Spacer()
                    }

                    // Approver names
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        let user = UsersData.byId[entry.userId ?? ""]
                        let name = user?.fullName ?? entry.userId ?? "—"
                        let approved = tierApprovals.first { $0.userId == entry.userId }
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(approved != nil ? Color.green.opacity(0.15) : isCurrentTier ? Color.gold.opacity(0.15) : Color.gray.opacity(0.1))
                                    .frame(width: 20, height: 20)
                                Text(String(name.prefix(1)))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(approved != nil ? .green : isCurrentTier ? .goldDark : .secondary)
                            }
                            Text(name).font(.system(size: 11)).foregroundColor(.primary).lineLimit(1)
                            if let a = approved {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundColor(.green)
                                Text(FormatUtils.formatTimestamp(a.approvedAt ?? 0)).font(.system(size: 9)).foregroundColor(.secondary)
                            }
                        }
                    }
                }.padding(.vertical, 4)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
        }
    }

    // MARK: - PDF Download

    private func downloadPDF() {
        guard !isLoadingPDF else { return }
        isLoadingPDF = true
        pdfError = nil

        let deptMap: [String: String] = (po.lineItems ?? []).reduce(into: [:]) { map, li in
            let dept_ = li.department ?? ""
            if !dept_.isEmpty, map[dept_] == nil {
                let dept = DepartmentsData.sorted.first { $0.id == dept_ || $0.identifier == dept_ }
                map[dept_] = dept?.displayName ?? dept_
            }
        }

        let displayNames: [String: Any] = [
            "vendor": po.vendor ?? "",
            "vendorAddress": po.vendorAddress ?? "",
            "department": po.department ?? "",
            "raised_by_name": UsersData.byId[po.userId ?? ""]?.fullName ?? "",
            "departmentMap": deptMap
        ]

        let task = POCodableTask.generatePDF(po.id ?? "", displayNames) { result in
            DispatchQueue.main.async {
                self.isLoadingPDF = false
                switch result {
                case .success(let data):
                    if let data = data {
                        self.pdfData = data
                        self.navigateToPDF = true
                        debugPrint("✅ PDF generated: \(data.count) bytes")
                    }
                case .failure(let error):
                    self.pdfError = "Failed to generate PDF: \(error.localizedDescription)"
                    debugPrint("❌ PDF generation failed: \(error)")
                }
            }
        }
        pdfTask = task.urlDataTask
        pdfTask?.resume()
    }
}

// MARK: - PDF Viewer Page (Navigation push destination)
