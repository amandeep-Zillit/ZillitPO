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
        case .department: list = list.filter { ($0.departmentId ?? "") == user.departmentId && $0.userId != user.id }
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
                $0.invoiceNumber.lowercased().contains(q) ||
                $0.supplierName.lowercased().contains(q) ||
                ($0.description ?? "").lowercased().contains(q)
            }
        }

        return list.sorted { $0.createdAt > $1.createdAt }
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
        if inv.approvals.contains(where: { $0.userId == u.id }) { return true }
        if inv.assignedTo == u.id { return true }
        let vis = appState.invoiceApprovalVisibility(for: inv)
        return vis.visible
    }

    private var invoiceTabCounts: [InvoiceTab: Int] {
        guard let user = appState.currentUser else { return [:] }
        return [
            .all: appState.invoices.filter { isInvoiceVisible($0) }.count,
            .department: appState.invoices.filter { ($0.departmentId ?? "") == user.departmentId && $0.userId != user.id }.count,
            .my: appState.invoices.filter { $0.userId == user.id }.count
        ]
    }

    private var pendingPaymentRunCount: Int {
        let uid = appState.userId
        let sortedAuth = appState.invoiceRunAuth.sorted { $0.tier < $1.tier }
        return appState.paymentRuns.filter { run in
            guard run.isPending else { return false }
            if sortedAuth.isEmpty { return true }
            let nextLevel = sortedAuth.first { level in
                !run.approval.contains { $0.tierNumber == level.tier }
            }
            return nextLevel?.user.contains(uid) == true
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
        let totalValue = list.reduce(0.0) { $0 + $1.grossAmount }

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

// MARK: - Payment Run Approval Page

struct PaymentRunApprovalPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToDetail = false
    @State private var selectedRun: PaymentRun?

    private var pendingRuns: [PaymentRun] {
        let uid = appState.userId
        let sortedAuth = appState.invoiceRunAuth.sorted { $0.tier < $1.tier }
        return appState.paymentRuns.filter { run in
            guard run.isPending else { return false }
            // If no run_authorization configured, show all pending runs
            if sortedAuth.isEmpty { return true }
            // Find the next unapproved tier
            let nextLevel = sortedAuth.first { level in
                !run.approval.contains { $0.tierNumber == level.tier }
            }
            // Show only if current user is in that next tier
            return nextLevel?.user.contains(uid) == true
        }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 0) {
                    if appState.isLoading && appState.paymentRuns.isEmpty {
                        LoaderView()
                    } else if pendingRuns.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "banknote").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("No pending payment runs").font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 480)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(pendingRuns, id: \.id) { run in
                                Button(action: { selectedRun = run; navigateToDetail = true }) {
                                    PaymentRunRow(run: run, appState: appState)
                                }.buttonStyle(BorderlessButtonStyle())
                                if run.id != pendingRuns.last?.id {
                                    Divider().padding(.horizontal, 12)
                                }
                            }
                        }
                        .background(Color.bgSurface).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                        .padding(.top, 12)
                    }
                }
            }.padding(.horizontal, 16).padding(.bottom, 40)

            NavigationLink(destination: Group {
                if let run = selectedRun {
                    PaymentRunDetailPage(paymentRun: run).environmentObject(appState)
                } else { EmptyView() }
            }, isActive: $navigateToDetail) { EmptyView() }
                .frame(width: 0, height: 0).hidden()
        }
        .navigationBarTitle(Text("Payment Run Approval"), displayMode: .inline)
        .onAppear { if appState.paymentRuns.isEmpty { appState.loadPaymentRuns() } }
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
        if !invoice.supplierName.isEmpty { return invoice.supplierName }
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
                Text(invoice.invoiceNumber.isEmpty ? "—" : invoice.invoiceNumber)
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
                Text(FormatUtils.formatCurrency(invoice.grossAmount, code: invoice.currency))
                    .font(.system(size: 13, design: .monospaced))
                invoiceStatusBadge
                if let due = invoice.dueDate, due > 0 {
                    HStack(spacing: 2) {
                        if invoice.isOverdue {
                            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 8)).foregroundColor(.red)
                        }
                        Text("Due: \(FormatUtils.formatTimestamp(due))")
                            .font(.system(size: 9)).foregroundColor(invoice.isOverdue ? .red : .secondary)
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
            .navigationBarTitle(Text(liveInvoice.invoiceNumber.isEmpty ? "Invoice" : liveInvoice.invoiceNumber), displayMode: .inline)
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
                        destination: InvoiceHistoryPage(invoiceId: liveInvoice.id, invoiceLabel: liveInvoice.invoiceNumber.isEmpty ? "Invoice" : liveInvoice.invoiceNumber).environmentObject(appState),
                        isActive: $navigateToHistory
                    ) { EmptyView() }.frame(width: 0, height: 0).hidden()
                    NavigationLink(
                        destination: InvoiceQueriesPage(invoiceId: liveInvoice.id, invoiceLabel: liveInvoice.invoiceNumber.isEmpty ? "Invoice" : liveInvoice.invoiceNumber).environmentObject(appState),
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

// ═══════════════════════════════════════════════════════════════════
// MARK: - Invoice History Page
// ═══════════════════════════════════════════════════════════════════

struct InvoiceHistoryPage: View {
    @EnvironmentObject var appState: POViewModel
    let invoiceId: String
    let invoiceLabel: String

    private var entries: [InvoiceHistoryEntry] { appState.invoiceHistory[invoiceId] ?? [] }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            if appState.invoiceHistoryLoading && entries.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                    Text("No history yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                    Text("Actions on this invoice will appear here.")
                        .font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Summary header
                        if !invoiceLabel.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                                Text(invoiceLabel)
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                                Spacer()
                                Text("\(entries.count) event\(entries.count == 1 ? "" : "s")")
                                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                            }
                            .padding(12).background(Color.bgSurface).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
                        }

                        ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                            historyRow(entry, isLast: idx == entries.count - 1)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarTitle(Text("Invoice History"), displayMode: .inline)
        .onAppear { appState.loadInvoiceHistory(invoiceId) }
    }

    private func actionColor(_ action: String) -> Color {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return .green }
        if a.contains("reject") { return .red }
        if a.contains("override") { return .orange }
        if a.contains("submit") || a.contains("upload") { return .goldDark }
        if a.contains("escalat") { return .red }
        if a.contains("post") || a.contains("paid") { return Color(red: 0.1, green: 0.6, blue: 0.3) }
        return .goldDark
    }

    private func actionIcon(_ action: String) -> String {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return "checkmark.circle.fill" }
        if a.contains("reject") { return "xmark.circle.fill" }
        if a.contains("override") { return "bolt.fill" }
        if a.contains("submit") { return "paperplane.fill" }
        if a.contains("upload") { return "arrow.up.circle.fill" }
        if a.contains("escalat") { return "exclamationmark.triangle.fill" }
        if a.contains("post") || a.contains("paid") { return "tray.and.arrow.down.fill" }
        if a.contains("update") || a.contains("edit") { return "pencil.circle.fill" }
        return "circle.fill"
    }

    /// Turn a raw backend action string into a past-tense Title Case label.
    /// "inbox_processed" → "Inbox processed", "created" → "Created".
    private func actionTitle(_ raw: String) -> String {
        if raw.isEmpty { return "—" }
        let replaced = raw.replacingOccurrences(of: "_", with: " ")
        return replaced.prefix(1).uppercased() + replaced.dropFirst()
    }

    /// Resolve the user for a history entry — returns both the display name
    /// and (optionally) a formatted designation like "Production Accountant".
    private func resolvedUser(for entry: InvoiceHistoryEntry) -> (name: String, role: String?) {
        if let uid = entry.userId, !uid.isEmpty, let u = UsersData.byId[uid] {
            let role = u.displayDesignation.isEmpty ? nil : u.displayDesignation
            return (u.fullName, role)
        }
        if let name = entry.userName, !name.isEmpty { return (name, nil) }
        if let uid = entry.userId, !uid.isEmpty { return (uid, nil) }
        return ("Unknown", nil)
    }

    private func historyRow(_ entry: InvoiceHistoryEntry, isLast: Bool) -> some View {
        let actionStr = entry.action ?? ""
        let title = actionTitle(actionStr)
        let color = actionColor(actionStr)
        let who = resolvedUser(for: entry)
        return HStack(alignment: .top, spacing: 12) {
            // Timeline icon + connecting line
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: actionIcon(actionStr))
                        .font(.system(size: 11, weight: .bold)).foregroundColor(color)
                }
                if !isLast {
                    Rectangle().fill(Color.borderColor).frame(width: 2)
                        .frame(maxHeight: .infinity).padding(.top, 2)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                // "Updated"
                Text(title)
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.primary)

                // "by Sarah Alderton (Production Accountant)"
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                        .padding(.trailing, 4)
                    (
                        Text("by ").foregroundColor(.secondary)
                        + Text(who.name).fontWeight(.semibold).foregroundColor(.primary)
                        + Text({
                            if let r = who.role { return " (\(r))" }
                            return ""
                        }()).foregroundColor(.secondary)
                    )
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }

                // Optional free-text details (legacy endpoint)
                if let d = entry.details, !d.isEmpty {
                    Text(d).font(.system(size: 12)).foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // "14 Apr 2026, 00:46"
                if let ts = entry.timestamp, ts > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.gray)
                        Text(FormatUtils.formatHistoryDateTime(ts))
                            .font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgSurface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            .padding(.bottom, isLast ? 0 : 10)
        }
        .padding(.horizontal, 16).padding(.top, 4)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Invoice Queries Page
// ═══════════════════════════════════════════════════════════════════

/// Flattened chat message (query root or reply) used for display.
private struct QueryMessage: Identifiable {
    let id: String
    let userId: String?
    let userName: String?
    let text: String
    let timestamp: Int64?
    let isLocal: Bool   // true when the message was typed into the composer
                        // and hasn't round-tripped through the backend yet.
}

struct InvoiceQueriesPage: View {
    @EnvironmentObject var appState: POViewModel
    let invoiceId: String
    let invoiceLabel: String

    @State private var draft: String = ""
    @State private var localMessages: [QueryMessage] = []

    private var thread: InvoiceQueryThread? { appState.invoiceQueries[invoiceId] }

    /// Flatten the backend thread's `messages` + any optimistic local
    /// messages into a single sorted chat list.
    private var messages: [QueryMessage] {
        var list: [QueryMessage] = []
        if let t = thread {
            for m in t.messages {
                guard let body = m.query, !body.isEmpty else { continue }
                list.append(QueryMessage(
                    id: m.id,
                    userId: m.queriedBy,
                    userName: nil,        // backend doesn't ship a name; we resolve via UsersData
                    text: body,
                    timestamp: m.queriedAt,
                    isLocal: false
                ))
            }
        }
        list.append(contentsOf: localMessages)
        return list.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header: invoice number only (centered) ──────────────────
            Text(invoiceLabel.isEmpty ? "—" : invoiceLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 10)

            Divider()

            // ── Chat area ────────────────────────────────────────────
            Group {
                if appState.invoiceQueriesLoading && messages.isEmpty {
                    VStack { Spacer(); LoaderView(); Spacer() }
                } else if messages.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "text.bubble")
                            .font(.system(size: 32)).foregroundColor(.gray.opacity(0.4))
                        Text("No messages yet")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                        Text("Type a message to start the conversation.")
                            .font(.system(size: 11)).foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .trailing, spacing: 16) {
                            ForEach(messages) { m in messageBubble(m) }
                        }
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 16)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // ── Composer: text field + orange send button ────────────
            Divider()
            HStack(spacing: 10) {
                TextField("Type a message…", text: $draft)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Capsule().fill(Color.bgSurface))
                    .overlay(Capsule().stroke(Color.borderColor, lineWidth: 1))
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(draft.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.gold.opacity(0.5)
                            : Color(red: 0.95, green: 0.55, blue: 0.15)))
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.bgSurface)
        }
        .background(Color.bgSurface.edgesIgnoringSafeArea(.all))
        .navigationBarTitle(Text("Query"), displayMode: .inline)
        .onAppear { appState.loadInvoiceQueries(invoiceId) }
    }

    // MARK: - Chat bubble (right-aligned, orange background)

    private func messageBubble(_ m: QueryMessage) -> some View {
        let resolvedName: String = {
            if let n = m.userName, !n.isEmpty { return n }
            if let uid = m.userId { return UsersData.byId[uid]?.fullName ?? "Unknown" }
            return "Unknown"
        }()
        let role: String = {
            if let uid = m.userId, let u = UsersData.byId[uid] {
                return u.displayDesignation
            }
            return ""
        }()
        let stamp: String = {
            guard let ts = m.timestamp, ts > 0 else { return "" }
            return FormatUtils.formatHistoryDateTime(ts)
        }()
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        return HStack {
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                // Name (bold) + role (secondary)
                HStack(spacing: 4) {
                    Text(resolvedName).font(.system(size: 13, weight: .bold))
                    if !role.isEmpty {
                        Text(role).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                }

                // Orange message pill — caps length to ~78% of screen so
                // long messages wrap instead of stretching edge-to-edge.
                Text(m.text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(orange)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)

                if !stamp.isEmpty {
                    Text(stamp)
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Send

    /// Append the typed message to the local thread. Network wiring for
    /// POSTing new query replies can be added alongside this — for now the
    /// message appears in the UI and a warning logs the missing endpoint.
    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let me = appState.currentUser
        localMessages.append(QueryMessage(
            id: UUID().uuidString,
            userId: me?.id,
            userName: me?.fullName,
            text: text,
            timestamp: now,
            isLocal: true
        ))
        draft = ""
        print("⚠️ sendQueryMessage: no POST endpoint wired yet. Message added locally.")
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
        let hasNoApprovals = invoice.approvals.isEmpty
        let terminalStates: [InvoiceStatus] = [.approved, .paid, .rejected, .voided, .override_]
        let isTerminal = terminalStates.contains(invoice.invoiceStatus)
        return isOwner && hasNoApprovals && !isTerminal
    }

    private var resolvedTierConfig: LegacyTierConfig? {
        let tiers = appState.effectiveInvoiceTierConfigs
        return ApprovalHelpers.resolveConfig(tiers, deptId: invoice.departmentId, amount: invoice.totalAmount)
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
                    if !invoice.poIds.isEmpty || invoice.poNumber != nil || !invoice.linkedPOs.isEmpty {
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
                message: Text("Are you sure you want to delete invoice \(invoice.invoiceNumber.isEmpty ? "" : invoice.invoiceNumber)? This action cannot be undone."),
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
                            return (u.fullName, u.displayDesignation.isEmpty ? nil : u.displayDesignation)
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
            Text(invoice.invoiceNumber.isEmpty ? "—" : invoice.invoiceNumber)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.goldDark)
            HStack(spacing: 8) {
                Text({
                    let desc = invoice.description ?? ""
                    if desc.isEmpty { return invoice.supplierName.isEmpty ? "No description" : invoice.supplierName }
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
                return ("Pending (\(invoice.approvals.count)/\(totalTiers))", Color.goldDark, Color.gold.opacity(0.15))
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
        let name    = !invoice.supplierName.isEmpty ? invoice.supplierName : (v?.name ?? "")
        let address = !invoice.vendorAddress.isEmpty ? invoice.vendorAddress : (v?.address.formatted ?? "")
        let phone: String = {
            if !invoice.vendorPhone.isEmpty { return invoice.vendorPhone }
            guard let v = v else { return "" }
            return "\(v.phone.countryCode) \(v.phone.number)".trimmingCharacters(in: .whitespaces)
        }()
        let email   = !invoice.vendorEmail.isEmpty ? invoice.vendorEmail : (v?.email ?? "")
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
                    Text("By \(UsersData.byId[rejBy]?.fullName ?? rejBy)")
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
            metaCell(label: "Department", value: invoice.department.isEmpty ? "—" : invoice.department)
            Divider().frame(height: 44)
            metaCell(label: "Currency", value: invoice.currency.isEmpty ? "GBP" : invoice.currency)
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
            Text(FormatUtils.formatCurrency(invoice.grossAmount, code: invoice.currency))
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
            dateCell(label: "Due Date", value: invoice.dueDate.flatMap { $0 > 0 ? FormatUtils.formatTimestamp($0) : nil } ?? "—", overdue: invoice.isOverdue)
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
        if !invoice.linkedPOs.isEmpty {
            return invoice.linkedPOs.map { lp in
                // Fall back to appState lookup if the backend didn't resolve
                // the vendor name (e.g. the vendor list on backend is stale).
                var vendor = lp.poVendorName
                if vendor.isEmpty, !lp.poVendorId.isEmpty,
                   let v = appState.vendors.first(where: { $0.id == lp.poVendorId }) {
                    vendor = v.name
                }
                return LinkedPORow(
                    id: lp.id,
                    poNumber: lp.poNumber.isEmpty ? "PO-\(String(lp.poId.suffix(8)).uppercased())" : lp.poNumber,
                    vendorName: vendor,
                    amount: lp.poGrossTotal > 0 ? lp.poGrossTotal : nil,
                    currency: lp.currency
                )
            }
        }
        // 2) Fall back to the flat po_ids array + PO lookup.
        var rows: [LinkedPORow] = invoice.poIds.compactMap { id in
            guard !id.isEmpty else { return nil }
            if let po = appState.purchaseOrders.first(where: { $0.id == id }) {
                let vendor = po.vendor.isEmpty
                    ? (po.vendorId.flatMap { vid in appState.vendors.first { $0.id == vid }?.name } ?? "")
                    : po.vendor
                // `po.grossTotal` is optional; only surface it when we have
                // a positive value to show.
                let amt: Double? = {
                    if let g = po.grossTotal, g > 0 { return g }
                    return nil
                }()
                return LinkedPORow(
                    id: id,
                    poNumber: po.poNumber.isEmpty ? "PO-\(String(id.suffix(8)).uppercased())" : po.poNumber,
                    vendorName: vendor,
                    amount: amt,
                    currency: po.currency
                )
            }
            let short = "PO-\(String(id.suffix(8)).uppercased())"
            return LinkedPORow(id: id, poNumber: short, vendorName: "", amount: nil, currency: invoice.currency)
        }
        // 3) Legacy single-PO fallback
        if rows.isEmpty, let p = invoice.poNumber, !p.isEmpty {
            rows = [LinkedPORow(id: p, poNumber: p, vendorName: invoice.supplierName, amount: nil, currency: invoice.currency)]
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
            ForEach(invoice.lineItems, id: \.id) { li in
                HStack {
                    Text(li.description).font(.system(size: 12)).lineLimit(1)
                    Spacer()
                    Text("×\(Int(li.quantity))").font(.system(size: 11)).foregroundColor(.secondary)
                    Text(FormatUtils.formatCurrency(li.quantity * li.unitPrice, code: invoice.currency))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                Divider().padding(.horizontal, 14)
            }
            HStack {
                Spacer()
                Text("Total: ").font(.system(size: 13, weight: .semibold))
                Text(FormatUtils.formatCurrency(invoice.grossAmount, code: invoice.currency))
                    .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }.padding(.horizontal, 14).padding(.vertical, 8)
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Audit Footer

    private var auditFooter: some View {
        let creator = UsersData.byId[invoice.userId]
        let updater = invoice.updatedBy.flatMap { UsersData.byId[$0] }
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CREATED BY").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                Text(creator?.fullName ?? "—").font(.system(size: 13, weight: .semibold))
                if let d = creator?.displayDesignation, !d.isEmpty {
                    Text(d).font(.system(size: 10)).foregroundColor(.secondary)
                }
                if invoice.createdAt > 0 {
                    Text(FormatUtils.formatDateTime(invoice.createdAt)).font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if invoice.updatedAt > 0 {
                Divider().frame(height: 54).padding(.horizontal, 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("UPDATED BY").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    Text(updater?.fullName ?? invoice.updatedBy ?? "—").font(.system(size: 13, weight: .semibold))
                    if let d = updater?.displayDesignation, !d.isEmpty {
                        Text(d).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Text(FormatUtils.formatDateTime(invoice.updatedAt)).font(.system(size: 10)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let assignedTo = invoice.assignedTo, !assignedTo.isEmpty, let assignee = UsersData.byId[assignedTo] {
                Divider().frame(height: 54).padding(.horizontal, 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ASSIGNED TO").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    Text(assignee.fullName).font(.system(size: 13, weight: .semibold))
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
        let cfg = ApprovalHelpers.resolveConfig(tiers, deptId: invoice.departmentId, amount: invoice.totalAmount)
            ?? ApprovalHelpers.resolveConfig(tiers, deptId: invoice.departmentId)
        let totalTiers = ApprovalHelpers.getTotalTiers(cfg)
        let approvedSet = Dictionary(grouping: invoice.approvals, by: { $0.tierNumber })

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
            po.departmentId = invoice.departmentId; po.approvals = invoice.approvals
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
                                let approverUser = UsersData.byId[approval.userId]
                                let approverName = approverUser?.fullName ?? approval.userId
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
                                    Text(FormatUtils.formatTimestamp(approval.approvedAt)).font(.system(size: 9)).foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // Fully approved but no explicit entry — show config users as approved
                            ForEach(entries, id: \.userId) { entry in
                                let user = UsersData.byId[entry.userId]
                                let name = user?.fullName ?? entry.userId
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
                        Text("Reject invoice \(inv.invoiceNumber)")
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

// MARK: - Payment Run Row

struct PaymentRunRow: View {
    let run: PaymentRun
    var appState: POViewModel

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(run.number).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(.goldDark)
                Text(run.name.isEmpty ? "Payment Run" : run.name).font(.system(size: 13, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                HStack(spacing: 8) {
                    if !run.payMethod.isEmpty {
                        Text(run.payMethod.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundColor(.blue)
                            .padding(.horizontal, 5).padding(.vertical, 2).background(Color.blue.opacity(0.08)).cornerRadius(3)
                    }
                    Text("\(run.invoiceCount) invoice\(run.invoiceCount == 1 ? "" : "s")")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                let vis = appState.paymentRunApprovalVisibility(for: run)
                if vis.totalTiers > 0 {
                    Text("\(vis.approvedCount)/\(vis.totalTiers) approved").font(.system(size: 9, weight: .medium)).foregroundColor(.goldDark)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(FormatUtils.formatGBP(run.totalAmount)).font(.system(size: 13, design: .monospaced))
                paymentRunStatusBadge
                if run.createdAt > 0 {
                    Text(FormatUtils.formatTimestamp(run.createdAt)).font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
        }
        .padding(12).contentShape(Rectangle())
    }

    private var paymentRunStatusBadge: some View {
        let vis = appState.paymentRunApprovalVisibility(for: run)
        let label: String
        let fg: Color
        let bg: Color
        if run.isPending && vis.totalTiers > 0 {
            label = "Pending (\(vis.approvedCount)/\(vis.totalTiers))"
            fg = .goldDark; bg = Color.gold.opacity(0.15)
        } else if run.isApproved {
            label = "Approved"; fg = .green; bg = Color.green.opacity(0.1)
        } else if run.isRejected {
            label = "Rejected"; fg = .red; bg = Color.red.opacity(0.1)
        } else {
            label = run.status.capitalized; fg = .goldDark; bg = Color.gold.opacity(0.15)
        }
        return Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
    }
}

// MARK: - Payment Run Detail Page

struct PaymentRunDetailPage: View {
    let paymentRun: PaymentRun
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var fetchedInvoices: [Invoice] = []
    @State private var loadingInvoices = false

    private var liveRun: PaymentRun {
        appState.paymentRuns.first(where: { $0.id == paymentRun.id }) ?? paymentRun
    }

    /// Invoices for this run: use fetched detail, static data, or match from appState
    private var runInvoices: [PaymentRunInvoice] {
        if !liveRun.invoices.isEmpty { return liveRun.invoices }
        // Build from fetched full invoices
        if !fetchedInvoices.isEmpty {
            return fetchedInvoices.map {
                PaymentRunInvoice(id: $0.id, invoiceNumber: $0.invoiceNumber,
                                  supplierName: $0.supplierName,
                                  description: $0.description ?? "",
                                  dueDate: $0.dueDate, amount: $0.grossAmount, currency: $0.currency)
            }
        }
        return []
    }

    private var showActions: Bool {
        guard liveRun.isPending else { return false }
        // Hide if this user already approved at their tier
        let userAlreadyApproved = liveRun.approval.contains { $0.userId == appState.userId }
        if userAlreadyApproved { return false }
        // Check via tier visibility
        let vis = appState.paymentRunApprovalVisibility(for: liveRun)
        if vis.canApprove { return true }
        // Check via run authorization (invoice settings)
        if appState.isRunAuthApprover { return true }
        // Check if user is in any tier config (PO or invoice)
        let poInfo = ApprovalHelpers.getApproverDeptIds(appState.tierConfigRows, userId: appState.userId)
        let invInfo = ApprovalHelpers.getApproverDeptIds(appState.invoiceTierConfigRows, userId: appState.userId)
        if poInfo.isApproverInAllScope || invInfo.isApproverInAllScope { return true }
        // Accountants can always approve payment runs
        if appState.currentUser?.isAccountant == true { return true }
        return false
    }

    private var tierChain: [(tier: Int, users: [AppUser], isApproved: Bool)] {
        // Try PO tier configs first, fall back to invoice tier configs
        let cfg = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: nil)
            ?? ApprovalHelpers.resolveConfig(appState.invoiceTierConfigRows, deptId: nil)
        guard let cfg = cfg else { return [] }
        return cfg.keys.compactMap { Int($0) }.sorted().compactMap { t in
            let entries = cfg[String(t)] ?? []
            let users = entries.compactMap { UsersData.byId[$0.userId] }
            guard !users.isEmpty else { return nil }
            let isApproved = liveRun.approval.contains { $0.tierNumber == t }
            return (tier: t, users: users, isApproved: isApproved)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Approval Chain
                    if !tierChain.isEmpty { approvalChainSection }

                    // Invoices
                    if loadingInvoices {
                        HStack(spacing: 8) {
                            ActivityIndicator(isAnimating: true).frame(width: 16, height: 16)
                            Text("Loading invoices…").font(.system(size: 12)).foregroundColor(.secondary)
                        }.padding(14).frame(maxWidth: .infinity)
                        .background(Color.bgSurface).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    } else if !runInvoices.isEmpty {
                        invoicesSection
                    }

                    // Rejection reason
                    if liveRun.isRejected, let reason = liveRun.rejectionReason, !reason.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundColor(.red)
                            Text(reason).font(.system(size: 12)).foregroundColor(.red)
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.05)).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 1))
                    }

                    // Created by
                    createdBySection
                }
                .padding(16)
                .padding(.bottom, showActions ? 88 : 0)
            }

            // Fixed bottom action bar
            if showActions {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        Button(action: {
                            appState.rejectPaymentRunTarget = liveRun
                            appState.showRejectPaymentRunSheet = true
                        }) {
                            Text("Reject")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.4), lineWidth: 1.5))
                        }.buttonStyle(BorderlessButtonStyle())

                        Button(action: {
                            appState.approvePaymentRun(liveRun)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Approve")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.gold).cornerRadius(10)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .background(Color.bgSurface.edgesIgnoringSafeArea(.bottom))
            }
        }
        .navigationBarTitle(Text("\(liveRun.number) — \(liveRun.name.isEmpty ? "Payment Run" : liveRun.name)"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .onAppear {
            if appState.paymentRuns.isEmpty { appState.loadPaymentRuns() }
            if appState.invoiceTierConfigRows.isEmpty { appState.loadInvoiceApprovalTiers() }
            if appState.vendors.isEmpty { appState.loadVendors() }
            // Fetch run detail to get invoices
            if liveRun.invoices.isEmpty {
                loadingInvoices = true
                POCodableTask.getPaymentRun(liveRun.id) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let response):
                            if let raw = response?.data {
                                let v = appState.vendors
                                let d = DepartmentsData.all
                                fetchedInvoices = (raw.invoices ?? []).map { $0.toInvoice(vendors: v, departments: d) }
                            }
                        case .failure(let error):
                            print("❌ Fetch run invoices failed: \(error)")
                        }
                        loadingInvoices = false
                    }
                }.urlDataTask?.resume()
            }
        }
        .sheet(isPresented: $appState.showRejectPaymentRunSheet) {
            RejectPaymentRunSheetView().environmentObject(appState)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            // Run Number
            summaryRow(label: "Run Number", value: liveRun.number.isEmpty ? "—" : liveRun.number)
            Divider().padding(.leading, 14)

            // Run Name
            summaryRow(label: "Run Name", value: liveRun.name.isEmpty ? "—" : liveRun.name)
            Divider().padding(.leading, 14)

            // Pay Method
            if !liveRun.payMethod.isEmpty {
                HStack {
                    Text("Pay Method").font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    Text(liveRun.payMethod.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.blue.opacity(0.08)).cornerRadius(4)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                Divider().padding(.leading, 14)
            }

            // Total Amount
            HStack {
                Text("Total Amount").font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                Text(FormatUtils.formatGBP(liveRun.totalAmount))
                    .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Divider().padding(.leading, 14)

            // Computed Total (if different)
            if liveRun.computedTotal > 0 && liveRun.computedTotal != liveRun.totalAmount {
                summaryRow(label: "Computed Total", value: FormatUtils.formatGBP(liveRun.computedTotal))
                Divider().padding(.leading, 14)
            }

            // Invoice Count
            if liveRun.invoiceCount > 0 {
                summaryRow(label: "Invoices", value: "\(liveRun.invoiceCount) invoice\(liveRun.invoiceCount == 1 ? "" : "s")")
                Divider().padding(.leading, 14)
            }

            // Unique Vendors
            if !runInvoices.isEmpty {
                let vendorCount = Set(runInvoices.map { $0.supplierName }).filter { !$0.isEmpty }.count
                if vendorCount > 0 {
                    summaryRow(label: "Vendors", value: "\(vendorCount) vendor\(vendorCount == 1 ? "" : "s")")
                    Divider().padding(.leading, 14)
                }
            }

            // Status
            HStack {
                Text("Status").font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                let statusColor: Color = liveRun.isApproved ? .green : liveRun.isRejected ? .red : .goldDark
                let statusLabel = liveRun.isApproved ? "Approved" : liveRun.isRejected ? "Rejected" : "Pending"
                Text(statusLabel)
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(statusColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(statusColor.opacity(0.12)).cornerRadius(4)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Divider().padding(.leading, 14)

            // Approval Progress
            let vis = appState.paymentRunApprovalVisibility(for: liveRun)
            if vis.totalTiers > 0 {
                summaryRow(label: "Approval Progress", value: "\(vis.approvedCount)/\(vis.totalTiers) tiers approved")
                Divider().padding(.leading, 14)
            }

            // Created Date
            if liveRun.createdAt > 0 {
                summaryRow(label: "Created", value: FormatUtils.formatDateTime(liveRun.createdAt))
            }

            // Updated Date
            if liveRun.updatedAt > 0 && liveRun.updatedAt != liveRun.createdAt {
                Divider().padding(.leading, 14)
                summaryRow(label: "Last Updated", value: FormatUtils.formatDateTime(liveRun.updatedAt))
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: - Approval Chain

    private var approvalChainSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APPROVAL CHAIN")
                .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
            VStack(spacing: 10) {
                ForEach(tierChain, id: \.tier) { item in tierCard(item) }
            }
        }
    }

    private func tierCard(_ item: (tier: Int, users: [AppUser], isApproved: Bool)) -> some View {
        let color: Color = item.isApproved ? .green : liveRun.isRejected ? .red : .goldDark
        let statusLabel = item.isApproved ? "Approved" : liveRun.isRejected ? "Rejected" : "Pending"
        let approvedEntries = liveRun.approval.filter { $0.tierNumber == item.tier }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Level \(item.tier)").font(.system(size: 13, weight: .bold))
                Spacer()
                Text(statusLabel)
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.12)).cornerRadius(5)
            }
            if item.isApproved {
                ForEach(approvedEntries) { entry in
                    let u = UsersData.byId[entry.userId]
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.green.opacity(0.15)).frame(width: 28, height: 28)
                            Text(u?.initials ?? String(entry.userId.prefix(1)))
                                .font(.system(size: 10, weight: .semibold)).foregroundColor(.green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(u?.fullName ?? entry.userId)
                                .font(.system(size: 12, weight: .medium)).foregroundColor(.primary)
                            if let designation = u?.displayDesignation, !designation.isEmpty {
                                Text(designation)
                                    .font(.system(size: 10)).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundColor(.green)
                            if entry.approvedAt > 0 {
                                Text(FormatUtils.formatDateTime(entry.approvedAt))
                                    .font(.system(size: 9)).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                ForEach(item.users, id: \.id) { user in
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.gray.opacity(0.12)).frame(width: 28, height: 28)
                            Text(user.initials)
                                .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.fullName)
                                .font(.system(size: 12, weight: .medium)).foregroundColor(.primary)
                            if !user.displayDesignation.isEmpty {
                                Text(user.displayDesignation)
                                    .font(.system(size: 10)).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "clock").font(.system(size: 12)).foregroundColor(.goldDark)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.05)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Invoices Table

    private var invoicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INVOICES IN THIS RUN")
                .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.6)

            VStack(spacing: 0) {
                ForEach(Array(runInvoices.enumerated()), id: \.element.id) { index, inv in
                    VStack(alignment: .leading, spacing: 6) {
                        // Row 1: Invoice number + Amount
                        HStack {
                            Text(inv.invoiceNumber.isEmpty ? "—" : inv.invoiceNumber)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.goldDark)
                            Spacer()
                            Text(FormatUtils.formatCurrency(inv.amount, code: inv.currency))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        // Row 2: Vendor
                        HStack(spacing: 4) {
                            Text("Vendor:").font(.system(size: 11)).foregroundColor(.secondary)
                            Text(inv.supplierName.isEmpty ? "—" : inv.supplierName)
                                .font(.system(size: 12, weight: .medium)).lineLimit(1)
                        }
                        // Row 3: Description
                        HStack(spacing: 4) {
                            Text("Description:").font(.system(size: 11)).foregroundColor(.secondary)
                            Text(inv.description.isEmpty ? "—" : inv.description)
                                .font(.system(size: 11)).foregroundColor(.primary).lineLimit(2)
                        }
                        // Row 4: Due Date + Currency
                        HStack {
                            HStack(spacing: 4) {
                                Text("Due:").font(.system(size: 11)).foregroundColor(.secondary)
                                Text(inv.dueDate.flatMap { $0 > 0 ? FormatUtils.formatTimestamp($0) : nil } ?? "—")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            Spacer()
                            Text(inv.currency)
                                .font(.system(size: 10, weight: .semibold)).foregroundColor(.gray)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.gray.opacity(0.08)).cornerRadius(4)
                        }
                    }
                    .padding(12)
                    if index < runInvoices.count - 1 { Divider() }
                }

                // Footer
                Divider()
                HStack {
                    Text("\(Set(runInvoices.map { $0.supplierName }).filter { !$0.isEmpty }.count) vendors · \(runInvoices.count) invoices")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    Spacer()
                    Text(FormatUtils.formatGBP(runInvoices.reduce(0) { $0 + $1.amount }))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.goldDark)
                }
                .padding(12)
            }
            .background(Color.bgSurface).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    // MARK: - Created By

    private var createdBySection: some View {
        let creator = UsersData.byId[liveRun.createdBy]
        let rejector = liveRun.rejectedBy.flatMap { UsersData.byId[$0] }

        return VStack(alignment: .leading, spacing: 0) {
            // Created by
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.gold.opacity(0.15)).frame(width: 36, height: 36)
                    Text(creator?.initials ?? String(liveRun.createdBy.prefix(1)))
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.goldDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("CREATED BY").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    Text(creator?.fullName ?? liveRun.createdBy)
                        .font(.system(size: 14, weight: .semibold))
                    if let d = creator?.displayDesignation, !d.isEmpty {
                        Text(d).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    if let dept = creator?.displayDepartment, !dept.isEmpty {
                        Text(dept).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if liveRun.createdAt > 0 {
                    Text(FormatUtils.formatDateTime(liveRun.createdAt))
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            .padding(14)

            // Rejected by (if applicable)
            if liveRun.isRejected, let rejBy = liveRun.rejectedBy, !rejBy.isEmpty {
                Divider().padding(.horizontal, 14)
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.red.opacity(0.15)).frame(width: 36, height: 36)
                        Text(rejector?.initials ?? String(rejBy.prefix(1)))
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.red)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REJECTED BY").font(.system(size: 8, weight: .bold)).foregroundColor(.red).tracking(0.5)
                        Text(rejector?.fullName ?? rejBy)
                            .font(.system(size: 14, weight: .semibold))
                        if let d = rejector?.displayDesignation, !d.isEmpty {
                            Text(d).font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if let rejAt = liveRun.rejectedAt, rejAt > 0 {
                        Text(FormatUtils.formatDateTime(rejAt))
                            .font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }
                .padding(14)
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

}

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
                        Text("Reject \(run.number)").font(.system(size: 15, weight: .semibold))
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

// MARK: - Camera Page (Navigation push)

struct InvoiceCameraPage: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isActive: Bool
    var onCapture: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: InvoiceCameraPage
        init(_ parent: InvoiceCameraPage) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage
            parent.isActive = false
            parent.onCapture()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isActive = false
        }
    }
}

struct InvoiceCameraPageWrapper: View {
    @Binding var selectedImage: UIImage?
    @Binding var isActive: Bool
    var onCapture: () -> Void

    var body: some View {
        InvoiceCameraPage(selectedImage: $selectedImage, isActive: $isActive, onCapture: onCapture)
            .edgesIgnoringSafeArea(.all)
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarHidden(true)
    }
}

// MARK: - Image Picker (UIKit wrapper)

struct InvoiceImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: InvoiceImagePicker
        init(_ parent: InvoiceImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage
            parent.isPresented = false
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Document Picker (UIKit wrapper)

struct InvoiceDocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileName: String?
    @Binding var selectedFileURL: URL?
    @Binding var isPresented: Bool
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .jpeg, .png, .image], asCopy: true)
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.pdf", "public.jpeg", "public.png", "public.image"], in: .import)
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: InvoiceDocumentPicker
        init(_ parent: InvoiceDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                let ext = url.pathExtension.lowercased()
                let allowed = ["pdf", "jpg", "jpeg", "png", "heic", "heif"]
                guard allowed.contains(ext) else {
                    parent.errorMessage = "Only JPEG, PNG and PDF are acceptable"
                    parent.isPresented = false
                    return
                }
                parent.selectedFileURL = url
                parent.selectedFileName = url.lastPathComponent
            }
            parent.isPresented = false
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Upload Invoice Page

struct UploadInvoicePage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    // Step tracking: 1 = pick file, 2 = preview + extract, 3 = type select
    @State private var step: Int = 1

    // File selection
    @State private var selectedImage: UIImage?
    @State private var selectedFileName: String?
    @State private var selectedFileURL: URL?
    @State private var showImagePicker = false
    @State private var navigateToCamera = false
    @State private var showDocumentPicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary

    // Upload / extraction
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var extraction: InvoiceExtraction?

    // Type selection
    @State private var selectedType: String? = nil // "po", "cheque", "wire"
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage: String?

    private var hasFile: Bool { selectedImage != nil || selectedFileName != nil }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 20) {
                    if step == 1 { filePickerStep }
                    else if step == 2 { previewStep }
                    else if step == 3 { typeSelectStep }
                }
                .padding(.horizontal, 20).padding(.top, 20)
            }
        }
        .navigationBarTitle(Text("Upload Invoice"), displayMode: .inline)
        .sheet(isPresented: $showImagePicker) {
            InvoiceImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage, isPresented: $showImagePicker)
                .onDisappear {
                    if selectedImage != nil { selectedFileName = nil; selectedFileURL = nil; startUpload() }
                }
        }
        .background(
            NavigationLink(destination: InvoiceCameraPageWrapper(selectedImage: $selectedImage, isActive: $navigateToCamera, onCapture: {
                selectedFileName = nil; selectedFileURL = nil; startUpload()
            }), isActive: $navigateToCamera) { EmptyView() }
                .frame(width: 0, height: 0).hidden()
        )
        .sheet(isPresented: $showDocumentPicker) {
            InvoiceDocumentPicker(selectedFileName: $selectedFileName, selectedFileURL: $selectedFileURL, isPresented: $showDocumentPicker, errorMessage: $uploadError)
                .onDisappear {
                    if selectedFileName != nil { selectedImage = nil; startUpload() }
                }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
    }

    // ── Step 1: File Picker ──

    private var filePickerStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "arrow.up.doc.fill").font(.system(size: 48)).foregroundColor(.gold)
                Text("Upload Invoice").font(.system(size: 20, weight: .bold))
                Text("Select a file to upload your invoice").font(.system(size: 13)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.bgSurface).cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8])).foregroundColor(Color.gold.opacity(0.4)))
            )

            VStack(spacing: 12) {
                uploadOptionButton(icon: "camera.fill", title: "Take Photo", subtitle: "Capture invoice with camera") {
                    navigateToCamera = true
                }
                uploadOptionButton(icon: "photo.fill", title: "Photo Library", subtitle: "Choose from saved photos") {
                    imagePickerSource = .photoLibrary; showImagePicker = true
                }
                uploadOptionButton(icon: "doc.fill", title: "Choose File", subtitle: "Upload PDF or document") {
                    showDocumentPicker = true
                }
            }
        }
    }

    // ── Step 2: Preview + Extraction ──

    private var previewStep: some View {
        VStack(spacing: 16) {
            // File preview
            VStack(spacing: 12) {
                if let img = selectedImage {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 240).cornerRadius(8)
                } else if let name = selectedFileName {
                    Image(systemName: "doc.fill").font(.system(size: 48)).foregroundColor(.gold)
                    Text(name).font(.system(size: 14, weight: .medium)).multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 24).background(Color.bgSurface).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

            // Extraction status
            if isUploading {
                HStack(spacing: 8) {
                    ActivityIndicator(isAnimating: true).frame(width: 18, height: 18)
                    Text("Extracting invoice data...").font(.system(size: 13)).foregroundColor(.goldDark)
                }
                .padding(12).frame(maxWidth: .infinity)
                .background(Color.gold.opacity(0.08)).cornerRadius(8)
            } else if let error = uploadError {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                    Text(error).font(.system(size: 12)).foregroundColor(.red)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.06)).cornerRadius(8)

                Button("Try Again") { startUpload() }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.goldDark)
            } else if extraction != nil {
                // Extraction complete — ready to send
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Invoice data extracted — ready to send").font(.system(size: 12)).foregroundColor(.green)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.06)).cornerRadius(8)
            }

            Spacer().frame(height: 4)

            // Actions
            HStack(spacing: 12) {
                Button("Change File") {
                    extraction = nil; uploadError = nil; isUploading = false
                    selectedImage = nil; selectedFileName = nil; selectedFileURL = nil
                    step = 1
                }
                .font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity).frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                Button("Send to Accounts") { step = 3 }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(!isUploading ? Color.gold : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                    .disabled(isUploading)
            }
        }
    }

    // ── Step 3: Type Selection ──

    private var typeSelectStep: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Send to Accounts").font(.system(size: 18, weight: .bold))
                Text("How should this invoice be processed?").font(.system(size: 13)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            typeOption(
                value: "po",
                icon: "cart.fill",
                title: "Against Purchase Order",
                subtitle: "Standard invoice matched to an existing PO"
            )
            typeOption(
                value: "cheque",
                icon: "banknote.fill",
                title: "Cheque Request",
                subtitle: "Payment via cheque — no PO required"
            )
            typeOption(
                value: "wire",
                icon: "bolt.fill",
                title: "Wire Request",
                subtitle: "Urgent wire transfer — requires override approval"
            )

            Spacer().frame(height: 4)

            HStack(spacing: 12) {
                Button("Back") { step = 2; selectedType = nil }
                    .font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                Button(action: submitInvoice) {
                    HStack(spacing: 6) {
                        if isSubmitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(isSubmitting ? "Sending..." : "Confirm & Send")
                    }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(selectedType != nil && !isSubmitting ? Color.gold : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .disabled(selectedType == nil || isSubmitting)
            }
        }
    }

    private func typeOption(value: String, icon: String, title: String, subtitle: String) -> some View {
        Button { selectedType = value } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedType == value ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20)).foregroundColor(selectedType == value ? .gold : .gray)
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(.goldDark)
                    .frame(width: 32, height: 32).background(Color.gold.opacity(0.12)).cornerRadius(6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                    Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(14).background(Color.bgSurface).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedType == value ? Color.gold : Color.borderColor, lineWidth: selectedType == value ? 1.5 : 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // ── Helpers ──

    private func uploadOptionButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(.goldDark)
                    .frame(width: 36, height: 36).background(Color.gold.opacity(0.15)).cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.gray)
            }
            .padding(14).background(Color.bgSurface).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(BorderlessButtonStyle())
    }

    private func extractionRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold))
        }
    }

    private func resizeImage(_ img: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = img.size.width, h = img.size.height
        guard max(w, h) > maxDimension else { return img }
        let scale = maxDimension / max(w, h)
        let newSize = CGSize(width: w * scale, height: h * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        img.draw(in: CGRect(origin: .zero, size: newSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? img
    }

    private func startUpload() {
        step = 2; isUploading = true; uploadError = nil; extraction = nil

        // Build file data
        var fileData: Data?
        var fileName = "invoice"
        var mimeType = "application/octet-stream"

        if let img = selectedImage {
            // Resize large camera photos to max 1600px and compress to stay under server limit
            let resized = resizeImage(img, maxDimension: 2400)
            if let data = resized.jpegData(compressionQuality: 0.8) {
                fileData = data
            }
            fileName = "invoice.jpg"; mimeType = "image/jpeg"
        } else if let url = selectedFileURL {
            let ext = url.pathExtension.lowercased()
            let allowed = ["pdf", "jpg", "jpeg", "png", "heic", "heif"]
            guard allowed.contains(ext) else {
                uploadError = "Only JPEG, PNG and PDF are acceptable"; isUploading = false; step = 1; return
            }
            _ = url.startAccessingSecurityScopedResource()
            if ext == "heic" || ext == "heif" {
                // Convert HEIC/HEIF to JPEG for server compatibility
                if let rawData = try? Data(contentsOf: url), let img = UIImage(data: rawData) {
                    let resized = resizeImage(img, maxDimension: 2400)
                    fileData = resized.jpegData(compressionQuality: 0.8)
                }
                fileName = url.deletingPathExtension().lastPathComponent + ".jpg"
                mimeType = "image/jpeg"
            } else {
                fileData = try? Data(contentsOf: url)
                fileName = url.lastPathComponent
                mimeType = ext == "pdf" ? "application/pdf" : ext == "png" ? "image/png" : "image/jpeg"
            }
            url.stopAccessingSecurityScopedResource()
        }

        guard let data = fileData else {
            uploadError = "Failed to read file"; isUploading = false; return
        }

        // Upload for extraction
        guard let req = APIClient.shared.buildMultipartRequest(
            "/api/v2/invoices/upload", fileData: data, fileName: fileName, mimeType: mimeType, fieldName: "file"
        ) else {
            uploadError = "Failed to build request"; isUploading = false; return
        }

        let task: URLSessionDataTask = APIClient.shared.codableResultTask(with: req) { (result: Result<APIResponse<InvoiceExtraction>?, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.extraction = response?.data
                case .failure(let error):
                    self.uploadError = error.localizedDescription
                }
                self.isUploading = false
            }
        }
        task.resume()
    }

    private func submitInvoice() {
        guard let type = selectedType, let user = appState.currentUser else { return }
        isSubmitting = true

        let ext = extraction
        let payMethod: String = {
            switch type {
            case "wire": return "wire"
            case "cheque": return "cheque"
            default: return "bacs"
            }
        }()

        let supplierName = ext?.supplier?.name ?? selectedFileName ?? "Uploaded invoice"
        var body: [String: Any] = [
            "description": selectedFileName ?? "Uploaded invoice",
            "supplier_name": supplierName,
            "pay_method": payMethod,
            "currency": ext?.currency ?? "GBP",
            "department_id": user.departmentId,
            "status": "inbox",
            "gross_amount": ext?.grossValue ?? 0,
        ]
        if let ext = ext {
            if ext.netValue > 0 { body["net_amount"] = ext.netValue }
            if ext.vatValue > 0 { body["vat_amount"] = ext.vatValue }
            if let d = ext.invoice_date, !d.isEmpty { body["invoice_date"] = d }
            if let d = ext.due_date, !d.isEmpty { body["due_date"] = d }
            if let n = ext.invoice_number, !n.isEmpty { body["invoice_number"] = n }
            if let p = ext.po_number, !p.isEmpty { body["po_number"] = p }
            if let uid = ext.upload_id { body["upload_id"] = uid }
            if let items = ext.line_items, !items.isEmpty {
                body["line_items"] = items.map { item -> [String: Any] in
                    var li: [String: Any] = [:]
                    if let d = item.description, !d.isEmpty { li["description"] = d }
                    if item.quantityValue > 0 { li["quantity"] = item.quantityValue }
                    if item.unitPriceValue > 0 { li["unit_price"] = item.unitPriceValue }
                    if item.amountValue > 0 { li["amount"] = item.amountValue }
                    return li
                }
            }
        }

        appState.submitInvoice(body) { success, error in
            isSubmitting = false
            if success {
                presentationMode.wrappedValue.dismiss()
            } else {
                errorMessage = error ?? "Submission failed"
                showError = true
            }
        }
    }
}

// MARK: - Invoice Document Viewer

struct InvoiceDocumentViewer: View {
    let url: URL
    @Environment(\.presentationMode) var presentationMode

    // Detected kind: nil until HEAD/initial load resolves the Content-Type.
    // Fallbacks to the URL extension so we display immediately when possible.
    @State private var resolvedKind: DocKind? = nil

    enum DocKind { case image, pdf, web }

    private var ext: String { url.pathExtension.lowercased() }
    private var guessedKind: DocKind {
        if ["png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "bmp", "tif", "tiff"].contains(ext) { return .image }
        if ext == "pdf" { return .pdf }
        // Unknown — render in WKWebView which handles most types, or probe later.
        return .web
    }

    var body: some View {
        NavigationView {
            Group {
                switch resolvedKind ?? guessedKind {
                case .image:
                    // Zoomable image view for PNG/JPG/HEIC/WebP/etc.
                    InvoiceImageView(url: url)
                case .pdf:
                    // PDFs render natively via WKWebView
                    InvoiceWebView(url: url)
                case .web:
                    // Generic fallback — WKWebView also handles images/PDFs/plain HTML
                    InvoiceWebView(url: url)
                }
            }
            .background(Color.bgBase.edgesIgnoringSafeArea(.all))
            .navigationBarTitle(Text(url.lastPathComponent.isEmpty ? "Document" : url.lastPathComponent), displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { presentationMode.wrappedValue.dismiss() }
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark))
            .onAppear { probeContentTypeIfNeeded() }
        }
    }

    /// If the URL has no extension (e.g. /uploads/<upload_id>), probe the
    /// server with a HEAD request to learn whether this is an image or PDF.
    private func probeContentTypeIfNeeded() {
        guard resolvedKind == nil, guessedKind == .web else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        let client = APIClient.shared
        req.setValue(client.projectId, forHTTPHeaderField: "x-project-id")
        req.setValue(client.userId, forHTTPHeaderField: "x-user-id")
        req.setValue(String(client.isAccountant), forHTTPHeaderField: "x-is-accountant")
        URLSession.shared.dataTask(with: req) { _, resp, _ in
            guard let http = resp as? HTTPURLResponse,
                  let type = (http.value(forHTTPHeaderField: "Content-Type")
                              ?? http.value(forHTTPHeaderField: "content-type"))?.lowercased()
            else { return }
            DispatchQueue.main.async {
                if type.contains("image/") { self.resolvedKind = .image }
                else if type.contains("pdf") { self.resolvedKind = .pdf }
                else { self.resolvedKind = .web }
            }
        }.resume()
    }
}

/// Loads an image via URLSession with the same auth headers APIClient uses.
/// Supports pinch-to-zoom via a UIScrollView + UIImageView.
struct InvoiceImageView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])

        // Loading spinner
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
        spinner.startAnimating()

        // Build authenticated request
        var request = URLRequest(url: url)
        let client = APIClient.shared
        request.setValue(client.projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(client.userId, forHTTPHeaderField: "x-user-id")
        request.setValue(String(client.isAccountant), forHTTPHeaderField: "x-is-accountant")

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                spinner.stopAnimating()
                spinner.removeFromSuperview()
                if let data = data, let img = UIImage(data: data) {
                    imageView.image = img
                } else {
                    let label = UILabel()
                    label.text = error?.localizedDescription ?? "Unable to load image"
                    label.textColor = .lightGray
                    label.font = .systemFont(ofSize: 13)
                    label.textAlignment = .center
                    label.numberOfLines = 0
                    label.translatesAutoresizingMaskIntoConstraints = false
                    scrollView.addSubview(label)
                    NSLayoutConstraint.activate([
                        label.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
                        label.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
                        label.widthAnchor.constraint(lessThanOrEqualTo: scrollView.widthAnchor, constant: -32),
                    ])
                }
            }
        }.resume()

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
}

struct InvoiceWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .systemGroupedBackground
        webView.isOpaque = false

        // Build request with same headers APIClient uses
        var request = URLRequest(url: url)
        let client = APIClient.shared
        request.setValue(client.projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(client.userId, forHTTPHeaderField: "x-user-id")
        request.setValue(String(client.isAccountant), forHTTPHeaderField: "x-is-accountant")
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
