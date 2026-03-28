import SwiftUI
import UIKit

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
        case .pending:  list = list.filter { $0.invoiceStatus == .approval }
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
        if inv.userId == u.id { return true }
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
        appState.paymentRuns.filter { $0.isPending }.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                tabBar

                filterBar.padding(.horizontal, 16).padding(.top, 12)
                searchBar.padding(.horizontal, 16).padding(.top, 10)
                ScrollView {
                    if appState.isLoading {
                        LoaderView().padding(.top, 40)
                    } else if filteredInvoices.isEmpty {
                        emptyState.padding(.top, 20)
                    } else {
                        invoiceList.padding(.top, 8)
                    }
                }.padding(.horizontal, 16).padding(.bottom, 80)
            }

            Button(action: { navigateToUpload = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Upload Invoice").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.gold).cornerRadius(28)
                .shadow(color: Color.gold.opacity(0.4), radius: 8, x: 0, y: 4)
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

    private var filterBar: some View {
        HStack(spacing: 8) {
            // Filter dropdown — matches PO QuickFiltersBar style
            Button(action: { showFilterSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                    Text(selectedFilter.rawValue)
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
            .compatActionSheet(title: "Filter by Status", isPresented: $showFilterSheet, buttons:
                InvoiceFilter.allCases.map { filter in
                    let label = filter == selectedFilter ? "\(filter.rawValue) ✓" : filter.rawValue
                    return CompatActionSheetButton.default(label) { selectedFilter = filter }
                } + [.cancel()]
            )

            Spacer()

            // Approval button — matches Drafts/Templates button style
            if appState.isInvoiceApprover {
                Button(action: { navigateToPaymentRunApproval = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "banknote")
                            .font(.system(size: 10, weight: .medium))
                        Text("Payment Run Approval").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        if pendingPaymentRunCount > 0 {
                            Text("\(pendingPaymentRunCount)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.goldDark)
                                .cornerRadius(8)
                        }
                    }
                    .foregroundColor(.goldDark)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(6)
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
        .padding(10).background(Color.white).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
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
            Image(systemName: "doc.text").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
            Text("No invoices found").font(.system(size: 13)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private var invoiceList: some View {
        VStack(spacing: 0) {
            ForEach(filteredInvoices, id: \.id) { invoice in
                Button(action: {
                    selectedInvoiceForDetail = invoice
                    navigateToDetail = true
                }) {
                    InvoiceRow(invoice: invoice, showApprovalInfo: false, appState: appState)
                }.buttonStyle(BorderlessButtonStyle())
                Divider().padding(.horizontal, 12)
            }
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

// MARK: - Payment Run Approval Page

struct PaymentRunApprovalPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToDetail = false
    @State private var selectedRun: PaymentRun?

    private var pendingRuns: [PaymentRun] {
        appState.paymentRuns.filter { $0.isPending }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 0) {
                    if appState.isLoading && appState.paymentRuns.isEmpty {
                        LoaderView().padding(.top, 40)
                    } else if pendingRuns.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "banknote").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                            Text("No pending payment runs").font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                        .background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                        .padding(.top, 20)
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
                        .background(Color.white).cornerRadius(10)
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

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.invoiceNumber.isEmpty ? "—" : invoice.invoiceNumber)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.goldDark)
                Text(invoice.supplierName.isEmpty ? "—" : invoice.supplierName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black).lineLimit(1)
                if let desc = invoice.description, !desc.isEmpty {
                    Text(desc).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                }
                if let poNum = invoice.poNumber, !poNum.isEmpty {
                    Text("PO: \(poNum)").font(.system(size: 9, weight: .medium)).foregroundColor(.blue.opacity(0.7))
                }
                if showApprovalInfo, let state = appState {
                    let vis = state.invoiceApprovalVisibility(for: invoice)
                    if vis.totalTiers > 0 {
                        Text("\(vis.approvedCount)/\(vis.totalTiers) approved")
                            .font(.system(size: 9, weight: .medium)).foregroundColor(.goldDark)
                    }
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

        label = invoice.invoiceStatus.displayName
        colors = {
            switch invoice.invoiceStatus {
            case .rejected: return (.red, Color.red.opacity(0.1))
            case .paid: return (.blue, Color.blue.opacity(0.1))
            case .voided: return (.gray, Color.gray.opacity(0.1))
            case .approved: return (.green, Color.green.opacity(0.1))
            case .draft: return (.orange, Color.orange.opacity(0.1))
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

    private var liveInvoice: Invoice {
        appState.invoices.first(where: { $0.id == invoice.id }) ?? invoice
    }

    var body: some View {
        InvoiceDetailContentView(invoice: liveInvoice, onClose: { presentationMode.wrappedValue.dismiss() })
            .environmentObject(appState)
            .navigationBarTitle(Text(liveInvoice.invoiceNumber.isEmpty ? "Invoice" : liveInvoice.invoiceNumber), displayMode: .inline)
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

// MARK: - Invoice Detail Content View

struct InvoiceDetailContentView: View {
    let invoice: Invoice
    var onClose: () -> Void
    @EnvironmentObject var appState: POViewModel

    private var vis: ApprovalVisibility { appState.invoiceApprovalVisibility(for: invoice) }

    private var resolvedTierConfig: LegacyTierConfig? {
        let tiers = appState.effectiveInvoiceTierConfigs
        return ApprovalHelpers.resolveConfig(tiers, deptId: invoice.departmentId, amount: invoice.totalAmount)
            ?? ApprovalHelpers.resolveConfig(tiers, deptId: invoice.departmentId)
    }
    private var totalTiers: Int { ApprovalHelpers.getTotalTiers(resolvedTierConfig) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                    VStack(alignment: .leading, spacing: 14) {

                        // Header card (scrolls with content)
                        invoiceHeader
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                        // Supplier card
                        supplierSection

                        // Hold reason banner
                        if let holdReason = invoice.holdReason, !holdReason.isEmpty {
                            holdBanner(reason: holdReason, note: invoice.holdNote)
                        }

                        // Dept / Currency / Pay Method grid
                        metaGrid

                        // Amounts
                        amountsSection

                        // Dates grid
                        datesGrid

                        // Linked POs
                        if !invoice.poIds.isEmpty || invoice.poNumber != nil {
                            linkedPOsSection
                        }

                        // Line Items
                        if !invoice.lineItems.isEmpty { lineItemsSection }

                        // Approval chain
                        invoiceApprovalFlowSection

                        // Rejection banner
                        if let reason = invoice.rejectionReason, !reason.isEmpty {
                            rejectionBanner(reason: reason)
                        }

                        // Audit footer
                        auditFooter
                    }
                    .padding(.horizontal, 16).padding(.top, 14)
                    .padding(.bottom, vis.canApprove ? 80 : 24)
            }

            // ── Pinned action bar ──────────────────────────────────────────
            if vis.canApprove {
                actionBar
            }
        }
    }

    // MARK: - Header

    private var invoiceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(invoice.invoiceNumber.isEmpty ? "—" : invoice.invoiceNumber)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.goldDark)
            Text((invoice.description ?? "").isEmpty ? "No description" : invoice.description ?? "")
                .font(.system(size: 16, weight: .bold)).foregroundColor(.primary)
            // Status badge row
            HStack(spacing: 6) {
                invoiceStatusBadge
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
                return ("Pending \(invoice.approvals.count)/\(totalTiers)", Color.goldDark, Color.gold.opacity(0.15))
            }
            switch invoice.invoiceStatus {
            case .approved, .paid: return (invoice.invoiceStatus.displayName, .green, Color.green.opacity(0.1))
            case .rejected: return (invoice.invoiceStatus.displayName, .red, Color.red.opacity(0.1))
            case .draft: return (invoice.invoiceStatus.displayName, .orange, Color.orange.opacity(0.1))
            case .onHold: return (invoice.invoiceStatus.displayName, .purple, Color.purple.opacity(0.1))
            default: return (invoice.invoiceStatus.displayName, .goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .semibold)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
    }

    // MARK: - Supplier

    private var supplierSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("VENDOR").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                .tracking(0.6)
            Text(invoice.supplierName.isEmpty ? "—" : invoice.supplierName)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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
            Text("AMOUNTS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            HStack(alignment: .bottom, spacing: 4) {
                Text(FormatUtils.formatCurrency(invoice.grossAmount, code: invoice.currency))
                    .font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundColor(.primary)
                Text("Gross").font(.system(size: 11)).foregroundColor(.secondary).padding(.bottom, 3)
            }
            if let costCentre = invoice.costCentre, !costCentre.isEmpty {
                Text("Cost Centre: \(costCentre)").font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Dates Grid

    private var datesGrid: some View {
        HStack(spacing: 0) {
            dateCell(label: "Invoice Date", value: invoice.invoiceDate.flatMap { $0 > 0 ? FormatUtils.formatTimestamp($0) : nil } ?? "—")
            Divider().frame(height: 44)
            dateCell(label: "Due Date", value: invoice.dueDate.flatMap { $0 > 0 ? FormatUtils.formatTimestamp($0) : nil } ?? "—", overdue: invoice.isOverdue)
            Divider().frame(height: 44)
            dateCell(label: "Effective Date", value: "—")
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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

    private var linkedPOsSection: some View {
        let poNums: [String] = {
            var nums = invoice.poIds.compactMap { id in
                appState.purchaseOrders.first(where: { $0.id == id })?.poNumber ?? (id.isEmpty ? nil : id)
            }
            if nums.isEmpty, let p = invoice.poNumber, !p.isEmpty { nums = [p] }
            return nums
        }()
        return VStack(alignment: .leading, spacing: 8) {
            Text("LINKED POs (\(poNums.count))").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            ForEach(poNums, id: \.self) { num in
                HStack {
                    Text(num).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "link").font(.system(size: 11)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.blue.opacity(0.04)).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.15), lineWidth: 1))
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Audit Footer

    private var auditFooter: some View {
        let creator = UsersData.byId[invoice.userId]
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CREATED BY").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                Text(creator?.fullName ?? "—").font(.system(size: 13, weight: .semibold))
                if let d = creator?.displayDesignation, !d.isEmpty {
                    Text(d).font(.system(size: 10)).foregroundColor(.secondary)
                }
                if invoice.createdAt > 0 {
                    Text(FormatUtils.formatTimestamp(invoice.createdAt)).font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
        .padding(14).background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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
                    HStack {
                        Image(systemName: "person.3.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                        Text("APPROVAL FLOW").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        Spacer()
                        if invoice.invoiceStatus == .approval {
                            Text("\(invoice.approvals.count)/\(totalTiers) Approved")
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(.goldDark)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.gold.opacity(0.15)).cornerRadius(4)
                        } else if invoice.invoiceStatus == .approved || invoice.invoiceStatus == .paid {
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
                    }
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

                    if let config = cfg {
                        ForEach(1...totalTiers, id: \.self) { tierNum in
                            invoiceTierRow(tierNum: tierNum, totalTiers: totalTiers, config: config, approvedSet: approvedSet)
                        }
                    }

                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.goldDark).frame(width: 22, height: 22)
                            Text(String((UsersData.byId[invoice.userId]?.firstName ?? "?").prefix(1)))
                                .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Raised by").font(.system(size: 9)).foregroundColor(.secondary)
                            Text(UsersData.byId[invoice.userId]?.fullName ?? invoice.userId)
                                .font(.system(size: 12, weight: .medium))
                        }
                        Spacer()
                        if invoice.createdAt > 0 {
                            Text(FormatUtils.formatTimestamp(invoice.createdAt)).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6).opacity(0.5))
                }
                .background(Color.white).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func invoiceTierRow(tierNum: Int, totalTiers: Int, config: LegacyTierConfig, approvedSet: [Int: [Approval]]) -> some View {
        let entries = config[String(tierNum)] ?? []
        let tierApprovals = approvedSet[tierNum] ?? []
        let isApproved = !tierApprovals.isEmpty

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
                        Text("Tier \(tierNum)").font(.system(size: 12, weight: .semibold))
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

                    ForEach(entries, id: \.userId) { entry in
                        let user = UsersData.byId[entry.userId]
                        let name = user?.fullName ?? entry.userId
                        let approved = tierApprovals.first { $0.userId == entry.userId }
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(approved != nil ? Color.green.opacity(0.15) : isCurrentTier ? Color.gold.opacity(0.15) : Color.gray.opacity(0.1))
                                    .frame(width: 20, height: 20)
                                Text(String(name.prefix(1))).font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(approved != nil ? .green : isCurrentTier ? .goldDark : .secondary)
                            }
                            Text(name).font(.system(size: 11)).foregroundColor(.primary).lineLimit(1)
                            if let a = approved {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundColor(.green)
                                Text(FormatUtils.formatTimestamp(a.approvedAt)).font(.system(size: 9)).foregroundColor(.secondary)
                            }
                        }
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
                            .background(Color.white).cornerRadius(8)
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
                Text(run.name.isEmpty ? "Payment Run" : run.name).font(.system(size: 13, weight: .medium)).foregroundColor(.black).lineLimit(1)
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

    private var liveRun: PaymentRun {
        appState.paymentRuns.first(where: { $0.id == paymentRun.id }) ?? paymentRun
    }

    private var showActions: Bool {
        liveRun.isPending && liveRun.createdBy != appState.userId
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
                    // Status badge
                    let statusColor: Color = liveRun.isApproved ? .green : liveRun.isRejected ? .red : .goldDark
                    let statusLabel = liveRun.isApproved ? "Approved" : liveRun.isRejected ? "Rejected" : "Pending"
                    Text(statusLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(statusColor.opacity(0.12)).cornerRadius(6)

                    // Summary
                    summaryCard

                    // Approval Chain
                    if !tierChain.isEmpty { approvalChainSection }

                    // Invoices
                    if !liveRun.invoices.isEmpty { invoicesSection }

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
                .background(Color.white.edgesIgnoringSafeArea(.bottom))
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
            if appState.tierConfigRows.isEmpty && appState.invoiceTierConfigRows.isEmpty {
                appState.loadAllData()
            }
        }
        .sheet(isPresented: $appState.showRejectPaymentRunSheet) {
            RejectPaymentRunSheetView().environmentObject(appState)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 0) {
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
            HStack {
                Text("Total Amount").font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                Text(FormatUtils.formatGBP(liveRun.totalAmount))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            if liveRun.invoiceCount > 0 {
                Divider().padding(.leading, 14)
                HStack {
                    Text("Invoices").font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    Text("\(liveRun.invoiceCount) invoice\(liveRun.invoiceCount == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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
                    if let u = UsersData.byId[entry.userId] {
                        Text("\(u.fullName) (\(u.displayDesignation))")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
            } else {
                let names = item.users.map { "\($0.fullName) (\($0.displayDesignation))" }.joined(separator: ", ")
                Text(names + " · Waiting")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.05)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Invoices Table

    private var invoicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INVOICES IN THIS RUN")
                .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
            VStack(spacing: 0) {
                // Rows
                ForEach(liveRun.invoices) { inv in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(inv.invoiceNumber)
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.goldDark)
                                Text(inv.supplierName)
                                    .font(.system(size: 13, weight: .medium)).foregroundColor(.primary)
                                if !inv.description.isEmpty {
                                    Text(inv.description)
                                        .font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(FormatUtils.formatCurrency(inv.amount, code: inv.currency))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                if let due = inv.dueDate {
                                    Text("Due: \(FormatUtils.formatTimestamp(due))")
                                        .font(.system(size: 10)).foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        if inv.id != liveRun.invoices.last?.id { Divider() }
                    }
                }
                // Footer
                Divider()
                HStack {
                    Text("\(Set(liveRun.invoices.map { $0.supplierName }).count) vendors · \(liveRun.invoices.count) invoices")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    Spacer()
                    Text(FormatUtils.formatGBP(liveRun.invoices.reduce(0) { $0 + $1.amount }))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.goldDark)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            .background(Color.white).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    // MARK: - Created By

    private var createdBySection: some View {
        let creator = UsersData.byId[liveRun.createdBy]
        return VStack(alignment: .leading, spacing: 4) {
            Text("CREATED BY")
                .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
            Text(creator?.fullName ?? liveRun.createdBy)
                .font(.system(size: 14, weight: .semibold))
            if let d = creator?.displayDesignation, !d.isEmpty {
                Text(d).font(.system(size: 12)).foregroundColor(.secondary)
            }
            if liveRun.createdAt > 0 {
                Text(FormatUtils.formatDateTime(liveRun.createdAt))
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white).cornerRadius(10)
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
                            .background(Color.white).cornerRadius(8)
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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .data], asCopy: true)
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.pdf", "public.image", "public.data"], in: .import)
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

    @State private var selectedImage: UIImage?
    @State private var selectedFileName: String?
    @State private var selectedFileURL: URL?
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            VStack(spacing: 20) {

                // Drop zone / preview
                VStack(spacing: 16) {
                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 180).cornerRadius(8)
                        Text("Photo selected — tap an option below to change")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    } else if let name = selectedFileName {
                        Image(systemName: "doc.fill").font(.system(size: 48)).foregroundColor(.gold)
                        Text(name).font(.system(size: 14, weight: .medium)).multilineTextAlignment(.center)
                        Text("Tap an option below to change").font(.system(size: 12)).foregroundColor(.secondary)
                    } else {
                        Image(systemName: "arrow.up.doc.fill").font(.system(size: 48)).foregroundColor(.gold)
                        Text("Upload Invoice").font(.system(size: 20, weight: .bold))
                        Text("Select a file to upload your invoice").font(.system(size: 13)).foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.white).cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8])).foregroundColor(Color.gold.opacity(0.4)))
                )

                // Pick options
                VStack(spacing: 12) {
                    uploadOptionButton(icon: "camera.fill", title: "Take Photo", subtitle: "Capture invoice with camera") {
                        imagePickerSource = .camera; showImagePicker = true
                    }
                    uploadOptionButton(icon: "photo.fill", title: "Photo Library", subtitle: "Choose from saved photos") {
                        imagePickerSource = .photoLibrary; showImagePicker = true
                    }
                    uploadOptionButton(icon: "doc.fill", title: "Choose File", subtitle: "Upload PDF or document") {
                        showDocumentPicker = true
                    }
                }

                // Submit — only shown after a file is selected
                if selectedImage != nil || selectedFileName != nil {
                    Button(action: submitInvoice) {
                        HStack(spacing: 8) {
                            if isSubmitting { ActivityIndicator(isAnimating: true).frame(width: 18, height: 18) }
                            Text(isSubmitting ? "Submitting..." : "Submit Invoice")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Color.gold).foregroundColor(.white).cornerRadius(10)
                    }
                    .disabled(isSubmitting)
                }
            }
            .padding(.horizontal, 20).padding(.top, 20)
        }
        .navigationBarTitle(Text("Upload Invoice"), displayMode: .inline)
        .sheet(isPresented: $showImagePicker) {
            InvoiceImagePicker(sourceType: imagePickerSource, selectedImage: $selectedImage, isPresented: $showImagePicker)
                .onDisappear { if selectedImage != nil { selectedFileName = nil; selectedFileURL = nil } }
        }
        .sheet(isPresented: $showDocumentPicker) {
            InvoiceDocumentPicker(selectedFileName: $selectedFileName, selectedFileURL: $selectedFileURL, isPresented: $showDocumentPicker)
                .onDisappear { if selectedFileName != nil { selectedImage = nil } }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Submission Failed"), message: Text(errorMessage ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
    }

    private func uploadOptionButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(.goldDark)
                    .frame(width: 36, height: 36).background(Color.gold.opacity(0.15)).cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.black)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.gray)
            }
            .padding(14).background(Color.white).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(BorderlessButtonStyle())
    }

    private func submitInvoice() {
        guard let user = appState.currentUser else { return }
        isSubmitting = true
        let body: [String: Any] = [
            "supplier_name": selectedFileName ?? "Invoice",
            "description": selectedFileName ?? "Uploaded invoice",
            "gross_amount": 0,
            "currency": "GBP",
            "department_id": user.departmentId,
            "status": "approval"
        ]
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
