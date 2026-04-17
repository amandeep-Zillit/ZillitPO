import SwiftUI

// MARK: - Payment Run Approval Page

struct PaymentRunApprovalPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToDetail = false
    @State private var selectedRun: PaymentRun?

    private var pendingRuns: [PaymentRun] {
        let uid = appState.userId
        let sortedAuth = appState.invoiceRunAuth.sorted { ($0.tier ?? 0) < ($1.tier ?? 0) }
        return appState.paymentRuns.filter { run in
            guard run.isPending else { return false }
            // If no run_authorization configured, show all pending runs
            if sortedAuth.isEmpty { return true }
            // Find the next unapproved tier
            let nextLevel = sortedAuth.first { level in
                !(run.approval ?? []).contains { $0.tierNumber == level.tier }
            }
            // Show only if current user is in that next tier
            return nextLevel?.user?.contains(uid) == true
        }.sorted { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }
    }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 0) {
                    if appState.isLoadingPaymentRuns && appState.paymentRuns.isEmpty {
                        LoaderView()
                            .frame(maxWidth: .infinity, minHeight: 480)
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
        .onAppear {
            // Always refresh on appear so the list stays current when the
            // user returns from a detail page (approvals may have changed).
            // The loader only shows on cold-open (when paymentRuns is empty)
            // so refreshes don't flash a spinner over existing rows.
            appState.loadPaymentRuns()
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
                Text(run.number ?? "").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(.goldDark)
                Text((run.name ?? "").isEmpty ? "Payment Run" : run.name ?? "").font(.system(size: 13, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                HStack(spacing: 8) {
                    if !(run.payMethod ?? "").isEmpty {
                        Text((run.payMethod ?? "").uppercased()).font(.system(size: 9, weight: .semibold)).foregroundColor(.blue)
                            .padding(.horizontal, 5).padding(.vertical, 2).background(Color.blue.opacity(0.08)).cornerRadius(3)
                    }
                    Text("\(run.invoiceCount ?? 0) invoice\((run.invoiceCount ?? 0) == 1 ? "" : "s")")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                let vis = appState.paymentRunApprovalVisibility(for: run)
                if vis.totalTiers > 0 {
                    Text("\(vis.approvedCount)/\(vis.totalTiers) approved").font(.system(size: 9, weight: .medium)).foregroundColor(.goldDark)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(FormatUtils.formatGBP(run.totalAmount ?? 0)).font(.system(size: 13, design: .monospaced))
                paymentRunStatusBadge
                if let ca = run.createdAt, ca > 0 {
                    Text(FormatUtils.formatTimestamp(ca)).font(.system(size: 9)).foregroundColor(.secondary)
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
            label = (run.status ?? "").capitalized; fg = .goldDark; bg = Color.gold.opacity(0.15)
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
        if !(liveRun.invoices ?? []).isEmpty { return liveRun.invoices ?? [] }
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
        let userAlreadyApproved = (liveRun.approval ?? []).contains { $0.userId == appState.userId }
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
        let auth = appState.invoiceRunAuth.sorted { ($0.tier ?? 0) < ($1.tier ?? 0) }
        guard !auth.isEmpty else { return [] }
        return auth.compactMap { level in
            let t = level.tier ?? 0
            let users = (level.user ?? []).compactMap { UsersData.byId[$0] }
            guard !users.isEmpty else { return nil }
            let isApproved = (liveRun.approval ?? []).contains { ($0.tierNumber ?? 0) == t }
            return (tier: t, users: users, isApproved: isApproved)
        }
    }

    // Pairs of tier items for 2-column layout
    private var tierPairs: [[(tier: Int, users: [AppUser], isApproved: Bool)]] {
        stride(from: 0, to: tierChain.count, by: 2).map { i in
            i + 1 < tierChain.count ? [tierChain[i], tierChain[i + 1]] : [tierChain[i]]
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Overall run status — shown here in the body (was
                    // previously a small badge in the nav bar). Surfaces
                    // Approved / Rejected / Pending + per-tier progress so
                    // the state is visible at a glance when the page opens.
                    statusHeader

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
                    } else {
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
        .navigationBarTitle(Text("\(liveRun.number ?? "") — \((liveRun.name ?? "").isEmpty ? "Payment Run" : liveRun.name ?? "")"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
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
            if (liveRun.invoices ?? []).isEmpty {
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
            summaryRow(label: "Run Number", value: (liveRun.number ?? "").isEmpty ? "—" : liveRun.number ?? "")
            Divider().padding(.leading, 14)

            // Run Name
            summaryRow(label: "Run Name", value: (liveRun.name ?? "").isEmpty ? "—" : liveRun.name ?? "")
            Divider().padding(.leading, 14)

            // Pay Method
            if !(liveRun.payMethod ?? "").isEmpty {
                HStack {
                    Text("Pay Method").font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    Text((liveRun.payMethod ?? "").uppercased())
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
                Text(FormatUtils.formatGBP(liveRun.totalAmount ?? 0))
                    .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Divider().padding(.leading, 14)

            // Computed Total (if different)
            if (liveRun.computedTotal ?? 0) > 0 && liveRun.computedTotal != liveRun.totalAmount {
                summaryRow(label: "Computed Total", value: FormatUtils.formatGBP(liveRun.computedTotal ?? 0))
                Divider().padding(.leading, 14)
            }

            // Invoice Count
            if (liveRun.invoiceCount ?? 0) > 0 {
                summaryRow(label: "Invoices", value: "\(liveRun.invoiceCount ?? 0) invoice\((liveRun.invoiceCount ?? 0) == 1 ? "" : "s")")
                Divider().padding(.leading, 14)
            }

            // Unique Vendors
            if !runInvoices.isEmpty {
                let vendorCount = Set(runInvoices.map { $0.supplierName ?? "" }).filter { !$0.isEmpty }.count
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
            if let ca = liveRun.createdAt, ca > 0 {
                summaryRow(label: "Created", value: FormatUtils.formatDateTime(ca))
            }

            // Updated Date
            if let ua = liveRun.updatedAt, ua > 0, ua != liveRun.createdAt {
                Divider().padding(.leading, 14)
                summaryRow(label: "Last Updated", value: FormatUtils.formatDateTime(ua))
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

    // MARK: - Status Header (run-level badge inside the details body)
    //
    // Shows the overall Pending / Approved / Rejected status with
    // per-tier progress. Rendered as the first block in the details
    // body so the page lands with a clear status read at the top.

    private var statusHeader: some View {
        let vis = appState.paymentRunApprovalVisibility(for: liveRun)
        let isApproved = liveRun.isApproved
        let isRejected = liveRun.isRejected
        let color: Color = isApproved ? .green : isRejected ? .red : .goldDark
        let label: String = {
            if isApproved { return "Approved" }
            if isRejected { return "Rejected" }
            if vis.totalTiers > 0 {
                return "Pending (\(vis.approvedCount)/\(vis.totalTiers))"
            }
            return "Pending"
        }()
        let icon: String = isApproved
            ? "checkmark.seal.fill"
            : isRejected
                ? "xmark.seal.fill"
                : "clock.fill"

        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("STATUS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary).tracking(0.5)
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(color)
            }
            Spacer()
            if vis.totalTiers > 0 && !isApproved && !isRejected {
                Text("\(vis.approvedCount)/\(vis.totalTiers) approved")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.goldDark)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.gold.opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Approval Chain

    private var approvalChainSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APPROVAL CHAIN")
                .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            VStack(spacing: 10) {
                ForEach(Array(tierPairs.enumerated()), id: \.offset) { _, pair in
                    HStack(alignment: .top, spacing: 10) {
                        tierCard(pair[0]).frame(maxWidth: .infinity, maxHeight: .infinity)
                        if pair.count > 1 {
                            tierCard(pair[1]).frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func tierCard(_ item: (tier: Int, users: [AppUser], isApproved: Bool)) -> some View {
        let color: Color = item.isApproved ? .green : liveRun.isRejected ? .red : .goldDark
        let statusLabel = item.isApproved ? "Approved" : liveRun.isRejected ? "Rejected" : "Pending"
        let approvedEntries = (liveRun.approval ?? []).filter { $0.tierNumber == item.tier }

        let userLine: String = {
            if item.isApproved {
                let names = approvedEntries.compactMap { entry -> String? in
                    let u = UsersData.byId[entry.userId ?? ""]
                    let name = u.flatMap { $0.fullName } ?? entry.userId ?? ""
                    let desg = u?.displayDesignation ?? ""
                    return desg.isEmpty ? name : "\(name) (\(desg))"
                }
                return names.joined(separator: ", ") + " · Approved"
            } else {
                let names = item.users.map { user -> String in
                    let desg = user.displayDesignation
                    let name = user.fullName ?? ""
                    return desg.isEmpty ? name : "\(name) (\(desg))"
                }
                return names.joined(separator: ", ") + " · Waiting"
            }
        }()

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Level \(item.tier)").font(.system(size: 13, weight: .bold))
                Spacer()
                Text(statusLabel)
                    .font(.system(size: 10, weight: .semibold)).foregroundColor(color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.12)).cornerRadius(5)
            }
            Text(userLine)
                .font(.system(size: 12))
                .foregroundColor(item.isApproved ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(0.05)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Invoices Table

    private var invoicesSection: some View {
        let vendorCount = Set(runInvoices.map { $0.supplierName ?? "" }).filter { !$0.isEmpty }.count
        let total = runInvoices.reduce(0.0) { $0 + ($1.amount ?? 0) }

        return VStack(alignment: .leading, spacing: 8) {
            // ── Section header with summary ──
            HStack {
                Text("INVOICES IN THIS RUN")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                Spacer()
                if !runInvoices.isEmpty {
                    Text("\(vendorCount) vendor\(vendorCount == 1 ? "" : "s") · \(runInvoices.count) invoice\(runInvoices.count == 1 ? "" : "s")")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }

            VStack(spacing: 0) {
                if runInvoices.isEmpty {
                    // ── Empty state ──
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text").font(.system(size: 22)).foregroundColor(.secondary.opacity(0.4))
                        Text("No invoices in this run")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                        Text("0 vendors · 0 invoices · \(FormatUtils.formatGBP(0))")
                            .font(.system(size: 11)).foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                } else {
                    ForEach(Array(runInvoices.enumerated()), id: \.element.id) { index, inv in
                        VStack(alignment: .leading, spacing: 6) {
                            // ── Row 1: Invoice number + Amount ──
                            HStack(alignment: .firstTextBaseline) {
                                Text((inv.invoiceNumber ?? "").isEmpty ? "—" : inv.invoiceNumber ?? "")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.goldDark)
                                    .lineLimit(1)
                                Spacer()
                                Text(FormatUtils.formatCurrency(inv.amount ?? 0, code: inv.currency ?? ""))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                            }
                            // ── Row 2: Vendor + Due date ──
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: "building.2").font(.system(size: 10)).foregroundColor(.secondary)
                                    Text((inv.supplierName ?? "").isEmpty ? "—" : inv.supplierName ?? "")
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                }
                                Spacer()
                                if let due = inv.dueDate, due > 0 {
                                    HStack(spacing: 3) {
                                        Image(systemName: "calendar").font(.system(size: 10)).foregroundColor(.secondary)
                                        Text(FormatUtils.formatTimestamp(due))
                                            .font(.system(size: 11)).foregroundColor(.secondary)
                                    }
                                }
                            }
                            // ── Row 3: Description ──
                            if !(inv.description ?? "").isEmpty {
                                Text(inv.description ?? "")
                                    .font(.system(size: 11)).foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)

                        if index < runInvoices.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }

                    // ── Footer ──
                    Divider()
                    HStack {
                        Text("\(vendorCount) vendor\(vendorCount == 1 ? "" : "s") · \(runInvoices.count) invoice\(runInvoices.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                        Spacer()
                        Text(FormatUtils.formatGBP(total))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.goldDark)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
            }
            .background(Color.bgSurface).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    // MARK: - Created By

    private var createdBySection: some View {
        let creator = liveRun.createdBy.flatMap { UsersData.byId[$0] }
        let rejector = liveRun.rejectedBy.flatMap { UsersData.byId[$0] }

        return VStack(alignment: .leading, spacing: 0) {
            // Created by
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.gold.opacity(0.15)).frame(width: 36, height: 36)
                    Text(creator?.initials ?? String((liveRun.createdBy ?? "").prefix(1)))
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.goldDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("CREATED BY").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    Text(creator.flatMap { $0.fullName } ?? liveRun.createdBy ?? "")
                        .font(.system(size: 14, weight: .semibold))
                    if let d = creator?.displayDesignation, !d.isEmpty {
                        Text(d).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    if let dept = creator?.displayDepartment, !dept.isEmpty {
                        Text(dept).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let ca = liveRun.createdAt, ca > 0 {
                    Text(FormatUtils.formatDateTime(ca))
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
                        Text(rejector.flatMap { $0.fullName } ?? rejBy)
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
