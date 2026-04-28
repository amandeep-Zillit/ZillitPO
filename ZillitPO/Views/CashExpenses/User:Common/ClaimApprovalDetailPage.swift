import SwiftUI

struct ClaimApprovalDetailPage: View {
    let claim: ClaimBatch
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var actioning = false
    @State private var showRejectSheet = false
    @State private var rejectReason = ""
    @State private var showHistory = false
    @State private var showQueries = false
    @State private var showActionsMenu = false
    @State private var historyEntries: [FloatHistoryEntry] = []
    @State private var isLoadingHistory = false

    private var isAccountant: Bool { appState.currentUser?.isAccountant == true }
    private var isApprover: Bool { appState.cashMeta?.isApprover == true }
    private var canOverride: Bool { appState.cashMeta?.canOverride == true }
    /// Anyone who can act on this batch — approvers (normal tier flow) and
    /// accountants. Both get Reject + Approve; accountants with
    /// `can_override` additionally get a gold Override button placed to the
    /// left in the same footer row.
    private var canAct: Bool {
        (claim.status ?? "").uppercased() == "AWAITING_APPROVAL" && (isApprover || isAccountant)
    }
    /// Show the extra Override row for accountants who have the `can_override`
    /// metadata flag set — independent of canAct's status gate so it's clear
    /// when the user has the privilege vs. whether the batch is actionable.
    private var showOverride: Bool { isAccountant && canOverride && canAct }
    private var totalApprovalTiers: Int { 2 }
    private var approvalsCount: Int { 0 } // ClaimBatch doesn't carry an approvals[] list

    private var user: AppUser? { UsersData.byId[claim.userId ?? ""] }

    private var roleLine: String {
        let role = user?.displayDesignation ?? ""
        let dept = (claim.department ?? "").isEmpty ? (user?.displayDepartment ?? "") : (claim.department ?? "")
        switch (role.isEmpty, dept.isEmpty) {
        case (false, false): return "\(role) · \(dept)"
        case (false, true):  return role
        case (true, false):  return dept
        default:             return ""
        }
    }

    private var typeLabel: String {
        if claim.isPettyCash { return "Petty Cash" }
        if claim.isOutOfPocket { return "Out of Pocket" }
        return (claim.expenseType ?? "").isEmpty ? "—" : (claim.expenseType ?? "").uppercased()
    }

    private var categoryLabel: String {
        if (claim.category ?? "").isEmpty { return "—" }
        if let m = claimCategories.first(where: { $0.0 == (claim.category ?? "") }) { return m.1 }
        return (claim.category ?? "").capitalized
    }

    private var settlementLabel: String {
        let s = (claim.settlementType ?? "").lowercased()
        switch s {
        case "":                       return "—"
        case "reduce", "reduce_float": return "Reduce Float"
        case "reimb", "reimburse":     return "Reimburse"
        case "reimburse_bacs", "bacs": return "Reimburse BACS"
        case "payroll":                return "Payroll"
        case "float":                  return "Float"
        default:                       return s.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgSurface.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    pendingHeader
                        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)
                    Divider()

                    detailsGrid
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                    Divider()

                    notesPanel
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                    Divider()

                    approvalProgressPanel
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                    if let reason = claim.rejectionReason, !reason.isEmpty {
                        Divider()
                        rejectionBanner(reason: reason)
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, canAct ? 100 : 24)
            }
            if canAct { actionFooter }
        }
        .navigationBarTitle(Text("\(claim.batchReference ?? "") — Receipt Batch"), displayMode: .inline)
        .navigationBarItems(trailing: trailingMenu)
        .background(
            NavigationLink(
                destination: ClaimHistoryPage(
                    batchId: resolvedBatchId,
                    label: claim.batchReference?.isEmpty == false ? (claim.batchReference ?? "Claim") : "Claim",
                    entries: historyEntries,
                    isLoading: isLoadingHistory
                ),
                isActive: $showHistory
            ) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            NavigationLink(
                destination: ClaimQueriesPage(
                    batchId: resolvedBatchId,
                    label: claim.batchReference?.isEmpty == false ? (claim.batchReference ?? "Claim") : "Claim"
                ).environmentObject(appState),
                isActive: $showQueries
            ) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            // iOS 13 fallback dropdown — same `showActionsMenu` flag as iOS 14+.
            Group {
                if #available(iOS 14.0, *) { EmptyView() }
                else {
                    Color.clear
                        .appDropdownMenu(
                            isPresented: $showActionsMenu,
                            items: [
                                .action("Query", systemImage: "text.bubble") { openQueries() },
                                .action("History", systemImage: "clock.arrow.circlepath") { openHistory() }
                            ]
                        )
                        .frame(width: 0, height: 0)
                }
            }
        )
        .sheet(isPresented: $showRejectSheet) { rejectSheet }
    }

    // MARK: - History / Query nav bar menu

    /// Prefer `claim.batchId` when populated (list came from /my-claims with
    /// joined batch id); fall back to `claim.id` when the row is already a
    /// batch record. Same rule as ClaimDetailPage.
    private var resolvedBatchId: String {
        if let bid = claim.batchId, !bid.isEmpty { return bid }
        return claim.id ?? ""
    }

    private func openHistory() {
        historyEntries = []
        showHistory = true
        isLoadingHistory = true
        appState.loadClaimHistory(resolvedBatchId) { entries in
            historyEntries = entries.sorted { ($0.actionAt ?? 0) > ($1.actionAt ?? 0) }
            isLoadingHistory = false
        }
    }

    private func openQueries() {
        showQueries = true
    }

    @ViewBuilder
    private var trailingMenu: some View {
        if #available(iOS 14.0, *) {
            Menu {
                Button { openQueries() } label: { Label("Query", systemImage: "text.bubble") }
                Button { openHistory() } label: { Label("History", systemImage: "clock.arrow.circlepath") }
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
        }
    }

    // MARK: - Header
    private var pendingHeader: some View {
        let name = user?.fullName ?? "—"
        let (badgeLabel, badgeFg, badgeBg) = statusBadge
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.system(size: 16, weight: .bold))
                if !roleLine.isEmpty {
                    Text(roleLine).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Text(FormatUtils.formatDateTime(claim.createdAt ?? 0))
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
            }
            Spacer(minLength: 8)
            Text(badgeLabel.uppercased())
                .font(.system(size: 10, weight: .bold)).foregroundColor(badgeFg)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(badgeBg).cornerRadius(6)
        }
    }

    private var statusBadge: (String, Color, Color) {
        switch (claim.status ?? "").uppercased() {
        case "AWAITING_APPROVAL": return ("Awaiting Approval", .goldDark, Color.gold.opacity(0.15))
        case "ACCT_OVERRIDE":     return ("Override",          .green,    Color.green.opacity(0.1))
        case "APPROVED":          return ("Approved",          .green,    Color.green.opacity(0.1))
        case "REJECTED":          return ("Rejected",          .red,      Color.red.opacity(0.1))
        case "POSTED":            return ("Posted",            .green,    Color.green.opacity(0.1))
        case "ESCALATED":         return ("Escalated",         .orange,   Color.orange.opacity(0.1))
        default:                  return (claim.statusDisplay, .goldDark, Color.gold.opacity(0.15))
        }
    }

    // MARK: - Grid
    private var detailsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                gridCell("TOTAL GROSS", FormatUtils.formatGBP(claim.totalGross ?? 0), valueColor: .goldDark, mono: true)
                gridCell("TOTAL NET", FormatUtils.formatGBP(claim.totalNet ?? 0), mono: true)
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("VAT", FormatUtils.formatGBP(claim.totalVat ?? 0), mono: true)
                gridCell("SETTLEMENT", settlementLabel)
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("TYPE", typeLabel)
                gridCell("CATEGORY", categoryLabel)
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("COST CODE", (claim.costCode ?? "").isEmpty ? "—" : (claim.costCode ?? "").uppercased())
                gridCell("RECEIPTS", "\(claim.claimCount ?? 0)")
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("BATCH REF", (claim.batchReference ?? "").isEmpty ? "—" : "#\(claim.batchReference ?? "")", mono: true)
                gridCell("DEPARTMENT", (claim.department ?? "").isEmpty ? "—" : (claim.department ?? ""))
            }
        }
    }

    private func gridCell(_ label: String, _ value: String,
                          valueColor: Color = .primary, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            Text(value)
                .font(mono
                      ? .system(size: 15, weight: .bold, design: .monospaced)
                      : .system(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Notes panel
    private var notesPanel: some View {
        let text: String = {
            if !(claim.codingDescription ?? "").isEmpty { return claim.codingDescription! }
            if !(claim.notes ?? "").isEmpty { return claim.notes! }
            return "—"
        }()
        return VStack(alignment: .leading, spacing: 6) {
            Text("NOTES / CODING DESCRIPTION")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            Text(text).font(.system(size: 13)).foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.bgRaised)
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Approval progress
    private var approvalProgressPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("APPROVAL PROGRESS (\(approvalsCount)/\(totalApprovalTiers))")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            switch (claim.status ?? "").uppercased() {
            case "AWAITING_APPROVAL":
                Text("Awaiting approval").font(.system(size: 13)).foregroundColor(.secondary)
            case "APPROVED", "ACCT_OVERRIDE":
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 12))
                    Text("Approved").font(.system(size: 13, weight: .semibold)).foregroundColor(.green)
                }
            case "REJECTED":
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red).font(.system(size: 12))
                    Text("Rejected").font(.system(size: 13, weight: .semibold)).foregroundColor(.red)
                }
            default:
                Text(claim.statusDisplay).font(.system(size: 13)).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Rejection banner
    private func rejectionBanner(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("REJECTION REASON")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.red).tracking(0.6)
            Text(reason).font(.system(size: 12)).foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 0)
    }

    // MARK: - Action footer (role-aware)
    //
    // Single row — Override | Reject | Approve. Override only appears when
    // the user is an accountant with `can_override`; everyone who canAct
    // sees Reject + Approve. All three share width equally.
    @ViewBuilder
    private var actionFooter: some View {
        HStack(spacing: 8) {
            if showOverride {
                Button(action: overrideBatch) {
                    HStack(spacing: 4) {
                        if actioning {
                            ActivityIndicator(isAnimating: true).frame(width: 12, height: 12)
                        }
                        Text(actioning ? "Overriding…" : "Override")
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.gold).cornerRadius(10)
                }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
            }
            Button(action: { showRejectSheet = true }) {
                Text("Reject").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.red).cornerRadius(10)
            }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
            Button(action: approveBatch) {
                HStack(spacing: 4) {
                    if actioning { ActivityIndicator(isAnimating: true).frame(width: 12, height: 12) }
                    Text(actioning ? "Approving…" : "Approve")
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.green).cornerRadius(10)
            }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.bgSurface)
        .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
    }

    private var rejectSheet: some View {
        NavigationView {
            ZStack {
                Color.bgBase.edgesIgnoringSafeArea(.all)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reject batch from \(user?.fullName ?? "—")")
                        .font(.system(size: 15, weight: .semibold))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reason").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                        TextField("Enter reason…", text: $rejectReason)
                            .font(.system(size: 14)).padding(10)
                            .background(Color.bgSurface).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }
                    Spacer()
                }.padding()
            }
            .navigationBarTitle(Text("Reject Batch"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { showRejectSheet = false; rejectReason = "" }.foregroundColor(.goldDark),
                trailing: Button("Reject") {
                    let r = rejectReason.trimmingCharacters(in: .whitespaces)
                    guard !r.isEmpty else { return }
                    showRejectSheet = false
                    rejectBatch(reason: r)
                }.foregroundColor(.red).font(.system(size: 16, weight: .bold))
            )
        }
    }

    // MARK: - Actions
    //
    // All three actions hit real server endpoints via the ViewModel:
    //   POST /api/v2/cash-expenses/claims/{id}/batch-approval   (approve | reject)
    //   POST /api/v2/cash-expenses/claims/{id}/override
    //
    // NOTE on tier numbering: the server enforces sequential tier approval
    // (tier 1 must be approved before tier 2, etc.). `ClaimBatch` doesn't
    // currently carry an approvals[] array so we default to tier 1 of 2 —
    // the server will return a "Tier N already approved" error if a later
    // tier is expected. The surfaced error message (humanised via our
    // APIError.serverError handler) tells the user to retry or escalate.

    private func approveBatch() {
        actioning = true
        appState.approveBatch(
            id: claim.id ?? "",
            tierNumber: 1,
            totalTiers: totalApprovalTiers
        ) { success in
            actioning = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }

    private func rejectBatch(reason: String) {
        actioning = true
        appState.rejectBatch(id: claim.id ?? "", reason: reason) { success in
            actioning = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }

    private func overrideBatch() {
        actioning = true
        appState.overrideBatch(id: claim.id ?? "") { success in
            actioning = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Float Request Form
// ═══════════════════════════════════════════════════════════════════

let durationOptions = ["3 days", "7 days", "10 days", "2 weeks"]
let collectionOptions = [
    ("production_office", "Collect from production office"),
    ("arrange_with_accountant", "Arrange with accountant"),
]
let costCodeOptions = [
    ("art_4100", "ART-4100 · Art Dept Misc"),
    ("art_4110", "ART-4110 · Set Dressing"),
    ("art_4120", "ART-4120 · Construction"),
    ("cost_2200", "COST-2200 · Costume"),
    ("prop_3300", "PROP-3300 · Props Purchase"),
    ("loc_3100", "LOC-3100 · Location Hire"),
    ("loc_3200", "LOC-3200 · Location Expenses"),
]
