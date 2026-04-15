//
//  CashExpensesModuleView.swift
//  ZillitPO
//

import SwiftUI

// MARK: - File-scope helpers (shared across all views in this file)

/// Maps a float status string to (foreground, background) colors used for
/// status badges. Mirrors the backend FloatRequestService state machine:
///   AWAITING_APPROVAL → APPROVED/ACCT_OVERRIDE → READY_TO_COLLECT → COLLECTED →
///   ACTIVE/SPENDING/SPENT/PENDING_RETURN → CLOSED/CANCELLED/REJECTED
///
/// Every status has a distinct color so two different states never look alike
/// in the badge list (e.g. AWAITING_APPROVAL was previously confused with
/// PENDING_RETURN because both used orange).
func floatStatusColors(_ s: String) -> (Color, Color) {
    let teal  = Color(red: 0.0,  green: 0.6,  blue: 0.5)   // #009980  — collected (got cash)
    let pink  = Color(red: 0.91, green: 0.29, blue: 0.48)  // #E84A7A  — pending return (needs physical action)
    let amber = Color(red: 0.95, green: 0.6,  blue: 0.0)   // #F29A00  — awaiting approval
    switch s.uppercased() {
    case "AWAITING_APPROVAL":   return (amber, amber.opacity(0.12))              // amber — awaiting review
    case "APPROVED",
         "ACCT_OVERRIDE":       return (.green, Color.green.opacity(0.12))       // green — approved
    case "READY_TO_COLLECT":    return (.blue, Color.blue.opacity(0.12))         // blue  — crew action needed
    case "COLLECTED":           return (teal, teal.opacity(0.12))                // teal  — cash in hand
    case "ACTIVE",
         "SPENDING":            return (.goldDark, Color.gold.opacity(0.15))     // gold  — in-use
    case "SPENT":               return (.purple, Color.purple.opacity(0.12))     // purple— out of cash
    case "PENDING_RETURN":      return (pink, pink.opacity(0.12))                // pink  — return required
    case "CLOSED":              return (.gray, Color.gray.opacity(0.12))         // gray  — terminal ok
    case "CANCELLED",
         "REJECTED":            return (.red, Color.red.opacity(0.1))            // red   — terminal bad
    default: return (.goldDark, Color.gold.opacity(0.15))
    }
}

// MARK: - Cash & Expenses Hub (2 tiles: Petty Cash, Out of Pocket)

struct CashExpensesHubView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToPettyCash = false
    @State private var navigateToOOP = false
    @State private var navigateToAuditQueue = false
    @State private var navigateToApprovalQueue = false
    @State private var navigateToCodingQueue = false

    private var isAcct: Bool { appState.currentUser?.isAccountant == true }
    private var isCoord: Bool { appState.cashMeta?.is_coordinator == true }

    private var auditClaims: [ClaimBatch] { appState.auditQueue }
    private var approvalClaims: [ClaimBatch] { appState.approvalQueueClaims }
    private var approvalQueueTotal: Int { appState.approvalQueueFloats.count + appState.approvalQueueClaims.count }
    private var codingClaims: [ClaimBatch] { appState.codingQueue }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 12) {
                    // Petty Cash tile
                    NavigationLink(destination: PettyCashModuleView().environmentObject(appState), isActive: $navigateToPettyCash) { EmptyView() }.hidden()
                    Button(action: { navigateToPettyCash = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "banknote.fill").font(.system(size: 20)).foregroundColor(.white)
                                .frame(width: 36, height: 36).background(Color(red: 0.2, green: 0.7, blue: 0.45)).cornerRadius(8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Petty Cash").font(.system(size: 15, weight: .semibold))
                                Text("Manage floats, submit & track claims").font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.45))
                        }.padding(14).background(Color.bgSurface).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.2, green: 0.7, blue: 0.45).opacity(0.3), lineWidth: 1))
                        .contentShape(Rectangle())
                    }.buttonStyle(BorderlessButtonStyle())

                    // Out of Pocket tile
                    NavigationLink(destination: OutOfPocketModuleView().environmentObject(appState), isActive: $navigateToOOP) { EmptyView() }.hidden()
                    Button(action: { navigateToOOP = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "wallet.pass.fill").font(.system(size: 20)).foregroundColor(.white)
                                .frame(width: 36, height: 36).background(Color(red: 0.56, green: 0.27, blue: 0.68)).cornerRadius(8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Out of Pocket").font(.system(size: 15, weight: .semibold))
                                Text("Submit & track reimbursement claims").font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.56, green: 0.27, blue: 0.68))
                        }.padding(14).background(Color.bgSurface).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.56, green: 0.27, blue: 0.68).opacity(0.3), lineWidth: 1))
                        .contentShape(Rectangle())
                    }.buttonStyle(BorderlessButtonStyle())

                    // Approval Queue tile (accountant + coordinator)
                    if isAcct || isCoord {
                        NavigationLink(destination: ApprovalQueuePage().environmentObject(appState), isActive: $navigateToApprovalQueue) { EmptyView() }.hidden()
                        Button(action: { navigateToApprovalQueue = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.shield.checkmark.fill").font(.system(size: 20)).foregroundColor(.white)
                                    .frame(width: 36, height: 36).background(Color.goldDark).cornerRadius(8)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Approval Queue").font(.system(size: 15, weight: .semibold))
                                        if approvalQueueTotal > 0 {
                                            Text("\(approvalQueueTotal)")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.goldDark).cornerRadius(8)
                                        }
                                    }
                                    Text("Approve or reject pending floats & claims").font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.goldDark)
                            }.padding(14).background(Color.bgSurface).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                            .contentShape(Rectangle())
                        }.buttonStyle(BorderlessButtonStyle())
                    }

                    // Coordinator-only tiles
                    if isCoord && !isAcct {
                        // Coding Queue tile
                        NavigationLink(
                            destination: CodingQueueListView(claims: codingClaims, isLoading: appState.isLoadingCodingQueue).environmentObject(appState)
                                .navigationBarTitle(Text("Coding Queue"), displayMode: .inline)
                                .onAppear { appState.loadCodingQueue() },   // GET /cash-expenses/claims/coding-queue
                            isActive: $navigateToCodingQueue
                        ) { EmptyView() }.hidden()
                        Button(action: { navigateToCodingQueue = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 20)).foregroundColor(.white)
                                    .frame(width: 36, height: 36).background(Color.blue).cornerRadius(8)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Coding Queue").font(.system(size: 15, weight: .semibold))
                                        if !codingClaims.isEmpty {
                                            Text("\(codingClaims.count)")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.blue).cornerRadius(8)
                                        }
                                    }
                                    Text("Claims awaiting budget coding").font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.blue)
                            }.padding(14).background(Color.bgSurface).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                            .contentShape(Rectangle())
                        }.buttonStyle(BorderlessButtonStyle())

                    }

                    Spacer()
                }
                .padding(.horizontal, 20).padding(.top, 20)
            }
        }
        .navigationBarTitle(Text("Cash & Expenses"), displayMode: .inline)
        .onAppear {
            // Only metadata — each tile loads its own data on appear
            appState.loadCashExpenseMetadata()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Petty Cash Module (role-based tabs)
// ═══════════════════════════════════════════════════════════════════

struct PettyCashModuleView: View {
    @EnvironmentObject var appState: POViewModel

    private var isAcct: Bool { appState.currentUser?.isAccountant == true }
    private var isCoord: Bool { appState.cashMeta?.is_coordinator == true }
    private var isSenior: Bool { appState.cashMeta?.is_senior == true }

    /// A float is "open" when it's not in a terminal state.
    /// Terminal statuses (backend FloatRequestService): CLOSED, CANCELLED, REJECTED.
    private var hasOpenFloat: Bool {
        let terminal: Set<String> = ["CLOSED", "CANCELLED", "REJECTED"]
        return appState.myFloats.contains { !terminal.contains($0.status.uppercased()) }
    }

    /// Whether the New Float button should be visible for the current role/tab.
    /// Hidden while underlying data is still loading so the button only appears
    /// once we know whether the user/account is in a state to create a float.
    private var showNewFloatButton: Bool {
        if isAcct {
            // Accountants see the button on the Active Floats register (to add on behalf of users).
            // Wait for activeFloats to finish loading so it shows up after the loader, not over it.
            return activeTab == "Active Floats" && !appState.isLoadingActiveFloats
        }
        // Crew / coordinator request new floats from the Float Request tab.
        // Wait for myFloats to load so we know whether they already have an open float.
        return activeTab == "Float Request" && !appState.isLoadingMyFloats
    }

    /// Whether the button should be disabled (tappable → opens form).
    private var newFloatDisabled: Bool {
        // Accountants can always create floats — on behalf of any user, no personal open-float restriction
        if isAcct { return false }
        // Crew/coord can only have one open float at a time
        return hasOpenFloat
    }

    private var tabs: [String] {
        if isAcct {
            return ["Active Floats", "Top-ups"]
        }
        if isCoord {
            return ["Active Floats", "Float Request", "Submit Receipts", "Receipts History"]
        }
        // User (Crew)
        return ["Float Request", "Submit Receipts", "Receipts History"]
    }

    @State private var activeTab = ""
    @State private var navigateToNewFloat = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Tab bar
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        let isActive = activeTab == tab
                        Button(action: { activeTab = tab }) {
                            Text(tab).font(.system(size: 11, weight: isActive ? .semibold : .regular)).lineLimit(1)
                                .foregroundColor(isActive ? .goldDark : .secondary)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .overlay(isActive ? Rectangle().fill(Color.goldDark).frame(height: 2) : nil, alignment: .bottom)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
                .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)

                // Content
                cashTabContent
            }

            if showNewFloatButton {
                Button(action: { navigateToNewFloat = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text("New Float").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(Color.gold).cornerRadius(28)
                    .opacity(newFloatDisabled ? 0.5 : 1)
                }
                .disabled(newFloatDisabled)
                .padding(.trailing, 20).padding(.bottom, 24)
            }
        }
        .background(
            NavigationLink(destination: FloatRequestFormView().environmentObject(appState).navigationBarTitle(Text("New Float"), displayMode: .inline), isActive: $navigateToNewFloat) { EmptyView() }
                .frame(width: 0, height: 0).hidden()
        )
        .background(Color.bgBase)
        .navigationBarTitle(Text("Petty Cash"), displayMode: .inline)
        .onAppear {
            if activeTab.isEmpty { activeTab = isAcct ? "Active Floats" : isCoord ? "Active Floats" : "Float Request" }
            appState.loadCashExpenseMetadata()
        }
    }

    @ViewBuilder
    private var cashTabContent: some View {
        switch activeTab {
        case "Active Floats":
            FloatsListView(floats: appState.activeFloats).environmentObject(appState)
                .onAppear { appState.loadActiveFloats() }
        case "Post & Ledger":
            ClaimsListView(claims: appState.allPettyCashClaims.filter { ["READY_TO_POST", "POSTED"].contains($0.status.uppercased()) }, title: "Post & Ledger", isLoading: appState.isLoadingAllClaims, hideFilterSearch: true).environmentObject(appState)
                .onAppear { appState.loadAllClaims() }
        case "Cash Recon":
            ReconciliationView().environmentObject(appState)
                .onAppear { appState.loadActiveFloats() }
        case "Sign-off":
            SignOffListView().environmentObject(appState)
                .onAppear { appState.loadSignOffQueue() }
        case "Approval Queue":
            ApprovalQueuePage().environmentObject(appState)
        case "History":
            ClaimsListView(claims: appState.allPettyCashClaims, title: "History", isLoading: appState.isLoadingAllClaims).environmentObject(appState)
                .onAppear { appState.loadAllClaims() }
        case "Top-ups":
            CashTopUpsView().environmentObject(appState)
        case "Coding Queue":
            CodingQueueListView(claims: appState.codingQueue, isLoading: appState.isLoadingCodingQueue).environmentObject(appState)
                .onAppear { appState.loadCodingQueue() }
        case "Float Request":
            FloatRequestListView().environmentObject(appState)
                .onAppear { appState.loadMyFloats() }
        case "Submit Receipts":
            SubmitClaimFormView(expenseType: "pc").environmentObject(appState)
        case "Receipts History":
            ClaimsListView(claims: appState.myPettyCashClaims, title: "Receipts History", isLoading: appState.isLoadingMyClaims, filterMode: .myClaims).environmentObject(appState)
                .onAppear { appState.loadMyClaims() }
        default: EmptyView()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Out of Pocket Module (role-based tabs)
// ═══════════════════════════════════════════════════════════════════

struct OutOfPocketModuleView: View {
    @EnvironmentObject var appState: POViewModel

    private var isAcct: Bool { appState.currentUser?.isAccountant == true }
    private var isApprover: Bool { appState.cashMeta?.is_approver == true }
    private var isSenior: Bool { appState.cashMeta?.is_senior == true }

    private var isCoord: Bool { appState.cashMeta?.is_coordinator == true }

    private var tabs: [String] {
        if isAcct {
            return ["Payment Routing"]
        }
        if isCoord {
            return ["Submit Receipts", "Receipts History"]
        }
        // User (Crew)
        return ["Submit Receipts", "Receipts History"]
    }

    @State private var activeTab = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    let isActive = activeTab == tab
                    Button(action: { activeTab = tab }) {
                        Text(tab).font(.system(size: 11, weight: isActive ? .semibold : .regular)).lineLimit(1)
                            .foregroundColor(isActive ? .goldDark : .secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .overlay(isActive ? Rectangle().fill(Color.goldDark).frame(height: 2) : nil, alignment: .bottom)
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)

            oopTabContent
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Out of Pocket"), displayMode: .inline)
        .onAppear {
            if activeTab.isEmpty { activeTab = isAcct ? "Payment Routing" : "Submit Receipts" }
            appState.loadCashExpenseMetadata()
        }
    }

    private func oopStatCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(.primary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(10)
        .background(Color.bgSurface).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
    }

    private func oopStatsCards(_ claims: [ClaimBatch], firstLabel: String) -> some View {
        let total = claims.reduce(0.0) { $0 + $1.totalGross }
        let claimants = Set(claims.map { $0.userId }).count
        return HStack(spacing: 8) {
            oopStatCard(label: firstLabel, value: "\(claims.count)")
            oopStatCard(label: "TOTAL VALUE", value: FormatUtils.formatGBP(total))
            oopStatCard(label: "CLAIMANTS", value: "\(claimants)")
        }
        .frame(height: 64)
        .padding(.horizontal, 16).padding(.top, 12)
    }

    @ViewBuilder
    private var oopTabContent: some View {
        switch activeTab {
        case "Post & Ledger":
            let c = appState.allOOPClaims.filter { ["READY_TO_POST", "POSTED"].contains($0.status.uppercased()) }
            VStack(spacing: 0) {
                oopStatsCards(c, firstLabel: "BATCHES")
                ClaimsListView(claims: c, title: "Post & Ledger", isLoading: appState.isLoadingAllClaims, hideFilterSearch: true).environmentObject(appState)
            }
            .onAppear { appState.loadAllClaims() }
        case "Payment Routing":
            PaymentRoutingView().environmentObject(appState)
        case "Sign-off":
            let c = appState.signOffQueue.filter { $0.isOutOfPocket }
            VStack(spacing: 0) {
                oopStatsCards(c, firstLabel: "AWAITING SIGN-OFF")
                OOPSignOffListView().environmentObject(appState)
            }
            .onAppear { appState.loadSignOffQueue() }
        case "Approval Queue":
            ApprovalQueuePage().environmentObject(appState)
        case "History":
            let c = appState.allOOPClaims
            VStack(spacing: 0) {
                oopStatsCards(c, firstLabel: "BATCHES")
                ClaimsListView(claims: c, title: "History", isLoading: appState.isLoadingAllClaims).environmentObject(appState)
            }
            .onAppear { appState.loadAllClaims() }
        case "Coding Queue":
            ClaimsListView(claims: appState.codingQueue, title: "Coding Queue", isLoading: appState.isLoadingCodingQueue, filterMode: .expenseType).environmentObject(appState)
                .onAppear { appState.loadCodingQueue() }
        case "Submit Receipts":
            SubmitClaimFormView(expenseType: "oop").environmentObject(appState)
        case "Receipts History":
            ClaimsListView(claims: appState.myOOPClaims, title: "Receipts History", isLoading: appState.isLoadingMyClaims, filterMode: .myClaims).environmentObject(appState)
                .onAppear { appState.loadMyClaims() }
        default: EmptyView()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Claims List View (reusable)
// ═══════════════════════════════════════════════════════════════════

enum ClaimFilterMode { case status, expenseType, myClaims }

struct ClaimsListView: View {
    let claims: [ClaimBatch]
    var title: String = ""
    var isLoading: Bool = false
    @EnvironmentObject var appState: POViewModel
    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var activeFilter = "All"

    var filterMode: ClaimFilterMode = .status
    var hideFilterSearch: Bool = false

    private var filters: [String] {
        switch filterMode {
        case .expenseType:
            return ["All", "Petty Cash", "Out of Pocket"]
        case .myClaims:
            return ["All", "With Coordinator", "In Audit", "Awaiting Approval", "Ready to Post", "Rejected", "Under Review", "Escalated", "Queried", "Posted"]
        case .status:
            var unique = Set<String>()
            for c in claims { unique.insert(c.statusDisplay) }
            var list = ["All"]
            let order = ["Coding", "Coded", "In Audit", "Awaiting Approval", "Escalated", "Approved", "Override", "Ready to Post", "Posted", "Rejected"]
            for s in order { if unique.contains(s) { list.append(s) } }
            for s in unique.sorted() { if !list.contains(s) { list.append(s) } }
            return list
        }
    }

    private var filtered: [ClaimBatch] {
        var list = claims
        if activeFilter != "All" {
            switch filterMode {
            case .expenseType:
                if activeFilter == "Petty Cash" { list = list.filter { $0.isPettyCash } }
                else if activeFilter == "Out of Pocket" { list = list.filter { $0.isOutOfPocket } }
            case .myClaims:
                let mapped: String = {
                    switch activeFilter {
                    case "With Coordinator": return "CODING"
                    case "In Audit": return "IN_AUDIT"
                    case "Awaiting Approval": return "AWAITING_APPROVAL"
                    case "Ready to Post": return "READY_TO_POST"
                    case "Rejected": return "REJECTED"
                    case "Under Review": return "UNDER_REVIEW"
                    case "Escalated": return "ESCALATED"
                    case "Queried": return "QUERIED"
                    case "Posted": return "POSTED"
                    default: return activeFilter.uppercased()
                    }
                }()
                list = list.filter { $0.status.uppercased() == mapped || ($0.status.uppercased() == "CODED" && mapped == "CODING") }
            case .status:
                list = list.filter { $0.statusDisplay == activeFilter }
            }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter { $0.batchReference.lowercased().contains(q) || $0.notes.lowercased().contains(q) || $0.department.lowercased().contains(q) }
        }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !hideFilterSearch {
                // Search + Filter in one line
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                        TextField("Search claims…", text: $searchText).font(.system(size: 14))
                    }
                    .padding(10).background(Color.bgSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                    Button(action: { showFilterSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                            Text(activeFilter).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                            Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 10).background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .selectionActionSheet(
                        title: filterMode == .expenseType ? "Filter by Type" : "Filter by Status",
                        isPresented: $showFilterSheet,
                        options: filters,
                        isSelected: { $0 == activeFilter },
                        label: { $0 },
                        onSelect: { activeFilter = $0 }
                    )
                }.padding(.horizontal, 16).padding(.top, 12)
            }

            ScrollView {
                VStack(spacing: 10) {
                    if isLoading && claims.isEmpty {
                        LoaderView()
                    } else if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("No claims found").font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 480)
                    } else {
                        ForEach(filtered) { claim in
                            if filterMode == .myClaims {
                                NavigationLink(destination: ClaimDetailPage(claim: claim)) {
                                    ClaimRow(claim: claim)
                                }.buttonStyle(PlainButtonStyle())
                            } else {
                                ClaimRow(claim: claim)
                            }
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Claim Row

struct ClaimRow: View {
    let claim: ClaimBatch

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: reference + status
            HStack {
                Text(claim.batchReference.isEmpty ? "—" : claim.batchReference)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                Spacer()
                let (fg, bg) = claimStatusColor(claim.status)
                Text(claim.statusDisplay).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
            }
            // Type badge + department
            HStack(spacing: 6) {
                Text(claim.isPettyCash ? "Petty Cash" : "Out of Pocket")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(claim.isPettyCash ? Color(red: 0.2, green: 0.7, blue: 0.45) : .purple)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background((claim.isPettyCash ? Color(red: 0.2, green: 0.7, blue: 0.45) : Color.purple).opacity(0.1)).cornerRadius(3)
                if !claim.department.isEmpty {
                    Text(claim.department).font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            // Submitter
            if let user = UsersData.byId[claim.userId] {
                Text(user.fullName).font(.system(size: 13, weight: .medium))
            }
            // Amounts
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Gross").font(.system(size: 9)).foregroundColor(.secondary)
                    Text(FormatUtils.formatGBP(claim.totalGross)).font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Net").font(.system(size: 9)).foregroundColor(.secondary)
                    Text(FormatUtils.formatGBP(claim.totalNet)).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("VAT").font(.system(size: 9)).foregroundColor(.secondary)
                    Text(FormatUtils.formatGBP(claim.totalVat)).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(.secondary)
                }
                Spacer()
                if claim.claimCount > 0 {
                    Text("\(claim.claimCount) item\(claim.claimCount == 1 ? "" : "s")")
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
            }
            // Rejection
            if let reason = claim.rejectionReason, !reason.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundColor(.red)
                    Text(reason).font(.system(size: 10)).foregroundColor(.red).lineLimit(1)
                }
            }
            // Date
            if claim.createdAt > 0 {
                Text(FormatUtils.formatDateTime(claim.createdAt)).font(.system(size: 10)).foregroundColor(.gray)
            }
        }
        .padding(12).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func claimStatusColor(_ s: String) -> (Color, Color) {
        switch s.uppercased() {
        case "CODING", "CODED": return (.blue, Color.blue.opacity(0.1))
        case "IN_AUDIT": return (.purple, Color.purple.opacity(0.1))
        case "AWAITING_APPROVAL": return (.goldDark, Color.gold.opacity(0.15))
        case "APPROVED", "ACCT_OVERRIDE": return (.green, Color.green.opacity(0.1))
        case "READY_TO_POST": return (.blue, Color.blue.opacity(0.1))
        case "POSTED": return (.green, Color.green.opacity(0.1))
        case "REJECTED": return (.red, Color.red.opacity(0.1))
        case "ESCALATED": return (.orange, Color.orange.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

// MARK: - Floats List View

// ═══════════════════════════════════════════════════════════════════
// MARK: - Cash Top-ups View (accountant side, Petty Cash tab)
// ═══════════════════════════════════════════════════════════════════

struct CashTopUpsView: View {
    @EnvironmentObject var appState: POViewModel

    enum TopUpFilter: String, CaseIterable {
        case all = "All", pending = "Pending", completed = "Completed", skipped = "Skipped"
    }
    @State private var activeFilter: TopUpFilter = .all
    @State private var showFilterSheet = false

    private var pending: [TopUpItem] {
        appState.cashTopUpQueue
            .filter { $0.status.lowercased() == "pending" }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var history: [TopUpItem] {
        appState.cashTopUpQueue
            .filter { ["completed", "partial", "skipped"].contains($0.status.lowercased()) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var filteredPending: [TopUpItem] {
        switch activeFilter {
        case .all, .pending: return pending
        default: return []
        }
    }

    private var filteredHistory: [TopUpItem] {
        switch activeFilter {
        case .all: return history
        case .pending: return []
        case .completed: return history.filter { ["completed", "partial"].contains($0.status.lowercased()) }
        case .skipped: return history.filter { $0.status.lowercased() == "skipped" }
        }
    }

    var body: some View {
        Group {
            if appState.isLoadingTopUps && appState.cashTopUpQueue.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
                    .background(Color.bgBase)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        infoBanner
                        filterBar
                        if !filteredPending.isEmpty { pendingSection }
                        if !filteredHistory.isEmpty { historySection }
                        if filteredPending.isEmpty && filteredHistory.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
                }
                .background(Color.bgBase)
            }
        }
        .onAppear { appState.loadTopUpQueue() }
    }

    // ── Orange info banner ────────────────────────────────────────
    private var infoBanner: some View {
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "chart.bar.fill").font(.system(size: 12)).foregroundColor(orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Petty Cash Top-Ups")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(orange)
                Text("Cash float top-up requests created from crew claim submissions. Mark as topped-up when you hand over the cash.")
                    .font(.system(size: 11)).foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(orange.opacity(0.08)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(orange.opacity(0.25), lineWidth: 1))
    }

    // ── Filter dropdown (compact action sheet) ────────────────────
    private var filterBar: some View {
        HStack(spacing: 6) {
            Button(action: { showFilterSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                    Text(activeFilter.rawValue)
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.bgSurface).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
            .selectionActionSheet(
                title: "Filter by Status",
                isPresented: $showFilterSheet,
                options: TopUpFilter.allCases,
                isSelected: { $0 == activeFilter },
                label: { $0.rawValue },
                onSelect: { activeFilter = $0 }
            )
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle").font(.system(size: 28)).foregroundColor(.gray.opacity(0.35))
            Text("No top-ups match this filter").font(.system(size: 13)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private var summaryCards: some View {
        let pendingTotal = pending.reduce(0.0) { $0 + $1.amount }
        let completedTotal = history.filter { $0.status.lowercased() == "completed" }.reduce(0.0) { $0 + $1.amount }
        return HStack(spacing: 8) {
            statCard(label: "PENDING", value: FormatUtils.formatGBP(pendingTotal),
                     sub: "\(pending.count) request\(pending.count == 1 ? "" : "s")",
                     color: Color(red: 0.95, green: 0.55, blue: 0.15))
            statCard(label: "COMPLETED", value: FormatUtils.formatGBP(completedTotal),
                     sub: "\(history.filter { $0.status.lowercased() == "completed" }.count) completed",
                     color: Color(red: 0.0, green: 0.6, blue: 0.5))
        }
        .frame(height: 80)
    }

    private func statCard(label: String, value: String, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            Text(value).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(color)
            Text(sub).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(Color.bgSurface).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
    }

    private var pendingSection: some View {
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").font(.system(size: 12)).foregroundColor(orange)
                Text("PENDING TOP-UPS").font(.system(size: 11, weight: .bold)).tracking(0.4)
                Text("\(filteredPending.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(orange).cornerRadius(8)
                Spacer()
            }
            .padding(12).background(orange.opacity(0.06))

            ForEach(filteredPending) { item in
                Divider()
                cashTopUpRow(item, isPending: true)
            }
        }
        .background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private var historySection: some View {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let title: String = {
            switch activeFilter {
            case .completed: return "COMPLETED"
            case .skipped:   return "SKIPPED"
            default:         return "COMPLETED & SKIPPED"
            }
        }()
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundColor(teal)
                Text(title).font(.system(size: 11, weight: .bold)).tracking(0.4)
                Text("\(filteredHistory.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2)).cornerRadius(8)
                Spacer()
            }
            .padding(12).background(Color.gray.opacity(0.06))

            ForEach(filteredHistory) { item in
                Divider()
                cashTopUpRow(item, isPending: false)
            }
        }
        .background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private func cashTopUpRow(_ item: TopUpItem, isPending: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Info section — wrapped in NavigationLink so tapping opens the
            // full-page Top-Up Details view. Action buttons stay outside
            // the link so they don't trigger navigation.
            NavigationLink(destination: CashTopUpDetailPage(item: item)) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.holderName.isEmpty ? "—" : item.holderName)
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                        if !item.department.isEmpty {
                            Text(item.department).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        if !item.floatReqNumber.isEmpty {
                            Text(item.floatReqNumber).font(.system(size: 10, design: .monospaced)).foregroundColor(.goldDark)
                        }
                        // Date/time line — "Requested DD MMM YYYY | h:mm a"
                        // for pending items, "Completed …" / "Skipped …" for
                        // history items (uses updatedAt when available).
                        if let dateLine = topUpDateLine(item, isPending: isPending), !dateLine.isEmpty {
                            Text(dateLine)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(FormatUtils.formatGBP(item.amount))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
                        statusBadge(item.status)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10)).foregroundColor(.gray.opacity(0.6))
                        .padding(.leading, 2).padding(.top, 4)
                }
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if isPending {
                HStack(spacing: 8) {
                    Button(action: { appState.markTopUpCompleted(item.id, amount: item.amount) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 11))
                            Text("Mark Topped Up").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color(red: 0.0, green: 0.6, blue: 0.5)).cornerRadius(6)
                    }.buttonStyle(BorderlessButtonStyle())
                    Button(action: { appState.skipTopUp(item.id) }) {
                        Text("Skip").font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                    Spacer()
                }
            }
        }
        .padding(12)
    }

    /// Builds the date/time line shown under each top-up row.
    ///   • Pending → "Requested 14 Apr 2026 | 10:42 AM"
    ///   • History → "Completed 14 Apr 2026 | 11:03 AM" (uses updatedAt),
    ///     or "Skipped …" for skipped items.
    /// Falls back to createdAt if updatedAt isn't set.
    private func topUpDateLine(_ item: TopUpItem, isPending: Bool) -> String? {
        let ts: Int64 = (isPending ? item.createdAt : (item.updatedAt > 0 ? item.updatedAt : item.createdAt))
        guard ts > 0 else { return nil }
        let stamp = FormatUtils.formatDateTime(ts)
        if isPending { return "Requested \(stamp)" }
        switch item.status.lowercased() {
        case "completed": return "Completed \(stamp)"
        case "partial":   return "Partial top-up \(stamp)"
        case "skipped":   return "Skipped \(stamp)"
        default:          return stamp
        }
    }

    private func statusBadge(_ s: String) -> some View {
        let (fg, bg, label): (Color, Color, String) = {
            switch s.lowercased() {
            case "pending":   return (Color(red: 0.95, green: 0.55, blue: 0.15), Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.12), "Pending")
            case "completed": return (Color(red: 0.0, green: 0.6, blue: 0.5), Color(red: 0.0, green: 0.6, blue: 0.5).opacity(0.12), "Completed")
            case "partial":   return (.blue, Color.blue.opacity(0.12), "Partial")
            case "skipped":   return (.gray, Color.gray.opacity(0.12), "Skipped")
            default:          return (.secondary, Color.gray.opacity(0.12), s.capitalized)
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(bg).cornerRadius(4)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Cash Top-Up Detail Page
// Full-page layout matching the "Top-Up Details" screenshot:
// header with icon, then a 2x2 grid of details (HOLDER / FLOAT,
// AMOUNT / STATUS, FLOAT BALANCE / FLOAT ISSUED, CREATED / UPDATED).
// ═══════════════════════════════════════════════════════════════════

struct CashTopUpDetailPage: View {
    let item: TopUpItem

    private var user: AppUser? { UsersData.byId[item.userId] }

    private var subtitleLine: String {
        let role = user?.displayDesignation ?? ""
        let dept = item.department.isEmpty ? (user?.displayDepartment ?? "") : item.department
        switch (role.isEmpty, dept.isEmpty) {
        case (false, false): return "\(role) · \(dept)"
        case (false, true):  return role
        case (true, false):  return dept
        default:             return ""
        }
    }

    private var statusDisplay: String { item.statusDisplay }

    private var statusColor: Color {
        switch item.status.lowercased() {
        case "pending":   return Color(red: 0.95, green: 0.55, blue: 0.15)
        case "completed": return Color(red: 0.0,  green: 0.6,  blue: 0.5)
        case "partial":   return .blue
        case "skipped":   return .gray
        default:          return .secondary
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header: icon + "Top-Up Details" ─────────────────────
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18)).foregroundColor(.goldDark)
                        .frame(width: 34, height: 34)
                        .background(Color.gold.opacity(0.15)).cornerRadius(8)
                    Text("Top-Up Details").font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

                Divider()

                // ── 2-column grid of details ────────────────────────────
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        detailCell(
                            label: "HOLDER",
                            primary: item.holderName.isEmpty ? "—" : item.holderName,
                            secondary: subtitleLine
                        )
                        detailCell(
                            label: "FLOAT",
                            primary: item.floatReqNumber.isEmpty ? "—" : "#\(item.floatReqNumber)",
                            mono: true
                        )
                    }
                    HStack(alignment: .top, spacing: 16) {
                        detailCell(
                            label: "AMOUNT",
                            primary: FormatUtils.formatGBP(item.amount),
                            primaryColor: Color(red: 0.95, green: 0.55, blue: 0.15),
                            mono: true
                        )
                        detailCell(
                            label: "STATUS",
                            primary: statusDisplay,
                            primaryColor: statusColor
                        )
                    }
                    HStack(alignment: .top, spacing: 16) {
                        detailCell(
                            label: "FLOAT BALANCE",
                            primary: FormatUtils.formatGBP(item.floatBalance),
                            mono: true
                        )
                        detailCell(
                            label: "FLOAT ISSUED",
                            primary: FormatUtils.formatGBP(item.floatIssued),
                            mono: true
                        )
                    }
                    HStack(alignment: .top, spacing: 16) {
                        detailCell(
                            label: "CREATED",
                            primary: item.createdAt > 0 ? FormatUtils.formatDateTime(item.createdAt) : "—",
                            mono: true
                        )
                        detailCell(
                            label: "UPDATED",
                            primary: item.updatedAt > 0 ? FormatUtils.formatDateTime(item.updatedAt) : "—",
                            mono: true
                        )
                    }
                }
                .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 18)

                // ── Optional note ───────────────────────────────────────
                if !item.note.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTE")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        Text(item.note).font(.system(size: 13)).foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).background(Color.bgRaised).cornerRadius(8)
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bgSurface)
        .navigationBarTitle(Text("Top-Up Details"), displayMode: .inline)
    }

    /// Two-line cell: uppercase grey label on top, bold value below,
    /// optional secondary line under the primary (used by HOLDER which
    /// shows the role · department under the name).
    private func detailCell(label: String,
                            primary: String,
                            secondary: String? = nil,
                            primaryColor: Color = .primary,
                            mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            Text(primary)
                .font(mono
                      ? .system(size: 15, weight: .bold, design: .monospaced)
                      : .system(size: 15, weight: .semibold))
                .foregroundColor(primaryColor)
                .fixedSize(horizontal: false, vertical: true)
            if let s = secondary, !s.isEmpty {
                Text(s).font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FloatsListView: View {
    let floats: [FloatRequest]
    @EnvironmentObject var appState: POViewModel

    @State private var searchText: String = ""
    @State private var showRecordReturn: Bool = false

    private var totalOutstanding: Double { floats.reduce(0) { $0 + $1.remaining } }

    /// Filters by crew member name, department, float ref number or purpose.
    private var filteredFloats: [FloatRequest] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return floats }
        return floats.filter { f in
            let name = UsersData.byId[f.userId]?.fullName.lowercased() ?? ""
            return f.reqNumber.lowercased().contains(q)
                || name.contains(q)
                || f.department.lowercased().contains(q)
                || f.purpose.lowercased().contains(q)
        }
    }

    var body: some View {
        Group {
            if appState.isLoadingActiveFloats && floats.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bgBase)
            } else {
                // Fixed header + search bar at the top; only the float list
                // below scrolls.
                VStack(alignment: .leading, spacing: 0) {
                    // ── Register header + Record Cash Return action ──
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active Floats Register").font(.system(size: 15, weight: .bold))
                            Text("\(floats.count) active float\(floats.count == 1 ? "" : "s") · \(FormatUtils.formatGBP(totalOutstanding)) outstanding")
                                .font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        if !floats.isEmpty {
                            NavigationLink(
                                destination: RecordCashReturnPage(floats: floats).environmentObject(appState),
                                isActive: $showRecordReturn
                            ) { EmptyView() }.frame(width: 0, height: 0).hidden()
                            Button(action: { showRecordReturn = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .font(.system(size: 11))
                                    Text("Record Cash Return").font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Color.goldDark).cornerRadius(6)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)

                    // ── Search bar (fixed) ───────────────────────────
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12)).foregroundColor(.gray)
                        TextField("Search by crew, department, ref…", text: $searchText)
                            .font(.system(size: 13))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12)).foregroundColor(.gray)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.bgSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    .padding(.horizontal, 16).padding(.bottom, 10)

                    // ── Scrollable list below ─────────────────────────
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if floats.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer(minLength: 0)
                                    Image(systemName: "banknote").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                    Text("No active floats").font(.system(size: 13)).foregroundColor(.secondary)
                                    Spacer(minLength: 0)
                                }.frame(maxWidth: .infinity, minHeight: 480)
                            } else if filteredFloats.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer(minLength: 0)
                                    Image(systemName: "magnifyingglass").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                    Text("No floats match \"\(searchText)\"").font(.system(size: 13)).foregroundColor(.secondary)
                                    Spacer(minLength: 0)
                                }.frame(maxWidth: .infinity, minHeight: 320)
                            } else {
                                ForEach(filteredFloats) { f in
                                    NavigationLink(destination: FloatDetailView(float: f).environmentObject(appState)) {
                                        FloatCard(
                                            float: f,
                                            batches: appState.allClaims.filter { $0.floatRequestId == f.id },
                                            disableInternalTap: true
                                        )
                                        .padding(.horizontal, 16)
                                    }.buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.top, 2).padding(.bottom, 20)
                    }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Record Manual Cash Return page (navigation-pushed)
// Select a float → enter amount + date + reason + optional notes →
// POST /record-return. Rendered as a pushed detail page (not a
// modal sheet) so it sits natively in the nav stack.
// ═══════════════════════════════════════════════════════════════════

struct RecordCashReturnPage: View {
    let floats: [FloatRequest]
    /// Optional float id to preselect on appear — used when the page is
    /// opened from a specific float's detail page so the user doesn't
    /// have to pick again. When nil, the picker starts empty.
    var preselectedFloatId: String? = nil
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedFloatId: String = ""
    @State private var amountText: String = ""
    @State private var receivedDate: Date = Date()
    @State private var returnReason: String = "close_full_return"
    /// Sub-option when `returnReason == "other"` — maps to
    /// `close_other` / `continue_other` on submit.
    @State private var otherAction: String = "close"
    @State private var notes: String = ""
    @State private var submitting: Bool = false
    @State private var errorMessage: String?
    @State private var showFloatPicker: Bool = false
    @State private var showReasonPicker: Bool = false

    /// Reason options — keys + labels match the web `RETURN_REASONS`.
    private let reasonOptions: [(key: String, label: String)] = [
        ("close_full_return",       "Float closing — full return"),
        ("continue_partial_return", "Partial return — float continues"),
        ("overspend_settlement",    "Overspend settlement — crew paying back"),
        ("cancel_float_return",     "Float cancelled"),
        ("other",                   "Other"),
    ]

    /// Reasons that close the float — the return amount MUST equal the
    /// remaining balance (same rule the web enforces).
    private let fullReturnReasons: Set<String> = [
        "close_full_return", "cancel_float_return",
        "overspend_settlement", "close_other"
    ]

    /// Reasons that keep the float active — returning the full balance
    /// would drain it to zero, which the web rejects.
    private let continueReasons: Set<String> = [
        "continue_partial_return", "continue_other"
    ]

    private var selectedFloat: FloatRequest? {
        floats.first(where: { $0.id == selectedFloatId })
    }

    private var balance: Double { selectedFloat?.remaining ?? 0 }

    private var selectedFloatLabel: String {
        guard let f = selectedFloat else { return "— Select crew member —" }
        let name = UsersData.byId[f.userId]?.fullName ?? "—"
        return "\(name) · #\(f.reqNumber) · Bal: \(FormatUtils.formatGBP(f.remaining))"
    }

    private var selectedReasonLabel: String {
        reasonOptions.first(where: { $0.key == returnReason })?.label ?? "— Select —"
    }

    /// Matches the web logic — splits "other" into close_other/continue_other
    /// based on the radio selection; every other reason passes through.
    private var resolvedReason: String {
        if returnReason == "other" {
            return otherAction == "close" ? "close_other" : "continue_other"
        }
        return returnReason
    }

    /// Button enabled condition — mirrors the web (`!saving && amount`).
    /// Detailed validation (full-return vs continue, amount > balance)
    /// runs inline in `submit()` so the user sees a specific error.
    private var canSubmit: Bool {
        !submitting && !amountText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // Info banner
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill").font(.system(size: 12)).foregroundColor(.blue)
                        Text("Use this to record cash physically returned to production by a crew member — reduces their float balance and updates the cash safe log.")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.06)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2), lineWidth: 1))

                    // Crew Member / Float picker
                    fieldLabel("CREW MEMBER / FLOAT", required: true)
                    Button(action: { showFloatPicker = true }) {
                        HStack {
                            Text(selectedFloatLabel)
                                .font(.system(size: 13))
                                .foregroundColor(selectedFloatId.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                        }
                        .padding(10).frame(maxWidth: .infinity)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .sheet(isPresented: $showFloatPicker) {
                        FloatPickerSheet(
                            floats: floats,
                            selectedId: selectedFloatId
                        ) { pickedId in
                            selectedFloatId = pickedId
                            showFloatPicker = false
                        } onCancel: {
                            showFloatPicker = false
                        }
                    }

                    // Amount + Date (side by side)
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("AMOUNT RETURNED", required: true)
                            TextField("£0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 14))
                                .padding(10).frame(maxWidth: .infinity)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            Text("Cash physically received").font(.system(size: 10)).foregroundColor(.gray)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("DATE RECEIVED", required: true)
                            DatePicker("", selection: $receivedDate, displayedComponents: .date)
                                .labelsHidden()
                                .padding(6).frame(maxWidth: .infinity)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                    }

                    // Return reason
                    fieldLabel("RETURN REASON", required: false)
                    Button(action: { showReasonPicker = true }) {
                        HStack {
                            Text(selectedReasonLabel).font(.system(size: 13)).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                        }
                        .padding(10).frame(maxWidth: .infinity)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .selectionActionSheet(
                        title: "Return Reason",
                        isPresented: $showReasonPicker,
                        options: reasonOptions.map { $0.key },
                        isSelected: { $0 == returnReason },
                        label: { key in reasonOptions.first { $0.key == key }?.label ?? key },
                        onSelect: { returnReason = $0 }
                    )

                    // "Other" sub-option — close vs continue radio
                    if returnReason == "other" {
                        HStack(spacing: 16) {
                            otherOption(label: "Close the float", value: "close")
                            otherOption(label: "Continue the float", value: "continue")
                            Spacer()
                        }
                    }

                    // Notes
                    fieldLabel("NOTES", required: false)
                    TextField("e.g. Cash returned in person at production office, witnessed by Line Producer…", text: $notes)
                        .font(.system(size: 13))
                        .padding(10).frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                    if let err = errorMessage {
                        Text(err).font(.system(size: 11)).foregroundColor(.red)
                            .padding(.top, 4)
                    }

                    // Bottom spacer to avoid the pinned footer covering the notes field
                    Spacer().frame(height: 80)
                }
                .padding(16)
            }

            // ── Pinned action footer ─────────────────────────────────
            HStack(spacing: 10) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())
                Spacer()
                Button(action: submit) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                        Text(submitting ? "Recording…" : "Record Cash Return")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(canSubmit ? Color.goldDark : Color.gray.opacity(0.4))
                    .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Record Manual Cash Return"), displayMode: .inline)
        .onAppear {
            // Auto-select the float when the page is opened from a
            // specific float's detail screen. Only runs once on first
            // appear (leaves any user-changed selection intact).
            if selectedFloatId.isEmpty {
                if let preId = preselectedFloatId,
                   floats.contains(where: { $0.id == preId }) {
                    selectedFloatId = preId
                } else if floats.count == 1 {
                    // Convenience: if the caller passed a single-float
                    // list (e.g., from FloatDetailView), use it directly.
                    selectedFloatId = floats[0].id
                }
            }
        }
    }

    private func fieldLabel(_ text: String, required: Bool) -> some View {
        HStack(spacing: 2) {
            Text(text).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            if required { Text("*").font(.system(size: 10, weight: .bold)).foregroundColor(.red) }
        }
    }

    /// Custom radio button for the "Other" sub-option row.
    private func otherOption(label: String, value: String) -> some View {
        Button(action: { otherAction = value }) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(otherAction == value ? Color.goldDark : Color.gray.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    if otherAction == value {
                        Circle().fill(Color.goldDark).frame(width: 7, height: 7)
                    }
                }
                Text(label).font(.system(size: 12)).foregroundColor(.primary)
            }
            .contentShape(Rectangle())
        }.buttonStyle(BorderlessButtonStyle())
    }

    /// Validates + submits — mirrors the web's detailed guards so
    /// errors surface the same way they do on the desktop form.
    private func submit() {
        errorMessage = nil
        // Float selected?
        guard !selectedFloatId.isEmpty else {
            errorMessage = "Please select a crew member / float."
            return
        }
        // Amount valid?
        let raw = amountText.trimmingCharacters(in: .whitespaces)
        guard let amt = Double(raw), amt > 0 else {
            errorMessage = "Please enter a valid return amount."
            return
        }
        // Amount not more than remaining balance
        if amt > balance + 0.005 {
            errorMessage = "Return amount \(FormatUtils.formatGBP(amt)) exceeds the remaining balance of \(FormatUtils.formatGBP(balance))."
            return
        }
        let reasonKey = resolvedReason
        // Closing/cancelling → amount MUST equal the full balance
        if fullReturnReasons.contains(reasonKey) && abs(amt - balance) > 0.005 {
            errorMessage = "This option will close the float. The return amount must be the full remaining balance of \(FormatUtils.formatGBP(balance))."
            return
        }
        // Continue options can't drain the balance to zero
        if continueReasons.contains(reasonKey) && abs(amt - balance) < 0.005 {
            errorMessage = "Returning the full balance of \(FormatUtils.formatGBP(balance)) will leave the float with zero balance. Choose a close option instead, or reduce the return amount."
            return
        }

        submitting = true
        let dateMs = Int64(receivedDate.timeIntervalSince1970 * 1000)
        appState.recordFloatReturn(
            id: selectedFloatId,
            amount: amt,
            dateMs: dateMs,
            reason: reasonKey,
            notes: notes.trimmingCharacters(in: .whitespaces)
        ) { success, err in
            submitting = false
            if success {
                // Reset + dismiss — matches the web behaviour.
                amountText = ""
                notes = ""
                returnReason = "close_full_return"
                otherAction = "close"
                selectedFloatId = ""
                errorMessage = nil
                presentationMode.wrappedValue.dismiss()
            } else {
                errorMessage = err ?? "Failed to record cash return."
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Float Picker Sheet
// Searchable list of crew members with their float ref + balance.
// Replaces the compact action-sheet picker that could only show a
// single text label per option and ran out of vertical room quickly.
// ═══════════════════════════════════════════════════════════════════

struct FloatPickerSheet: View {
    let floats: [FloatRequest]
    let selectedId: String
    var onPick: (String) -> Void
    var onCancel: () -> Void

    @State private var searchText: String = ""

    /// Only floats that currently hold cash AND are in a status where a
    /// return makes sense:
    ///   • COLLECTED      — cash has been handed over, some may come back
    ///   • SPENT          — receipts exhausted the cash but return still possible
    ///   • PENDING_RETURN — already flagged as awaiting physical return
    /// `ACTIVE`/`SPENDING` floats are still being used and aren't typically
    /// closed out via the return flow; closed/cancelled ones have nothing
    /// left to return.
    private var eligible: [FloatRequest] {
        let allowed: Set<String> = ["COLLECTED", "SPENT", "PENDING_RETURN"]
        return floats.filter { f in
            allowed.contains(f.status.uppercased()) && f.remaining > 0.005
        }
    }

    private var filtered: [FloatRequest] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return eligible }
        return eligible.filter { f in
            let name = UsersData.byId[f.userId]?.fullName.lowercased() ?? ""
            let role = UsersData.byId[f.userId]?.displayDesignation.lowercased() ?? ""
            return name.contains(q)
                || role.contains(q)
                || f.reqNumber.lowercased().contains(q)
                || f.department.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgBase.edgesIgnoringSafeArea(.all)
                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12)).foregroundColor(.gray)
                        TextField("Search crew, department, ref…", text: $searchText)
                            .font(.system(size: 13))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12)).foregroundColor(.gray)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.bgSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

                    // List
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text(searchText.isEmpty
                                 ? "No floats with cash to return"
                                 : "No floats match \"\(searchText)\"")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(filtered) { f in
                                    Button(action: { onPick(f.id) }) {
                                        floatRow(f)
                                    }.buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8).padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationBarTitle(Text("Select Float"), displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Cancel", action: onCancel).foregroundColor(.goldDark)
            )
        }
    }

    private func floatRow(_ f: FloatRequest) -> some View {
        let user = UsersData.byId[f.userId]
        let name = user?.fullName ?? "—"
        let role = user?.displayDesignation ?? ""
        let dept = f.department.isEmpty ? (user?.displayDepartment ?? "") : f.department
        let isSelected = selectedId == f.id
        return HStack(alignment: .center, spacing: 12) {
            // Avatar
            ZStack {
                Circle().fill(Color.gold.opacity(0.18)).frame(width: 36, height: 36)
                Text(user?.initials ?? "—")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.goldDark)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 14, weight: .bold)).foregroundColor(.primary).lineLimit(1)
                // Role · Department
                let subtitle: String = {
                    switch (role.isEmpty, dept.isEmpty) {
                    case (false, false): return "\(role) · \(dept)"
                    case (false, true):  return role
                    case (true, false):  return dept
                    default:             return ""
                    }
                }()
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                }
                Text("#\(f.reqNumber)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.goldDark)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("BALANCE").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                Text(FormatUtils.formatGBP(f.remaining))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.goldDark)
            }
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16)).foregroundColor(.green)
                    .padding(.leading, 4)
            }
        }
        .padding(12)
        .background(isSelected ? Color.gold.opacity(0.08) : Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
            isSelected ? Color.goldDark : Color.borderColor,
            lineWidth: isSelected ? 2 : 1))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Float Approval Detail Page (full breakdown for approvers)
// ═══════════════════════════════════════════════════════════════════

struct FloatApprovalDetailPage: View {
    let float: FloatRequest
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var details: FloatDetailsResponse? = nil
    @State private var liveFloat: FloatRequest? = nil
    @State private var isLoading = true
    @State private var showRejectSheet = false
    @State private var rejectReason = ""
    @State private var actioning = false

    private var displayFloat: FloatRequest { liveFloat ?? float }
    private var totals: FloatTotals { details?.totals ?? FloatTotals() }
    private var isAccountant: Bool { appState.currentUser?.isAccountant == true }
    private var isApprover: Bool { appState.cashMeta?.is_approver == true }
    private var canAct: Bool {
        // Approvers and accountants can approve / reject AWAITING_APPROVAL floats
        displayFloat.status.uppercased() == "AWAITING_APPROVAL" && (isApprover || isAccountant)
    }

    /// 2 if no tier config is carried on the model — matches the web.
    private var totalApprovalTiers: Int { max(2, displayFloat.approvals.count + 1) }

    private var isAwaitingApproval: Bool {
        displayFloat.status.uppercased() == "AWAITING_APPROVAL"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgSurface.edgesIgnoringSafeArea(.all)
            if isLoading {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header — name, role, date, pending badge
                        pendingHeader
                            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

                        Divider()

                        // 2-column grid of details (screenshot 2 layout)
                        detailsGrid
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                        Divider()

                        // Purpose panel (light grey box)
                        purposePanel
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                        Divider()

                        // Approval progress
                        approvalProgressPanel
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                        // Rejection reason (if set)
                        if let reason = displayFloat.rejectionReason, !reason.isEmpty {
                            Divider()
                            rejectionCard(reason: reason)
                                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                        }

                        // Activity sections only make sense AFTER issuance;
                        // suppressed while the float is still AWAITING_APPROVAL.
                        if !isAwaitingApproval {
                            if !(details?.batches.isEmpty ?? true)  {
                                Divider()
                                batchesSection.padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            if !(details?.topups.isEmpty ?? true)   {
                                Divider()
                                topupsSection.padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            if !(details?.returns.isEmpty ?? true)  {
                                Divider()
                                returnsSection.padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, canAct ? 100 : 24)
                }
            }
            if canAct { actionFooter }
        }
        .navigationBarTitle(Text("\(displayFloat.reqNumber) — Float Request"), displayMode: .inline)
        .onAppear { reload() }
        .sheet(isPresented: $showRejectSheet) { rejectSheet }
    }

    // MARK: - New header / grid / purpose / approval panels

    /// Top section — user name (bold), role · department, submitted date/time,
    /// and a "PENDING X/Y" badge on the right.
    private var pendingHeader: some View {
        let user = UsersData.byId[displayFloat.userId]
        let name = user?.fullName ?? "—"
        let roleLine: String = {
            let role = user?.displayDesignation ?? ""
            let dept = displayFloat.department.isEmpty ? (user?.displayDepartment ?? "") : displayFloat.department
            switch (role.isEmpty, dept.isEmpty) {
            case (false, false): return "\(role) · \(dept)"
            case (false, true):  return role
            case (true, false):  return dept
            default:             return ""
            }
        }()
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.system(size: 16, weight: .bold))
                if !roleLine.isEmpty {
                    Text(roleLine).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Text(FormatUtils.formatDateTime(displayFloat.createdAt))
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
            }
            Spacer(minLength: 8)
            Text("PENDING \(displayFloat.approvals.count)/\(totalApprovalTiers)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.goldDark)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.gold.opacity(0.15)).cornerRadius(6)
        }
    }

    /// Two-column grid of six fields — REQUESTED AMOUNT / HOW LONG,
    /// COLLECTION METHOD / DEPARTMENT, START DATE / COLLECT DATE/TIME.
    private var detailsGrid: some View {
        let duration: String = {
            let d = displayFloat.duration.lowercased()
            if d == "run_of_show" { return "Run of Show" }
            if d.isEmpty { return "—" }
            if let n = Int(d) { return "\(n) day\(n == 1 ? "" : "s")" }
            return displayFloat.duration
        }()
        let collection: String = {
            let key = displayFloat.collectionMethod
            if let label = collectionOptions.first(where: { $0.0 == key })?.1 { return label }
            if key.isEmpty { return "—" }
            return key.replacingOccurrences(of: "_", with: " ").capitalized
        }()
        let startDate: String = {
            guard let s = displayFloat.startDate, s > 0 else { return "—" }
            return FormatUtils.formatTimestamp(s)
        }()
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                gridCell("REQUESTED AMOUNT", FormatUtils.formatGBP(displayFloat.reqAmount), valueColor: .goldDark, mono: true)
                gridCell("HOW LONG", duration)
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("COLLECTION METHOD", collection)
                gridCell("DEPARTMENT", displayFloat.department.isEmpty ? "—" : displayFloat.department)
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("START DATE", startDate)
                gridCell("COLLECT DATE/TIME", "—")
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

    /// "PURPOSE / JUSTIFICATION" with the body in a subtle grey-filled box.
    private var purposePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PURPOSE / JUSTIFICATION")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            Text(displayFloat.purpose.isEmpty ? "—" : displayFloat.purpose)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.bgRaised)
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// APPROVAL PROGRESS (N/T) — lists existing approvals, or "No approvals yet".
    private var approvalProgressPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("APPROVAL PROGRESS (\(displayFloat.approvals.count)/\(totalApprovalTiers))")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            if displayFloat.approvals.isEmpty {
                Text("No approvals yet")
                    .font(.system(size: 13)).foregroundColor(.secondary)
            } else {
                ForEach(displayFloat.approvals, id: \.tierNumber) { a in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12)).foregroundColor(.green)
                        Text(UsersData.byId[a.userId]?.fullName ?? a.userId)
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("Tier \(a.tierNumber)")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                        Text(FormatUtils.formatDateTime(a.approvedAt))
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    private var headerCard: some View {
        let (fg, bg) = floatStatusColors(displayFloat.status)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(UsersData.byId[displayFloat.userId]?.fullName ?? "—")
                        .font(.system(size: 16, weight: .bold))
                    if !displayFloat.department.isEmpty {
                        Text(displayFloat.department).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Text("#\(displayFloat.reqNumber)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.goldDark)
                }
                Spacer()
                Text(displayFloat.statusDisplay.uppercased())
                    .font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(bg).cornerRadius(4)
            }
            if !displayFloat.statusSubtitle.isEmpty {
                Text(displayFloat.statusSubtitle).font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack(spacing: 12) {
                metaCol("Submitted", FormatUtils.formatTimestamp(displayFloat.createdAt))
                metaCol("Duration", displayFloat.duration.isEmpty ? "—" : (displayFloat.duration == "run_of_show" ? "Run of Show" : "\(displayFloat.duration) days"))
                metaCol("Cost Code", displayFloat.costCode.isEmpty ? "—" : displayFloat.costCode.uppercased())
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func metaCol(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(.system(size: 11, weight: .semibold))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var purposeCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PURPOSE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(displayFloat.purpose).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Amounts breakdown

    private var amountsBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Amounts").font(.system(size: 14, weight: .bold))
            VStack(spacing: 6) {
                amountRow("Requested",   FormatUtils.formatGBP(totals.requested > 0 ? totals.requested : displayFloat.reqAmount))
                amountRow("Issued",      FormatUtils.formatGBP(totals.issued))
                if totals.toppedUp > 0   { amountRow("Topped Up",  FormatUtils.formatGBP(totals.toppedUp), color: .blue) }
                amountRow("Spent",       FormatUtils.formatGBP(totals.spent), color: .orange)
                if totals.returned > 0   { amountRow("Returned",   FormatUtils.formatGBP(totals.returned), color: .gray) }
                Divider()
                amountRow("Balance",     FormatUtils.formatGBP(totals.finalBalance > 0 ? totals.finalBalance : displayFloat.remaining), color: .goldDark, bold: true)
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func amountRow(_ label: String, _ value: String, color: Color = .primary, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: bold ? .bold : .regular)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: bold ? .bold : .semibold, design: .monospaced)).foregroundColor(color)
        }
    }

    // MARK: - Posted batches

    private var batchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Posted Batches").font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\(details?.batches.count ?? 0)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
            }
            ForEach(details?.batches ?? [], id: \.id) { raw in
                let batch = raw.toClaimBatch()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("#\(batch.batchReference)").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                        Text(batch.statusDisplay).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(FormatUtils.formatGBP(batch.totalGross))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .padding(10).background(Color.bgRaised).cornerRadius(8)
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Top-ups

    private var topupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Top-ups").font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\(details?.topups.count ?? 0)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
            }
            ForEach(details?.topups ?? [], id: \.id) { t in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.status.capitalized).font(.system(size: 11, weight: .semibold))
                        if t.createdAt > 0 {
                            Text(FormatUtils.formatTimestamp(t.createdAt)).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text(FormatUtils.formatGBP(t.issuedAmount > 0 ? t.issuedAmount : t.amount))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.blue)
                }
                .padding(10).background(Color.bgRaised).cornerRadius(8)
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Returns

    private var returnsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cash Returns").font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\(details?.returns.count ?? 0)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
            }
            ForEach(details?.returns ?? [], id: \.id) { r in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(r.returnReason.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text(FormatUtils.formatGBP(r.returnAmount))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.gray)
                    }
                    if !r.reasonNotes.isEmpty {
                        Text(r.reasonNotes).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    if r.recordedAt > 0 {
                        Text(FormatUtils.formatDateTime(r.recordedAt)).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bgRaised).cornerRadius(8)
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Approvals

    private var approvalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Approvals").font(.system(size: 14, weight: .bold))
            ForEach(displayFloat.approvals.sorted(by: { $0.tierNumber < $1.tierNumber }), id: \.userId) { a in
                HStack {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tier \(a.tierNumber) — \(UsersData.byId[a.userId]?.fullName ?? a.userId)")
                            .font(.system(size: 12, weight: .semibold))
                        if a.approvedAt > 0 {
                            Text(FormatUtils.formatDateTime(a.approvedAt)).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func rejectionCard(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundColor(.red)
                Text("Rejection Reason").font(.system(size: 12, weight: .bold)).foregroundColor(.red)
            }
            Text(reason).font(.system(size: 11)).foregroundColor(.primary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.06)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Action footer (role-aware)
    //
    // Accountants get a single "Override" button (bypasses the tier chain;
    // matches the web flow that stamps the float as ACCT_OVERRIDE).
    // Approvers see the normal "Reject" + "Approve" pair.

    @ViewBuilder
    private var actionFooter: some View {
        Group {
            if isAccountant {
                // Accountant: single gold "Override" button, right-aligned.
                // Accountants have override privilege over the approval chain,
                // so this takes precedence even if they also happen to be an
                // approver on this float.
                HStack {
                    Spacer()
                    Button(action: overrideFloat) {
                        HStack(spacing: 6) {
                            if actioning {
                                ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                            }
                            Text(actioning ? "Overriding…" : "Override")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 28).padding(.vertical, 12)
                        .background(Color.gold).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
                }
            } else {
                // Approver (and approver+accountant): Reject + Approve pair
                HStack(spacing: 10) {
                    Button(action: { showRejectSheet = true }) {
                        Text("Reject").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.red).cornerRadius(10)
                    }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
                    Button(action: approve) {
                        HStack(spacing: 6) {
                            if actioning { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                            Text(actioning ? "Approving…" : "Approve").font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.green).cornerRadius(10)
                    }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
                }
            }
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
                    Text("Reject float request from \(UsersData.byId[displayFloat.userId]?.fullName ?? "—")")
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
            .navigationBarTitle(Text("Reject Float"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { showRejectSheet = false; rejectReason = "" }.foregroundColor(.goldDark),
                trailing: Button("Reject") {
                    let r = rejectReason.trimmingCharacters(in: .whitespaces)
                    guard !r.isEmpty else { return }
                    showRejectSheet = false
                    reject(reason: r)
                }.foregroundColor(.red).font(.system(size: 16, weight: .bold))
            )
        }
    }

    // MARK: - Actions

    private func reload() {
        appState.loadFloatDetails(displayFloat.id) { d in
            details = d
            if let raw = d?.float { liveFloat = raw.toFloatRequest() }
            isLoading = false
        }
    }

    private func approve() {
        actioning = true
        // Backend is keyed on tier_number. Approver supplies their own tier; for now use next tier.
        let nextTier = (displayFloat.approvals.map { $0.tierNumber }.max() ?? 0) + 1
        let totalTiers = max(nextTier, 1)
        appState.approveFloatRequest(id: displayFloat.id, tierNumber: nextTier, totalTiers: totalTiers) { success in
            actioning = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }

    private func reject(reason: String) {
        actioning = true
        appState.rejectFloatRequest(id: displayFloat.id, reason: reason) { success in
            actioning = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }

    /// Accountant one-click override — posts `override: true` alongside the
    /// standard approve payload. Backend stamps the float as ACCT_OVERRIDE.
    private func overrideFloat() {
        actioning = true
        appState.overrideFloatRequest(id: displayFloat.id) { success in
            actioning = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }
}

struct FloatCard: View {
    let float: FloatRequest
    var batches: [ClaimBatch] = []
    var disableInternalTap: Bool = false
    var forceExpanded: Bool = false
    var onTap: (() -> Void)? = nil
    @State private var expandedState = false
    @State private var selectedBatchId: String?

    private var expanded: Bool { forceExpanded || expandedState }

    // MARK: - Stats (match web PCFloatsPage calculations)
    //
    // The web derives every stat from `req_amount` (the float limit),
    // `balance` (server's live remaining), and `issued_float`:
    //
    //   floatLimit = req_amount
    //   balance    = balance ?? floatLimit              // fallback
    //   spent      = max(0, floatLimit - balance)       // simple derivation
    //   issued     = issued_float > 0 ? issued_float : floatLimit
    //
    // We mirror that here so iOS numbers exactly match the desktop.

    private var floatLimit: Double { float.reqAmount }
    private var liveBalance: Double { float.balance ?? floatLimit }
    private var spentDerived: Double { max(0, floatLimit - liveBalance) }
    private var issuedDisplay: Double {
        float.issuedFloat > 0 ? float.issuedFloat : floatLimit
    }
    private var spendPct: Double {
        guard floatLimit > 0 else { return 0 }
        return min(max(spentDerived / floatLimit, 0), 1)
    }

    /// Branch the stat strip exactly like the web (`PCFloatsPage.jsx`):
    ///   • CLOSED / CANCELLED      → Limit / Closed
    ///   • in-use (COLLECTED…PENDING_RETURN) → Balance / Spent / Issued + bar
    ///   • otherwise (pre-collection: AWAITING_APPROVAL, APPROVED,
    ///     ACCT_OVERRIDE, READY_TO_COLLECT, REJECTED) → Requested only
    private enum StatsVariant { case terminal, inUse, preCollection }
    private var statsVariant: StatsVariant {
        switch float.status.uppercased() {
        case "CLOSED", "CANCELLED":
            return .terminal
        case "COLLECTED", "ACTIVE", "SPENDING", "SPENT", "PENDING_RETURN":
            return .inUse
        default:
            return .preCollection
        }
    }
    private var isClosedLike: Bool { statsVariant == .terminal }

    /// Value shown under the CLOSED / CANCELLED column. Prefer the
    /// returned amount (what actually came back); fall back to the
    /// original limit so the column is never £0 on legacy data.
    private var closedStatValue: Double {
        if float.returnAmount > 0 { return float.returnAmount }
        return floatLimit
    }

    /// Days since submission — web uses the same `daysAgo(created_at)`.
    private var daysActive: Int {
        guard float.createdAt > 0 else { return 0 }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let diff = max(0, nowMs - float.createdAt)
        return Int(diff / 86_400_000)
    }

    /// Duration text — "Run of Show" when run_of_show, else "N days duration".
    private var durationText: String {
        let d = float.duration.lowercased()
        if d == "run_of_show" { return "Run of Show" }
        if d.isEmpty { return "" }
        if let n = Int(d) { return "\(n) day\(n == 1 ? "" : "s") duration" }
        return "\(float.duration) duration"
    }

    /// Shared header + stat strip layout. A tiny status branch inside
    /// the stat strip swaps SPENT/BALANCE → CLOSED/CANCELLED when the
    /// float is terminal; everything else stays identical across states.
    @ViewBuilder private var headerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: avatar + name + float number + status
            HStack(spacing: 8) {
                if !disableInternalTap && onTap == nil {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(.gray)
                }
                if let user = UsersData.byId[float.userId] {
                    ZStack {
                        Circle().fill(Color.gold.opacity(0.2)).frame(width: 32, height: 32)
                        Text(user.initials).font(.system(size: 11, weight: .bold)).foregroundColor(.goldDark)
                    }
                    Text(user.fullName).font(.system(size: 14, weight: .bold)).lineLimit(1)
                }
                Text("· \(float.reqNumber)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                Spacer()
                let (fg, bg) = floatStatusColor(float.status)
                Text(float.statusDisplay.uppercased()).font(.system(size: 8, weight: .bold)).foregroundColor(fg)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(bg).cornerRadius(4)
            }

            // Row 2: submitted date + N days active + duration
            // Matches the web: "Submitted DD MMM · N days active · <duration>".
            HStack(spacing: 6) {
                Text("Submitted \(FormatUtils.formatTimestamp(float.createdAt))").font(.system(size: 10)).foregroundColor(.gray)
                Text("· \(daysActive) day\(daysActive == 1 ? "" : "s") active")
                    .font(.system(size: 10)).foregroundColor(.gray)
                if !durationText.isEmpty {
                    Text("· \(durationText)").font(.system(size: 10)).foregroundColor(.gray)
                }
            }

            // Row 3: stats — three branches mirroring PCFloatsPage.jsx.
            switch statsVariant {
            case .terminal:
                // CLOSED / CANCELLED → Limit + Closed (greyed)
                let isCancelled = float.status.uppercased() == "CANCELLED"
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("LIMIT").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                        Text(FormatUtils.formatGBP(floatLimit))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity)
                    VStack(spacing: 2) {
                        Text(isCancelled ? "CANCELLED" : "CLOSED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary).tracking(0.3)
                        Text(FormatUtils.formatGBP(closedStatValue))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity)
                }
                .padding(.vertical, 6).background(Color.bgRaised).cornerRadius(8)
                .opacity(0.75)

            case .inUse:
                // COLLECTED / ACTIVE / SPENDING / SPENT / PENDING_RETURN →
                // Balance + Spent + Issued + progress bar underneath.
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text("BALANCE").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                            Text(FormatUtils.formatGBP(liveBalance))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: 2) {
                            // The derivation (limit - balance) covers both
                            // posted receipts AND cash returned — so the
                            // label reflects both, matching the web.
                            Text("SPENT/RETURN").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                            Text(FormatUtils.formatGBP(spentDerived))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(spentDerived > 0 ? .blue : .gray)
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: 2) {
                            Text("ISSUED").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                            Text(FormatUtils.formatGBP(issuedDisplay))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }.frame(maxWidth: .infinity)
                    }
                    // Spend progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5).fill(Color(.systemGray5)).frame(height: 3)
                            RoundedRectangle(cornerRadius: 1.5).fill(Color.goldDark)
                                .frame(width: max(geo.size.width * CGFloat(spendPct), 0), height: 3)
                        }
                    }.frame(height: 3)
                    Text("Spent/Returned \(FormatUtils.formatGBP(spentDerived)) of \(FormatUtils.formatGBP(floatLimit))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8).padding(.horizontal, 8)
                .background(Color.bgRaised).cornerRadius(8)

            case .preCollection:
                // AWAITING_APPROVAL / APPROVED / ACCT_OVERRIDE /
                // READY_TO_COLLECT / REJECTED → only the Requested amount.
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("REQUESTED").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                        Text(FormatUtils.formatGBP(floatLimit))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12).contentShape(Rectangle())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onTap = onTap {
                Button(action: onTap) { headerContent }.buttonStyle(PlainButtonStyle())
            } else if disableInternalTap {
                headerContent
            } else {
                Button(action: { expandedState.toggle() }) { headerContent }.buttonStyle(PlainButtonStyle())
            }

            // ── Expanded: details + batches ──
            if expanded {
                Divider()
                // Details
                VStack(spacing: 0) {
                    if !float.costCode.isEmpty { detailRow("Cost Code", float.costCode.uppercased()) }
                    if !float.purpose.isEmpty { detailRow("Purpose", float.purpose) }
                    if !float.duration.isEmpty { detailRow("Duration", "\(float.duration) days") }
                    if !float.collectionMethod.isEmpty { detailRow("Collection", float.collectionMethod.replacingOccurrences(of: "_", with: " ").capitalized) }
                    if let start = float.startDate, start > 0 { detailRow("Start Date", FormatUtils.formatTimestamp(start)) }
                    if !float.department.isEmpty { detailRow("Department", float.department) }
                }

                // Approvals
                if !float.approvals.isEmpty {
                    Divider().padding(.horizontal, 14)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("APPROVALS (\(float.approvals.count))").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        ForEach(float.approvals, id: \.tierNumber) { a in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundColor(.green)
                                Text(UsersData.byId[a.userId]?.fullName ?? a.userId).font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text("Tier \(a.tierNumber)").font(.system(size: 10)).foregroundColor(.secondary)
                                Text(FormatUtils.formatTimestamp(a.approvedAt)).font(.system(size: 9)).foregroundColor(.gray)
                            }
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 8)
                }

                // Batches
                if !batches.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(batches.count) BATCHES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 6)

                        ForEach(batches) { batch in
                            let isSelected = selectedBatchId == batch.id
                            VStack(spacing: 0) {
                                Button(action: { selectedBatchId = isSelected ? nil : batch.id }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text").font(.system(size: 11))
                                            .foregroundColor(isSelected ? .goldDark : .gray)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("#\(batch.batchReference)").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                                            Text("\(batch.claimCount) receipt\(batch.claimCount == 1 ? "" : "s") · \(FormatUtils.formatTimestamp(batch.createdAt))").font(.system(size: 10)).foregroundColor(.gray)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(FormatUtils.formatGBP(batch.totalGross)).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.primary)
                                            let (bfg, bbg) = batchStatusColor(batch.status)
                                            Text(batch.statusDisplay).font(.system(size: 8, weight: .bold)).foregroundColor(bfg)
                                                .padding(.horizontal, 6).padding(.vertical, 2).background(bbg).cornerRadius(3)
                                        }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(isSelected ? Color.gold.opacity(0.04) : Color.clear)
                                    .overlay(isSelected ? RoundedRectangle(cornerRadius: 6).stroke(Color.gold.opacity(0.3), lineWidth: 1).padding(.horizontal, 8) : nil)
                                }.buttonStyle(PlainButtonStyle())

                                // Inline status flow when selected
                                if isSelected {
                                    batchStatusFlow(batch)
                                }

                                Divider().padding(.horizontal, 14)
                            }
                        }
                    }
                }

                // Rejection
                if let reason = float.rejectionReason, !reason.isEmpty {
                    Divider().padding(.horizontal, 14)
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundColor(.red)
                        Text(reason).font(.system(size: 10)).foregroundColor(.red).lineLimit(2)
                    }.padding(.horizontal, 14).padding(.vertical, 8)
                }
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func batchStatusFlow(_ batch: ClaimBatch) -> some View {
        let steps: [(key: String, label: String, sub: String)] = [
            ("CODING", "Submitted", "Batch #\(batch.batchReference)"),
            ("CODED", "Coordinator Coding", "Budget coding done"),
            ("IN_AUDIT", "Accounts Audit", "Audited & verified"),
            ("AWAITING_APPROVAL", "Approval", "Approved"),
            ("READY_TO_POST", "Post & Ledger", "Ready to post"),
            ("POSTED", "Settlement", batch.settlementType.isEmpty ? "Complete" : batch.settlementType.replacingOccurrences(of: "_", with: " ").capitalized),
        ]

        let current: Int = {
            let s = batch.status.uppercased()
            switch s {
            case "CODING": return 0
            case "CODED": return 1
            case "IN_AUDIT": return 2
            case "AWAITING_APPROVAL", "ACCT_OVERRIDE": return 3
            case "READY_TO_POST", "ESCALATED": return 4
            case "POSTED": return 5
            case "REJECTED": return -1
            default: return 0
            }
        }()

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("#\(batch.batchReference)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .padding(.horizontal, 14).padding(.top, 10)
            Text("\(FormatUtils.formatGBP(batch.totalGross)) · \(batch.claimCount) receipt\(batch.claimCount == 1 ? "" : "s") · \(FormatUtils.formatDateTime(batch.createdAt))")
                .font(.system(size: 11)).foregroundColor(.secondary)
                .padding(.horizontal, 14).padding(.bottom, 8)

            Text("STATUS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                .padding(.horizontal, 14).padding(.bottom, 6)

            // Timeline
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(idx < current ? Color.green :
                                  idx == current ? Color.goldDark :
                                  Color.gray.opacity(0.25))
                            .frame(width: 12, height: 12)
                        if idx < steps.count - 1 {
                            Rectangle()
                                .fill(idx < current ? Color.green.opacity(0.4) : Color.gray.opacity(0.2))
                                .frame(width: 2, height: 24)
                        }
                    }.frame(width: 12)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.label)
                            .font(.system(size: 12, weight: idx == current ? .bold : .medium))
                            .foregroundColor(idx < current ? .green : idx == current ? .goldDark : .secondary)
                        Text(step.sub).font(.system(size: 10)).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
            }

            // Rejected
            if batch.status.uppercased() == "REJECTED" {
                HStack(spacing: 8) {
                    Circle().fill(Color.red).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rejected").font(.system(size: 12, weight: .bold)).foregroundColor(.red)
                        Text("Resubmit required").font(.system(size: 10)).foregroundColor(.red.opacity(0.7))
                    }
                }.padding(.horizontal, 14).padding(.top, 4)
            }

        }.padding(.bottom, 10).background(Color.bgRaised.opacity(0.5))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium))
        }.padding(.horizontal, 14).padding(.vertical, 6)
    }

    private func floatStatusColor(_ s: String) -> (Color, Color) {
        floatStatusColors(s)
    }

    private func batchStatusColor(_ s: String) -> (Color, Color) {
        switch s.uppercased() {
        case "CODING", "CODED": return (.purple, Color.purple.opacity(0.1))
        case "POSTED": return (.green, Color.green.opacity(0.1))
        case "REJECTED": return (.red, Color.red.opacity(0.1))
        case "ESCALATED": return (.orange, Color.orange.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Submit Receipts Form
// ═══════════════════════════════════════════════════════════════════

struct ClaimReceiptItem: Identifiable {
    let id = UUID()
    var date: String = ""
    var amount: String = ""
    var description: String = ""
    var category: String = "materials"
    var costCode: String = ""
    var episode: String = ""
    var codedDescription: String = ""
    var fileName: String = ""
    var fileData: Data?
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Float Detail View (navigation page)
// ═══════════════════════════════════════════════════════════════════

struct FloatDetailView: View {
    let float: FloatRequest
    @EnvironmentObject var appState: POViewModel
    @State private var selectedBatchId: String?
    /// Rich details from GET /float-requests/{id}/details (batches, top-ups,
    /// returns, totals). Fetched on appear so batches always populate even
    /// if the Active Floats tab hasn't loaded `allClaims` yet.
    @State private var details: FloatDetailsResponse? = nil
    /// True on first entry and during any subsequent re-fetch. Drives the
    /// full-screen loader so the user sees a spinner instead of the raw
    /// `float` prop data while `/details` is in-flight.
    @State private var isLoading: Bool = true
    /// Drives the nav-bar History button → FloatHistoryPage push.
    @State private var navigateToHistory = false
    /// Drives the pink "Record Cash Return" action → RecordCashReturnPage.
    @State private var navigateToRecordReturn = false
    /// Collapsible state for the CASH RETURNS section — collapsed by
    /// default so the page stays short when there are many returns.
    @State private var cashReturnsExpanded: Bool = false

    /// Batches belonging to this float. Prefer the authoritative
    /// `/details` response; fall back to the client-side filter on
    /// `allClaims` so the UI still works if the detail call hasn't
    /// completed yet and the claims list happens to be populated.
    private var batches: [ClaimBatch] {
        if let d = details, !d.batches.isEmpty {
            return d.batches.map { $0.toClaimBatch() }
        }
        return appState.allClaims.filter { $0.floatRequestId == float.id }
    }
    private var balance: Double { float.remaining }

    /// Delegates to the shared file-scope helper so float status colors are
    /// consistent everywhere (FloatCard, FloatDetailView, approval queue, etc.)
    /// Uses the full backend state machine:
    /// AWAITING_APPROVAL → APPROVED / ACCT_OVERRIDE → READY_TO_COLLECT →
    /// COLLECTED → ACTIVE / SPENDING / SPENT / PENDING_RETURN →
    /// CLOSED / CANCELLED / REJECTED.
    private func statusColor(_ s: String) -> (Color, Color) {
        floatStatusColors(s)
    }

    private func batchColor(_ s: String) -> (Color, Color) {
        switch s.uppercased() {
        case "CODING", "CODED": return (.purple, Color.purple.opacity(0.1))
        case "POSTED": return (.green, Color.green.opacity(0.1))
        case "REJECTED": return (.red, Color.red.opacity(0.1))
        case "ESCALATED": return (.orange, Color.orange.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium))
        }.padding(.horizontal, 14).padding(.vertical, 6)
    }

    @ViewBuilder
    private func batchStatusFlow(_ batch: ClaimBatch) -> some View {
        let steps: [(key: String, label: String, sub: String)] = [
            ("CODING", "Submitted", "Batch #\(batch.batchReference)"),
            ("CODED", "Coordinator Coding", "Budget coding done"),
            ("IN_AUDIT", "Accounts Audit", "Audited & verified"),
            ("AWAITING_APPROVAL", "Approval", "Approved"),
            ("READY_TO_POST", "Post & Ledger", "Ready to post"),
            ("POSTED", "Settlement", batch.settlementType.isEmpty ? "Complete" : batch.settlementType.replacingOccurrences(of: "_", with: " ").capitalized),
        ]
        let current: Int = {
            switch batch.status.uppercased() {
            case "CODING": return 0
            case "CODED": return 1
            case "IN_AUDIT": return 2
            case "AWAITING_APPROVAL", "ACCT_OVERRIDE": return 3
            case "READY_TO_POST", "ESCALATED": return 4
            case "POSTED": return 5
            case "REJECTED": return -1
            default: return 0
            }
        }()
        VStack(alignment: .leading, spacing: 0) {
            Text("STATUS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 6)
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(idx < current ? Color.green : idx == current ? Color.goldDark : Color.gray.opacity(0.25))
                            .frame(width: 12, height: 12)
                        if idx < steps.count - 1 {
                            Rectangle()
                                .fill(idx < current ? Color.green.opacity(0.4) : Color.gray.opacity(0.2))
                                .frame(width: 2, height: 24)
                        }
                    }.frame(width: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.label)
                            .font(.system(size: 12, weight: idx == current ? .bold : .medium))
                            .foregroundColor(idx < current ? .green : idx == current ? .goldDark : .secondary)
                        Text(step.sub).font(.system(size: 10)).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
            }
            if batch.status.uppercased() == "REJECTED" {
                HStack(spacing: 8) {
                    Circle().fill(Color.red).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rejected").font(.system(size: 12, weight: .bold)).foregroundColor(.red)
                        Text("Resubmit required").font(.system(size: 10)).foregroundColor(.red.opacity(0.7))
                    }
                }.padding(.horizontal, 14).padding(.top, 4)
            }
        }
        .padding(.bottom, 10).background(Color.bgRaised.opacity(0.5))
    }

    // MARK: - Layout helpers

    private var spendPercent: Double {
        let issued = float.issuedFloat
        guard issued > 0 else { return 0 }
        return min(max(float.receiptsAmount / issued, 0), 1)
    }

    private var statusFooter: (String, Color, String) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        switch float.status.uppercased() {
        case "AWAITING_APPROVAL":   return ("Float request submitted — awaiting approval", .orange, "clock.fill")
        case "APPROVED":            return ("Float approved — awaiting cash preparation", .green, "checkmark.circle.fill")
        case "ACCT_OVERRIDE":       return ("Override approved — awaiting cash preparation", .green, "bolt.fill")
        case "READY_TO_COLLECT":    return ("Cash ready — collect from the accountant", .blue, "banknote.fill")
        case "COLLECTED":           return ("Cash collected — ready to spend", teal, "checkmark.seal.fill")
        case "ACTIVE":              return ("Float active — submit receipts against this float", .goldDark, "creditcard.fill")
        case "SPENDING":            return ("Spending in progress — submit receipts as you go", .goldDark, "cart.fill")
        case "SPENT":               return ("All cash spent — submit final receipts to close", .purple, "doc.text.fill")
        case "PENDING_RETURN":      return ("Awaiting physical cash return to accountant", Color(red: 0.91, green: 0.29, blue: 0.48), "arrow.uturn.backward.circle.fill")
        case "CLOSED":              return ("Float closed", .gray, "checkmark.seal.fill")
        case "CANCELLED":           return ("Float cancelled", .red, "xmark.circle.fill")
        case "REJECTED":            return ("Float rejected — see notes below", .red, "xmark.circle.fill")
        default:                    return (float.statusDisplay, .secondary, "info.circle.fill")
        }
    }

    /// Two-line detail cell (label on top, value below) used in the 3-column grid.
    private func gridCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 13, weight: value.isEmpty ? .regular : .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Three stat columns (Float Issued / Spent / Remaining Balance) — styled
    /// like the web screenshot with subtle cream background and colored values.
    private func statColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Body

    // Totals — prefer backend-computed values from /details; fall back
    // to the values baked into the float object when the API is slow.
    private var issuedTotal: Double   { details?.totals.issued       ?? float.issuedFloat }
    private var spentTotal: Double    { details?.totals.spent        ?? float.spentTotal }
    private var toppedUpTotal: Double { details?.totals.toppedUp     ?? 0 }
    private var finalBalance: Double  { details?.totals.finalBalance ?? float.remaining }
    private var returnedTotal: Double { details?.totals.returned     ?? float.returnAmount }

    /// Action bar visibility — only PENDING_RETURN currently triggers a
    /// pinned footer action ("Record Cash Return"). More button states
    /// (Ready to Collect / Mark Collected / Mark Close) can be slotted
    /// into `actionFooter` alongside this one.
    private var hasFooterAction: Bool {
        float.status.uppercased() == "PENDING_RETURN"
    }

    /// Pinned footer action bar. Shown for statuses where a primary
    /// action makes sense — currently PENDING_RETURN surfaces the pink
    /// "Record Cash Return" button matching the web.
    @ViewBuilder
    private var actionFooter: some View {
        if float.status.uppercased() == "PENDING_RETURN" {
            HStack {
                Spacer()
                Button(action: { navigateToRecordReturn = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 13))
                        Text("Record Cash Return")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color(red: 0.91, green: 0.29, blue: 0.48)) // pink-500
                    .cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgSurface.edgesIgnoringSafeArea(.all)
            if isLoading {
                // Full-screen spinner while /details is in-flight. Users
                // see this before any content shows, so there's no flash
                // of stale list-level values.
                VStack { Spacer(); LoaderView(); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header row ─────────────────────────────────────────
                // #PC-XXXX + status chip · REQUESTED value on the right
                // submitted/collected dates + purpose in italic below
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("#\(float.reqNumber)")
                                .font(.system(size: 17, weight: .bold, design: .monospaced))
                            let (fg, bg) = statusColor(float.status)
                            Text(float.statusDisplay)
                                .font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(bg).cornerRadius(4)
                        }
                        Text(submittedCollectedLine)
                            .font(.system(size: 11)).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !float.purpose.isEmpty {
                            Text("\u{201C}\(float.purpose)\u{201D}")
                                .font(.system(size: 12, weight: .regular))
                                .italic()
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("REQUESTED")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        Text(FormatUtils.formatGBP(float.reqAmount))
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                    }
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

                Divider()

                // ── SUMMARY: 2-col grid (2×2 + 1 spill row for RETURNED)
                VStack(alignment: .leading, spacing: 0) {
                    Text("SUMMARY")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        .padding(.bottom, 10)
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            summaryCell("ISSUED",    FormatUtils.formatGBP(issuedTotal),   color: .goldDark)
                            summaryCell("SPENT",     FormatUtils.formatGBP(spentTotal),    color: .blue)
                        }
                        HStack(spacing: 12) {
                            summaryCell("TOPPED UP", FormatUtils.formatGBP(toppedUpTotal),
                                        color: Color(red: 0.95, green: 0.55, blue: 0.15))
                            summaryCell("FINAL BALANCE", FormatUtils.formatGBP(finalBalance),
                                        color: Color(red: 0.0, green: 0.55, blue: 0.25))
                        }
                        // Lone RETURNED cell spans the full screen width.
                        summaryCell("RETURNED", FormatUtils.formatGBP(returnedTotal),
                                    color: Color(red: 0.91, green: 0.29, blue: 0.48))
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 16)

                Divider()

                // ── POSTED BATCHES ──────────────────────────────────────
                // Mirrors the web: each batch row expands inline to reveal
                // SETTLEMENT + FOLLOW-UP metadata, then a table of receipts.
                Text("POSTED BATCHES · \(batches.count)")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
                if batches.isEmpty {
                    emptySection(text: "No posted batches against this float.")
                        .padding(.horizontal, 16).padding(.bottom, 14)
                } else {
                    VStack(spacing: 10) {
                        ForEach(batches) { batch in
                            postedBatchCard(batch)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 14)
                }

                Divider()

                // ── TOP-UPS ─────────────────────────────────────────────
                let topups = details?.topups ?? []
                Text("TOP-UPS · \(topups.count)")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
                if topups.isEmpty {
                    emptySection(text: "No top-ups were requested against this float.")
                        .padding(.horizontal, 16).padding(.bottom, 14)
                } else {
                    ForEach(topups, id: \.id) { t in
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.up.circle").font(.system(size: 12))
                                .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t.status.capitalized.isEmpty ? "Top-Up" : t.status.capitalized)
                                    .font(.system(size: 12, weight: .semibold))
                                if t.createdAt > 0 {
                                    Text(FormatUtils.formatDateTime(t.createdAt))
                                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Text(FormatUtils.formatGBP(t.issuedAmount > 0 ? t.issuedAmount : t.amount))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        Divider()
                    }
                    Spacer().frame(height: 8)
                }

                Divider()

                // ── CASH RETURNS (collapsible) ─────────────────────────
                // Collapsed by default so the detail page stays compact
                // even when a float has accumulated many partial returns.
                let returns = details?.returns ?? []
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        cashReturnsExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("CASH RETURNS · \(returns.count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary).tracking(0.6)
                        Spacer()
                        Image(systemName: cashReturnsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

                if cashReturnsExpanded {
                    if returns.isEmpty {
                        emptySection(text: "No cash returns recorded against this float.")
                            .padding(.horizontal, 16).padding(.bottom, 14)
                    } else {
                        ForEach(returns, id: \.id) { r in
                            cashReturnRow(r)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                            Divider()
                        }
                        Spacer().frame(height: 8)
                    }
                }

                // ── Rejection banner (only when applicable) ─────────────
                if let reason = float.rejectionReason, !reason.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REJECTION REASON")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.red).tracking(0.6)
                        Text(reason).font(.system(size: 12)).foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.red.opacity(0.06))
                }

                // Bottom spacer so the pinned action bar doesn't cover the
                // last section (rejection banner / cash returns / etc).
                if hasFooterAction {
                    Spacer().frame(height: 80)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
            } // end if isLoading { … } else { ScrollView … }

            // ── Pinned action footer ─────────────────────────────────
            if hasFooterAction && !isLoading { actionFooter }
        }
        .navigationBarTitle(Text("Float \(float.reqNumber)"), displayMode: .inline)
        // History button — visible on every status. Even pre-collection
        // floats have a "Submitted" entry worth showing, and users may
        // want to see rejection notes etc.
        .navigationBarItems(trailing:
            Button(action: { navigateToHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.goldDark)
            }
            .accessibility(label: Text("History"))
        )
        .background(
            ZStack {
                NavigationLink(
                    destination: FloatHistoryPage(floatId: float.id, floatLabel: "#\(float.reqNumber)")
                        .environmentObject(appState),
                    isActive: $navigateToHistory
                ) { EmptyView() }.frame(width: 0, height: 0).hidden()
                // Preselects this float on the record-return form so the
                // user lands straight on amount/date/reason — the detail
                // page already made the selection explicit.
                NavigationLink(
                    destination: RecordCashReturnPage(floats: [float], preselectedFloatId: float.id)
                        .environmentObject(appState),
                    isActive: $navigateToRecordReturn
                ) { EmptyView() }.frame(width: 0, height: 0).hidden()
            }
        )
        .onAppear {
            // Show the loader, then re-hit /details so Issued/Spent/
            // Balance reflect the latest backend state (after a return
            // was recorded or a batch posted via another screen).
            isLoading = true
            appState.loadFloatDetails(float.id) { d in
                if let d = d { self.details = d }
                // Whether the call succeeded or returned empty, we're
                // done loading — the existing `float` prop + any new
                // `details` are enough to render a sensible page.
                self.isLoading = false
            }
            if appState.allClaims.isEmpty { appState.loadAllClaims() }
        }
    }

    // MARK: - Header helpers

    /// "Submitted 10 Apr 2026 · Collected 10 Apr 2026" — matches the web.
    /// `startDate` acts as the collected date when set (that's when the
    /// crew physically took the cash).
    private var submittedCollectedLine: String {
        var parts: [String] = []
        if float.createdAt > 0 {
            parts.append("Submitted \(FormatUtils.formatTimestamp(float.createdAt))")
        }
        if let s = float.startDate, s > 0 {
            parts.append("Collected \(FormatUtils.formatTimestamp(s))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Summary cell (used by the 2×2 SUMMARY grid)

    private func summaryCell(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.bgRaised.opacity(0.4))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
    }

    private func emptySection(text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 18)
            .background(Color.bgRaised.opacity(0.3))
            .cornerRadius(8)
    }

    // MARK: - Posted batch card (inline expandable)
    //
    // Collapsed: #RB-XXXX + status chip, "Posted … · N receipt · Settlement
    // Type", amount on right, chevron.
    // Expanded: SETTLEMENT + FOLLOW-UP chips, then a receipt table.

    private func settlementLabel(_ type: String) -> String {
        let t = type.lowercased()
        switch t {
        case "":                          return "—"
        case "reduce", "reduce_float":    return "Reduce Float"
        case "reimb", "reimburse":        return "Reimburse"
        case "reimburse_bacs", "bacs":    return "Reimburse BACS"
        case "payroll":                   return "Payroll"
        case "float":                     return "Float"
        default:                          return t.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func followUpLabel(_ key: String) -> String {
        let k = key.lowercased()
        switch k {
        case "":        return "—"
        case "close":   return "Close the Float"
        case "top_up":  return "Reimburse to Float"
        default:        return k.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Short status chip label ("Close" when the batch has `close` follow-up,
    /// else the normal statusDisplay) — mirrors the web's compact chip.
    private func batchChipLabel(_ batch: ClaimBatch) -> String {
        if batch.followUp.lowercased() == "close" { return "Close" }
        return batch.statusDisplay
    }

    @ViewBuilder
    private func postedBatchCard(_ batch: ClaimBatch) -> some View {
        let isSelected = selectedBatchId == batch.id
        let (bfg, bbg) = batchColor(batch.status)
        VStack(spacing: 0) {
            // ── Header row (tap toggles expansion) ─────────────────
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedBatchId = isSelected ? nil : batch.id
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 12)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("#\(batch.batchReference)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                            Text(batchChipLabel(batch))
                                .font(.system(size: 9, weight: .bold)).foregroundColor(bfg)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(bbg).cornerRadius(3)
                        }
                        Text(batchSubtitle(batch))
                            .font(.system(size: 10)).foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(FormatUtils.formatGBP(batch.totalGross))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.0, green: 0.55, blue: 0.25))
                }
                .padding(12)
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            // ── Expanded body: settlement + follow-up + table ──────
            if isSelected {
                Divider()
                // Settlement · Follow-up meta row
                HStack(alignment: .top, spacing: 16) {
                    metaPair("SETTLEMENT", settlementLabel(batch.settlementType))
                    metaPair("FOLLOW-UP", followUpLabel(batch.followUp))
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.bgRaised.opacity(0.35))

                Divider()

                // Receipt table (single aggregate row if we don't have
                // individual receipts decoded yet — batch totals stand in).
                batchReceiptTable(batch)
            }
        }
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(isSelected ? Color.goldDark : Color.borderColor,
                    lineWidth: isSelected ? 2 : 1))
    }

    private func batchSubtitle(_ batch: ClaimBatch) -> String {
        var parts: [String] = []
        let stamp = batch.postedAt ?? batch.createdAt
        if stamp > 0 { parts.append("Posted \(FormatUtils.formatDateTime(stamp))") }
        parts.append("\(batch.claimCount) receipt\(batch.claimCount == 1 ? "" : "s")")
        if !batch.settlementType.isEmpty { parts.append(settlementLabel(batch.settlementType)) }
        return parts.joined(separator: " · ")
    }

    private func metaPair(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary)
        }
    }

    /// Table of receipts inside a batch. Individual receipts aren't
    /// decoded in the current `ClaimBatchRaw`; we surface a single
    /// aggregate row (description = notes/coding, amount = totalGross).
    /// When the backend returns per-receipt data we can switch this
    /// `ForEach` to iterate the real line items.
    @ViewBuilder
    private func batchReceiptTable(_ batch: ClaimBatch) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                tableHeader("#",           width: 24,  align: .leading)
                tableHeader("DESCRIPTION", width: nil, align: .leading)
                tableHeader("AMOUNT",      width: 72,  align: .trailing)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.bgRaised.opacity(0.2))

            Divider()

            // One row — aggregate from batch data until per-receipt data
            // is available from the backend.
            HStack(alignment: .top, spacing: 8) {
                Text("1").font(.system(size: 11)).foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
                Text({
                    if !batch.codingDescription.isEmpty { return batch.codingDescription }
                    if !batch.notes.isEmpty { return batch.notes }
                    return "—"
                }())
                .font(.system(size: 11)).foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(FormatUtils.formatGBP(batch.totalGross))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .frame(width: 72, alignment: .trailing)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            Divider()

            // Meta row: settlement/follow-up date references
            HStack(spacing: 16) {
                metaPair("SETTLEMENT", settlementLabel(batch.settlementType))
                metaPair("FOLLOW-UP", followUpLabel(batch.followUp))
                Spacer()
                let dateStr: String = {
                    if let p = batch.postedAt, p > 0 { return FormatUtils.formatTimestamp(p) }
                    return "—"
                }()
                metaPair("DATE", dateStr)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
    }

    private func tableHeader(_ text: String, width: CGFloat?, align: Alignment) -> some View {
        let t = Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.secondary)
            .tracking(0.5)
        return Group {
            if let w = width {
                t.frame(width: w, alignment: align)
            } else {
                t.frame(maxWidth: .infinity, alignment: align)
            }
        }
    }

    // MARK: - Cash Return row

    private func cashReturnRow(_ r: FloatReturnEntry) -> some View {
        // Mark as PARTIAL RETURN when the amount is less than the issued
        // total, else FULL RETURN. Reason notes appear below.
        let isFull = r.returnAmount > 0 && abs(r.returnAmount - issuedTotal) < 0.005
        let chipLabel = isFull ? "FULL RETURN" : "PARTIAL RETURN"
        let chipColor = Color(red: 0.91, green: 0.29, blue: 0.48)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(FormatUtils.formatGBP(r.returnAmount)) returned")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text(chipLabel)
                    .font(.system(size: 9, weight: .bold)).foregroundColor(chipColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(chipColor.opacity(0.12))
                    .cornerRadius(3)
                Spacer()
            }
            HStack(spacing: 6) {
                if r.recordedAt > 0 {
                    Text("Recorded \(FormatUtils.formatDateTime(r.recordedAt))")
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                if r.receivedDate > 0 {
                    if r.recordedAt > 0 { Text("·").font(.system(size: 10)).foregroundColor(.gray) }
                    Text("Received \(FormatUtils.formatTimestamp(r.receivedDate))")
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
            }
            if !r.reasonNotes.isEmpty || !r.notes.isEmpty {
                let body = !r.reasonNotes.isEmpty ? r.reasonNotes : r.notes
                Text(body).font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    private var durationLabel: String {
        let d = float.duration.lowercased()
        if d == "run_of_show" { return "Run of Show" }
        if d.isEmpty { return "—" }
        if let n = Int(d) { return "\(n) day\(n == 1 ? "" : "s")" }
        return float.duration
    }

    private func collectionDisplay(_ key: String) -> String {
        if let label = collectionOptions.first(where: { $0.0 == key })?.1 { return label }
        if key.isEmpty { return "—" }
        return key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Float History Page
// Timeline of float status transitions + batch transitions merged into
// a single chronological feed (matches the backend `getHistory` shape:
// [{ action, action_by, action_at, note? }]).
// ═══════════════════════════════════════════════════════════════════

struct FloatHistoryPage: View {
    let floatId: String
    let floatLabel: String
    @EnvironmentObject var appState: POViewModel

    @State private var entries: [FloatHistoryEntry] = []
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack {
            Color.bgSurface.edgesIgnoringSafeArea(.all)
            if isLoading && entries.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32)).foregroundColor(.gray.opacity(0.35))
                    Text("No history yet").font(.system(size: 13)).foregroundColor(.secondary)
                    Text("Status transitions on this float will appear here.")
                        .font(.system(size: 11)).foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Summary header chip
                        HStack(spacing: 6) {
                            Image(systemName: "banknote").font(.system(size: 12)).foregroundColor(.goldDark)
                            Text(floatLabel)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.goldDark)
                            Spacer()
                            Text("\(entries.count) event\(entries.count == 1 ? "" : "s")")
                                .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        .padding(12).background(Color.bgRaised.opacity(0.4)).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

                        ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                            historyRow(entry, isLast: idx == entries.count - 1)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitle(Text("Float History"), displayMode: .inline)
        .onAppear {
            appState.loadFloatHistory(floatId) { list in
                // Sort newest-first for display.
                self.entries = list.sorted { ($0.actionAt ?? 0) > ($1.actionAt ?? 0) }
                self.isLoading = false
            }
        }
    }

    /// Colour tied to the action string (status transitions mostly).
    private func actionColor(_ action: String) -> Color {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return .green }
        if a.contains("reject") || a.contains("cancel") { return .red }
        if a.contains("override") { return .orange }
        if a.contains("posted") { return .green }
        if a.contains("collected") || a.contains("ready") { return .blue }
        if a.contains("closed") { return .gray }
        return .goldDark
    }

    private func actionIcon(_ action: String) -> String {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return "checkmark.circle.fill" }
        if a.contains("reject") { return "xmark.circle.fill" }
        if a.contains("cancel") { return "slash.circle.fill" }
        if a.contains("override") { return "bolt.fill" }
        if a.contains("posted") { return "tray.and.arrow.down.fill" }
        if a.contains("collected") { return "banknote.fill" }
        if a.contains("ready") { return "checkmark.seal.fill" }
        if a.contains("closed") { return "lock.fill" }
        return "circle.fill"
    }

    private func resolvedUser(_ entry: FloatHistoryEntry) -> (String, String?) {
        if let uid = entry.actionBy, !uid.isEmpty, let u = UsersData.byId[uid] {
            return (u.fullName, u.displayDesignation.isEmpty ? nil : u.displayDesignation)
        }
        if let uid = entry.actionBy, !uid.isEmpty { return (uid, nil) }
        return ("Unknown", nil)
    }

    @ViewBuilder
    private func historyRow(_ entry: FloatHistoryEntry, isLast: Bool) -> some View {
        let action = entry.action ?? "—"
        let color = actionColor(action)
        let (name, role) = resolvedUser(entry)
        HStack(alignment: .top, spacing: 12) {
            // Timeline rail: dot + connecting line
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: actionIcon(action))
                        .font(.system(size: 11, weight: .bold)).foregroundColor(color)
                }
                if !isLast {
                    Rectangle().fill(Color.borderColor).frame(width: 2)
                        .frame(maxHeight: .infinity).padding(.top, 2)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(action).font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                // "by Name (Role)"
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                        .padding(.trailing, 4)
                    (
                        Text("by ").foregroundColor(.secondary)
                        + Text(name).fontWeight(.semibold).foregroundColor(.primary)
                        + Text({ if let r = role { return " (\(r))" } else { return "" } }())
                            .foregroundColor(.secondary)
                    )
                    .font(.system(size: 11))
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                if let n = entry.note, !n.isEmpty {
                    Text(n).font(.system(size: 11)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let ts = entry.actionAt, ts > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.gray)
                        Text(FormatUtils.formatHistoryDateTime(ts))
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
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
// MARK: - Batch Status Detail Page
// Full-page status timeline for a single claim batch. Mirrors the web
// layout: header (ref + summary), STATUS label, then a 6-step vertical
// timeline with green dots/labels for completed steps and an orange dot
// for the current step.
// ═══════════════════════════════════════════════════════════════════

struct BatchStatusDetailPage: View {
    let batch: ClaimBatch

    /// 6-step flow — matches the web screenshot.
    private var steps: [(key: String, label: String, subCompleted: String, subCurrent: String)] {
        [
            ("CODING",            "Submitted",         "Batch #\(batch.batchReference)",           "Receipts sent"),
            ("CODED",             "Coordinator Coding", "Budget coding done",                      "Awaiting coding"),
            ("IN_AUDIT",          "Accounts Audit",    "Audited & verified",                       "Awaiting audit"),
            ("AWAITING_APPROVAL", "Approval",          "Approved",                                 "Awaiting approval"),
            ("READY_TO_POST",     "Post & Ledger",     "Posted to ledger",                         "Ready to post"),
            ("POSTED",            "Settlement",
                settlementSubtitle(batch.settlementType, fallback: "Complete"),
                settlementSubtitle(batch.settlementType, fallback: "Pending settlement"))
        ]
    }

    /// Current step index based on batch.status. Returns -1 when rejected.
    private var currentIndex: Int {
        switch batch.status.uppercased() {
        case "CODING":                          return 0
        case "CODED":                           return 1
        case "IN_AUDIT":                        return 2
        case "AWAITING_APPROVAL", "ACCT_OVERRIDE", "APPROVED":
            return 3
        case "READY_TO_POST", "ESCALATED":      return 4
        case "POSTED":                          return 5
        case "REJECTED":                        return -1
        default:                                return 0
        }
    }

    /// Map settlement type → humanised subtitle ("Reduce float" / "Reimburse
    /// BACS" / "Payroll" etc.).
    private func settlementSubtitle(_ type: String, fallback: String) -> String {
        let t = type.lowercased()
        switch t {
        case "":                          return fallback
        case "reduce", "reduce_float":    return "Reduce float"
        case "reimb", "reimburse":        return "Reimburse"
        case "reimburse_bacs", "bacs":    return "Reimburse BACS"
        case "payroll":                   return "Payroll"
        case "float":                     return "Float"
        default:                          return t.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private var headerSubtitle: String {
        let total = FormatUtils.formatGBP(batch.totalGross)
        let receipts = "\(batch.claimCount) receipt\(batch.claimCount == 1 ? "" : "s")"
        let stamp = FormatUtils.formatDateTime(batch.createdAt)
        return "\(total) · \(receipts) · \(stamp)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── Header ─────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(batch.batchReference)")
                        .font(.system(size: 18, weight: .bold))
                    Text(headerSubtitle)
                        .font(.system(size: 12)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

                Divider()

                // ── STATUS label + timeline ────────────────────────────
                Text("STATUS")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)

                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                        timelineRow(index: idx, step: step, isLast: idx == steps.count - 1)
                    }
                    // Rejected — append a red terminal node
                    if batch.status.uppercased() == "REJECTED" {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle().fill(Color.red).frame(width: 12, height: 12)
                            }
                            .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Rejected")
                                    .font(.system(size: 14, weight: .bold)).foregroundColor(.red)
                                Text("Resubmit required")
                                    .font(.system(size: 11)).foregroundColor(.red.opacity(0.7))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.top, 4)
                    }
                }
                .padding(.bottom, 18)

                // ── Settlement + rejection details ─────────────────────
                if let reason = batch.rejectionReason, !reason.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REJECTION REASON")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.red).tracking(0.6)
                        Text(reason).font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.red.opacity(0.06))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bgSurface)
        .navigationBarTitle(Text("Batch \(batch.batchReference)"), displayMode: .inline)
    }

    /// Renders one row of the vertical status timeline with connecting
    /// lines between the dots, matching the screenshot.
    @ViewBuilder
    private func timelineRow(index: Int,
                             step: (key: String, label: String,
                                    subCompleted: String, subCurrent: String),
                             isLast: Bool) -> some View {
        let current = currentIndex
        let isCompleted = current > index
        let isCurrent   = current == index
        // Color: green when completed, gold when current, gray otherwise.
        let dotColor: Color = isCompleted ? .green : (isCurrent ? Color(red: 1.0, green: 0.55, blue: 0.0) : Color.gray.opacity(0.35))
        let labelColor: Color = isCompleted ? .green : (isCurrent ? Color(red: 1.0, green: 0.55, blue: 0.0) : .secondary)
        let subtitle = isCompleted ? step.subCompleted : (isCurrent ? step.subCurrent : step.subCurrent)

        HStack(alignment: .top, spacing: 12) {
            // Column: dot + connecting line
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(dotColor).frame(width: 12, height: 12)
                }
                .frame(width: 20, height: 20)
                if !isLast {
                    Rectangle()
                        .fill((isCompleted ? Color.green : Color.gray.opacity(0.25)).opacity(0.5))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 20)

            // Right: title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(step.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(labelColor)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(labelColor.opacity(0.85))
            }
            .padding(.bottom, isLast ? 0 : 12)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Float Request List (inline details cards)
// ═══════════════════════════════════════════════════════════════════

struct FloatRequestListView: View {
    @EnvironmentObject var appState: POViewModel

    private var floats: [FloatRequest] {
        appState.myFloats.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if appState.isLoadingMyFloats && appState.myFloats.isEmpty {
                    LoaderView()
                } else if floats.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "banknote").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No float requests yet").font(.system(size: 13)).foregroundColor(.secondary)
                        Text("Tap + New Float to submit your first request.").font(.system(size: 11)).foregroundColor(.gray)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: 480)
                } else {
                    ForEach(floats) { f in
                        NavigationLink(destination: FloatDetailView(float: f).environmentObject(appState)) {
                            FloatRequestRow(float: f).padding(.horizontal, 16)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }.padding(.top, 12).padding(.bottom, 100)
        }
        .background(Color.bgBase)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Claim Detail Page (Receipt Details)
// ═══════════════════════════════════════════════════════════════════

struct ClaimDetailPage: View {
    let claim: ClaimBatch

    private var currentStep: Int {
        switch claim.status.uppercased() {
        case "CODING": return 0
        case "CODED": return 1
        case "IN_AUDIT": return 2
        case "AWAITING_APPROVAL", "ACCT_OVERRIDE", "APPROVED": return 3
        case "READY_TO_POST", "ESCALATED": return 3
        case "POSTED": return 4
        case "REJECTED": return -1
        default: return 0
        }
    }

    private var statusColors: (Color, Color) {
        switch claim.status.uppercased() {
        case "CODING", "CODED": return (.blue, Color.blue.opacity(0.12))
        case "IN_AUDIT": return (.purple, Color.purple.opacity(0.12))
        case "AWAITING_APPROVAL": return (.goldDark, Color.gold.opacity(0.15))
        case "APPROVED", "ACCT_OVERRIDE": return (.green, Color.green.opacity(0.12))
        case "READY_TO_POST": return (.blue, Color.blue.opacity(0.12))
        case "POSTED": return (.green, Color.green.opacity(0.12))
        case "REJECTED": return (.red, Color.red.opacity(0.12))
        case "ESCALATED": return (.orange, Color.orange.opacity(0.12))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private func settlementDisplay(_ s: String) -> String {
        switch s.uppercased() {
        case "REIMBURSE": return "Reimburse"
        case "PAYROLL": return "Payroll"
        case "FLOAT": return "Float"
        default: return s.isEmpty ? "—" : s.capitalized
        }
    }

    private func categoryDisplay(_ c: String) -> String {
        if c.isEmpty { return "—" }
        if let match = claimCategories.first(where: { $0.0 == c }) { return match.1 }
        return c.capitalized
    }

    private func costCodeLabel(_ c: String) -> String {
        if c.isEmpty { return "—" }
        if let match = costCodeOptions.first(where: { $0.0 == c }) { return match.1 }
        return c.uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header: "Receipt Details" + status badge ──────────
                HStack {
                    Text("Receipt Details").font(.system(size: 16, weight: .bold))
                    Spacer()
                    let (fg, bg) = statusColors
                    Text(claim.statusDisplay)
                        .font(.system(size: 11, weight: .bold)).foregroundColor(fg)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(bg).cornerRadius(6)
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

                Divider()

                // ── Progress flow (5 steps) ───────────────────────────
                HStack(spacing: 0) {
                    stepDot(index: 0, label: "Submitted", sub: "Receipts sent")
                    stepDot(index: 1, label: "Coordinator", sub: "Budget coding")
                    stepDot(index: 2, label: "Accounts", sub: "Audit & verify")
                    stepDot(index: 3, label: "Approval", sub: "Sign-off")
                    stepDot(index: 4, label: "Posted", sub: "Ledger / payment")
                }
                .padding(.horizontal, 10).padding(.top, 14).padding(.bottom, 16)

                Divider()

                // ── Summary row: title + amount ───────────────────────
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 16)).foregroundColor(.goldDark)
                        .frame(width: 32, height: 32).background(Color.gold.opacity(0.15)).cornerRadius(6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(claim.notes.isEmpty ? (claim.batchReference.isEmpty ? "—" : "#\(claim.batchReference)") : claim.notes)
                            .font(.system(size: 15, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Text(FormatUtils.formatTimestamp(claim.createdAt)).font(.system(size: 11)).foregroundColor(.secondary)
                            Text("·").foregroundColor(.secondary)
                            Text(claim.isPettyCash ? "Petty Cash" : "Out of Pocket")
                                .font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text(FormatUtils.formatGBP(claim.totalGross))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.goldDark)
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                Divider()

                // ── 2-column details grid (2 per row) ─────────────────
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        infoCell(label: "BATCH", value: claim.batchReference.isEmpty ? "—" : "#\(claim.batchReference)", mono: true)
                        infoCell(label: "CATEGORY", value: categoryDisplay(claim.category))
                    }
                    HStack(alignment: .top, spacing: 16) {
                        infoCell(label: "SETTLEMENT", value: settlementDisplay(claim.settlementType))
                        infoCell(label: "COST CODE", value: costCodeLabel(claim.costCode))
                    }
                    HStack(alignment: .top, spacing: 16) {
                        infoCell(label: "TYPE", value: claim.isPettyCash ? "Petty Cash" : (claim.isOutOfPocket ? "Out of Pocket" : (claim.expenseType.isEmpty ? "—" : claim.expenseType.uppercased())))
                        infoCell(label: "RECEIPTS", value: "\(claim.claimCount)")
                    }
                    HStack(alignment: .top, spacing: 16) {
                        infoCell(label: "TOTAL NET", value: FormatUtils.formatGBP(claim.totalNet), mono: true)
                        infoCell(label: "VAT", value: FormatUtils.formatGBP(claim.totalVat), mono: true)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                // ── Notes / coding description ────────────────────────
                let desc = claim.codingDescription.isEmpty ? claim.notes : claim.codingDescription
                if !desc.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CODING DESCRIPTION")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        Text(desc).font(.system(size: 13)).foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.bgRaised)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                }

                // ── Rejection banner (tinted callout) ─────────────────
                if let reason = claim.rejectionReason, !reason.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REJECTION REASON")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.red).tracking(0.6)
                        Text(reason).font(.system(size: 12)).foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.red.opacity(0.06))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bgSurface)
        .navigationBarTitle(Text("Receipt Details"), displayMode: .inline)
    }

    private func stepDot(index: Int, label: String, sub: String) -> some View {
        let isDone = index < currentStep
        let isActive = index == currentStep
        let color: Color = isDone ? .green : isActive ? .goldDark : Color.gray.opacity(0.4)
        let labelColor: Color = isDone ? .green : isActive ? .goldDark : .secondary
        return VStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 11, weight: isActive ? .bold : .semibold)).foregroundColor(labelColor).lineLimit(1).minimumScaleFactor(0.7)
            Text(sub).font(.system(size: 9)).foregroundColor(.gray).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func infoCell(label: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(mono ? .system(size: 13, weight: .semibold, design: .monospaced) : .system(size: 13))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FloatRequestRow: View {
    let float: FloatRequest

    /// Delegates to the shared file-scope helper so the status badge colors on
    /// the list match exactly what's shown on the detail page / approval queue.
    private var statusColors: (Color, Color) {
        floatStatusColors(float.status)
    }

    private var durationLabel: String {
        let d = float.duration.lowercased()
        if d == "run_of_show" { return "Run of Show" }
        if d.isEmpty { return "" }
        if let n = Int(d) { return "\(n) day\(n == 1 ? "" : "s")" }
        return float.duration
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("#\(float.reqNumber)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    let (fg, bg) = statusColors
                    Text(float.statusDisplay.uppercased())
                        .font(.system(size: 8, weight: .bold)).foregroundColor(fg)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(bg).cornerRadius(3)
                }
                Text("Submitted \(FormatUtils.formatTimestamp(float.createdAt))")
                    .font(.system(size: 10)).foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(FormatUtils.formatGBP(float.reqAmount))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                if !durationLabel.isEmpty {
                    Text(durationLabel).font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.gray)
        }
        .padding(14)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

struct FloatRequestDetailPage: View {
    let float: FloatRequest
    var body: some View {
        ScrollView {
            VStack {
                FloatDetailsCard(float: float).padding(.horizontal, 16).padding(.top, 12)
            }
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Float \(float.reqNumber)"), displayMode: .inline)
    }
}

struct FloatDetailsCard: View {
    let float: FloatRequest

    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        switch float.status.uppercased() {
        case "AWAITING_APPROVAL":   return (.orange, Color.orange.opacity(0.15))
        case "APPROVED",
             "ACCT_OVERRIDE":       return (.green, Color.green.opacity(0.12))
        case "READY_TO_COLLECT":    return (.blue, Color.blue.opacity(0.12))
        case "COLLECTED":           return (teal, teal.opacity(0.12))
        case "ACTIVE",
             "SPENDING":            return (.goldDark, Color.gold.opacity(0.15))
        case "SPENT":               return (.purple, Color.purple.opacity(0.12))
        case "PENDING_RETURN":      return (.orange, Color.orange.opacity(0.15))
        case "CLOSED":              return (.gray, Color.gray.opacity(0.15))
        case "REJECTED",
             "CANCELLED":           return (.red, Color.red.opacity(0.12))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private var footer: (String, Color, String) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        switch float.status.uppercased() {
        case "AWAITING_APPROVAL":
            return ("Float request submitted — awaiting approval", .orange, "clock.fill")
        case "APPROVED":
            return ("Float approved — awaiting cash preparation", .green, "checkmark.circle.fill")
        case "ACCT_OVERRIDE":
            return ("Override approved — awaiting cash preparation", .green, "bolt.fill")
        case "READY_TO_COLLECT":
            return ("Cash ready — collect from the accountant", .blue, "banknote.fill")
        case "COLLECTED":
            return ("Cash collected — ready to spend", teal, "checkmark.seal.fill")
        case "ACTIVE":
            return ("Float active — submit receipts against this float", .goldDark, "creditcard.fill")
        case "SPENDING":
            return ("Spending in progress — submit receipts as you go", .goldDark, "cart.fill")
        case "SPENT":
            return ("All cash spent — submit final receipts to close", .purple, "doc.text.fill")
        case "PENDING_RETURN":
            return ("Awaiting physical cash return to accountant", .orange, "arrow.uturn.backward.circle.fill")
        case "CLOSED":
            return ("Float closed", .gray, "checkmark.seal.fill")
        case "CANCELLED":
            return ("Float cancelled", .red, "xmark.circle.fill")
        case "REJECTED":
            return ("Float rejected — see notes below", .red, "xmark.circle.fill")
        default:
            return (float.statusDisplay, .secondary, "info.circle.fill")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Float Details").font(.system(size: 14, weight: .bold))
                Spacer()
                let (fg, bg) = statusColors
                Text(float.statusDisplay.uppercased())
                    .font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(bg).cornerRadius(4)
            }
            .padding(14)

            Divider()

            // Two-column grid of details
            VStack(spacing: 14) {
                detailRow(leftLabel: "REF.", leftValue: "#\(float.reqNumber)",
                          rightLabel: "SUBMITTED ON", rightValue: FormatUtils.formatTimestamp(float.createdAt),
                          leftMono: true)
                detailRow(leftLabel: "USER", leftValue: UsersData.byId[float.userId]?.fullName ?? "—",
                          rightLabel: "DEPARTMENT", rightValue: float.department.isEmpty ? "—" : float.department)
                detailRow(leftLabel: "REQUESTED AMOUNT", leftValue: FormatUtils.formatGBP(float.reqAmount),
                          rightLabel: "DURATION", rightValue: float.duration.isEmpty ? "—" : "\(float.duration) days",
                          leftMono: true)
                detailRow(leftLabel: "COST CODE", leftValue: costCodeDisplay(float.costCode),
                          rightLabel: "START DATE", rightValue: (float.startDate ?? 0) > 0 ? FormatUtils.formatTimestamp(float.startDate!) : "—")
                if !float.collectionMethod.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PREFERRED COLLECTION METHOD").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Text(collectionDisplay(float.collectionMethod)).font(.system(size: 13))
                        }
                        Spacer()
                    }
                }
                if !float.purpose.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PURPOSE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Text(float.purpose).font(.system(size: 13))
                        }
                        Spacer()
                    }
                }
            }
            .padding(14)

            Divider()

            // Footer status line
            let (text, color, icon) = footer
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
                Text(text).font(.system(size: 12, weight: .semibold)).foregroundColor(color)
            }.padding(14)

            // Rejection reason if present
            if let reason = float.rejectionReason, !reason.isEmpty {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundColor(.red)
                    Text(reason).font(.system(size: 11)).foregroundColor(.red)
                    Spacer()
                }.padding(14).background(Color.red.opacity(0.06))
            }
        }
        .background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private func detailRow(leftLabel: String, leftValue: String, rightLabel: String, rightValue: String, leftMono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(leftLabel).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                Text(leftValue).font(leftMono ? .system(size: 14, weight: .bold, design: .monospaced) : .system(size: 13))
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(rightLabel).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                Text(rightValue).font(.system(size: 13))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func costCodeDisplay(_ code: String) -> String {
        if code.isEmpty { return "—" }
        if let match = costCodeOptions.first(where: { $0.0 == code }) { return match.1 }
        return code.uppercased()
    }

    private func collectionDisplay(_ method: String) -> String {
        if let match = collectionOptions.first(where: { $0.0 == method }) { return match.1 }
        return method.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

let claimCategories = [
    ("materials", "Materials"), ("equipment", "Props / Equipment"),
    ("stationery", "Consumables / Stationery"), ("catering", "Catering"),
    ("fuel", "Fuel"), ("parking", "Parking"), ("taxi", "Taxi / Travel"),
    ("accommodation", "Accommodation"), ("other", "Other"),
]

struct SubmitClaimFormView: View {
    var expenseType: String = "pc" // "pc" or "oop"
    @EnvironmentObject var appState: POViewModel

    @State private var receipts: [ClaimReceiptItem] = [ClaimReceiptItem()]
    // Primary settlement is auto-derived ("reimb" or "reduce") — never user-overridable.
    // followUp is an OPTIONAL extra action (independent of the primary):
    //   nil      → no extra action
    //   "top_up" → reimburse this batch back into the float
    //   "close"  → close the float after this batch
    @State private var settlementType: String = ""  // legacy — only used for old reimbursement panel
    @State private var followUp: String? = nil

    // Pending (not-yet-posted) batches against the active float — fetched on appear.
    // Used to compute the *effective* float balance (live balance − pending submissions)
    // so the primary derivation accounts for receipts already in the pipeline.
    @State private var pendingBatches: [ClaimBatch] = []
    private var pendingBatchesTotal: Double {
        pendingBatches.reduce(0) { $0 + $1.totalGross }
    }
    @State private var reimbMethod: String = "bacs"
    @State private var accountName: String = ""
    @State private var sortCode: String = ""
    @State private var accountNumber: String = ""
    @State private var reimbAmount: String = ""
    @State private var extraFields: [(label: String, value: String)] = []
    @State private var topUpAmount: String = ""
    @State private var notes: String = ""
    @State private var submitting = false
    @State private var submitted = false
    @State private var submitError: String?
    @State private var categorySheetForId: UUID?
    @State private var uploadReceiptId: UUID?
    @State private var navigateToUpload = false
    @State private var receiptDates: [UUID: Date] = [:]
    @State private var receiptDatePickerId: UUID?
    @State private var budgetCodingOpenId: UUID?

    private var batchTotal: Double {
        receipts.reduce(0) { $0 + (Double($1.amount) ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Step 1: Receipts ──
                stepHeader(number: "1", title: "Add Your Receipts", subtitle: "Upload receipts for your purchases")

                ForEach(receipts) { item in
                    receiptCard(item)
                }

                Button(action: { receipts.append(ClaimReceiptItem()) }) {
                    HStack {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        Text("Add Another Receipt").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.goldDark).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())

                Divider()

                // ── Step 2: Settlement / Reimbursement ──
                if expenseType == "pc" {
                    stepHeader(number: "2", title: "Choose Your Settlement", subtitle: "This will be sent to the accountant with your receipts")

                    settlementStatsBanner
                    primarySettlementCard

                    // When this batch overdraws the float, the primary becomes "Reimburse"
                    // and the user needs to provide reimbursement bank details.
                    // Also show when the user picked "Reimburse to Float" follow-up — the
                    // reimbursement amount goes back to the float, but the form is the same.
                    if autoPrimarySettlement == "reimb" {
                        reimbursementSection
                    }

                    optionalSettlementPills
                    optionalSettlementDetail
                } else {
                    // OOP: always reimbursement
                    stepHeader(number: "2", title: "Reimbursement Method", subtitle: "How would you like to be paid back?")
                    reimbursementSection
                }

                // ── Notes ──
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADDITIONAL NOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    MultilineTextView(text: $notes, placeholder: "Any additional context for the accountant…")
                        .frame(maxWidth: .infinity, minHeight: 70)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }

                // ── Error ──
                if let err = submitError {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        Text(err).font(.system(size: 11)).foregroundColor(.red)
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.06)).cornerRadius(8)
                }

                // ── Submit (full-width) ──
                Button(action: submitClaim) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(submitted ? "Submitted" : submitting ? "Submitting..." : "Submit Claim for Coding & Approval")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(submitted ? Color.green : Color.orange).cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(submitting || submitted)

                claimInfoBanner

            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 30)
        }
        .background(
            NavigationLink(destination: ClaimFilePickerPage(onFilePicked: { name, data in
                if let id = uploadReceiptId, let idx = receipts.firstIndex(where: { $0.id == id }) {
                    receipts[idx].fileName = name; receipts[idx].fileData = data
                }
                uploadReceiptId = nil
            }), isActive: $navigateToUpload) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .onAppear {
            // Load the user's floats so we can compute float balance for the settlement banner
            if appState.myFloats.isEmpty { appState.loadMyFloats() }
            // Load the user's batches so we can subtract pending (not-yet-posted) ones
            // from the effective balance — matches the web's pendingBatches calc.
            appState.loadMyBatches()
        }
        .onReceive(appState.$myBatches) { batches in
            recomputePendingBatches(from: batches)
        }
        .onReceive(appState.$myFloats) { _ in
            // Float list arrived (or refreshed) → re-derive pending batches for the new active float
            recomputePendingBatches(from: appState.myBatches)
        }
    }

    /// Filter myBatches to those against the current active float that are still
    /// in the pipeline (not POSTED / REJECTED / CLOSED). These reduce the
    /// effective balance used to derive the primary settlement.
    private func recomputePendingBatches(from batches: [ClaimBatch]) {
        guard let floatId = activeFloat?.id else {
            pendingBatches = []
            return
        }
        let terminal: Set<String> = ["POSTED", "REJECTED", "CLOSED"]
        pendingBatches = batches.filter { b in
            b.floatRequestId == floatId && !terminal.contains(b.status.uppercased())
        }
    }

    // MARK: - Receipt Card

    private func receiptCard(_ item: ClaimReceiptItem) -> some View {
        let itemId = item.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECEIPT \(receiptIndex(item) + 1)").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                Spacer()
                if receipts.count > 1 {
                    Button(action: { receipts.removeAll { $0.id == itemId } }) {
                        Text("Remove").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(Color.red).cornerRadius(4)
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }

            // File upload
            if item.fileName.isEmpty {
                Button(action: { uploadReceiptId = itemId; navigateToUpload = true }) {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.up.doc").font(.system(size: 22)).foregroundColor(.gray.opacity(0.4))
                        Text("Upload receipt image or PDF").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        Text("Tap to browse · JPG, PNG, PDF").font(.system(size: 10)).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.bgRaised).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundColor(Color.borderColor))
                }.buttonStyle(PlainButtonStyle())
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip").font(.system(size: 11)).foregroundColor(.green)
                    Text(item.fileName).font(.system(size: 12)).foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3)).lineLimit(1)
                    Spacer()
                    Button(action: {
                        if let idx = receipts.firstIndex(where: { $0.id == itemId }) {
                            receipts[idx].fileName = ""; receipts[idx].fileData = nil
                        }
                    }) {
                        Text("Remove").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3).background(Color.red).cornerRadius(4)
                    }.buttonStyle(BorderlessButtonStyle())
                }
                .padding(8).background(Color.green.opacity(0.06)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))
            }

            // Date + Amount
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date of Purchase *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    if receiptDates[itemId] != nil {
                        HStack {
                            DatePicker("", selection: Binding(
                                get: { receiptDates[itemId] ?? Date() },
                                set: { newDate in
                                    receiptDates[itemId] = newDate
                                    let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"
                                    if let idx = receipts.firstIndex(where: { $0.id == itemId }) { receipts[idx].date = df.string(from: newDate) }
                                }
                            ), in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            Button(action: {
                                receiptDates[itemId] = nil
                                if let idx = receipts.firstIndex(where: { $0.id == itemId }) { receipts[idx].date = "" }
                            }) {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.gray)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    } else {
                        Button(action: {
                            receiptDates[itemId] = Date()
                            let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"
                            if let idx = receipts.firstIndex(where: { $0.id == itemId }) { receipts[idx].date = df.string(from: Date()) }
                        }) {
                            HStack {
                                Text("dd/mm/yyyy").font(.system(size: 13)).foregroundColor(.gray)
                                Spacer()
                                Image(systemName: "calendar").font(.system(size: 12)).foregroundColor(.goldDark)
                            }
                            .padding(8).background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    TextField("£0.00", text: receiptBinding(itemId, \.amount))
                        .font(.system(size: 13, design: .monospaced)).keyboardType(.decimalPad)
                        .padding(8).background(Color.bgRaised).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }
            }

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Description *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                TextField("What did you purchase?", text: receiptBinding(itemId, \.description))
                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }

            // Category dropdown
            VStack(alignment: .leading, spacing: 4) {
                Text("Category").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                Button(action: { categorySheetForId = itemId }) {
                    HStack {
                        Text(claimCategories.first { $0.0 == item.category }?.1 ?? "Materials")
                            .font(.system(size: 13)).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                    }
                    .padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                .selectionActionSheet(
                    title: "Select Category",
                    isPresented: Binding(
                        get: { categorySheetForId == itemId },
                        set: { if !$0 { categorySheetForId = nil } }
                    ),
                    options: claimCategories.map { $0.0 },
                    isSelected: { $0 == item.category },
                    label: { val in claimCategories.first { $0.0 == val }?.1 ?? val },
                    onSelect: { val in
                        if let idx = receipts.firstIndex(where: { $0.id == itemId }) { receipts[idx].category = val }
                    }
                )
            }

            // Budget Coding (collapsible)
            VStack(spacing: 0) {
                Button(action: { budgetCodingOpenId = budgetCodingOpenId == itemId ? nil : itemId }) {
                    HStack(spacing: 6) {
                        Image(systemName: budgetCodingOpenId == itemId ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8)).foregroundColor(.gray)
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                        Text("Budget Coding").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.secondary)
                        Text("Optional — leave blank if unsure").font(.system(size: 10)).foregroundColor(.gray)
                        Spacer()
                        if !item.costCode.isEmpty {
                            Text(item.costCode).font(.system(size: 10, design: .monospaced)).foregroundColor(.green)
                        }
                    }
                    .padding(10).background(Color.bgRaised).contentShape(Rectangle())
                }.buttonStyle(PlainButtonStyle())

                if budgetCodingOpenId == itemId {
                    VStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COST CODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            CostCodePickerButton(selectedCode: receiptBinding(itemId, \.costCode))
                        }
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("EPISODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                                TextField("e.g. Ep.3", text: receiptBinding(itemId, \.episode))
                                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DESCRIPTION").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                                TextField("Coding description (optional)", text: receiptBinding(itemId, \.codedDescription))
                                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                        }
                    }.padding(10)
                    .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
                }
            }
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
        }
        .padding(12).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Helpers

    private func receiptIndex(_ item: ClaimReceiptItem) -> Int {
        receipts.firstIndex(where: { $0.id == item.id }) ?? 0
    }

    private func receiptBinding(_ id: UUID, _ kp: WritableKeyPath<ClaimReceiptItem, String>) -> Binding<String> {
        Binding(
            get: { receipts.first(where: { $0.id == id })?[keyPath: kp] ?? "" },
            set: { val in if let idx = receipts.firstIndex(where: { $0.id == id }) { receipts[idx][keyPath: kp] = val } }
        )
    }

    private var reimbursementSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                reimbOption("Bank Transfer (BACS)", value: "bacs", icon: "building.columns.fill")
                reimbOption("Add to Payroll", value: "payroll", icon: "doc.text.fill")
            }
            if reimbMethod == "bacs" {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        formField("Account Name", text: $accountName)
                        formField("Sort Code", text: $sortCode)
                    }
                    HStack(spacing: 10) {
                        formField("Account Number", text: $accountNumber)
                        formField("Amount", text: $reimbAmount, keyboardType: .decimalPad, placeholder: "£0.00")
                    }

                    // Extra fields
                    ForEach(Array(extraFields.enumerated()), id: \.offset) { idx, _ in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Field name (e.g. IBAN)", text: Binding(
                                    get: { extraFields[idx].label },
                                    set: { extraFields[idx].label = $0 }
                                )).font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Value", text: Binding(
                                    get: { extraFields[idx].value },
                                    set: { extraFields[idx].value = $0 }
                                )).font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            Button(action: { extraFields.remove(at: idx) }) {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundColor(.red.opacity(0.6))
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }

                    // Add additional detail button
                    Button(action: { extraFields.append((label: "", value: "")) }) {
                        Text("+ Add additional detail (IBAN, BIC, routing number, etc.)")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(.goldDark)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundColor(Color.goldDark.opacity(0.4)))
                    }.buttonStyle(BorderlessButtonStyle())
                }
                .padding(12).background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            }
        }
    }

    // ── Info banner ──────────────────────────────────────────────────
    private var claimInfoBanner: some View {
        let info: Text = {
            let plain  = Font.system(size: 11)
            let bold   = Font.system(size: 11, weight: .bold)
            var t = Text("Your claim goes to your ").font(plain)
            t = t + Text("Department Coordinator").font(bold)
            t = t + Text(" for budget coding, then ").font(plain)
            t = t + Text("Accountants").font(bold)
            t = t + Text(" for auditing purposes. You'll be notified at each stage.").font(plain)
            return t
        }()
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill").font(.system(size: 12)).foregroundColor(.blue)
            info.foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2), lineWidth: 1))
    }

    // ── Current user's active float (for balance display) ────────────
    /// Match the web's allow-list of statuses (any spendable / pre-spendable state).
    private var activeFloat: FloatRequest? {
        let allowed: Set<String> = [
            "READY_TO_COLLECT", "COLLECTED", "ACTIVE", "SPENDING",
            "APPROVED", "ACCT_OVERRIDE", "AWAITING_APPROVAL",
            "SPENT", "PENDING_RETURN"
        ]
        return appState.myFloats.first { allowed.contains($0.status.uppercased()) }
    }

    /// Live float balance from the server — the running cash remaining on the float.
    /// Mirrors the web's `parseFloat(activeFloat?.balance || 0)`.
    private var floatBalance: Double {
        // FloatRequest exposes `remaining` as a derived property; the server's
        // authoritative `balance` field is set during issue/return/topup, so use
        // remaining as a stand-in (issuedFloat − receiptsAmount − returnAmount).
        activeFloat?.remaining ?? 0
    }

    /// Effective balance = live balance − pending batches not yet posted.
    /// This is what determines whether THIS new batch overdraws the float.
    private var effectiveBalance: Double {
        max(0, floatBalance - pendingBatchesTotal)
    }

    /// Auto-derive the primary settlement: reimburse only if this batch would
    /// overdraw the *effective* balance (live balance − pending batches).
    /// Mirrors web logic `newBatchTotal > effectiveBalance ? "reimburse" : "reduce"`.
    private var autoPrimarySettlement: String {
        batchTotal > effectiveBalance ? "reimb" : "reduce"
    }

    /// Overdraft amount (only meaningful when primary == "reimb").
    private var overdraftAmount: Double {
        max(0, batchTotal - floatBalance)
    }

    // Primary card always reflects the auto-derived settlement — it does NOT
    // change when the user taps an "optional also do one of" pill.
    // Copy mirrors the web's PCSettlementSection.
    private var primaryTitle: String {
        autoPrimarySettlement == "reimb" ? "Reimburse Me" : "Reduce My Float"
    }

    private var primaryDescription: String {
        autoPrimarySettlement == "reimb"
            ? "This batch overdraws your float. The overdraft will be reimbursed to you."
            : "Batch is within float balance — this will reduce your remaining float."
    }

    private var primaryIcon: String {
        autoPrimarySettlement == "reimb"
            ? "arrow.uturn.backward.circle.fill"
            : "chart.line.downtrend.xyaxis"
    }

    // ── Settlement stats banner ──────────────────────────────────────
    private var settlementStatsBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Batch total:").font(.system(size: 10)).foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Text(FormatUtils.formatGBP(batchTotal))
                        .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.primary)
                    Text("· \(receipts.count) receipt\(receipts.count == 1 ? "" : "s")")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            Divider().frame(height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Float balance:").font(.system(size: 10)).foregroundColor(.secondary)
                Text(FormatUtils.formatGBP(floatBalance))
                    .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.primary)
            }
            Spacer()
            Text("PENDING SUBMISSION")
                .font(.system(size: 8, weight: .bold)).tracking(0.5).foregroundColor(.orange)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.orange.opacity(0.12)).cornerRadius(4)
        }
        .padding(12).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // ── Primary settlement card (auto-selected, highlighted) ─────────
    private var primarySettlementCard: some View {
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: primaryIcon).font(.system(size: 18)).foregroundColor(orange)
                    .frame(width: 32, height: 32)
                    .background(orange.opacity(0.12)).cornerRadius(6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryTitle).font(.system(size: 14, weight: .bold))
                    Text(primaryDescription).font(.system(size: 11)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundColor(orange)
            }

            // Cream-colored impact banner — shows overdraft breakdown for reimburse,
            // or the simple "£X will reduce the float" message for reduce.
            HStack {
                Text(primaryImpactText)
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.05))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(orange.opacity(0.08)).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(orange.opacity(0.2), lineWidth: 1))
        }
        .padding(14)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(orange, lineWidth: 1.5))
    }

    /// Impact strip text shown inside the primary card's cream banner.
    /// - reimburse → "Overdraft £X reimbursed · £Y float consumed"
    /// - reduce    → "£X will reduce the float"
    private var primaryImpactText: String {
        if autoPrimarySettlement == "reimb" {
            return "Overdraft \(FormatUtils.formatGBP(overdraftAmount)) reimbursed · "
                + "\(FormatUtils.formatGBP(floatBalance)) float consumed"
        }
        return "\(FormatUtils.formatGBP(batchTotal)) will reduce the float"
    }

    // ── Optional follow-up pills ─────────────────────────────────────
    /// Pills are additive to the primary — tapping toggles selection on/off.
    /// followUp values map to web's: "top_up" (reimburse to float) | "close" (close the float).
    private var optionalSettlementPills: some View {
        let pills: [(String, String)] = [
            ("top_up", "Reimburse to Float"),
            ("close",  "Close the Float"),
        ]
        return VStack(alignment: .leading, spacing: 6) {
            Text("OPTIONAL — ALSO DO ONE OF:")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            HStack(spacing: 8) {
                ForEach(pills, id: \.0) { opt in
                    pillButton(id: opt.0, label: opt.1)
                }
                Spacer()
            }
        }
    }

    private func pillButton(id: String, label: String) -> some View {
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        let active = followUp == id
        return Button(action: {
            // Toggle: tapping the active pill deselects it
            followUp = active ? nil : id
        }) {
            Text(label)
                .font(.system(size: 12, weight: active ? .semibold : .medium))
                .foregroundColor(active ? orange : .primary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(active ? orange.opacity(0.05) : Color.bgSurface)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(active ? orange : Color.borderColor, lineWidth: 1))
        }.buttonStyle(BorderlessButtonStyle())
    }

    // ── Optional detail card (shown below pills when a pill is active) ──
    @ViewBuilder
    private var optionalSettlementDetail: some View {
        if followUp == "top_up" {
            reimburseToFloatBanner
        } else if followUp == "close" {
            closeFloatBreakdown
        }
    }

    private var reimburseToFloatBanner: some View {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundColor(teal)
            (Text(FormatUtils.formatGBP(batchTotal)).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.primary)
             + Text(" will be reimbursed back to your float balance after this batch is posted.")
                .font(.system(size: 12)).foregroundColor(.primary))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(teal.opacity(0.06)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(teal.opacity(0.3), lineWidth: 1))
    }

    private var closeFloatBreakdown: some View {
        // Mirrors web logic exactly:
        //   returnAmount = balance − batchTotal − pendingBatchesTotal
        //   > 0.005     → amber: "Return £X cash to the accountant"
        //   ≈ 0         → green: "No cash to return — this batch will zero out the float"
        //   < -0.005    → red warning: pending batches exceed balance, may be overdrawn
        let amber = Color(red: 0.85, green: 0.5, blue: 0.05)
        let green = Color(red: 0.0, green: 0.55, blue: 0.3)
        let returnAmount = floatBalance - batchTotal - pendingBatchesTotal
        let needsReturn = returnAmount > 0.005
        let isOverdrawn = returnAmount < -0.005
        let bannerColor = needsReturn ? amber : (isOverdrawn ? .red : green)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Close Float").font(.system(size: 14, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                // Status line
                HStack(spacing: 6) {
                    Image(systemName: needsReturn ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.system(size: 11)).foregroundColor(bannerColor)
                    Text(needsReturn
                         ? "Return \(FormatUtils.formatGBP(returnAmount)) cash to the accountant"
                         : "No cash to return — this batch will zero out the float")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(bannerColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Breakdown rows (mirrors web's exact lines)
                VStack(spacing: 4) {
                    breakdownRow(label: "Current float balance", value: FormatUtils.formatGBP(floatBalance), sign: "")
                    breakdownRow(label: "This batch total", value: "−\(FormatUtils.formatGBP(batchTotal))", sign: "−")
                    if pendingBatches.count > 0 {
                        let pluralS = pendingBatches.count == 1 ? "" : "es"
                        breakdownRow(
                            label: "\(pendingBatches.count) pending batch\(pluralS) not yet posted",
                            value: "−\(FormatUtils.formatGBP(pendingBatchesTotal))",
                            sign: "−"
                        )
                    }
                    Divider()
                    breakdownRow(
                        label: "Cash to return",
                        value: FormatUtils.formatGBP(max(0, returnAmount)),
                        sign: "=",
                        bold: true
                    )
                }

                if isOverdrawn {
                    Text("Warning: pending batches exceed the current balance by \(FormatUtils.formatGBP(abs(returnAmount))). You may be overdrawn.")
                        .font(.system(size: 11)).foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .padding(12)
            .background(bannerColor.opacity(0.08)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(bannerColor.opacity(0.3), lineWidth: 1))
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func breakdownRow(label: String, value: String, sign: String, bold: Bool = false) -> some View {
        HStack(spacing: 6) {
            if !sign.isEmpty {
                Text(sign).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
                    .frame(width: 10, alignment: .leading)
            }
            Text(label)
                .font(.system(size: 11, weight: bold ? .bold : .regular, design: .monospaced))
                .foregroundColor(bold ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: bold ? .bold : .regular, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    private func settlementOption(id: String, icon: String, title: String, desc: String, color: Color) -> some View {
        let active = settlementType == id
        return Button(action: { settlementType = id }) {
            HStack(spacing: 12) {
                Image(systemName: active ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18)).foregroundColor(active ? color : .gray)
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(active ? color : .gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(active ? color : .primary)
                    Text(desc).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer()
            }
            .padding(12).background(Color.bgSurface).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? color : Color.borderColor, lineWidth: active ? 2 : 1))
        }.buttonStyle(PlainButtonStyle())
    }

    private func formField(_ label: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, placeholder: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            TextField(placeholder ?? label, text: text).font(.system(size: 13)).keyboardType(keyboardType).padding(8)
                .background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    private func stepHeader(number: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.gold).frame(width: 24, height: 24)
                Text(number).font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
    }

    private func reimbOption(_ label: String, value: String, icon: String) -> some View {
        let active = reimbMethod == value
        let subtitle = value == "bacs" ? "Direct to your bank · 1–3 working days" : "Included in next payroll run"
        return Button(action: { reimbMethod = value }) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(active ? .goldDark : .gray)
                Text(label).font(.system(size: 12, weight: .bold)).foregroundColor(active ? .goldDark : .primary)
                Text(subtitle).font(.system(size: 9)).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color.bgSurface).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(active ? Color.gold : Color.borderColor, lineWidth: active ? 2 : 1))
        }.buttonStyle(PlainButtonStyle())
    }

    // MARK: - Submit

    private func submitClaim() {
        guard let user = appState.currentUser else { return }
        let validReceipts = receipts.filter { !$0.description.isEmpty && !$0.amount.isEmpty }
        guard !validReceipts.isEmpty else { submitError = "Add at least one receipt with description and amount"; return }
        submitting = true; submitError = nil

        let receiptItems: [[String: Any]] = validReceipts.map { r in
            var item: [String: Any] = ["description": r.description, "amount": Double(r.amount) ?? 0, "category": r.category]
            if !r.date.isEmpty { item["date"] = r.date }
            if !r.costCode.isEmpty { item["cost_code"] = r.costCode }
            if !r.episode.isEmpty { item["episode"] = r.episode }
            if !r.codedDescription.isEmpty { item["coded_description"] = r.codedDescription }
            return item
        }

        // settlement_type is ALWAYS the auto-derived primary (REIMBURSE or REDUCE_FLOAT for PC).
        // The optional follow-up pill is sent separately as `settlement_details.follow_up`.
        // Mirrors web payload exactly.
        let settleType: String = {
            if expenseType == "pc" {
                return autoPrimarySettlement == "reimb" ? "REIMBURSE" : "REDUCE_FLOAT"
            }
            // OOP: always reimburse
            return "REIMBURSE"
        }()

        var settlementDetails: [String: Any] = [:]
        let isPrimaryReimburse = (settleType == "REIMBURSE")

        if isPrimaryReimburse {
            settlementDetails["payment_method"] = reimbMethod == "bacs" ? "BACS" : "PAYROLL"
            if reimbMethod == "bacs" {
                var bd: [String: Any] = ["account_name": accountName, "sort_code": sortCode, "account_number": accountNumber]
                let extras = extraFields.filter { !$0.label.isEmpty && !$0.value.isEmpty }.map { ["label": $0.label, "value": $0.value] }
                if !extras.isEmpty { bd["additional_details"] = extras }
                settlementDetails["bank_details"] = bd
            }
        }

        // Optional follow-up action (independent of primary)
        if let fu = followUp {
            settlementDetails["follow_up"] = fu
            if fu == "top_up" {
                // Reimburse the batch back into the float
                settlementDetails["top_up_amount"] = (batchTotal * 100).rounded() / 100
            }
        } else {
            settlementDetails["follow_up"] = NSNull()
        }

        // Promote first receipt's coding info to batch level so the detail view can display it
        let first = validReceipts.first
        var body: [String: Any] = [
            "expense_type": expenseType,
            "department_id": user.departmentId,
            "float_request_id": activeFloat?.id ?? NSNull(),
            "settlement_type": settleType,
            "settlement_details": settlementDetails,
            "notes": notes,
            "category": first?.category ?? "",
            "cost_code": first?.costCode ?? "",
            "coding_description": first?.codedDescription ?? "",
            "claims": receiptItems,
        ]

        CashExpenseCodableTask.createClaimBatch(body) { [self] result in
            DispatchQueue.main.async {
                submitting = false
                switch result {
                case .success:
                    submitted = true
                    appState.loadMyClaims()
                case .failure(let error):
                    submitError = error.localizedDescription
                }
            }
        }.urlDataTask?.resume()
    }
}

// MARK: - Claim File Picker Page (navigation, with camera/photo/file options)

struct ClaimFilePickerPage: View {
    var onFilePicked: (String, Data) -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var showImagePicker = false
    @State private var navigateToCamera = false
    @State private var showDocPicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedFileName: String?
    @State private var selectedFileURL: URL?

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.up.doc.fill").font(.system(size: 48)).foregroundColor(.gold)
                        Text("Upload Receipt").font(.system(size: 20, weight: .bold))
                        Text("Select a receipt photo or PDF").font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.bgSurface).cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8])).foregroundColor(Color.gold.opacity(0.4)))
                    )

                    VStack(spacing: 12) {
                        pickerBtn(icon: "camera.fill", title: "Take Photo", sub: "Capture receipt with camera") { navigateToCamera = true }
                        pickerBtn(icon: "photo.fill", title: "Photo Library", sub: "Choose from saved photos") { showImagePicker = true }
                        pickerBtn(icon: "doc.fill", title: "Choose File", sub: "Upload PDF or document") { showDocPicker = true }
                    }

                    HStack(spacing: 8) {
                        ForEach(["JPG", "PNG", "HEIC", "PDF"], id: \.self) { f in
                            Text(f).font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray).padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.bgRaised).cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.borderColor, lineWidth: 1))
                        }
                    }
                }.padding(.horizontal, 20).padding(.top, 20)
            }
        }
        .navigationBarTitle(Text("Upload Receipt"), displayMode: .inline)
        .sheet(isPresented: $showImagePicker) {
            ClaimImagePickerView { img, name in
                if let data = img.jpegData(compressionQuality: 0.8) {
                    onFilePicked(name, data); presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .sheet(isPresented: $showDocPicker) {
            ClaimDocPickerView { name, data in
                onFilePicked(name, data); presentationMode.wrappedValue.dismiss()
            }
        }
        .background(
            NavigationLink(destination: ClaimCameraView { img, name in
                if let data = img.jpegData(compressionQuality: 0.8) {
                    onFilePicked(name, data); presentationMode.wrappedValue.dismiss()
                }
            }, isActive: $navigateToCamera) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
    }

    private func pickerBtn(icon: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(.goldDark)
                    .frame(width: 36, height: 36).background(Color.gold.opacity(0.15)).cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Text(sub).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.gray)
            }.padding(14).background(Color.bgSurface).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(BorderlessButtonStyle())
    }
}

// MARK: - UIKit Wrappers for Claim File Picker

struct ClaimImagePickerView: UIViewControllerRepresentable {
    var onPick: (UIImage, String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .photoLibrary; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ClaimImagePickerView; init(_ p: ClaimImagePickerView) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onPick(img, (info[.imageURL] as? URL)?.lastPathComponent ?? "receipt.jpg") }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}

struct ClaimCameraView: UIViewControllerRepresentable {
    var onPick: (UIImage, String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ClaimCameraView; init(_ p: ClaimCameraView) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onPick(img, "photo.jpg") }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}

struct ClaimDocPickerView: UIViewControllerRepresentable {
    var onPick: (String, Data) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            p = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .jpeg, .png, .image], asCopy: true)
        } else {
            p = UIDocumentPickerViewController(documentTypes: ["public.pdf", "public.jpeg", "public.png"], in: .import)
        }
        p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: ClaimDocPickerView; init(_ p: ClaimDocPickerView) { parent = p }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            if let data = try? Data(contentsOf: url) { parent.onPick(url.lastPathComponent, data) }
            url.stopAccessingSecurityScopedResource()
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Sign-off List View
// ═══════════════════════════════════════════════════════════════════

struct SignOffListView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var expandedId: String?

    private var queue: [ClaimBatch] { appState.signOffQueue }
    private var escalatedCount: Int { queue.filter { $0.status.uppercased() == "ESCALATED" }.count }
    private var totalValue: Double { queue.reduce(0) { $0 + $1.totalGross } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header banner
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill").font(.system(size: 14)).foregroundColor(.goldDark)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Senior Sign-off").font(.system(size: 13, weight: .bold))
                        Text("Review escalated batches, confirm coding, and post to the ledger.").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gold.opacity(0.06)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.2), lineWidth: 1))

                // Stats cards
                HStack(spacing: 8) {
                    statCard(label: "AWAITING SIGN-OFF", value: "\(queue.count)", sub: "\(escalatedCount) escalated · 0 for review · 0 approved")
                    statCard(label: "TOTAL VALUE", value: FormatUtils.formatGBP(totalValue), sub: "\(queue.count) batches")
                    statCard(label: "ESCALATED", value: "\(escalatedCount)", sub: "Requires your attention")
                }
                .frame(height: 86)

                // Sign-off Queue header
                Text("Sign-off Queue").font(.system(size: 15, weight: .bold))

                if appState.isLoadingSignOffQueue && appState.signOffQueue.isEmpty {
                    LoaderView()
                } else if queue.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "checkmark.seal").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No claims awaiting sign-off").font(.system(size: 13)).foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: 480)
                } else {
                    ForEach(queue) { claim in
                        signOffCard(claim)
                    }
                }
            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 20)
        }
    }

    private func statCard(label: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(.primary).lineLimit(1).minimumScaleFactor(0.7)
            Text(sub).font(.system(size: 9)).foregroundColor(.gray).lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(10)
        .background(Color.bgSurface).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
    }

    private func signOffCard(_ claim: ClaimBatch) -> some View {
        let isExpanded = expandedId == claim.id
        let user = UsersData.byId[claim.userId]
        let escalator = claim.escalationReason != nil ? UsersData.byId[claim.assignedTo ?? ""] : nil

        return VStack(alignment: .leading, spacing: 0) {
            // Header: tap to expand
            Button(action: { expandedId = isExpanded ? nil : claim.id }) {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(.gray)
                    if let u = user {
                        ZStack {
                            Circle().fill(Color.gold.opacity(0.2)).frame(width: 32, height: 32)
                            Text(u.initials).font(.system(size: 11, weight: .bold)).foregroundColor(.goldDark)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user?.fullName ?? "—").font(.system(size: 14, weight: .bold))
                        Text("\(user?.displayDesignation ?? "") · \(claim.department)")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                        Text("#\(claim.batchReference) · \(FormatUtils.formatDateTime(claim.createdAt))")
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        let (fg, bg) = claimStatusColor(claim.status)
                        Text(claim.statusDisplay).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(bg).cornerRadius(3)
                        Text(FormatUtils.formatGBP(claim.totalGross))
                            .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        Text("\(claim.claimCount) receipt").font(.system(size: 9)).foregroundColor(.gray)
                    }
                }
                .padding(12).contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            // Expanded details
            if isExpanded {
                Divider()

                // Escalation note
                if let reason = claim.escalationReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note from \(escalator?.fullName ?? "Accounts") (\(escalator?.displayDesignation ?? "")):")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\"\(reason)\"").font(.system(size: 12)).italic()
                        if claim.updatedAt > 0 {
                            Text(FormatUtils.formatDateTime(claim.updatedAt)).font(.system(size: 10)).foregroundColor(.gray)
                        }
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.06))
                    .overlay(Rectangle().fill(Color.orange).frame(width: 3), alignment: .leading)
                }

                // Claims & Line Items
                VStack(alignment: .leading, spacing: 0) {
                    Text("CLAIMS & LINE ITEMS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 6)
                    Divider()
                    HStack {
                        Text("Total").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(FormatUtils.formatGBP(claim.totalGross))
                            .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    }.padding(.horizontal, 14).padding(.vertical, 8)
                }.background(Color.bgRaised.opacity(0.5))

                // Sign-off notes
                VStack(alignment: .leading, spacing: 4) {
                    Text("SENIOR SIGN-OFF NOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    Text("Confirm coding decisions and any notes for the audit trail…")
                        .font(.system(size: 11)).foregroundColor(.gray).italic()
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.bgSurface).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }.padding(14)

                // Action buttons
                HStack(spacing: 10) {
                    Button(action: {}) {
                        Text("← Return to Accounts").font(.system(size: 11, weight: .semibold)).foregroundColor(.orange)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())

                    Button(action: {}) {
                        Text("Approve & Post").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.green).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())
                }.padding(.horizontal, 14).padding(.bottom, 12)
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func claimStatusColor(_ s: String) -> (Color, Color) {
        switch s.uppercased() {
        case "ESCALATED": return (.orange, Color.orange.opacity(0.1))
        case "AWAITING_APPROVAL": return (.goldDark, Color.gold.opacity(0.15))
        case "POSTED": return (.green, Color.green.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Cash Reconciliation View
// ═══════════════════════════════════════════════════════════════════

struct CashDenom {
    let label: String; let value: Double; let type: String; let seed: Int
}

let denominations: [CashDenom] = [
    CashDenom(label: "£50 note", value: 50, type: "note", seed: 0),
    CashDenom(label: "£20 note", value: 20, type: "note", seed: 0),
    CashDenom(label: "£10 note", value: 10, type: "note", seed: 0),
    CashDenom(label: "£5 note", value: 5, type: "note", seed: 0),
    CashDenom(label: "£2 coin", value: 2, type: "coin", seed: 0),
    CashDenom(label: "£1 coin", value: 1, type: "coin", seed: 0),
    CashDenom(label: "50p", value: 0.5, type: "coin", seed: 0),
    CashDenom(label: "20p", value: 0.2, type: "coin", seed: 0),
    CashDenom(label: "10p", value: 0.1, type: "coin", seed: 0),
    CashDenom(label: "5p", value: 0.05, type: "coin", seed: 0),
    CashDenom(label: "2p", value: 0.02, type: "coin", seed: 0),
    CashDenom(label: "1p", value: 0.01, type: "coin", seed: 0),
]

struct ReconItem: Identifiable {
    let id = UUID()
    var desc: String = ""
    var ref: String = ""
    var type: String = "out" // "out", "in", "timing"
    var amount: String = ""

    var typeLabel: String {
        switch type {
        case "out": return "Paid out"
        case "in": return "Received"
        case "timing": return "Timing off"
        default: return "Paid out"
        }
    }
}

struct ReconciliationView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var quantities: [Int: Int] = [:]
    @State private var reconItems: [ReconItem] = [
        ReconItem(desc: "OOP claim paid out in cash — not yet entered in system", ref: "OOP-0022", type: "out", amount: "250.22"),
        ReconItem(desc: "Float advance to Fiona Castle — verbal, not yet raised", ref: "PC-PENDING", type: "out", amount: "150.00"),
    ]
    @State private var signOffNotes: String = ""
    @State private var signedOff = false

    private var activeFloats: [FloatRequest] { appState.activeFloats }
    private var bookBalance: Double { activeFloats.reduce(0) { $0 + $1.issuedFloat } }

    private var physicalTotal: Double {
        denominations.enumerated().reduce(0) { sum, item in
            sum + Double(quantities[item.offset] ?? 0) * item.element.value
        }
    }

    private var reconAdjustment: Double {
        reconItems.reduce(0) { sum, item in
            let amt = Double(item.amount) ?? 0
            switch item.type {
            case "out": return sum - amt
            case "in": return sum + amt
            case "timing": return sum - amt
            default: return sum - amt
            }
        }
    }
    private var adjustedBook: Double { bookBalance + reconAdjustment }
    private var variance: Double { physicalTotal - adjustedBook }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header banner
                HStack(spacing: 8) {
                    Image(systemName: "house.fill").font(.system(size: 14)).foregroundColor(.goldDark)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Cash Reconciliation").font(.system(size: 13, weight: .bold))
                        Text("Count physical cash and balance against the book.").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gold.opacity(0.06)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.2), lineWidth: 1))

                // Physical Cash Count
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Physical Cash Count").font(.system(size: 14, weight: .bold))
                        Spacer()
                        Text(FormatUtils.formatGBP(physicalTotal))
                            .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    }.padding(.horizontal, 14).padding(.vertical, 10)

                    Divider()

                    // Banknotes
                    Text("BANKNOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 4)

                    ForEach(denominations.indices.filter { denominations[$0].type == "note" }, id: \.self) { i in
                        denomRow(i)
                    }

                    Divider().padding(.horizontal, 14)

                    // Coins
                    Text("COINS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 4)

                    ForEach(denominations.indices.filter { denominations[$0].type == "coin" }, id: \.self) { i in
                        denomRow(i)
                    }
                }
                .background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // ── Reconciling Items ──
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Reconciling Items").font(.system(size: 14, weight: .bold))
                        Spacer()
                        Button(action: { reconItems.append(ReconItem()) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                                Text("Add Item").font(.system(size: 11, weight: .semibold))
                            }.foregroundColor(.goldDark)
                        }.buttonStyle(BorderlessButtonStyle())
                    }.padding(.horizontal, 14).padding(.vertical, 10)

                    Text("Items that have left or entered the safe but aren't yet in the system.")
                        .font(.system(size: 10)).foregroundColor(.gray)
                        .padding(.horizontal, 14).padding(.bottom, 8)

                    if reconItems.isEmpty {
                        Text("No reconciling items. Tap + Add Item to add.")
                            .font(.system(size: 12)).foregroundColor(.gray)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                    } else {
                        ForEach(reconItems) { item in
                            reconItemRow(item)
                            Divider().padding(.horizontal, 14)
                        }
                        // Total adjustment
                        HStack {
                            Text("Total adjustment to book balance").font(.system(size: 11)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(reconAdjustment >= 0 ? "" : "−")\(FormatUtils.formatGBP(abs(reconAdjustment)))")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(reconAdjustment == 0 ? .primary : .red)
                        }.padding(.horizontal, 14).padding(.vertical, 8)

                        Divider().padding(.horizontal, 14)

                        // Adjusted book balance
                        HStack {
                            Text("Adjusted book balance").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                            Text("(book + reconciling items)").font(.system(size: 9)).foregroundColor(.gray)
                            Spacer()
                            Text(FormatUtils.formatGBP(adjustedBook))
                                .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        }.padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.gold.opacity(0.06))
                    }
                }
                .background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // ── Reconciliation ──
                VStack(spacing: 0) {
                    Text("Reconciliation").font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 14).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                    reconRow("Book balance (float ledger)", FormatUtils.formatGBP(bookBalance), .primary)
                    Divider().padding(.leading, 14)
                    reconRow("Reconciling items (net)", "\(reconAdjustment >= 0 ? "" : "−")\(FormatUtils.formatGBP(abs(reconAdjustment)))", reconAdjustment == 0 ? .primary : .red)
                    Divider().padding(.leading, 14)
                    HStack {
                        Text("Adjusted book balance").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        Spacer()
                        Text(FormatUtils.formatGBP(adjustedBook)).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    }.padding(.horizontal, 14).padding(.vertical, 10).background(Color.gold.opacity(0.06))
                    Divider()
                    reconRow("Physical count", FormatUtils.formatGBP(physicalTotal), .primary)
                    Divider().padding(.leading, 14)
                    HStack {
                        Text("Variance").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(variance >= 0 ? "" : "−")\(FormatUtils.formatGBP(abs(variance)))\(variance < 0 ? " shortfall" : variance > 0 ? " surplus" : "")")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(variance == 0 ? .green : .red)
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                }
                .background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // Variance warning
                if variance != 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundColor(.red)
                        Text("Cash is \(FormatUtils.formatGBP(abs(variance))) \(variance < 0 ? "short of" : "over") adjusted book balance. Add any missing reconciling items or investigate.")
                            .font(.system(size: 11)).foregroundColor(.red)
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.06)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 1))
                }

                // Sign-off notes
                VStack(alignment: .leading, spacing: 4) {
                    Text("SIGN-OFF NOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    TextField("Notes will be attached to this period's reconciliation…", text: $signOffNotes)
                        .font(.system(size: 12)).padding(10).background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }

                // Active Float Balances
                Text("ACTIVE FLOAT BALANCES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)

                if activeFloats.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "banknote").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No active floats").font(.system(size: 13)).foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: 480)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("CREW MEMBER").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Spacer()
                            Text("ISSUED").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(width: 60, alignment: .trailing)
                            Text("BALANCE").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(width: 70, alignment: .trailing)
                        }.padding(.horizontal, 14).padding(.vertical, 8)
                        Divider()
                        ForEach(activeFloats) { f in
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(UsersData.byId[f.userId]?.fullName ?? "—").font(.system(size: 12, weight: .medium))
                                    Text("\(f.department) · \(f.statusDisplay)").font(.system(size: 10)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(FormatUtils.formatGBP(f.issuedFloat)).font(.system(size: 11, design: .monospaced)).frame(width: 60, alignment: .trailing)
                                Text(FormatUtils.formatGBP(f.remaining))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(f.remaining > 0 ? .goldDark : .green)
                                    .frame(width: 70, alignment: .trailing)
                            }.padding(.horizontal, 14).padding(.vertical, 8)
                            Divider().padding(.horizontal, 14)
                        }
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }

                // Sign off button
                Button(action: { signedOff = true }) {
                    Text(signedOff ? "Period Reconciliation Signed Off" : "Sign Off Period Reconciliation")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(signedOff ? .white : .black)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(signedOff ? Color.green : Color.gold).cornerRadius(10)
                }.buttonStyle(BorderlessButtonStyle()).disabled(signedOff)

            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 20)
        }
    }

    @State private var typeSheetForId: UUID?

    private func reconItemRow(_ item: ReconItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: Description + delete
            HStack {
                TextField("Description", text: reconItemBinding(item.id, \.desc))
                    .font(.system(size: 12)).padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                Button(action: { reconItems.removeAll { $0.id == item.id } }) {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundColor(.gray)
                }.buttonStyle(BorderlessButtonStyle())
            }
            // Row 2: Reference + Type + Amount
            HStack(spacing: 8) {
                TextField("Reference", text: reconItemBinding(item.id, \.ref))
                    .font(.system(size: 12, design: .monospaced)).padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))

                Button(action: { typeSheetForId = item.id }) {
                    HStack(spacing: 4) {
                        Text(item.typeLabel).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
                        Image(systemName: "chevron.down").font(.system(size: 8)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }
                .buttonStyle(BorderlessButtonStyle())
                .selectionActionSheet(
                    title: "Select Type",
                    isPresented: Binding(
                        get: { typeSheetForId == item.id },
                        set: { if !$0 { typeSheetForId = nil } }
                    ),
                    options: ["out", "in", "timing"],
                    isSelected: { $0 == item.type },
                    label: { key in
                        switch key {
                        case "out":    return "Paid out"
                        case "in":     return "Received"
                        case "timing": return "Timing off"
                        default:       return key
                        }
                    },
                    onSelect: { key in
                        if let idx = reconItems.firstIndex(where: { $0.id == item.id }) { reconItems[idx].type = key }
                    }
                )

                TextField("0.00", text: reconItemBinding(item.id, \.amount))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced)).keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing).padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    .frame(width: 80)
            }
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func reconItemBinding(_ id: UUID, _ kp: WritableKeyPath<ReconItem, String>) -> Binding<String> {
        Binding(
            get: { reconItems.first(where: { $0.id == id })?[keyPath: kp] ?? "" },
            set: { val in if let idx = reconItems.firstIndex(where: { $0.id == id }) { reconItems[idx][keyPath: kp] = val } }
        )
    }

    private func denomRow(_ i: Int) -> some View {
        let d = denominations[i]
        let qty = quantities[i] ?? 0
        let total = Double(qty) * d.value
        return HStack {
            Text(d.label).font(.system(size: 13))
            Spacer()
            HStack(spacing: 8) {
                Button(action: { if qty > 0 { quantities[i] = qty - 1 } }) {
                    Image(systemName: "minus.circle.fill").font(.system(size: 18)).foregroundColor(qty > 0 ? .goldDark : .gray.opacity(0.3))
                }.buttonStyle(BorderlessButtonStyle())
                Text("\(qty)").font(.system(size: 14, weight: .semibold, design: .monospaced)).frame(width: 30, alignment: .center)
                Button(action: { quantities[i] = qty + 1 }) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 18)).foregroundColor(.goldDark)
                }.buttonStyle(BorderlessButtonStyle())
            }
            Text(FormatUtils.formatGBP(total))
                .font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary).frame(width: 60, alignment: .trailing)
        }.padding(.horizontal, 14).padding(.vertical, 4)
    }

    private func reconRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(color)
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - OOP Sign-off List View
// ═══════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════
// MARK: - Payment Routing View (BACS + Payroll)
// ═══════════════════════════════════════════════════════════════════

struct PaymentRoutingView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var bacsGenerated = false
    @State private var showBacsAlert = false
    @State private var activeSection = "bacs"   // "bacs" | "payroll"

    private var routing: PaymentRoutingResponse { appState.paymentRouting }
    private var bacsBatches: [PaymentRoutingBatch]    { routing.bacsBatches }
    private var payrollBatches: [PaymentRoutingBatch] { routing.payrollBatches }
    private var bacsTotal: Double    { routing.stats.bacsReady }
    private var payrollTotal: Double { routing.stats.payrollTotal }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header banner
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.down.circle.fill").font(.system(size: 14)).foregroundColor(.goldDark)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payment Routing").font(.system(size: 13, weight: .bold))
                    Text("Approved BACS claims batched for export. Payroll claims auto-add to the payroll run on approval.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12).background(Color.gold.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.25), lineWidth: 1))
            .cornerRadius(8).padding(.horizontal, 16).padding(.top, 12)

            // Tappable section cards — mirrors the Approval Queue pattern
            HStack(spacing: 10) {
                Button(action: { activeSection = "bacs" }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "building.columns.fill").font(.system(size: 14)).foregroundColor(.goldDark)
                            Text("BACS Payments").font(.system(size: 13, weight: .bold)).lineLimit(1)
                        }
                        Text("\(bacsBatches.count) claims · \(FormatUtils.formatGBP(bacsTotal))")
                            .font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(12)
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(activeSection == "bacs" ? Color.goldDark : Color.borderColor, lineWidth: activeSection == "bacs" ? 2 : 1))
                }.buttonStyle(PlainButtonStyle())

                Button(action: { activeSection = "payroll" }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.plus").font(.system(size: 14)).foregroundColor(.goldDark)
                            Text("Payroll Additions").font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Text("\(payrollBatches.count) additions · \(FormatUtils.formatGBP(payrollTotal))")
                            .font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(12)
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(activeSection == "payroll" ? Color.goldDark : Color.borderColor, lineWidth: activeSection == "payroll" ? 2 : 1))
                }.buttonStyle(PlainButtonStyle())
            }
            .frame(height: 64)
            .padding(.horizontal, 16).padding(.top, 12)

            // Active section content
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if activeSection == "bacs" {
                        // Previous BACS Payments section card — icon header,
                        // badge, batch body, footer with total + Generate BACS.
                        sectionCard(
                            icon: "building.columns.fill",
                            title: "BACS Payments",
                            subtitle: "\(bacsBatches.count) claims · \(FormatUtils.formatGBP(bacsTotal))",
                            badge: bacsGenerated ? "Generated" : "Ready",
                            badgeColor: .green,
                            emptyText: "No BACS claims to process.",
                            batches: bacsBatches,
                            kind: .bacs,
                            footerValue: FormatUtils.formatGBP(bacsTotal),
                            footerSub: "\(Set(bacsBatches.map { $0.userId }).count) payees",
                            actionTitle: bacsGenerated ? "BACS File Ready" : "Generate BACS File",
                            actionEnabled: !bacsGenerated && !bacsBatches.isEmpty,
                            onAction: { generateBACS() }
                        )
                    } else {
                        // Previous Payroll Additions section card.
                        sectionCard(
                            icon: "calendar.badge.plus",
                            title: "Payroll Additions",
                            subtitle: "Auto-added to payroll run on approval",
                            badge: "Auto-routed",
                            badgeColor: .gray,
                            emptyText: "No payroll claims.",
                            batches: payrollBatches,
                            kind: .payroll,
                            footerValue: FormatUtils.formatGBP(payrollTotal),
                            footerSub: "\(payrollBatches.count) additions",
                            actionTitle: nil,
                            actionEnabled: false,
                            onAction: {}
                        )
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
            }
        }
        .background(Color.bgBase)
        .onAppear { appState.loadPaymentRouting() }
        .alert(isPresented: $showBacsAlert) {
            Alert(
                title: Text("BACS File Generated"),
                message: Text("\(bacsBatches.count) claim\(bacsBatches.count == 1 ? "" : "s") totaling \(FormatUtils.formatGBP(bacsTotal)) have been batched and are ready to upload to your bank."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Batch row

    private enum RoutingKind { case bacs, payroll }

    private func routingBatchRow(_ b: PaymentRoutingBatch, kind: RoutingKind) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("#\(b.batchReference.isEmpty ? String(b.id.suffix(6)).uppercased() : b.batchReference)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    let (fg, bg): (Color, Color) = kind == .bacs
                        ? (.green, Color.green.opacity(0.12))
                        : (Color(red: 0.2, green: 0.5, blue: 0.85), Color.blue.opacity(0.1))
                    Text(kind == .bacs ? "BACS" : "PAYROLL")
                        .font(.system(size: 8, weight: .bold)).foregroundColor(fg)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(bg).cornerRadius(3)
                }
                Text(b.holderName).font(.system(size: 12, weight: .medium))
                Text("\(b.claimCount) claim\(b.claimCount == 1 ? "" : "s")")
                    .font(.system(size: 10)).foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(FormatUtils.formatGBP(b.totalGross))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                if let pa = b.postedAt, pa > 0 {
                    Text(FormatUtils.formatTimestamp(pa))
                        .font(.system(size: 9)).foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func generateBACS() {
        guard !bacsBatches.isEmpty else { return }
        bacsGenerated = true
        showBacsAlert = true
    }

    // MARK: - Section card (restored from previous design)
    // Renders the full card: gold-circle icon header + badge, body (batch
    // list or empty state), footer with total + optional action button.

    private func sectionCard(icon: String, title: String, subtitle: String,
                             badge: String, badgeColor: Color,
                             emptyText: String,
                             batches: [PaymentRoutingBatch],
                             kind: RoutingKind,
                             footerValue: String, footerSub: String,
                             actionTitle: String?, actionEnabled: Bool,
                             onAction: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(.goldDark)
                    .frame(width: 28, height: 28).background(Color.gold.opacity(0.12)).cornerRadius(6)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .bold))
                    Text(subtitle).font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
                Text(badge).font(.system(size: 9, weight: .bold)).foregroundColor(badgeColor)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(badgeColor.opacity(0.12)).cornerRadius(4)
            }.padding(12)

            Divider()

            // Body — either a list of batch rows or the empty state
            if batches.isEmpty {
                Text(emptyText).font(.system(size: 11)).foregroundColor(.gray)
                    .frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(batches.enumerated()), id: \.element.id) { idx, b in
                        routingBatchRow(b, kind: kind)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                        if idx < batches.count - 1 { Divider().padding(.leading, 12) }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(footerValue).font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text(footerSub).font(.system(size: 9)).foregroundColor(.gray)
                }
                Spacer()
                if let actionTitle = actionTitle {
                    Button(action: onAction) {
                        Text(actionTitle).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(actionEnabled ? Color.goldDark : Color.gray.opacity(0.4))
                            .cornerRadius(6)
                    }.disabled(!actionEnabled).buttonStyle(PlainButtonStyle())
                }
            }.padding(12)
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

struct OOPSignOffListView: View {
    @EnvironmentObject var appState: POViewModel

    private var claims: [ClaimBatch] {
        appState.signOffQueue.filter { $0.isOutOfPocket }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if appState.isLoadingSignOffQueue && appState.signOffQueue.isEmpty {
                    LoaderView()
                } else if claims.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "checkmark.seal").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No OOP claims awaiting sign-off").font(.system(size: 13)).foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: 480)
                } else {
                    ForEach(claims) { claim in ClaimRow(claim: claim) }
                }
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Audit Queue Page (chip filters: All, Petty Cash, Out of Pocket)
// ═══════════════════════════════════════════════════════════════════

struct AuditQueuePage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var activeFilter = "All"
    @State private var showFilterSheet = false

    private var auditClaims: [ClaimBatch] { appState.auditQueue }

    private var filtered: [ClaimBatch] {
        switch activeFilter {
        case "Petty Cash": return auditClaims.filter { $0.isPettyCash }
        case "Out of Pocket": return auditClaims.filter { $0.isOutOfPocket }
        default: return auditClaims
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header banner
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill").font(.system(size: 14)).foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.86))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Audit Queue — \(appState.currentUser?.fullName ?? "")")
                        .font(.system(size: 13, weight: .bold))
                    Text("Verify receipts and forward for approval.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12).background(Color(red: 0.2, green: 0.6, blue: 0.86).opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.2, green: 0.6, blue: 0.86).opacity(0.2), lineWidth: 1))
            .cornerRadius(8).padding(.horizontal, 16).padding(.top, 12)

            // Filter dropdown + pending count
            HStack(spacing: 8) {
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                        Text(activeFilter).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8).background(Color.bgSurface).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                .selectionActionSheet(
                    title: "Filter by Type",
                    isPresented: $showFilterSheet,
                    options: ["All", "Petty Cash", "Out of Pocket"],
                    isSelected: { $0 == activeFilter },
                    label: { $0 },
                    onSelect: { activeFilter = $0 }
                )
                Spacer()
                Text("\(filtered.count) PENDING").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            // Claims list
            ScrollView {
                VStack(spacing: 10) {
                    if appState.isLoadingAuditQueue && appState.auditQueue.isEmpty {
                        LoaderView()
                    } else if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark.seal").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("No batches awaiting audit.").font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 480)
                    } else {
                        ForEach(filtered) { claim in ClaimRow(claim: claim) }
                    }
                }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 20)
            }
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Audit Queue"), displayMode: .inline)
        .onAppear { appState.loadAuditQueue() }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Approval Queue Page (two sections: Float Requests + Receipt Batches)
// ═══════════════════════════════════════════════════════════════════

struct ApprovalQueuePage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var activeSection = "floats" // "floats" or "batches"
    @State private var batchFilter = "All"
    @State private var showBatchFilterSheet = false

    private var pendingFloats: [FloatRequest] { appState.approvalQueueFloats }
    private var pendingClaims: [ClaimBatch] { appState.approvalQueueClaims }
    private var filteredClaims: [ClaimBatch] {
        switch batchFilter {
        case "Petty Cash": return pendingClaims.filter { $0.isPettyCash }
        case "Out of Pocket": return pendingClaims.filter { $0.isOutOfPocket }
        default: return pendingClaims
        }
    }

    /// How many approval tiers this float needs, for the "Pending X/Y" badge.
    /// Falls back to the number of approvals + 1 when the tier config hasn't
    /// loaded yet, with a minimum of 2 so we never show "0/0".
    fileprivate func totalTiers(for f: FloatRequest) -> Int {
        // Most projects use 2-tier approval on floats. If your model already
        // carries a `totalTiers` field per float, prefer that.
        max(2, f.approvals.count + 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header banner
            HStack(spacing: 8) {
                Image(systemName: "person.badge.shield.checkmark.fill").font(.system(size: 14)).foregroundColor(.goldDark)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Approval Queue — \(appState.currentUser?.fullName ?? "")")
                        .font(.system(size: 13, weight: .bold))
                    Text("Review and approve or reject float requests and receipt batches.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12).background(Color.gold.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.2), lineWidth: 1))
            .cornerRadius(8).padding(.horizontal, 16).padding(.top, 12)

            // Tappable section cards
            HStack(spacing: 10) {
                Button(action: { activeSection = "floats" }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath").font(.system(size: 14)).foregroundColor(.goldDark)
                            Text("Float Requests").font(.system(size: 13, weight: .bold)).lineLimit(1)
                        }
                        Text("\(pendingFloats.count) pending approval").font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(12)
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(activeSection == "floats" ? Color.goldDark : Color.borderColor, lineWidth: activeSection == "floats" ? 2 : 1))
                }.buttonStyle(PlainButtonStyle())

                Button(action: { activeSection = "batches" }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc").font(.system(size: 14)).foregroundColor(.goldDark)
                            Text("Receipt Batches & OOP").font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Text("\(pendingClaims.count) items").font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(12)
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(activeSection == "batches" ? Color.goldDark : Color.borderColor, lineWidth: activeSection == "batches" ? 2 : 1))
                }.buttonStyle(PlainButtonStyle())
            }
            .frame(height: 64)
            .padding(.horizontal, 16).padding(.top, 12)

            // Section content
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if activeSection == "floats" {
                        HStack {
                            Text("Float Requests").font(.system(size: 14, weight: .bold))
                            Spacer()
                            Text("\(pendingFloats.count) PENDING").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
                        }

                        if pendingFloats.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "banknote").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No float requests awaiting your approval.").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
                        } else {
                            ForEach(pendingFloats) { f in
                                NavigationLink(destination: FloatApprovalDetailPage(float: f).environmentObject(appState)) {
                                    ApprovalFloatRow(float: f, totalTiers: totalTiers(for: f))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Button(action: { showBatchFilterSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                                    Text(batchFilter).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8).background(Color.bgSurface).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .selectionActionSheet(
                                title: "Filter by Type",
                                isPresented: $showBatchFilterSheet,
                                options: ["All", "Petty Cash", "Out of Pocket"],
                                isSelected: { $0 == batchFilter },
                                label: { $0 },
                                onSelect: { batchFilter = $0 }
                            )
                            Spacer()
                            Text("\(filteredClaims.count) PENDING").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
                        }

                        if appState.isLoadingApprovalClaims && appState.approvalQueueClaims.isEmpty {
                            LoaderView()
                        } else if filteredClaims.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No batches awaiting approval.").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
                        } else {
                            ForEach(filteredClaims) { claim in
                                NavigationLink(destination: ClaimApprovalDetailPage(claim: claim).environmentObject(appState)) {
                                    ApprovalClaimRow(claim: claim)
                                }.buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
            }
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Approval Queue"), displayMode: .inline)
        .onAppear {
            appState.loadApprovalQueueFloats()
            appState.loadApprovalQueueClaims()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Approval Queue — compact float row
// Matches the web screenshot: avatar + name + role + ref/date on the left;
// pending badge + amount on the right. No ISSUED/SPENT/BALANCE (the float
// hasn't been issued yet when it's in the approval queue).
// ═══════════════════════════════════════════════════════════════════

struct ApprovalFloatRow: View {
    let float: FloatRequest
    let totalTiers: Int

    private var user: AppUser? { UsersData.byId[float.userId] }

    private var roleLine: String {
        let role = user?.displayDesignation ?? ""
        let dept = float.department.isEmpty ? (user?.displayDepartment ?? "") : float.department
        switch (role.isEmpty, dept.isEmpty) {
        case (false, false): return "\(role) · \(dept)"
        case (false, true):  return role
        case (true, false):  return dept
        default:             return ""
        }
    }

    private var submittedLine: String {
        let ref = "#\(float.reqNumber)"
        let stamp = FormatUtils.formatDateTime(float.createdAt)
        return "\(ref) · \(stamp)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Avatar initials
            ZStack {
                Circle().fill(Color.gold.opacity(0.18)).frame(width: 36, height: 36)
                Text(user?.initials ?? "—")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.goldDark)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user?.fullName ?? "Unknown")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if !roleLine.isEmpty {
                    Text(roleLine)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(submittedLine)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            // Right: Pending badge + Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text("Pending \(float.approvals.count)/\(totalTiers)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.goldDark)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.gold.opacity(0.15))
                    .cornerRadius(4)
                Text(FormatUtils.formatGBP(float.reqAmount))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.goldDark)
            }
        }
        .padding(12)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Approval Queue — compact claim batch row
// Mirrors the web design: avatar + name + role + ref/date on the left;
// "Awaiting Approval" badge + amount + "N receipts" on the right.
// ═══════════════════════════════════════════════════════════════════

struct ApprovalClaimRow: View {
    let claim: ClaimBatch

    private var user: AppUser? { UsersData.byId[claim.userId] }

    private var roleLine: String {
        let role = user?.displayDesignation ?? ""
        let dept = claim.department.isEmpty ? (user?.displayDepartment ?? "") : claim.department
        switch (role.isEmpty, dept.isEmpty) {
        case (false, false): return "\(role) · \(dept)"
        case (false, true):  return role
        case (true, false):  return dept
        default:             return ""
        }
    }

    private var submittedLine: String {
        let ref = claim.batchReference.isEmpty ? "—" : "#\(claim.batchReference)"
        let stamp = FormatUtils.formatDateTime(claim.createdAt)
        return "\(ref) · \(stamp)"
    }

    private var statusBadge: (label: String, fg: Color, bg: Color) {
        switch claim.status.uppercased() {
        case "CODING", "CODED":           return ("Awaiting Coding",    .blue,     Color.blue.opacity(0.1))
        case "IN_AUDIT":                  return ("Awaiting Audit",     .purple,   Color.purple.opacity(0.1))
        case "AWAITING_APPROVAL":         return ("Awaiting Approval",  .goldDark, Color.gold.opacity(0.15))
        case "ACCT_OVERRIDE":             return ("Override",           .green,    Color.green.opacity(0.1))
        case "READY_TO_POST":             return ("Ready to Post",      .blue,     Color.blue.opacity(0.1))
        case "POSTED":                    return ("Posted",             .green,    Color.green.opacity(0.1))
        case "REJECTED":                  return ("Rejected",           .red,      Color.red.opacity(0.1))
        case "ESCALATED":                 return ("Escalated",          .orange,   Color.orange.opacity(0.1))
        default:                          return (claim.statusDisplay,  .goldDark, Color.gold.opacity(0.15))
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Avatar initials — pink/rose tint to match the screenshot
            ZStack {
                Circle()
                    .fill(Color(red: 0.98, green: 0.83, blue: 0.80))
                    .frame(width: 36, height: 36)
                Text(user?.initials ?? "—")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.78, green: 0.30, blue: 0.33))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user?.fullName ?? "Unknown")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if !roleLine.isEmpty {
                    Text(roleLine)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(submittedLine)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            // Right: status badge + amount + receipts count
            VStack(alignment: .trailing, spacing: 4) {
                let s = statusBadge
                Text(s.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(s.fg)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(s.bg)
                    .cornerRadius(4)
                Text(FormatUtils.formatGBP(claim.totalGross))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.goldDark)
                if claim.claimCount > 0 {
                    Text("\(claim.claimCount) receipt\(claim.claimCount == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Claim Approval Detail Page
// Full-page detail for a receipt batch in the approval queue — mirrors
// the FloatApprovalDetailPage layout: header (name + role + date +
// status), 2-column grid of details, notes panel, approval progress,
// and a role-aware action footer (Override for accountants, Approve/
// Reject for approvers).
// ═══════════════════════════════════════════════════════════════════

struct ClaimApprovalDetailPage: View {
    let claim: ClaimBatch
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var actioning = false
    @State private var showRejectSheet = false
    @State private var rejectReason = ""

    private var isAccountant: Bool { appState.currentUser?.isAccountant == true }
    private var isApprover: Bool { appState.cashMeta?.is_approver == true }
    private var canAct: Bool {
        claim.status.uppercased() == "AWAITING_APPROVAL" && (isApprover || isAccountant)
    }
    private var totalApprovalTiers: Int { 2 }
    private var approvalsCount: Int { 0 } // ClaimBatch doesn't carry an approvals[] list

    private var user: AppUser? { UsersData.byId[claim.userId] }

    private var roleLine: String {
        let role = user?.displayDesignation ?? ""
        let dept = claim.department.isEmpty ? (user?.displayDepartment ?? "") : claim.department
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
        return claim.expenseType.isEmpty ? "—" : claim.expenseType.uppercased()
    }

    private var categoryLabel: String {
        if claim.category.isEmpty { return "—" }
        if let m = claimCategories.first(where: { $0.0 == claim.category }) { return m.1 }
        return claim.category.capitalized
    }

    private var settlementLabel: String {
        let s = claim.settlementType.lowercased()
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
        .navigationBarTitle(Text("\(claim.batchReference) — Receipt Batch"), displayMode: .inline)
        .sheet(isPresented: $showRejectSheet) { rejectSheet }
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
                Text(FormatUtils.formatDateTime(claim.createdAt))
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
        switch claim.status.uppercased() {
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
                gridCell("TOTAL GROSS", FormatUtils.formatGBP(claim.totalGross), valueColor: .goldDark, mono: true)
                gridCell("TOTAL NET", FormatUtils.formatGBP(claim.totalNet), mono: true)
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("VAT", FormatUtils.formatGBP(claim.totalVat), mono: true)
                gridCell("SETTLEMENT", settlementLabel)
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("TYPE", typeLabel)
                gridCell("CATEGORY", categoryLabel)
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("COST CODE", claim.costCode.isEmpty ? "—" : claim.costCode.uppercased())
                gridCell("RECEIPTS", "\(claim.claimCount)")
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("BATCH REF", claim.batchReference.isEmpty ? "—" : "#\(claim.batchReference)", mono: true)
                gridCell("DEPARTMENT", claim.department.isEmpty ? "—" : claim.department)
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
            if !claim.codingDescription.isEmpty { return claim.codingDescription }
            if !claim.notes.isEmpty { return claim.notes }
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
            switch claim.status.uppercased() {
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
    @ViewBuilder
    private var actionFooter: some View {
        Group {
            if isAccountant {
                HStack {
                    Spacer()
                    Button(action: overrideBatch) {
                        HStack(spacing: 6) {
                            if actioning {
                                ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                            }
                            Text(actioning ? "Overriding…" : "Override")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 28).padding(.vertical, 12)
                        .background(Color.gold).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
                }
            } else {
                HStack(spacing: 10) {
                    Button(action: { showRejectSheet = true }) {
                        Text("Reject").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.red).cornerRadius(10)
                    }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
                    Button(action: approveBatch) {
                        HStack(spacing: 6) {
                            if actioning { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                            Text(actioning ? "Approving…" : "Approve").font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.green).cornerRadius(10)
                    }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
                }
            }
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
    // Claim-batch approval endpoints aren't wired in the current API layer;
    // these handlers are placeholders that flip the loader, pop the page,
    // and refresh the approval queue so the list updates when the backend
    // routes are added later.
    private func approveBatch() {
        actioning = true
        print("⚠️ approveBatch: no endpoint wired yet for batch \(claim.id)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            actioning = false
            appState.loadApprovalQueueClaims()
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func rejectBatch(reason: String) {
        actioning = true
        print("⚠️ rejectBatch(\(reason)): no endpoint wired yet for batch \(claim.id)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            actioning = false
            appState.loadApprovalQueueClaims()
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func overrideBatch() {
        actioning = true
        print("⚠️ overrideBatch: no endpoint wired yet for batch \(claim.id)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            actioning = false
            appState.loadApprovalQueueClaims()
            presentationMode.wrappedValue.dismiss()
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

struct FloatRequestFormView: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var reqAmount = ""
    @State private var startDate: Date?
    @State private var howLongMode: String = ""       // "" | "run_of_show" | "days"
    @State private var durationDays: String = ""
    @State private var collectionMethod = "production_office"
    @State private var collectDate: Date?
    @State private var collectTime: Date?
    @State private var purpose = ""
    @State private var submitting = false
    @State private var submitted = false
    @State private var submitError: String?
    @State private var showHowLongSheet = false
    @State private var showCollectionSheet = false

    private let howLongOptions: [(String, String)] = [
        ("run_of_show", "Run of Show"),
        ("days", "Days")
    ]

    private var howLongDisplay: String {
        if howLongMode.isEmpty { return "— Select —" }
        return howLongOptions.first { $0.0 == howLongMode }?.1 ?? "— Select —"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header banner
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle").font(.system(size: 14)).foregroundColor(.goldDark)
                    Text("Crew Portal — \(appState.currentUser?.fullName ?? "") (\(appState.currentUser?.displayDepartment ?? ""))")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.goldDark)
                    Text("· Requesting a new petty cash float.").font(.system(size: 11)).foregroundColor(.secondary)
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gold.opacity(0.06)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.2), lineWidth: 1))

                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Request a Petty Cash Float").font(.system(size: 18, weight: .bold))
                    Text("Float requests are reviewed by the production accountant. You'll receive a notification once approved and cash is ready to collect.")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }

                // Float Details form
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Float Details").font(.system(size: 15, weight: .bold))
                        Spacer()
                        Text("NEW REQUEST").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
                    }

                    // User + Department (read-only)
                    HStack(alignment: .top, spacing: 10) {
                        formReadOnly("USER *", appState.currentUser?.fullName ?? "—")
                            .frame(maxWidth: .infinity)
                        formReadOnly("DEPARTMENT *", appState.currentUser?.displayDepartment ?? "—")
                            .frame(maxWidth: .infinity)
                    }
                    Text("Pre-filled from your Zillit profile").font(.system(size: 10)).foregroundColor(.gray)

                    // Requested Amount + Start Date
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            labelRequired("REQUESTED AMOUNT")
                            TextField("£0.00", text: $reqAmount)
                                .font(.system(size: 14, design: .monospaced)).keyboardType(.decimalPad)
                                .padding(.horizontal, 10)
                                .frame(height: 40)
                                .background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            Text("Max single float: £500 · your dept limit: £400")
                                .font(.system(size: 9)).foregroundColor(.gray)
                                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("START DATE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            datePickerCell(date: $startDate)
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // How Long (Run of Show / Days)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HOW LONG").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        HStack(spacing: 10) {
                            Button(action: { showHowLongSheet = true }) {
                                HStack {
                                    Text(howLongDisplay)
                                        .font(.system(size: 14))
                                        .foregroundColor(howLongMode.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                                }
                                .padding(10).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .frame(maxWidth: .infinity)
                            .selectionActionSheet(
                                title: "How Long",
                                isPresented: $showHowLongSheet,
                                options: howLongOptions.map { $0.0 },
                                isSelected: { $0 == howLongMode },
                                label: { key in howLongOptions.first { $0.0 == key }?.1 ?? key },
                                onSelect: { howLongMode = $0 }
                            )

                            if howLongMode == "days" {
                                TextField("e.g. 7", text: $durationDays)
                                    .font(.system(size: 14, design: .monospaced)).keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .padding(10).background(Color.bgRaised).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                                    .frame(width: 90)
                            }
                        }
                        Text("Run of Show = open until production wraps")
                            .font(.system(size: 9)).foregroundColor(.gray)
                    }

                    // Preferred Collection Method
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PREFERRED COLLECTION METHOD").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        Button(action: { showCollectionSheet = true }) {
                            HStack {
                                Text(collectionOptions.first { $0.0 == collectionMethod }?.1 ?? "Select")
                                    .font(.system(size: 14)).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                            }
                            .padding(10).background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .frame(maxWidth: .infinity)
                        .selectionActionSheet(
                            title: "Collection Method",
                            isPresented: $showCollectionSheet,
                            options: collectionOptions.map { $0.0 },
                            isSelected: { $0 == collectionMethod },
                            label: { key in collectionOptions.first { $0.0 == key }?.1 ?? key },
                            onSelect: { collectionMethod = $0 }
                        )
                    }

                    // Collect Date + Collect Time
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COLLECT DATE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            datePickerCell(date: $collectDate)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("COLLECT TIME").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            timePickerCell(time: $collectTime)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Purpose / Reason
                    VStack(alignment: .leading, spacing: 4) {
                        labelRequired("PURPOSE/REASON")
                        MultilineTextView(text: $purpose, placeholder: "Please be specific. Vague descriptions may delay approval.")
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(Color.bgRaised)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        Text("Please be specific. Vague descriptions may delay approval.")
                            .font(.system(size: 9)).foregroundColor(.gray)
                    }
                }
                .padding(14).background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // Info
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                    Text("You must retain all original receipts. Submit via the Zillit portal within 48 hours of each purchase. Unreceipted items cannot be reimbursed and will be deducted from your float.")
                        .font(.system(size: 11)).foregroundColor(.goldDark)
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gold.opacity(0.06)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.2), lineWidth: 1))

                // Error
                if let err = submitError {
                    Text(err).font(.system(size: 11)).foregroundColor(.red)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.06)).cornerRadius(8)
                }

                // Submit button (full-width)
                Button(action: submitFloat) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(submitted ? "Submitted" : submitting ? "Submitting..." : "Submit Float Request")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(submitted ? Color.green : Color.orange).cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(submitting || submitted)

            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 20)
        }
        .onAppear {
            // Fetch the float request form template so dynamic fields reflect the
            // latest server configuration (GET /form-templates?module=float_requests).
            appState.loadFloatFormTemplate()
        }
    }

    private func formReadOnly(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(.system(size: 14)).padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    /// Label with a small red asterisk to indicate a required field.
    @ViewBuilder
    private func labelRequired(_ text: String) -> some View {
        HStack(spacing: 2) {
            Text(text).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text("*").font(.system(size: 9, weight: .bold)).foregroundColor(.red)
        }
    }

    /// Inline date picker cell — placeholder "dd/mm/yyyy" when unset, native picker when set.
    /// Uses a fixed 40pt height so it vertically aligns with adjacent TextField cells.
    @ViewBuilder
    private func datePickerCell(date: Binding<Date?>) -> some View {
        if date.wrappedValue != nil {
            HStack(spacing: 6) {
                DatePicker("", selection: Binding(
                    get: { date.wrappedValue ?? Date() },
                    set: { date.wrappedValue = $0 }
                ), displayedComponents: .date).labelsHidden()
                Spacer(minLength: 0)
                Button(action: { date.wrappedValue = nil }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.gray)
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(Color.bgRaised).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        } else {
            Button(action: { date.wrappedValue = Date() }) {
                HStack {
                    Text("dd/mm/yyyy").font(.system(size: 14)).foregroundColor(.gray)
                    Spacer()
                    Image(systemName: "calendar").font(.system(size: 12)).foregroundColor(.goldDark)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }.buttonStyle(BorderlessButtonStyle())
        }
    }

    /// Inline time picker cell — placeholder "--:-- --" when unset.
    @ViewBuilder
    private func timePickerCell(time: Binding<Date?>) -> some View {
        if time.wrappedValue != nil {
            HStack(spacing: 6) {
                DatePicker("", selection: Binding(
                    get: { time.wrappedValue ?? Date() },
                    set: { time.wrappedValue = $0 }
                ), displayedComponents: .hourAndMinute).labelsHidden()
                Spacer(minLength: 0)
                Button(action: { time.wrappedValue = nil }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.gray)
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(Color.bgRaised).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        } else {
            Button(action: { time.wrappedValue = Date() }) {
                HStack {
                    Text("--:-- --").font(.system(size: 14)).foregroundColor(.gray)
                    Spacer()
                    Image(systemName: "clock").font(.system(size: 12)).foregroundColor(.goldDark)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }.buttonStyle(BorderlessButtonStyle())
        }
    }

    private func formatDate(_ d: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"; return df.string(from: d)
    }

    private func submitFloat() {
        guard let user = appState.currentUser else { return }
        guard let amount = Double(reqAmount), amount > 0 else { submitError = "Enter a valid amount"; return }
        guard !purpose.trimmingCharacters(in: .whitespaces).isEmpty else { submitError = "Purpose is required"; return }
        submitting = true; submitError = nil

        var body: [String: Any] = [
            "department_id": user.departmentId,
            "req_amount": amount,
            "collection_method": collectionMethod,
            "purpose": purpose
        ]

        // How long: either "run_of_show" (open-ended) or explicit day count
        if howLongMode == "run_of_show" {
            body["duration"] = "run_of_show"
        } else if howLongMode == "days", let days = Int(durationDays), days > 0 {
            body["duration"] = String(days)
        }

        if let d = startDate {
            body["start_date"] = Int64(d.timeIntervalSince1970 * 1000)
        }
        if let d = collectDate {
            body["collect_date"] = Int64(d.timeIntervalSince1970 * 1000)
        }
        if let t = collectTime {
            let df = DateFormatter(); df.dateFormat = "HH:mm"
            body["collect_time"] = df.string(from: t)
        }

        appState.submitFloatRequest(body) { success, error in
            submitting = false
            if success {
                submitted = true
                // Give the user a brief "Submitted" confirmation then pop back
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            else { submitError = error ?? "Failed to submit" }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Calendar Picker Sheet
// ═══════════════════════════════════════════════════════════════════

struct CalendarPickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                Spacer()
            }
            .padding(.top, 20)
            .navigationBarTitle(Text("Select Date"), displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Done") { isPresented = false }
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark)
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Batch Status Sheet
// ═══════════════════════════════════════════════════════════════════

struct BatchStatusSheet: View {
    let batch: ClaimBatch
    @Environment(\.presentationMode) var presentationMode

    private var user: AppUser? { UsersData.byId[batch.userId] }

    private let statusFlow: [(status: String, label: String, sub: String)] = [
        ("CODING", "Submitted", "Receipts submitted"),
        ("CODED", "Coordinator Coding", "Budget coding in progress"),
        ("IN_AUDIT", "Accounts Audit", "VAT · split · verify"),
        ("AWAITING_APPROVAL", "Approval", "Awaiting sign-off"),
        ("READY_TO_POST", "Post & Ledger", "Ready to post"),
        ("POSTED", "Settlement", "Complete"),
    ]

    private var currentStep: Int {
        let s = batch.status.uppercased()
        switch s {
        case "CODING": return 0
        case "CODED": return 1
        case "IN_AUDIT": return 2
        case "AWAITING_APPROVAL", "ACCT_OVERRIDE": return 3
        case "READY_TO_POST", "ESCALATED": return 4
        case "POSTED": return 5
        case "REJECTED": return -1
        default: return 0
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("#\(batch.batchReference)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                            Spacer()
                            let (fg, bg) = statusColor(batch.status)
                            Text(batch.statusDisplay).font(.system(size: 10, weight: .bold)).foregroundColor(fg)
                                .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
                        }
                        if let u = user {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle().fill(Color.gold.opacity(0.2)).frame(width: 32, height: 32)
                                    Text(u.initials).font(.system(size: 11, weight: .bold)).foregroundColor(.goldDark)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(u.fullName).font(.system(size: 14, weight: .semibold))
                                    Text("\(u.displayDesignation) · \(batch.department)").font(.system(size: 11)).foregroundColor(.secondary)
                                }
                            }
                        }
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("GROSS").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                                Text(FormatUtils.formatGBP(batch.totalGross)).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("NET").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                                Text(FormatUtils.formatGBP(batch.totalNet)).font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("VAT").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                                Text(FormatUtils.formatGBP(batch.totalVat)).font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(batch.claimCount) receipt\(batch.claimCount == 1 ? "" : "s")").font(.system(size: 10)).foregroundColor(.gray)
                        }
                    }
                    .padding(14).background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Status Flow
                    VStack(alignment: .leading, spacing: 0) {
                        Text("STATUS FLOW").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

                        ForEach(Array(statusFlow.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 12) {
                                // Timeline
                                VStack(spacing: 0) {
                                    if idx > 0 {
                                        Rectangle().fill(idx <= currentStep ? Color.green.opacity(0.4) : Color.gray.opacity(0.2))
                                            .frame(width: 2, height: 10)
                                    }
                                    ZStack {
                                        Circle()
                                            .fill(batch.status.uppercased() == "REJECTED" && idx == 0 ? .red :
                                                  idx < currentStep ? .green :
                                                  idx == currentStep ? .goldDark : Color.gray.opacity(0.25))
                                            .frame(width: 24, height: 24)
                                        if idx < currentStep {
                                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                        } else if idx == currentStep {
                                            Circle().fill(Color.white).frame(width: 8, height: 8)
                                        }
                                    }
                                    if idx < statusFlow.count - 1 {
                                        Rectangle().fill(idx < currentStep ? Color.green.opacity(0.4) : Color.gray.opacity(0.2))
                                            .frame(width: 2, height: 10)
                                    }
                                }

                                // Label
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.label).font(.system(size: 12, weight: idx == currentStep ? .bold : .medium))
                                        .foregroundColor(idx == currentStep ? .goldDark : idx < currentStep ? .green : .secondary)
                                    Text(step.sub).font(.system(size: 10)).foregroundColor(.gray)
                                }.padding(.vertical, 2)

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                        }

                        // Rejected banner
                        if batch.status.uppercased() == "REJECTED" {
                            HStack(spacing: 8) {
                                Circle().fill(Color.red).frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Rejected").font(.system(size: 12, weight: .bold)).foregroundColor(.red)
                                    Text("Resubmit required").font(.system(size: 10)).foregroundColor(.red.opacity(0.7))
                                }
                            }.padding(.horizontal, 14).padding(.vertical, 8)
                        }
                    }
                    .padding(.bottom, 8)
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Details
                    VStack(spacing: 0) {
                        detailRow("Type", batch.isPettyCash ? "Petty Cash" : "Out of Pocket")
                        Divider().padding(.leading, 14)
                        detailRow("Settlement", batch.settlementType.isEmpty ? "—" : batch.settlementType.replacingOccurrences(of: "_", with: " ").capitalized)
                        Divider().padding(.leading, 14)
                        detailRow("Department", batch.department)
                        Divider().padding(.leading, 14)
                        detailRow("Submitted", FormatUtils.formatDateTime(batch.createdAt))
                        if batch.updatedAt > 0 && batch.updatedAt != batch.createdAt {
                            Divider().padding(.leading, 14)
                            detailRow("Last Updated", FormatUtils.formatDateTime(batch.updatedAt))
                        }
                        if let postedAt = batch.postedAt, postedAt > 0 {
                            Divider().padding(.leading, 14)
                            detailRow("Posted", FormatUtils.formatDateTime(postedAt))
                        }
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Rejection
                    if let reason = batch.rejectionReason, !reason.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("REJECTION REASON").font(.system(size: 9, weight: .bold)).foregroundColor(.red).tracking(0.5)
                            Text(reason).font(.system(size: 12)).foregroundColor(.primary)
                            if let rejBy = batch.rejectedBy, !rejBy.isEmpty {
                                Text("By \(UsersData.byId[rejBy]?.fullName ?? rejBy)").font(.system(size: 10)).foregroundColor(.secondary)
                            }
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.06)).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 1))
                    }

                    // Escalation
                    if let reason = batch.escalationReason, !reason.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ESCALATION NOTE").font(.system(size: 9, weight: .bold)).foregroundColor(.orange).tracking(0.5)
                            Text(reason).font(.system(size: 12)).foregroundColor(.primary)
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.06)).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.2), lineWidth: 1))
                    }

                }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 20)
            }
            .background(Color.bgBase)
            .navigationBarTitle(Text("#\(batch.batchReference)"), displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Done") { presentationMode.wrappedValue.dismiss() }
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark)
            )
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold)).lineLimit(1)
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func statusColor(_ s: String) -> (Color, Color) {
        switch s.uppercased() {
        case "CODING", "CODED": return (.purple, Color.purple.opacity(0.1))
        case "IN_AUDIT": return (.blue, Color.blue.opacity(0.1))
        case "AWAITING_APPROVAL", "ACCT_OVERRIDE": return (.goldDark, Color.gold.opacity(0.15))
        case "READY_TO_POST": return (.blue, Color.blue.opacity(0.1))
        case "POSTED": return (.green, Color.green.opacity(0.1))
        case "REJECTED": return (.red, Color.red.opacity(0.1))
        case "ESCALATED": return (.orange, Color.orange.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Coding Queue List (tappable → detail page)
// ═══════════════════════════════════════════════════════════════════

struct CodingQueueListView: View {
    let claims: [ClaimBatch]
    var isLoading: Bool = false
    @EnvironmentObject var appState: POViewModel
    @State private var activeFilter = "All"
    @State private var showFilterSheet = false
    @State private var navigateToDetail = false
    @State private var selectedClaim: ClaimBatch?

    private var filtered: [ClaimBatch] {
        switch activeFilter {
        case "Petty Cash": return claims.filter { $0.isPettyCash }
        case "Out of Pocket": return claims.filter { $0.isOutOfPocket }
        default: return claims
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                        Text(activeFilter).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8).background(Color.bgSurface).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }
                .buttonStyle(BorderlessButtonStyle())
                .selectionActionSheet(
                    title: "Filter by Type",
                    isPresented: $showFilterSheet,
                    options: ["All", "Petty Cash", "Out of Pocket"],
                    isSelected: { $0 == activeFilter },
                    label: { $0 },
                    onSelect: { activeFilter = $0 }
                )
                Spacer()
                Text("\(filtered.count) PENDING").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 10) {
                    if isLoading && claims.isEmpty {
                        LoaderView()
                    } else if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("No claims in coding queue").font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 480)
                    } else {
                        ForEach(filtered) { claim in
                            Button(action: { selectedClaim = claim; navigateToDetail = true }) {
                                ClaimRow(claim: claim)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
        .background(
            NavigationLink(destination: Group {
                if let c = selectedClaim { CodingDetailPage(claim: c).environmentObject(appState) }
                else { EmptyView() }
            }, isActive: $navigateToDetail) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Coding Detail Page
// ═══════════════════════════════════════════════════════════════════

struct CodingDetailPage: View {
    let claim: ClaimBatch
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var nominalCode = ""
    @State private var vatTreatment = "standard_20"
    @State private var codingNotes = ""
    @State private var saving = false
    @State private var forwarding = false
    @State private var showError: String?

    private var user: AppUser? { UsersData.byId[claim.userId] }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("#\(claim.batchReference)").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                            Spacer()
                            Text(claim.statusDisplay).font(.system(size: 10, weight: .bold)).foregroundColor(.purple)
                                .padding(.horizontal, 8).padding(.vertical, 3).background(Color.purple.opacity(0.1)).cornerRadius(4)
                        }
                        if let u = user {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle().fill(Color.gold.opacity(0.2)).frame(width: 32, height: 32)
                                    Text(u.initials).font(.system(size: 11, weight: .bold)).foregroundColor(.goldDark)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(u.fullName).font(.system(size: 14, weight: .semibold))
                                    Text("\(u.displayDesignation) · \(claim.department)").font(.system(size: 11)).foregroundColor(.secondary)
                                }
                            }
                        }
                        HStack(spacing: 6) {
                            Text(claim.isPettyCash ? "Petty Cash" : "Out of Pocket")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(claim.isPettyCash ? Color(red: 0.2, green: 0.7, blue: 0.45) : .purple)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background((claim.isPettyCash ? Color(red: 0.2, green: 0.7, blue: 0.45) : Color.purple).opacity(0.1)).cornerRadius(3)
                            Text("Submitted \(FormatUtils.formatDateTime(claim.createdAt))").font(.system(size: 10)).foregroundColor(.gray)
                        }
                    }
                    .padding(14).background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Amounts
                    VStack(spacing: 0) {
                        codingAmtRow("Gross Total", FormatUtils.formatGBP(claim.totalGross), .primary)
                        Divider().padding(.leading, 14)
                        codingAmtRow("Net", FormatUtils.formatGBP(claim.totalNet), .secondary)
                        Divider().padding(.leading, 14)
                        codingAmtRow("VAT", FormatUtils.formatGBP(claim.totalVat), .secondary)
                        Divider().padding(.leading, 14)
                        codingAmtRow("Items", "\(claim.claimCount) receipt\(claim.claimCount == 1 ? "" : "s")", .secondary)
                        if !claim.settlementType.isEmpty {
                            Divider().padding(.leading, 14)
                            codingAmtRow("Settlement", claim.settlementType.replacingOccurrences(of: "_", with: " ").capitalized, .secondary)
                        }
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Budget Coding
                    VStack(alignment: .leading, spacing: 12) {
                        Text("BUDGET CODING").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOMINAL / COST CODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            TextField("e.g. ART-4100", text: $nominalCode)
                                .font(.system(size: 14, design: .monospaced)).padding(10)
                                .background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VAT TREATMENT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Text(VATHelpers.vatLabel(vatTreatment)).font(.system(size: 14))
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CODING NOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            TextField("Notes for accounts team…", text: $codingNotes)
                                .font(.system(size: 13)).padding(10)
                                .background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }
                    }
                    .padding(14).background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    if !claim.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SUBMITTER NOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                            Text(claim.notes).font(.system(size: 13))
                        }
                        .padding(14).background(Color.bgSurface).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    if let err = showError {
                        Text(err).font(.system(size: 11)).foregroundColor(.red)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.06)).cornerRadius(8)
                    }
                }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 90)
            }

            // Bottom bar
            HStack(spacing: 12) {
                Button(action: saveDraft) {
                    HStack(spacing: 4) {
                        if saving { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                        Text(saving ? "Saving..." : "Save Draft")
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle()).disabled(saving || forwarding)

                Button(action: forwardToAccounts) {
                    HStack(spacing: 4) {
                        if forwarding { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                        Text(forwarding ? "Sending..." : "Forward to Accounts")
                    }
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.gold).cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle()).disabled(saving || forwarding)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("#\(claim.batchReference)"), displayMode: .inline)
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

    private func codingAmtRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(color)
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func saveDraft() {
        saving = true; showError = nil
        let body: [String: Any] = ["nominal_code": nominalCode, "vat_treatment": vatTreatment, "notes": codingNotes]
        CashExpenseCodableTask.saveClaims(claim.id, body) { result in
            DispatchQueue.main.async {
                saving = false
                if case .success = result { appState.loadCodingQueue(); presentationMode.wrappedValue.dismiss() }
                else if case .failure(let e) = result { showError = e.localizedDescription }
            }
        }.urlDataTask?.resume()
    }

    private func forwardToAccounts() {
        forwarding = true; showError = nil
        let body: [String: Any] = ["nominal_code": nominalCode, "vat_treatment": vatTreatment, "notes": codingNotes]
        CashExpenseCodableTask.saveAndSubmit(claim.id, body) { result in
            DispatchQueue.main.async {
                forwarding = false
                if case .success = result { appState.loadCodingQueue(); presentationMode.wrappedValue.dismiss() }
                else if case .failure(let e) = result { showError = e.localizedDescription }
            }
        }.urlDataTask?.resume()
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Cost Code Picker Button (opens compact action sheet)
// ═══════════════════════════════════════════════════════════════════

struct CostCodePickerButton: View {
    @Binding var selectedCode: String
    @State private var showSheet = false

    private var displayText: String {
        if selectedCode.isEmpty { return "Select cost code" }
        return costCodeOptions.first { $0.0 == selectedCode }?.1 ?? selectedCode
    }

    var body: some View {
        Button(action: { showSheet = true }) {
            HStack {
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundColor(selectedCode.isEmpty ? .gray : .primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
            }
            .padding(10).background(Color.bgRaised).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
        .buttonStyle(BorderlessButtonStyle())
        .selectionActionSheet(
            title: "Cost Code",
            isPresented: $showSheet,
            options: costCodeOptions.map { $0.0 },
            isSelected: { $0 == selectedCode },
            label: { key in costCodeOptions.first { $0.0 == key }?.1 ?? key },
            onSelect: { selectedCode = $0 }
        )
    }
}

// MARK: - Searchable Cost Code Field
// ═══════════════════════════════════════════════════════════════════

struct SearchableCostCodeField: View {
    @Binding var selectedCode: String
    @State private var searchText = ""
    @State private var isSearching = false

    private var displayText: String {
        if !selectedCode.isEmpty {
            return costCodeOptions.first { $0.0 == selectedCode }?.1 ?? selectedCode
        }
        return ""
    }

    private var filteredOptions: [(String, String)] {
        if searchText.isEmpty { return costCodeOptions }
        let q = searchText.lowercased()
        return costCodeOptions.filter { $0.0.lowercased().contains(q) || $0.1.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Field
            HStack {
                if isSearching {
                    TextField("Search cost codes…", text: $searchText, onEditingChanged: { editing in
                        if !editing { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isSearching = false } }
                    })
                    .font(.system(size: 13)).padding(8)
                } else {
                    Button(action: { isSearching = true; searchText = "" }) {
                        HStack {
                            Text(selectedCode.isEmpty ? "Search cost codes…" : displayText)
                                .font(.system(size: 13))
                                .foregroundColor(selectedCode.isEmpty ? .gray : .primary)
                            Spacer()
                        }.padding(8)
                    }.buttonStyle(PlainButtonStyle())
                }

                if !selectedCode.isEmpty {
                    Button(action: { selectedCode = ""; searchText = ""; isSearching = false }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.gray)
                    }.buttonStyle(BorderlessButtonStyle()).padding(.trailing, 4)
                }
            }
            .background(Color.bgRaised).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSearching ? Color.gold : Color.borderColor, lineWidth: isSearching ? 2 : 1))

            // Dropdown list
            if isSearching {
                VStack(spacing: 0) {
                    ForEach(filteredOptions, id: \.0) { option in
                        Button(action: {
                            selectedCode = option.0
                            searchText = ""
                            isSearching = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            HStack {
                                Text(option.1).font(.system(size: 12)).foregroundColor(.primary)
                                Spacer()
                                if selectedCode == option.0 {
                                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }.buttonStyle(PlainButtonStyle())
                        Divider().padding(.leading, 10)
                    }

                    if filteredOptions.isEmpty {
                        Text("No matching cost codes").font(.system(size: 12)).foregroundColor(.gray)
                            .padding(10)
                    }
                }
                .background(Color.bgSurface)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                .padding(.top, 4)
            }
        }
    }
}
