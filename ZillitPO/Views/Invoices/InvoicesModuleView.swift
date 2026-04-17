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
    @State private var activeTab: InvoiceTab = .all
    @State private var navigateToUpload = false
    @State private var navigateToDetail = false
    @State private var navigateToPaymentRunApproval = false
    @State private var selectedInvoiceForDetail: Invoice?

    // MARK: - Filtered Invoices

    private var filteredInvoices: [Invoice] {
        guard let user = appState.currentUser else { return [] }
        var list = appState.invoices

        switch activeTab {
        case .all:       list = list.filter { isInvoiceVisible($0) }
        case .department: list = list.filter { ($0.departmentId ?? "") == (user.departmentId ?? "") && $0.userId != user.id }
        case .my:        list = list.filter { $0.userId == user.id }
        }

        switch selectedFilter {
        case .pending:  list = list.filter { $0.invoiceStatus == .approval || $0.invoiceStatus == .inbox || $0.invoiceStatus == .draft }
        case .approved: list = list.filter { $0.invoiceStatus == .approved }
        case .rejected: list = list.filter { $0.invoiceStatus == .rejected }
        case .all: break
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
        guard let user = appState.currentUser else { return [:] }
        return [
            .all: appState.invoices.filter { isInvoiceVisible($0) }.count,
            .department: appState.invoices.filter { ($0.departmentId ?? "") == (user.departmentId ?? "") && $0.userId != user.id }.count,
            .my: appState.invoices.filter { $0.userId == user.id }.count
        ]
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
                    // Show the loader whenever an invoices fetch is in-flight
                    // AND we don't already have data on screen, OR during the
                    // initial app-wide load (`isLoading`). This way tapping
                    // the Invoices tile from the sidebar triggers the loader
                    // even if loadAllData didn't run first.
                    if (appState.isLoadingInvoices || appState.isLoading) && appState.invoices.isEmpty {
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
            // Invoices page only loads its own data: invoices + settings (for approver badge).
            // Payment runs are loaded lazily by the Payment Run tab / page when opened.
            appState.loadInvoices()
            appState.loadInvoiceSettings()
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
        let isActive = activeTab == tab
        return Button(action: { activeTab = tab; selectedFilter = .all }) {
            HStack(spacing: 4) {
                Text(tab.rawValue).font(.system(size: 12, weight: isActive ? .semibold : .regular)).lineLimit(1)
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

    private var invoiceStatusBadge: some View {
        let label: String
        let colors: (Color, Color)

        if let state = appState, showApprovalInfo {
            let vis = state.invoiceApprovalVisibility(for: invoice)
            if invoice.invoiceStatus == .approval && vis.totalTiers > 0 {
                let l = "Pending (\(vis.approvedCount)/\(vis.totalTiers))"
                let c: (Color, Color) = (.goldDark, Color.gold.opacity(0.15))
                return Text(l).font(.system(size: 10, weight: .medium)).foregroundColor(c.0)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(c.1).cornerRadius(4)
            }
        }

        label = {
            switch invoice.invoiceStatus {
            case .inbox: return "Pending at Accounts"
            case .draft: return "Pending"
            default: return invoice.invoiceStatus.displayName
            }
        }()
        colors = {
            switch invoice.invoiceStatus {
            case .inbox: return (.orange, Color.orange.opacity(0.1))
            case .rejected: return (.red, Color.red.opacity(0.1))
            case .paid: return (.blue, Color.blue.opacity(0.1))
            case .voided: return (.gray, Color.gray.opacity(0.1))
            case .approved: return (.green, Color.green.opacity(0.1))
            case .draft: return (.goldDark, Color.gold.opacity(0.15))
            case .onHold: return (.purple, Color.purple.opacity(0.1))
            case .partiallyPaid: return (.blue, Color.blue.opacity(0.1))
            default: return (.goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(colors.0)
            .padding(.horizontal, 8).padding(.vertical, 3).background(colors.1).cornerRadius(4)
    }
}
