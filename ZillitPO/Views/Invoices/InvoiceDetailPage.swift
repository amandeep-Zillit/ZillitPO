import SwiftUI
import UIKit

// MARK: - Invoice Detail Page

struct InvoiceDetailPage: View {
    let invoice: Invoice
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var navigateToHistory = false
    @State private var navigateToQueries = false
    @State private var showActionsMenu = false

    private var liveInvoice: Invoice {
        appState.invoices.first(where: { $0.id == invoice.id }) ?? invoice
    }

    var body: some View {
        InvoiceDetailContentView(invoice: liveInvoice, onClose: { presentationMode.wrappedValue.dismiss() })
            .environmentObject(appState)
            .navigationBarTitle(Text((liveInvoice.invoiceNumber ?? "").isEmpty ? "Invoice" : liveInvoice.invoiceNumber ?? ""), displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        Text("Back").font(.system(size: 16))
                    }.foregroundColor(.goldDark)
                },
                // Trailing: native SwiftUI `Menu` on iOS 14+ renders the
                // options as a dropdown popover anchored to the button.
                // iOS 13 falls back to the reusable `appDropdownMenu`
                // modifier (same AppActionSheetItem model).
                trailing: trailingMenu
            )
            .background(
                // Hidden NavigationLinks driven by the menu rows.
                ZStack {
                    NavigationLink(
                        destination: InvoiceHistoryPage(invoiceId: liveInvoice.id, invoiceLabel: (liveInvoice.invoiceNumber ?? "").isEmpty ? "Invoice" : liveInvoice.invoiceNumber ?? "").environmentObject(appState),
                        isActive: $navigateToHistory
                    ) { EmptyView() }.frame(width: 0, height: 0).hidden()
                    NavigationLink(
                        destination: InvoiceQueriesPage(invoiceId: liveInvoice.id, invoiceLabel: (liveInvoice.invoiceNumber ?? "").isEmpty ? "Invoice" : liveInvoice.invoiceNumber ?? "").environmentObject(appState),
                        isActive: $navigateToQueries
                    ) { EmptyView() }.frame(width: 0, height: 0).hidden()
                    // iOS 13 dropdown fallback — driven by the legacy
                    // button below when Menu{} isn't available.
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

    /// Trailing nav-bar trigger. iOS 14+ uses SwiftUI's native `Menu`
    /// which renders a system-styled dropdown popover anchored under
    /// the ellipsis. iOS 13 falls back to the reusable
    /// `appDropdownMenu` modifier (attached via the background ZStack
    /// above) toggled by the same button.
    @ViewBuilder
    private var trailingMenu: some View {
        if #available(iOS 14.0, *) {
            Menu {
                Button {
                    navigateToQueries = true
                } label: {
                    Label("Query", systemImage: "text.bubble")
                }
                Button {
                    navigateToHistory = true
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.goldDark)
            }
            .accessibility(label: Text("More actions"))
        } else {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showActionsMenu.toggle()
                }
            }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.goldDark)
            }
            .accessibility(label: Text("More actions"))
        }
    }
}

// MARK: - Invoice Detail Content View

struct InvoiceDetailContentView: View {
    let invoice: Invoice
    var onClose: () -> Void
    @EnvironmentObject var appState: POViewModel
    @State private var showDeleteConfirm = false
    /// Approval chain is collapsed by default — users who need to audit
    /// the tier state can expand it on demand.
    @State private var approvalChainExpanded = false

    private var vis: ApprovalVisibility { appState.invoiceApprovalVisibility(for: invoice) }
    private var canDelete: Bool {
        let uid = appState.userId
        let isOwner = invoice.userId == uid || invoice.assignedTo == uid || invoice.updatedBy == uid
        let hasNoApprovals = (invoice.approvals ?? []).isEmpty
        let terminalStates: [InvoiceStatus] = [.approved, .paid, .rejected, .voided, .override_]
        let isTerminal = terminalStates.contains(invoice.invoiceStatus)
        return isOwner && hasNoApprovals && !isTerminal
    }

    private var resolvedTierConfig: LegacyTierConfig? {
        let tiers = appState.effectiveInvoiceTierConfigs
        return ApprovalHelpers.resolveConfig(tiers, deptId: invoice.departmentId, amount: invoice.grossAmount)
            ?? ApprovalHelpers.resolveConfig(tiers, deptId: invoice.departmentId)
    }
    private var totalTiers: Int { ApprovalHelpers.getTotalTiers(resolvedTierConfig) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgSurface.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header ─────────────────────────────────────────
                    invoiceHeader
                        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

                    Divider()

                    // ── Vendor / Supplier ──────────────────────────────
                    supplierSection
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                    // ── Hold banner (kept as tinted callout) ───────────
                    if let holdReason = invoice.holdReason, !holdReason.isEmpty {
                        Divider()
                        holdBanner(reason: holdReason, note: invoice.holdNote)
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                    }

                    Divider()

                    // ── Department / Currency / Pay Method ─────────────
                    metaGrid
                        .padding(.top, 4).padding(.bottom, 4)

                    Divider()

                    // ── Gross Amount ───────────────────────────────────
                    amountsSection
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                    Divider()

                    // ── Invoice / Due / Effective dates ────────────────
                    datesGrid
                        .padding(.top, 4).padding(.bottom, 4)

                    // ── Linked POs ─────────────────────────────────────
                    if !(invoice.poIds ?? []).isEmpty || invoice.poNumber != nil || !(invoice.linkedPOs ?? []).isEmpty {
                        Divider()
                        linkedPOsSection
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                    }

                    // ── Approval chain ─────────────────────────────────
                    if invoice.invoiceStatus != .override_ {
                        Divider()
                        invoiceApprovalFlowSection
                    }

                    // ── Rejection banner (tinted callout) ──────────────
                    if let reason = invoice.rejectionReason, !reason.isEmpty {
                        Divider()
                        rejectionBanner(reason: reason)
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                    }

                    // ── Audit footer ───────────────────────────────────
                    Divider()
                    auditFooter
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, (vis.canApprove || canDelete || (invoice.status == "inbox" && appState.currentUser?.isAccountant == true)) ? 80 : 24)
            }

            // ── Pinned action bar ──────────────────────────────────────────
            VStack(spacing: 0) {
                if invoice.status == "inbox" && appState.currentUser?.isAccountant == true {
                    processInvoiceBar
                } else if vis.canApprove && canDelete {
                    // Show approve/reject + delete together
                    HStack(spacing: 10) {
                        Button(action: { showDeleteConfirm = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash").font(.system(size: 12, weight: .semibold))
                                Text("Delete").font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color(red: 0.91, green: 0.29, blue: 0.48)).cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                        Spacer()
                        Button(action: {
                            appState.rejectInvoiceTarget = invoice
                            appState.showRejectInvoiceSheet = true
                        }) {
                            Text("Reject").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 20).padding(.vertical, 10)
                                .background(Color(red: 0.91, green: 0.29, blue: 0.48)).cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                        Button(action: { appState.approveInvoice(invoice); onClose() }) {
                            Text("Approve").font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                                .padding(.horizontal, 20).padding(.vertical, 10)
                                .background(Color.gold).cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color(UIColor.systemGroupedBackground))
                    .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
                } else if vis.canApprove {
                    actionBar
                } else if canDelete {
                    deleteBar
                }
            }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text("Delete Invoice"),
                message: Text("Are you sure you want to delete invoice \((invoice.invoiceNumber ?? "").isEmpty ? "" : invoice.invoiceNumber ?? "")? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    appState.deleteInvoice(invoice)
                    onClose()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showDocumentViewer) {
            if let docURL = invoiceDocumentURL {
                InvoiceDocumentViewer(url: docURL)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill").font(.system(size: 36)).foregroundColor(.gray)
                    Text("No document available").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
                    Text("This invoice does not have an uploaded document.").font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.center)
                    Button("Close") { showDocumentViewer = false }
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.goldDark)
                        .padding(.top, 8)
                }.padding(32)
            }
        }
        .onAppear {
            // Make sure vendor + PO data is available so the supplier card
            // and "Linked POs" rows can resolve by id.
            if appState.vendors.isEmpty { appState.loadVendors() }
            if appState.purchaseOrders.isEmpty { appState.loadPOs() }
        }
    }

    // MARK: - History (kept private — used by InvoiceHistoryPage)

    private var historySection: some View {
        let entries = appState.invoiceHistory[invoice.id] ?? []
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("HISTORY").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                if appState.invoiceHistoryLoading && entries.isEmpty {
                    Spacer()
                    Text("Loading…").font(.system(size: 10)).foregroundColor(.gray)
                } else if !entries.isEmpty {
                    Spacer()
                    Text("\(entries.count)").font(.system(size: 9, weight: .semibold)).foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            if entries.isEmpty && !appState.invoiceHistoryLoading {
                Text("No history available").font(.system(size: 11)).foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.bottom, 12)
            } else {
                ForEach(entries) { entry in
                    let raw = entry.action ?? ""
                    let title: String = {
                        if raw.isEmpty { return "—" }
                        let replaced = raw.replacingOccurrences(of: "_", with: " ")
                        return replaced.prefix(1).uppercased() + replaced.dropFirst()
                    }()
                    let resolved: (name: String, role: String?) = {
                        if let uid = entry.userId, !uid.isEmpty, let u = UsersData.byId[uid] {
                            return (u.fullName ?? "", u.displayDesignation.isEmpty ? nil : u.displayDesignation)
                        }
                        if let name = entry.userName, !name.isEmpty { return (name, nil) }
                        if let uid = entry.userId, !uid.isEmpty { return (uid, nil) }
                        return ("Unknown", nil)
                    }()
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(Color.goldDark).frame(width: 8, height: 8).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.system(size: 12, weight: .semibold))
                            if let d = entry.details, !d.isEmpty {
                                Text(d).font(.system(size: 10)).foregroundColor(.secondary)
                            }
                            (
                                Text("by ").foregroundColor(.secondary)
                                + Text(resolved.name).fontWeight(.medium).foregroundColor(.goldDark)
                                + Text({
                                    if let r = resolved.role { return " (\(r))" }
                                    return ""
                                }()).foregroundColor(.secondary)
                            )
                            .font(.system(size: 10))
                            .fixedSize(horizontal: false, vertical: true)
                            if let ts = entry.timestamp, ts > 0 {
                                Text(FormatUtils.formatHistoryDateTime(ts))
                                    .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                            }
                        }
                        Spacer()
                    }.padding(.horizontal, 14).padding(.vertical, 6)
                }
                .padding(.bottom, 6)
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    /// Construct URL for viewing the uploaded invoice document.
    /// Format: <base>/uploads/<filename> — e.g.
    /// https://accounthub-dev.zillit.com/uploads/1776107650863-975643146.png
    ///
    /// Falls back to `upload_id` when no filename is present — some servers
    /// expose the file via `/uploads/<upload_id>` too. As a last resort we
    /// attempt `/api/v2/invoices/<id>/file`.
    private var invoiceDocumentURL: URL? {
        let base = APIClient.shared.baseURL

        // 1) Explicit file field (preferred)
        if let fileName = invoice.file, !fileName.isEmpty {
            if fileName.hasPrefix("http://") || fileName.hasPrefix("https://") {
                return URL(string: fileName)
            }
            let trimmed = fileName.hasPrefix("/") ? String(fileName.dropFirst()) : fileName
            // Server may return "uploads/xyz.png" already-prefixed
            if trimmed.hasPrefix("uploads/") {
                return URL(string: "\(base)/\(trimmed)")
            }
            return URL(string: "\(base)/uploads/\(trimmed)")
        }

        // 2) Fall back to upload_id — many servers let you fetch the file by id
        if let uid = invoice.uploadId, !uid.isEmpty {
            return URL(string: "\(base)/uploads/\(uid)")
        }

        // 3) Final fallback — invoice-scoped file endpoint
        return URL(string: "\(base)/api/v2/invoices/\(invoice.id)/file")
    }

    /// Whether there's any uploaded document we can try to show. The View
    /// button uses this so it still appears when the server didn't populate
    /// `file` directly but we have an `upload_id`.
    private var hasInvoiceDocument: Bool {
        if let f = invoice.file, !f.isEmpty { return true }
        if let u = invoice.uploadId, !u.isEmpty { return true }
        return false
    }

    // MARK: - Header

    @State private var showDocumentViewer = false

    private var invoiceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text((invoice.invoiceNumber ?? "").isEmpty ? "—" : invoice.invoiceNumber ?? "")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.goldDark)
            HStack(spacing: 8) {
                Text({
                    let desc = invoice.description ?? ""
                    if desc.isEmpty { return (invoice.supplierName ?? "").isEmpty ? "No description" : invoice.supplierName ?? "" }
                    if desc.hasPrefix("Invoice — ") { return String(desc.dropFirst(10)) }
                    if desc.hasPrefix("Invoice - ") { return String(desc.dropFirst(10)) }
                    return desc
                }())
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.primary)
                // Show the View button whenever we have any path to the file
                // (an explicit filename OR an upload id we can look up).
                if hasInvoiceDocument {
                    Button(action: { showDocumentViewer = true }) {
                        HStack(spacing: 3) {
                            Image(systemName: "eye.fill").font(.system(size: 10))
                            Text("View").font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.goldDark)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.gold.opacity(0.12)).cornerRadius(4)
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }
            // Status badge row
            HStack(spacing: 6) {
                if invoice.invoiceStatus != .inbox {
                    invoiceStatusBadge
                }
                if let pm = invoice.payMethod, pm == "wire" || pm == "cheque" {
                    Text("No PO · \(pm == "wire" ? "Urgent Wire" : "Cheque Request")")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(Color(red: 0.91, green: 0.29, blue: 0.48))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.1)).cornerRadius(4)
                }
            }
        }
    }

    private var invoiceStatusBadge: some View {
        let (label, fg, bg): (String, Color, Color) = {
            if invoice.invoiceStatus == .approval && totalTiers > 0 {
                return ("Pending (\((invoice.approvals ?? []).count)/\(totalTiers))", Color.goldDark, Color.gold.opacity(0.15))
            }
            switch invoice.invoiceStatus {
            case .approved, .paid: return (invoice.invoiceStatus.displayName, .green, Color.green.opacity(0.1))
            case .rejected: return (invoice.invoiceStatus.displayName, .red, Color.red.opacity(0.1))
            case .draft: return ("Pending", .goldDark, Color.gold.opacity(0.15))
            case .onHold: return (invoice.invoiceStatus.displayName, .purple, Color.purple.opacity(0.1))
            default: return (invoice.invoiceStatus.displayName, .goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .semibold)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
    }

    // MARK: - Supplier

    /// Resolve vendor live from `appState.vendors` so address/email/phone show
    /// up even if the invoice was loaded before the vendor list arrived.
    private var resolvedVendor: Vendor? {
        guard let vid = invoice.vendorId, !vid.isEmpty else { return nil }
        return appState.vendors.first { $0.id == vid }
    }

    private var supplierSection: some View {
        // Prefer live vendor data, fall back to whatever was baked into the invoice
        let v = resolvedVendor
        let name    = !(invoice.supplierName ?? "").isEmpty ? (invoice.supplierName ?? "") : (v?.name ?? "")
        let address = !(invoice.vendorAddress ?? "").isEmpty ? (invoice.vendorAddress ?? "") : (v?.address?.formatted ?? "")
        let phone: String = {
            if !(invoice.vendorPhone ?? "").isEmpty { return invoice.vendorPhone ?? "" }
            guard let v = v else { return "" }
            return "\(v.phone?.countryCode ?? "") \(v.phone?.number ?? "")".trimmingCharacters(in: .whitespaces)
        }()
        let email   = !(invoice.vendorEmail ?? "").isEmpty ? (invoice.vendorEmail ?? "") : (v?.email ?? "")
        let contact = v?.contactPerson ?? ""

        return VStack(alignment: .leading, spacing: 6) {
            Text("VENDOR").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                .tracking(0.6)
            Text(name.isEmpty ? "—" : name)
                .font(.system(size: 15, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            if !contact.isEmpty {
                Text("Contact: \(contact)")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            if !address.isEmpty {
                Text(address)
                    .font(.system(size: 12)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !phone.isEmpty || !email.isEmpty {
                HStack(alignment: .top, spacing: 16) {
                    if !phone.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PHONE").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                            Text(phone).font(.system(size: 12, weight: .medium))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !email.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("EMAIL").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                            Text(email).font(.system(size: 12, weight: .medium))
                                .lineLimit(1).truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Banners

    private func holdBanner(reason: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ON HOLD").font(.system(size: 9, weight: .bold)).foregroundColor(.purple).tracking(0.6)
            Text(reason).font(.system(size: 13, weight: .semibold)).foregroundColor(.purple)
            if let n = note, !n.isEmpty { Text(n).font(.system(size: 11)).foregroundColor(Color.purple.opacity(0.7)) }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.05)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.25), lineWidth: 1))
    }

    private func rejectionBanner(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("REJECTION REASON").font(.system(size: 9, weight: .bold)).foregroundColor(Color(red: 0.91, green: 0.29, blue: 0.48)).tracking(0.6)
            Text(reason).font(.system(size: 13)).foregroundColor(.primary)
            if let rejBy = invoice.rejectedBy, !rejBy.isEmpty {
                HStack(spacing: 4) {
                    Text("By \(UsersData.byId[rejBy].flatMap { $0.fullName } ?? rejBy)")
                    if let rejAt = invoice.rejectedAt, rejAt > 0 {
                        Text("· \(FormatUtils.formatTimestamp(rejAt))")
                    }
                }
                .font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.06)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.2), lineWidth: 1))
    }

    // MARK: - Meta Grid (Dept / Currency / Pay Method)

    private var metaGrid: some View {
        HStack(spacing: 0) {
            metaCell(label: "Department", value: (invoice.department ?? "").isEmpty ? "—" : invoice.department ?? "")
            Divider().frame(height: 44)
            metaCell(label: "Currency", value: (invoice.currency ?? "").isEmpty ? "GBP" : invoice.currency ?? "")
            Divider().frame(height: 44)
            metaCell(label: "Pay Method", value: (invoice.payMethod ?? "—").uppercased())
        }
    }

    private func metaCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            Text(value).font(.system(size: 13, weight: .semibold)).lineLimit(1)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Amounts

    private var amountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GROSS AMOUNT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            Text(FormatUtils.formatCurrency(invoice.grossAmount ?? 0, code: invoice.currency ?? ""))
                .font(.system(size: 24, weight: .bold, design: .monospaced)).foregroundColor(.primary)
            if let costCentre = invoice.costCentre, !costCentre.isEmpty {
                Text("Cost Centre: \(costCentre)").font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Dates Grid

    private var datesGrid: some View {
        HStack(spacing: 0) {
            dateCell(label: "Invoice Date", value: invoice.invoiceDate.flatMap { $0 > 0 ? FormatUtils.formatTimestamp($0) : nil } ?? "—")
            Divider().frame(height: 44)
            dateCell(label: "Due Date", value: invoice.dueDate.flatMap { $0 > 0 ? FormatUtils.formatTimestamp($0) : nil } ?? "—", overdue: invoice.isOverdue ?? false)
            Divider().frame(height: 44)
            dateCell(label: "Effective Date", value: invoice.effectiveDate.flatMap { $0 > 0 ? FormatUtils.formatTimestamp($0) : nil } ?? "—")
        }
    }

    private func dateCell(label: String, value: String, overdue: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            HStack(spacing: 4) {
                Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(overdue ? .red : .primary).lineLimit(1)
                if overdue { Text("OVERDUE").font(.system(size: 7, weight: .bold)).foregroundColor(.red)
                    .padding(.horizontal, 4).padding(.vertical, 1).background(Color.red.opacity(0.1)).cornerRadius(2) }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Linked POs

    /// Row model used in the linked-POs section. Prefers the rich
    /// `linked_pos` summary from the backend (po_number + vendor name +
    /// gross total) and falls back to a lookup on `invoice.poIds`.
    private struct LinkedPORow: Identifiable {
        let id: String
        let poNumber: String
        let vendorName: String
        let amount: Double?
        let currency: String
    }

    private var linkedPORows: [LinkedPORow] {
        // 1) Prefer the rich backend summary if present.
        if !(invoice.linkedPOs ?? []).isEmpty {
            return (invoice.linkedPOs ?? []).map { lp in
                // Fall back to appState lookup if the backend didn't resolve
                // the vendor name (e.g. the vendor list on backend is stale).
                var vendor = lp.poVendorName ?? ""
                if vendor.isEmpty, !((lp.poVendorId ?? "").isEmpty),
                   let v = appState.vendors.first(where: { $0.id == lp.poVendorId }) {
                    vendor = v.name ?? ""
                }
                return LinkedPORow(
                    id: lp.id,
                    poNumber: (lp.poNumber ?? "").isEmpty ? "PO-\(String((lp.poId ?? "").suffix(8)).uppercased())" : lp.poNumber ?? "",
                    vendorName: vendor,
                    amount: (lp.poGrossTotal ?? 0) > 0 ? lp.poGrossTotal : nil,
                    currency: lp.currency ?? ""
                )
            }
        }
        // 2) Fall back to the flat po_ids array + PO lookup.
        var rows: [LinkedPORow] = (invoice.poIds ?? []).compactMap { id in
            guard !id.isEmpty else { return nil }
            if let po = appState.purchaseOrders.first(where: { $0.id == id }) {
                let vendor = (po.vendor ?? "").isEmpty
                    ? (po.vendorId.flatMap { vid in appState.vendors.first { $0.id == vid }?.name } ?? "")
                    : po.vendor ?? ""
                // `po.grossTotal` is optional; only surface it when we have
                // a positive value to show.
                let amt: Double? = {
                    if let g = po.grossTotal, g > 0 { return g }
                    return nil
                }()
                return LinkedPORow(
                    id: id,
                    poNumber: (po.poNumber ?? "").isEmpty ? "PO-\(String(id.suffix(8)).uppercased())" : po.poNumber ?? "",
                    vendorName: vendor,
                    amount: amt,
                    currency: po.currency ?? ""
                )
            }
            let short = "PO-\(String(id.suffix(8)).uppercased())"
            return LinkedPORow(id: id, poNumber: short, vendorName: "", amount: nil, currency: invoice.currency ?? "")
        }
        // 3) Legacy single-PO fallback
        if rows.isEmpty, let p = invoice.poNumber, !p.isEmpty {
            rows = [LinkedPORow(id: p, poNumber: p, vendorName: invoice.supplierName ?? "", amount: nil, currency: invoice.currency ?? "")]
        }
        return rows
    }

    private var linkedPOsSection: some View {
        let items = linkedPORows
        return VStack(alignment: .leading, spacing: 10) {
            Text("LINKED POS (\(items.count))")
                .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.8)
            ForEach(items) { row in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.poNumber)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        if !row.vendorName.isEmpty {
                            Text(row.vendorName)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    if let amt = row.amount {
                        Text(FormatUtils.formatCurrency(amt, code: row.currency))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.bgRaised)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LINE ITEMS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
            ForEach(invoice.lineItems ?? [], id: \.id) { li in
                HStack {
                    Text(li.description ?? "").font(.system(size: 12)).lineLimit(1)
                    Spacer()
                    Text("×\(Int(li.quantity ?? 0))").font(.system(size: 11)).foregroundColor(.secondary)
                    Text(FormatUtils.formatCurrency((li.quantity ?? 0) * (li.unitPrice ?? 0), code: invoice.currency ?? ""))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                Divider().padding(.horizontal, 14)
            }
            HStack {
                Spacer()
                Text("Total: ").font(.system(size: 13, weight: .semibold))
                Text(FormatUtils.formatCurrency(invoice.grossAmount ?? 0, code: invoice.currency ?? ""))
                    .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }.padding(.horizontal, 14).padding(.vertical, 8)
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Audit Footer

    private var auditFooter: some View {
        let creator = invoice.userId.flatMap { UsersData.byId[$0] }
        let updater = invoice.updatedBy.flatMap { UsersData.byId[$0] }
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CREATED BY").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                Text(creator.flatMap { $0.fullName } ?? "—").font(.system(size: 13, weight: .semibold))
                if let d = creator?.displayDesignation, !d.isEmpty {
                    Text(d).font(.system(size: 10)).foregroundColor(.secondary)
                }
                if let ca = invoice.createdAt, ca > 0 {
                    Text(FormatUtils.formatDateTime(ca)).font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let ua = invoice.updatedAt, ua > 0 {
                Divider().frame(height: 54).padding(.horizontal, 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("UPDATED BY").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    Text(updater.flatMap { $0.fullName } ?? invoice.updatedBy ?? "—").font(.system(size: 13, weight: .semibold))
                    if let d = updater?.displayDesignation, !d.isEmpty {
                        Text(d).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Text(FormatUtils.formatDateTime(ua)).font(.system(size: 10)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let assignedTo = invoice.assignedTo, !assignedTo.isEmpty, let assignee = UsersData.byId[assignedTo] {
                Divider().frame(height: 54).padding(.horizontal, 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ASSIGNED TO").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    Text(assignee.fullName ?? "").font(.system(size: 13, weight: .semibold))
                    if !assignee.displayDesignation.isEmpty {
                        Text(assignee.displayDesignation).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Spacer()
            Button(action: {
                appState.rejectInvoiceTarget = invoice
                appState.showRejectInvoiceSheet = true
            }) {
                Text("Reject").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color(red: 0.91, green: 0.29, blue: 0.48)).cornerRadius(8)
            }.buttonStyle(BorderlessButtonStyle())

            Button(action: { appState.approveInvoice(invoice); onClose() }) {
                Text("Approve").font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.gold).cornerRadius(8)
            }.buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(UIColor.systemGroupedBackground))
        .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
    }

    // MARK: - Process Invoice Bar (Accounts team: inbox → approval)

    private var processInvoiceBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("INBOX").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(1)
                Text("Send to approval chain").font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { appState.processInvoice(invoice); onClose() }) {
                Text("Send to Approval").font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.gold).cornerRadius(8)
            }.buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(UIColor.systemGroupedBackground))
        .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
    }

    // MARK: - Delete Bar (creator, pending invoices only)

    private var deleteBar: some View {
        HStack(spacing: 10) {
            Spacer()
            Button(action: { showDeleteConfirm = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash").font(.system(size: 12, weight: .semibold))
                    Text("Delete Invoice").font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Color(red: 0.91, green: 0.29, blue: 0.48)).cornerRadius(8)
            }.buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(UIColor.systemGroupedBackground))
        .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
    }

    // MARK: - Approval Flow Section

    private var invoiceApprovalFlowSection: some View {
        let tiers = appState.effectiveInvoiceTierConfigs
        let cfg = ApprovalHelpers.resolveConfig(tiers, deptId: invoice.departmentId, amount: invoice.grossAmount)
            ?? ApprovalHelpers.resolveConfig(tiers, deptId: invoice.departmentId)
        let totalTiers = ApprovalHelpers.getTotalTiers(cfg)
        let approvedSet = Dictionary(grouping: invoice.approvals ?? [], by: { $0.tierNumber ?? 0 })

        return Group {
            if totalTiers > 0 {
                VStack(alignment: .leading, spacing: 0) {
                    // Collapsible header — tapping toggles the tier list.
                    // Closed by default so the detail page stays compact.
                    Button(action: { approvalChainExpanded.toggle() }) {
                        HStack {
                            Image(systemName: "person.3.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                            Text("APPROVAL CHAIN").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            Spacer()
                            if invoice.invoiceStatus == .approved || invoice.invoiceStatus == .paid {
                                Text("Fully Approved")
                                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.green)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.green.opacity(0.1)).cornerRadius(4)
                            } else if invoice.invoiceStatus == .rejected {
                                Text("Rejected")
                                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.red)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.red.opacity(0.1)).cornerRadius(4)
                            }
                            // Chevron indicates collapsed/expanded state
                            Image(systemName: approvalChainExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

                    // Tier rows — only rendered when expanded.
                    if approvalChainExpanded, let config = cfg {
                        ForEach(1...totalTiers, id: \.self) { tierNum in
                            invoiceTierRow(tierNum: tierNum, totalTiers: totalTiers, config: config, approvedSet: approvedSet)
                        }
                    }
                }
                .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private func invoiceTierRow(tierNum: Int, totalTiers: Int, config: LegacyTierConfig, approvedSet: [Int: [Approval]]) -> some View {
        let entries = config[String(tierNum)] ?? []
        let tierApprovals = approvedSet[tierNum] ?? []
        let isFullyApproved = invoice.invoiceStatus == .approved || invoice.invoiceStatus == .paid
        let isApproved = !tierApprovals.isEmpty || isFullyApproved

        let fakePO: PurchaseOrder = {
            var po = PurchaseOrder()
            po.id = invoice.id; po.userId = invoice.userId; po.status = invoice.status
            po.departmentId = invoice.departmentId; po.approvals = invoice.approvals ?? []
            po.netAmount = invoice.grossAmount
            return po
        }()

        let nextTier = ApprovalHelpers.getNextTier(po: fakePO, config: config)
        let isCurrentTier = (nextTier == tierNum) && invoice.invoiceStatus == .approval
        let isRejected = invoice.invoiceStatus == .rejected && !isApproved && (nextTier == nil || tierNum >= (nextTier ?? 0))

        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.horizontal, 14)
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 0) {
                    if tierNum > 1 {
                        Rectangle().fill(isApproved ? Color.green.opacity(0.4) : Color.gray.opacity(0.2)).frame(width: 2, height: 8)
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
                        Rectangle().fill(isApproved ? Color.green.opacity(0.4) : Color.gray.opacity(0.2)).frame(width: 2, height: 8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Level \(tierNum)").font(.system(size: 12, weight: .semibold))
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

                    if isApproved {
                        if !tierApprovals.isEmpty {
                            // Show actual approvers with timestamps
                            ForEach(tierApprovals) { approval in
                                let approverUser = UsersData.byId[approval.userId ?? ""]
                                let approverName = approverUser.flatMap { $0.fullName } ?? approval.userId ?? ""
                                HStack(spacing: 6) {
                                    ZStack {
                                        Circle().fill(Color.green.opacity(0.15)).frame(width: 20, height: 20)
                                        Text(String(approverName.prefix(1))).font(.system(size: 9, weight: .semibold)).foregroundColor(.green)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(approverName).font(.system(size: 11)).foregroundColor(.primary).lineLimit(1)
                                        if let designation = approverUser?.displayDesignation, !designation.isEmpty {
                                            Text(designation).font(.system(size: 9)).foregroundColor(.secondary).lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundColor(.green)
                                    Text(FormatUtils.formatTimestamp(approval.approvedAt ?? 0)).font(.system(size: 9)).foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // Fully approved but no explicit entry — show config users as approved
                            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                                let user = UsersData.byId[entry.userId ?? ""]
                                let name = user.flatMap { $0.fullName } ?? entry.userId ?? ""
                                HStack(spacing: 6) {
                                    ZStack {
                                        Circle().fill(Color.green.opacity(0.15)).frame(width: 20, height: 20)
                                        Text(String(name.prefix(1))).font(.system(size: 9, weight: .semibold)).foregroundColor(.green)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(name).font(.system(size: 11)).foregroundColor(.primary).lineLimit(1)
                                        if let designation = user?.displayDesignation, !designation.isEmpty {
                                            Text(designation).font(.system(size: 9)).foregroundColor(.secondary).lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundColor(.green)
                                }
                            }
                        }
                    } else {
                        // Show only "Awaiting" — no names until approved
                        Text("Awaiting")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(.vertical, 4)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
        }
    }
}
