import SwiftUI
import UIKit
import WebKit

// MARK: - Invoice Tab Enum

enum InvoiceTab: String, CaseIterable, Identifiable {
    case all = "All Invoices"
    case department = "My Department"
    case my = "My Invoices"
    var id: String { rawValue }
}

enum InvoiceFilter: String, CaseIterable {
    case all = "All", pending = "Pending", approved = "Approved", rejected = "Rejected"
}


// MARK: - Invoices Module View

struct InvoicesModuleView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var searchText = ""
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var navigateToUpload = false
    @State private var navigateToDetail = false
    @State private var navigateToPaymentRunApproval = false
    @State private var selectedInvoiceForDetail: Invoice?

    /// Non-accountants see "Approval Queue" (server-filtered via the
    /// `/approval` endpoint) instead of "All Invoices" — matches the
    /// PO-side pattern in `DepartmentPOModule.swift`. Accountants
    /// keep "All Invoices" because they hit the generic list endpoint.
    private var isAccountant: Bool { appState.currentUser?.isAccountant == true }
    private func tabLabel(_ tab: InvoiceTab) -> String {
        if tab == .all && !isAccountant { return "Approval Queue" }
        return tab.rawValue
    }

    /// Dispatches to the right loader for the currently-active tab +
    /// user role. Called on tab tap and `.onAppear`; every
    /// post-mutation refresh on the VM side also flows through the
    /// equivalent `refreshCurrentInvoiceTab()` helper.
    ///
    ///   • All Invoices (accountant)      → `loadInvoices()`
    ///   • Approval Queue (non-accountant) → `loadApprovalQueueInvoices()`
    ///   • My Invoices                    → `loadMyInvoices()`
    ///   • My Department                  → `loadDepartmentInvoices()`
    private func loadForCurrentInvoiceTab() {
        switch appState.activeInvoiceTab {
        case .all:
            if isAccountant { appState.loadInvoices() }
            else            { appState.loadApprovalQueueInvoices() }
        case .my:
            appState.loadMyInvoices()
        case .department:
            appState.loadDepartmentInvoices()
        }
    }

    // MARK: - Filtered Invoices

    private var filteredInvoices: [Invoice] {
        var list = appState.invoices

        // Each tab populates `invoices` from its own server-filtered
        // endpoint, so the client can render the list as-is. The
        // only path that still needs a client-side pass is the
        // accountant's "All Invoices" tab (generic list endpoint),
        // which still gets the `isInvoiceVisible` scope narrowing.
        switch appState.activeInvoiceTab {
        case .all:
            if isAccountant { list = list.filter { isInvoiceVisible($0) } }
        case .my, .department:
            break     // server already filtered via /my or ?department_id=
        }

        // Quick filter now mirrors the web (DepartmentInvoiceModule.jsx):
        // the pending / approved / rejected buttons key off the invoice
        // record's `approval_status` field, not the workflow `status`.
        // A missing `approval_status` is treated as "pending" — matches
        // the web fallback `(inv.approval_status || "pending")`.
        switch selectedFilter {
        case .pending:
            list = list.filter { ($0.approvalStatus ?? "pending").lowercased() == "pending" }
        case .approved:
            list = list.filter { ($0.approvalStatus ?? "").lowercased() == "approved" }
        case .rejected:
            list = list.filter { ($0.approvalStatus ?? "").lowercased() == "rejected" }
        case .all:
            break
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                ($0.invoiceNumber ?? "").lowercased().contains(q) ||
                ($0.supplierName ?? "").lowercased().contains(q) ||
                ($0.description ?? "").lowercased().contains(q)
            }
        }

        return list.sorted { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }
    }

    private func isInvoiceVisible(_ inv: Invoice) -> Bool {
        guard let u = appState.currentUser else { return false }
        // Creator always sees their own invoices
        if inv.userId == u.id { return true }
        // Inbox invoices: only accounts team can see them (to process)
        if inv.status == "inbox" {
            return u.isAccountant
        }
        if (inv.departmentId ?? "") == u.departmentId { return true }
        if (inv.approvals ?? []).contains(where: { $0.userId == u.id }) { return true }
        if inv.assignedTo == u.id { return true }
        let vis = appState.invoiceApprovalVisibility(for: inv)
        return vis.visible
    }

    private var invoiceTabCounts: [InvoiceTab: Int] {
        // Each tab loads its own server-filtered data, so only the
        // currently-active tab has a meaningful count — the cached
        // values for other tabs would reflect whichever endpoint
        // last ran. Match the PO-side approach: return a count for
        // `activeInvoiceTab` only.
        guard appState.currentUser != nil else { return [:] }
        let tab = appState.activeInvoiceTab
        let count: Int
        switch tab {
        case .all:
            count = isAccountant
                ? appState.invoices.filter { isInvoiceVisible($0) }.count
                : appState.invoices.count
        case .my, .department:
            count = appState.invoices.count
        }
        return [tab: count]
    }

    private var pendingPaymentRunCount: Int {
        let uid = appState.userId
        let sortedAuth = appState.invoiceRunAuth.sorted { ($0.tier ?? 0) < ($1.tier ?? 0) }
        return appState.paymentRuns.filter { run in
            guard run.isPending else { return false }
            if sortedAuth.isEmpty { return true }
            let nextLevel = sortedAuth.first { level in
                !(run.approval ?? []).contains { $0.tierNumber == level.tier }
            }
            return nextLevel?.user?.contains(uid) == true
        }.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                tabBar

                // Accountant-only informational banner on the "All
                // Invoices" tab. Flags that the full accountant
                // workflow (match / hold / post / override / coding /
                // payment runs) lives on Zillit web.
                if appState.activeInvoiceTab == .all && isAccountant {
                    accountantWebFeaturesBanner
                        .padding(.horizontal, 16).padding(.top, 10)
                }

                // Search + Filter
                if appState.isRunAuthApprover {
                    VStack(spacing: 8) {
                        filterBar
                        searchBar
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                } else {
                    // No payment-run button → use the bare filter button
                    // (no Spacer) so the search field can claim every
                    // remaining pixel of the row.
                    HStack(spacing: 8) {
                        searchBar
                        filterButton
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                }
                ScrollView {
                    // Show the loader on every per-tab fetch — matches
                    // the PO-side pattern (`DepartmentPOModule`). The
                    // list data is completely replaced each time a tab
                    // switches, so hiding the previous data while the
                    // new endpoint resolves keeps the UI honest.
                    if appState.isLoadingInvoices {
                        LoaderView()
                            .padding(.top, 60)
                            .frame(maxWidth: .infinity)
                    } else if filteredInvoices.isEmpty {
                        emptyState.padding(.top, 20)
                    } else {
                        invoiceList.padding(.top, 8)
                    }
                }.padding(.horizontal, 16).padding(.bottom, 16)
            }

            Button(action: { navigateToUpload = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Upload Invoice").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.gold).cornerRadius(28)
            }
            .padding(.trailing, 20).padding(.bottom, 24)
        }
        .background(
            Group {
                NavigationLink(destination: UploadInvoicePage().environmentObject(appState), isActive: $navigateToUpload) { EmptyView() }
                    .frame(width: 0, height: 0).hidden()
                NavigationLink(destination: Group {
                    if let inv = selectedInvoiceForDetail {
                        InvoiceDetailPage(invoice: inv).environmentObject(appState)
                    } else { EmptyView() }
                }, isActive: $navigateToDetail) { EmptyView() }
                    .frame(width: 0, height: 0).hidden()
                NavigationLink(destination: PaymentRunApprovalPage().environmentObject(appState), isActive: $navigateToPaymentRunApproval) { EmptyView() }
                    .frame(width: 0, height: 0).hidden()
            }
        )
        .sheet(isPresented: $appState.showRejectInvoiceSheet) {
            RejectInvoiceSheetView().environmentObject(appState)
        }
        .sheet(isPresented: $appState.showRejectPaymentRunSheet) {
            RejectPaymentRunSheetView().environmentObject(appState)
        }
        .navigationBarTitle(Text("Invoices"), displayMode: .inline)
        .onAppear {
            // Reset search on re-appear (e.g. after returning from a tapped row)
            searchText = ""
            // Initial fetch honours the current tab + role so a
            // non-accountant on the Approval Queue tab doesn't flash
            // the generic list before the per-tab call fires.
            // Payment runs are loaded lazily by the Payment Run tab / page when opened.
            loadForCurrentInvoiceTab()
            if appState.vendors.isEmpty { appState.loadVendors() }
            if appState.invoiceTierConfigRows.isEmpty { appState.loadInvoiceApprovalTiers() }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(InvoiceTab.allCases) { tab in invoiceTabButton(tab) }
        }
        .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)
    }

    private func invoiceTabButton(_ tab: InvoiceTab) -> some View {
        let isActive = appState.activeInvoiceTab == tab
        return Button(action: {
            appState.activeInvoiceTab = tab
            selectedFilter = .all
            // Each tap re-fetches the tab's dedicated endpoint so the
            // loader flashes and the list stays authoritative for
            // whichever tab is active.
            loadForCurrentInvoiceTab()
        }) {
            HStack(spacing: 4) {
                Text(tabLabel(tab)).font(.system(size: 12, weight: isActive ? .semibold : .regular)).lineLimit(1)
                if let count = invoiceTabCounts[tab] {
                    Text("\(count)").font(.system(size: 9, design: .monospaced))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(isActive ? Color.gold.opacity(0.2) : Color.bgRaised).cornerRadius(10)
                }
            }
            .foregroundColor(isActive ? .goldDark : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .overlay(isActive ? Rectangle().fill(Color.goldDark).frame(height: 2) : nil, alignment: .bottom)
        }.buttonStyle(BorderlessButtonStyle())
    }

    @State private var showFilterSheet = false

    /// Filter button alone — sized to its content, no Spacer. Used by
    /// both layouts so the inline (no-approver) row doesn't inherit a
    /// width-stealing Spacer from the multi-button approver row.
    private var filterButton: some View {
        Button(action: { showFilterSheet = true }) {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                Text(selectedFilter.rawValue)
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            .background(Color.bgSurface).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .selectionActionSheet(
            title: "Filter by Status",
            isPresented: $showFilterSheet,
            options: InvoiceFilter.allCases,
            isSelected: { $0 == selectedFilter },
            label: { $0.rawValue },
            onSelect: { selectedFilter = $0 }
        )
    }

    /// Two-row layout — Filter + Payment Run Approval on top, Search
    /// below — used when the current user is a payment-run approver.
    private var filterBar: some View {
        HStack(spacing: 6) {
            filterButton

            Spacer()

            // Payment Run Approval button (right)
            if appState.isRunAuthApprover {
                Button(action: { navigateToPaymentRunApproval = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "banknote").font(.system(size: 10, weight: .medium))
                        Text("Payment Run Approval").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        if pendingPaymentRunCount > 0 {
                            Text("\(pendingPaymentRunCount)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.goldDark).cornerRadius(8)
                        }
                    }
                    .foregroundColor(.goldDark)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.bgSurface).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
            TextField("Search invoices…", text: $searchText).font(.system(size: 14))
        }
        .padding(10).background(Color.bgSurface).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
        .frame(maxWidth: .infinity)
    }

    /// Informational banner shown to accountants on the All Invoices
    /// tab. The mobile app intentionally keeps only the core
    /// approve/reject flow — match / hold / post / override / coding
    /// queues / payment run authorisation / supplier settings all
    /// live on Zillit web. The banner surfaces that so accountants
    /// don't go looking for those buttons on the phone.
    private var accountantWebFeaturesBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.goldDark)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("More accountant features on Zillit web")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Matching, hold, post-to-ledger, coding queue and payment run authorisation live on the web app.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.gold.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gold.opacity(0.3), lineWidth: 1))
    }

    private var statsCards: some View {
        let list = filteredInvoices
        let total = list.count
        let pending = list.filter { $0.invoiceStatus == .approval }.count
        let approved = list.filter { $0.invoiceStatus == .approved }.count
        let totalValue = list.reduce(0.0) { $0 + ($1.grossAmount ?? 0) }

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatCard(title: "Total", value: "\(total)", color: .blue)
                StatCard(title: "Pending", value: "\(pending)", color: .orange)
            }
            HStack(spacing: 10) {
                StatCard(title: "Approved", value: "\(approved)", color: .green)
                StatCard(title: "Value", value: FormatUtils.formatGBP(totalValue), color: .goldDark)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
            Text("No invoices found").font(.system(size: 13)).foregroundColor(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 480)
    }

    private var invoiceList: some View {
        VStack(spacing: 0) {
            ForEach(filteredInvoices, id: \.id) { invoice in
                Button(action: {
                    selectedInvoiceForDetail = invoice
                    navigateToDetail = true
                }) {
                    InvoiceRow(invoice: invoice, showApprovalInfo: true, appState: appState)
                }.buttonStyle(BorderlessButtonStyle())
                Divider().padding(.horizontal, 12)
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

// MARK: - Invoice Row

struct InvoiceRow: View {
    let invoice: Invoice
    var showApprovalInfo: Bool = false
    var appState: POViewModel? = nil
    var onViewFile: (() -> Void)? = nil

    /// Display name: use supplier name, fall back to description stripped of "Invoice — " prefix
    private var displayName: String {
        if !(invoice.supplierName ?? "").isEmpty { return invoice.supplierName ?? "" }
        if let desc = invoice.description, !desc.isEmpty {
            if desc.hasPrefix("Invoice — ") { return String(desc.dropFirst(10)) }
            if desc.hasPrefix("Invoice - ") { return String(desc.dropFirst(10)) }
            return desc
        }
        return "—"
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text((invoice.invoiceNumber ?? "").isEmpty ? "—" : invoice.invoiceNumber ?? "")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.goldDark)
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary).lineLimit(1)
                    if onViewFile != nil {
                        Button(action: { onViewFile?() }) {
                            Text("View")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.goldDark)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.gold.opacity(0.12)).cornerRadius(4)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
                if let poNum = invoice.poNumber, !poNum.isEmpty {
                    Text("PO: \(poNum)").font(.system(size: 9, weight: .medium)).foregroundColor(.blue.opacity(0.7))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(FormatUtils.formatCurrency(invoice.grossAmount ?? 0, code: invoice.currency ?? ""))
                    .font(.system(size: 13, design: .monospaced))
                invoiceStatusBadge
                if let due = invoice.dueDate, due > 0 {
                    HStack(spacing: 2) {
                        if invoice.isOverdue ?? false {
                            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 8)).foregroundColor(.red)
                        }
                        Text("Due: \(FormatUtils.formatTimestamp(due))")
                            .font(.system(size: 9)).foregroundColor((invoice.isOverdue ?? false) ? .red : .secondary)
                    }
                }
            }
        }
        .padding(12).contentShape(Rectangle())
    }

    /// Role-aware status badge. Mirrors the web which renders two
    /// different badges for the same invoice depending on which
    /// module is looking at it:
    ///
    ///   • `DepartmentInvoiceModule.jsx` (non-accountant) treats
    ///     `status === "override"` as a green "Approved" pill — the
    ///     raiser just cares that the invoice cleared.
    ///   • `ApprovalPage.jsx` (accountant) treats `override` as a
    ///     distinct pink "Override" pill so accounts can spot rows
    ///     that went through the override escape hatch.
    ///   • `EntryPage.jsx` (accountant) labels `approved` /
    ///     `override` → "Ready" (green) and `under_review` → "Under
    ///     Review" (blue) — these states don't exist for end users.
    ///
    /// iOS uses one unified list, so we branch on
    /// `appState.currentUser?.isAccountant` to pick the right
    /// labelling scheme.
    @ViewBuilder
    private var invoiceStatusBadge: some View {
        let approvalStatus = (invoice.approvalStatus ?? "").lowercased()
        let rawStatus      = (invoice.status ?? "").lowercased()
        let payMethod      = (invoice.payMethod ?? "").lowercased()
        let isAccountant   = appState?.currentUser?.isAccountant == true

        // Urgent payment override — rendered on both sides as a pink
        // "Urgent Wire / Cheque / Faster" pill. Accountants spot
        // these quickly in their queue; raisers see them on the
        // detail header pink strip (so this branch here is mostly
        // for accountants, but behaves consistently regardless).
        if rawStatus == "override" && (payMethod == "wire" || payMethod == "cheque" || payMethod == "faster") {
            StatusBadge(urgentPaymentLabel(payMethod), color: .pink)
        }
        // Accountant-only: plain (non-urgent-payment) override shows
        // as a distinct pink "Override" chip so it's not lumped in
        // with normal approvals.
        else if isAccountant && rawStatus == "override" {
            StatusBadge("Override", color: .pink)
        }
        // Approved (non-override) — green on both sides. Non-accountant
        // also gets green for `override` here because the first two
        // branches covered the accountant case.
        else if approvalStatus == "approved" || rawStatus == "approved" || rawStatus == "override" {
            StatusBadge("Approved", color: .green)
        }
        // Rejected
        else if approvalStatus == "rejected" || rawStatus == "rejected" {
            StatusBadge("Rejected", color: .red)
        }
        // Pending with tier progress — "Pending (X/Y)" amber when we
        // know the approval chain context (matches DepartmentInvoice
        // Module.jsx exactly).
        else if rawStatus == "approval",
                showApprovalInfo,
                let state = appState,
                state.invoiceApprovalVisibility(for: invoice).totalTiers > 0 {
            let vis = state.invoiceApprovalVisibility(for: invoice)
            StatusBadge("Pending (\(vis.approvedCount)/\(vis.totalTiers))", color: .amber)
        }
        // Approval without tier context — e.g. an accountant viewing
        // an invoice they're not in the approval chain for. Fall
        // back to a neutral grey "Pending" pill since we can't
        // accurately report progress.
        else if rawStatus == "approval" {
            StatusBadge("Pending", color: .gray)
        }
        // Accountant-only post-approval workflow stages (EntryPage.jsx
        // + web INVOICE_STATUS_MAP).
        else if isAccountant && rawStatus == "under_review" {
            StatusBadge("Under Review", color: .blue)
        }
        else if isAccountant && rawStatus == "ready_to_pay" {
            StatusBadge("Ready to Pay", color: .teal)
        }
        // Canonical labels from the web's INVOICE_STATUS_MAP — with
        // the understanding that the final fallback is always a
        // neutral grey "Pending" pill so we never claim more progress
        // than we can verify.
        else {
            switch invoice.invoiceStatus {
            case .inbox:          StatusBadge("Inbox", color: .purple)
            case .paid:           StatusBadge("Paid", color: .green)
            case .partiallyPaid:  StatusBadge("Partially Paid", color: .blue)
            case .onHold:         StatusBadge("On Hold", color: .amber)
            case .voided:         StatusBadge("Cancelled", color: .gray)
            case .underReview:    StatusBadge("Under Review", color: .blue)
            case .readyToPay:     StatusBadge("Ready to Pay", color: .teal)
            default:              StatusBadge("Pending", color: .gray)
            }
        }
    }

    /// Human-readable label for the three payment methods that trigger
    /// the urgent-override flow. Mirrors the web's inline ternary on
    /// ApprovalPage.jsx.
    private func urgentPaymentLabel(_ pm: String) -> String {
        switch pm {
        case "wire":   return "Urgent Wire Request"
        case "cheque": return "Cheque Request"
        case "faster": return "Faster Payment"
        default:       return pm
        }
    }
}
