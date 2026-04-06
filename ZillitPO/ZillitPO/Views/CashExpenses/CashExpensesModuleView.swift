//
//  CashExpensesModuleView.swift
//  ZillitPO
//

import SwiftUI

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
    private var approvalClaims: [ClaimBatch] {
        appState.allClaims.filter { ["AWAITING_APPROVAL", "ESCALATED", "READY_TO_POST"].contains($0.status.uppercased()) }
    }
    private var codingClaims: [ClaimBatch] {
        appState.allClaims.filter { ["CODING", "CODED"].contains($0.status.uppercased()) }
    }

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
                        }.padding(14).background(Color.white).cornerRadius(12)
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
                        }.padding(14).background(Color.white).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.56, green: 0.27, blue: 0.68).opacity(0.3), lineWidth: 1))
                        .contentShape(Rectangle())
                    }.buttonStyle(BorderlessButtonStyle())

                    // Accountant-only tiles
                    if isAcct {
                        // Audit Queue tile
                        NavigationLink(destination: AuditQueuePage().environmentObject(appState), isActive: $navigateToAuditQueue) { EmptyView() }.hidden()
                        Button(action: { navigateToAuditQueue = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.shield.fill").font(.system(size: 20)).foregroundColor(.white)
                                    .frame(width: 36, height: 36).background(Color(red: 0.2, green: 0.6, blue: 0.86)).cornerRadius(8)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Audit Queue").font(.system(size: 15, weight: .semibold))
                                        if !auditClaims.isEmpty {
                                            Text("\(auditClaims.count)")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color(red: 0.2, green: 0.6, blue: 0.86)).cornerRadius(8)
                                        }
                                    }
                                    Text("Review & verify submitted claims").font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.86))
                            }.padding(14).background(Color.white).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.2, green: 0.6, blue: 0.86).opacity(0.3), lineWidth: 1))
                            .contentShape(Rectangle())
                        }.buttonStyle(BorderlessButtonStyle())

                        // Approval Queue tile
                        NavigationLink(destination: ApprovalQueuePage().environmentObject(appState), isActive: $navigateToApprovalQueue) { EmptyView() }.hidden()
                        Button(action: { navigateToApprovalQueue = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.shield.checkmark.fill").font(.system(size: 20)).foregroundColor(.white)
                                    .frame(width: 36, height: 36).background(Color.goldDark).cornerRadius(8)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Approval Queue").font(.system(size: 15, weight: .semibold))
                                        if !approvalClaims.isEmpty {
                                            Text("\(approvalClaims.count)")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.goldDark).cornerRadius(8)
                                        }
                                    }
                                    Text("Approve or reject pending claims").font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.goldDark)
                            }.padding(14).background(Color.white).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                            .contentShape(Rectangle())
                        }.buttonStyle(BorderlessButtonStyle())
                    }

                    // Coordinator-only tiles
                    if isCoord && !isAcct {
                        // Coding Queue tile
                        NavigationLink(destination: CodingQueueListView(claims: codingClaims).environmentObject(appState).navigationBarTitle(Text("Coding Queue"), displayMode: .inline), isActive: $navigateToCodingQueue) { EmptyView() }.hidden()
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
                            }.padding(14).background(Color.white).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                            .contentShape(Rectangle())
                        }.buttonStyle(BorderlessButtonStyle())

                        // Approval Queue tile
                        NavigationLink(destination: ApprovalQueuePage().environmentObject(appState), isActive: $navigateToApprovalQueue) { EmptyView() }.hidden()
                        Button(action: { navigateToApprovalQueue = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.shield.checkmark.fill").font(.system(size: 20)).foregroundColor(.white)
                                    .frame(width: 36, height: 36).background(Color.goldDark).cornerRadius(8)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Approval Queue").font(.system(size: 15, weight: .semibold))
                                        if !appState.approvalQueueFloats.isEmpty {
                                            Text("\(appState.approvalQueueFloats.count)")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.goldDark).cornerRadius(8)
                                        }
                                    }
                                    Text("Floats awaiting your approval").font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.goldDark)
                            }.padding(14).background(Color.white).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                            .contentShape(Rectangle())
                        }.buttonStyle(BorderlessButtonStyle())
                    }

                    Spacer()
                }
                .padding(.horizontal, 20).padding(.top, 20)
            }
        }
        .navigationBarTitle(Text("Cash & Expenses"), displayMode: .inline)
        .onAppear { appState.loadAllCashExpenseData() }
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

    private var tabs: [String] {
        if isAcct {
            return ["Active Floats", "Post & Ledger", "Cash Recon", "Sign-off"]
        }
        if isCoord {
            return ["Active Floats", "Float Request", "Submit Claim", "My Claims"]
        }
        // User (Crew)
        return ["Float Request", "Submit Claim", "My Claims"]
    }

    @State private var activeTab = ""

    var body: some View {
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
        .background(Color.bgBase)
        .navigationBarTitle(Text("Petty Cash"), displayMode: .inline)
        .onAppear { if activeTab.isEmpty { activeTab = isAcct ? "Active Floats" : isCoord ? "Active Floats" : "Float Request" } }
    }

    @ViewBuilder
    private var cashTabContent: some View {
        switch activeTab {
        case "Active Floats": FloatsListView(floats: appState.activeFloats).environmentObject(appState)
        case "Post & Ledger": ClaimsListView(claims: appState.allPettyCashClaims.filter { ["READY_TO_POST", "POSTED"].contains($0.status.uppercased()) }, title: "Post & Ledger", hideFilterSearch: true).environmentObject(appState)
        case "Cash Recon": ReconciliationView().environmentObject(appState)
        case "Sign-off": SignOffListView().environmentObject(appState)
        case "Approval Queue": FloatsListView(floats: appState.approvalQueueFloats).environmentObject(appState)
        case "Coding Queue": CodingQueueListView(claims: appState.codingQueue).environmentObject(appState)
        case "Float Request": FloatRequestFormView().environmentObject(appState)
        case "Submit Claim":  SubmitClaimFormView(expenseType: "pc").environmentObject(appState)
        case "My Claims":    ClaimsListView(claims: appState.myPettyCashClaims, title: "My Claims", filterMode: .myClaims).environmentObject(appState)
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
            return ["Post & Ledger", "Payment", "Sign-off"]
        }
        if isCoord {
            return ["Submit Claim", "My Claims"]
        }
        // User (Crew)
        return ["Submit Claim", "My Claims"]
    }

    @State private var activeTab = ""
    @State private var navigateToNewClaim = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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

            if isAcct {
                Button(action: { navigateToNewClaim = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text("New Claim").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(Color.gold).cornerRadius(28)
                }
                .padding(.trailing, 20).padding(.bottom, 24)
            }
        }
        .background(
            NavigationLink(destination: SubmitClaimFormView(expenseType: "oop").environmentObject(appState).navigationBarTitle(Text("New Claim"), displayMode: .inline), isActive: $navigateToNewClaim) { EmptyView() }
                .frame(width: 0, height: 0).hidden()
        )
        .background(Color.bgBase)
        .navigationBarTitle(Text("Out of Pocket"), displayMode: .inline)
        .onAppear { if activeTab.isEmpty { activeTab = isAcct ? "Post & Ledger" : "Submit Claim" } }
    }

    @ViewBuilder
    private var oopTabContent: some View {
        switch activeTab {
        case "Post & Ledger":  ClaimsListView(claims: appState.allOOPClaims.filter { ["READY_TO_POST", "POSTED"].contains($0.status.uppercased()) }, title: "Post & Ledger", hideFilterSearch: true).environmentObject(appState)
        case "Payment":        ClaimsListView(claims: appState.allOOPClaims.filter { $0.status.uppercased() == "POSTED" }, title: "Payment Routing").environmentObject(appState)
        case "Sign-off":       OOPSignOffListView().environmentObject(appState)
        case "Approval Queue": ClaimsListView(claims: appState.allOOPClaims.filter { ["AWAITING_APPROVAL", "ESCALATED", "IN_AUDIT"].contains($0.status.uppercased()) }, title: "Approval Queue").environmentObject(appState)
        case "Coding Queue":   ClaimsListView(claims: appState.codingQueue, title: "Coding Queue", filterMode: .expenseType).environmentObject(appState)
        case "Submit Claim":   SubmitClaimFormView(expenseType: "oop").environmentObject(appState)
        case "My Claims":      ClaimsListView(claims: appState.myOOPClaims, title: "My Claims", filterMode: .myClaims).environmentObject(appState)
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
                // Filter + Search
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Button(action: { showFilterSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                                Text(activeFilter).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                                Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8).background(Color.white).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .compatActionSheet(title: filterMode == .expenseType ? "Filter by Type" : "Filter by Status", isPresented: $showFilterSheet, buttons:
                            filters.map { f in
                                let label = f == activeFilter ? "\(f) ✓" : f
                                return CompatActionSheetButton.default(label) { activeFilter = f }
                            } + [.cancel()]
                        )
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                        TextField("Search claims…", text: $searchText).font(.system(size: 14))
                    }.padding(10).background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }.padding(.horizontal, 16).padding(.top, 12)
            }

            ScrollView {
                VStack(spacing: 10) {
                    if filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("No claims found").font(.system(size: 13)).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 40)
                        .background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    } else {
                        ForEach(filtered) { claim in
                            ClaimRow(claim: claim)
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
        .padding(12).background(Color.white).cornerRadius(10)
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

struct FloatsListView: View {
    let floats: [FloatRequest]
    @EnvironmentObject var appState: POViewModel

    private var totalOutstanding: Double { floats.reduce(0) { $0 + $1.remaining } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Register header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Floats Register").font(.system(size: 15, weight: .bold))
                    Text("\(floats.count) active float\(floats.count == 1 ? "" : "s") · \(FormatUtils.formatGBP(totalOutstanding)) outstanding")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }.padding(.horizontal, 16).padding(.top, 4)

                if floats.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "banknote").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No active floats").font(.system(size: 13)).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    .padding(.horizontal, 16)
                } else {
                    ForEach(floats) { f in
                        FloatCard(float: f, batches: appState.allClaims.filter { $0.floatRequestId == f.id })
                            .padding(.horizontal, 16)
                    }
                }
            }.padding(.top, 8).padding(.bottom, 20)
        }
    }
}

struct FloatCard: View {
    let float: FloatRequest
    var batches: [ClaimBatch] = []
    @State private var expanded = false
    @State private var selectedBatchId: String?

    private var balance: Double { float.issuedFloat - float.receiptsAmount }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Tap header to expand ──
            Button(action: { expanded.toggle() }) {
                VStack(alignment: .leading, spacing: 8) {
                    // Row 1: avatar + name + float number + status
                    HStack(spacing: 8) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold)).foregroundColor(.gray)
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

                    // Row 2: submitted date + cost code + duration
                    HStack(spacing: 6) {
                        Text("Submitted \(FormatUtils.formatTimestamp(float.createdAt))").font(.system(size: 10)).foregroundColor(.gray)
                        if !float.costCode.isEmpty {
                            Text("· \(float.costCode.uppercased())").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                        }
                        if !float.duration.isEmpty {
                            Text("· \(float.duration) days duration").font(.system(size: 10)).foregroundColor(.gray)
                        }
                    }

                    // Row 3: amounts (Issued / Spent / Balance)
                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text("ISSUED").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                            Text(FormatUtils.formatGBP(float.issuedFloat)).font(.system(size: 14, weight: .bold, design: .monospaced))
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: 2) {
                            Text("SPENT").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                            Text(FormatUtils.formatGBP(float.receiptsAmount)).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: 2) {
                            Text("BALANCE").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                            Text(FormatUtils.formatGBP(balance)).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.green)
                        }.frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 6).background(Color.bgRaised).cornerRadius(8)
                }
                .padding(12).contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

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
        .background(Color.white).cornerRadius(10)
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
        switch s.uppercased() {
        case "APPROVED", "ACTIVE", "SPENDING": return (.green, Color.green.opacity(0.1))
        case "AWAITING_APPROVAL": return (.goldDark, Color.gold.opacity(0.15))
        case "REJECTED": return (.red, Color.red.opacity(0.1))
        case "CLOSED": return (.gray, Color.gray.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
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
// MARK: - Submit Claim Form
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
    @State private var settlementType: String = "reimb" // PC: reimb, reduce, topup, close  |  OOP: reimb only
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
                    stepHeader(number: "2", title: "Choose Your Settlement", subtitle: "How should this claim be settled?")

                    VStack(spacing: 8) {
                        settlementOption(id: "reimb", icon: "arrow.uturn.backward.circle.fill", title: "Reimburse Me",
                                         desc: "I overspent my float. Reimburse the difference.", color: Color(red: 0.2, green: 0.7, blue: 0.45))
                        settlementOption(id: "reduce", icon: "arrow.down.circle.fill", title: "Reduce My Float",
                                         desc: "I have cash remaining and want to reduce my float balance.", color: .orange)
                        settlementOption(id: "topup", icon: "arrow.up.circle.fill", title: "Top Up My Float",
                                         desc: "I'd like more cash to continue spending on this float.", color: .blue)
                        settlementOption(id: "close", icon: "xmark.circle.fill", title: "Close This Float",
                                         desc: "All receipts submitted. Return remaining cash and close.", color: .red)
                    }

                    // Show bank details for reimburse
                    if settlementType == "reimb" {
                        reimbursementSection
                    }
                    // Show top-up amount
                    if settlementType == "topup" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TOP UP AMOUNT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            TextField("£0.00", text: $topUpAmount)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced)).keyboardType(.decimalPad)
                                .padding(10).background(Color.white).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                    }
                } else {
                    // OOP: always reimbursement
                    stepHeader(number: "2", title: "Reimbursement Method", subtitle: "How would you like to be paid back?")
                    reimbursementSection
                }

                // ── Notes ──
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADDITIONAL NOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    TextField("Any additional context for the accountant…", text: $notes)
                        .font(.system(size: 13)).padding(10)
                        .background(Color.white).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }

                // ── Summary ──
                HStack {
                    Text("\(receipts.count) receipt\(receipts.count == 1 ? "" : "s")").font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    Text("Total: \(FormatUtils.formatGBP(batchTotal))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                }
                .padding(12).background(Color.white).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                // ── Error ──
                if let err = submitError {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        Text(err).font(.system(size: 11)).foregroundColor(.red)
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.06)).cornerRadius(8)
                }

                // ── Submit ──
                Button(action: submitClaim) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(submitted ? "Submitted" : submitting ? "Submitting..." : "Submit Claim for Coding & Approval")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(submitted ? .white : .black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(submitted ? Color.green : Color.gold).cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(submitting || submitted)

                // Info
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill").font(.system(size: 12)).foregroundColor(.blue)
                    Text("Your claim will be sent for coding by the department coordinator, then audited by accounts before approval.")
                        .font(.system(size: 11)).foregroundColor(.blue)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.04)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.15), lineWidth: 1))

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
                    Button(action: { receiptDatePickerId = receiptDatePickerId == itemId ? nil : itemId }) {
                        HStack {
                            Text(item.date.isEmpty ? "Select date" : item.date)
                                .font(.system(size: 13)).foregroundColor(item.date.isEmpty ? .gray : .primary)
                            Spacer()
                            Image(systemName: "calendar").font(.system(size: 12)).foregroundColor(.goldDark)
                        }
                        .padding(8).background(Color.bgRaised).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                    if receiptDatePickerId == itemId {
                        DatePicker("", selection: Binding(
                            get: { receiptDates[itemId] ?? Date() },
                            set: { newDate in
                                receiptDates[itemId] = newDate
                                let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"
                                if let idx = receipts.firstIndex(where: { $0.id == itemId }) { receipts[idx].date = df.string(from: newDate) }
                                receiptDatePickerId = nil
                            }
                        ), in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
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
                .compatActionSheet(title: "Select Category", isPresented: Binding(
                    get: { categorySheetForId == itemId },
                    set: { if !$0 { categorySheetForId = nil } }
                ), buttons: claimCategories.map { cat in
                    let (val, label) = cat
                    let current = item.category == val
                    return CompatActionSheetButton.default(current ? "\(label) ✓" : label) {
                        if let idx = receipts.firstIndex(where: { $0.id == itemId }) { receipts[idx].category = val }
                    }
                } + [.cancel()])
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
                            SearchableCostCodeField(selectedCode: receiptBinding(itemId, \.costCode))
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
        .padding(12).background(Color.white).cornerRadius(10)
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
                .padding(12).background(Color.white).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            }
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
            .padding(12).background(Color.white).cornerRadius(10)
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
            .background(Color.white).cornerRadius(8)
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

        let settleMap: [String: String] = ["reimb": "REIMBURSE", "reduce": "REDUCE_FLOAT", "topup": "TOP_UP_FLOAT", "close": "CLOSE_FLOAT"]
        let settleType = settleMap[settlementType] ?? "REIMBURSE"

        var settlementDetails: [String: Any] = [:]
        if settlementType == "reimb" {
            settlementDetails["payment_method"] = reimbMethod == "bacs" ? "BACS" : "PAYROLL"
            if reimbMethod == "bacs" {
                var bd: [String: Any] = ["account_name": accountName, "sort_code": sortCode, "account_number": accountNumber]
                let extras = extraFields.filter { !$0.label.isEmpty && !$0.value.isEmpty }.map { ["label": $0.label, "value": $0.value] }
                if !extras.isEmpty { bd["additional_details"] = extras }
                settlementDetails["bank_details"] = bd
                if let amt = Double(reimbAmount), amt > 0 { settlementDetails["amount"] = amt }
            }
        }
        if settlementType == "topup", let amt = Double(topUpAmount), amt > 0 {
            settlementDetails["top_up_amount"] = amt
        }
        if settlementType == "close" {
            settlementDetails["close_float_option"] = "CASH_TO_ACCOUNTANT"
        }

        var body: [String: Any] = [
            "expense_type": expenseType,
            "department_id": user.departmentId,
            "settlement_type": settleType,
            "settlement_details": settlementDetails,
            "notes": notes,
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
                    .frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.white).cornerRadius(12)
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
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.black)
                    Text(sub).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.gray)
            }.padding(14).background(Color.white).cornerRadius(12)
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

                // Sign-off Queue header
                Text("Sign-off Queue").font(.system(size: 15, weight: .bold))

                if queue.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No claims awaiting sign-off").font(.system(size: 13)).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(.primary)
            Text(sub).font(.system(size: 9)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
        .background(Color.white).cornerRadius(8)
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
                        .background(Color.white).cornerRadius(6)
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
        .background(Color.white).cornerRadius(10)
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
                .background(Color.white).cornerRadius(10)
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
                .background(Color.white).cornerRadius(10)
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
                .background(Color.white).cornerRadius(10)
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
                        .font(.system(size: 12)).padding(10).background(Color.white).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }

                // Active Float Balances
                Text("ACTIVE FLOAT BALANCES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)

                if activeFloats.isEmpty {
                    VStack(spacing: 8) {
                        Text("No active floats").font(.system(size: 13)).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 30)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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
                    .background(Color.white).cornerRadius(10)
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
                .compatActionSheet(title: "Select Type", isPresented: Binding(
                    get: { typeSheetForId == item.id },
                    set: { if !$0 { typeSheetForId = nil } }
                ), buttons: [
                    CompatActionSheetButton.default(item.type == "out" ? "Paid out ✓" : "Paid out") {
                        if let idx = reconItems.firstIndex(where: { $0.id == item.id }) { reconItems[idx].type = "out" }
                    },
                    CompatActionSheetButton.default(item.type == "in" ? "Received ✓" : "Received") {
                        if let idx = reconItems.firstIndex(where: { $0.id == item.id }) { reconItems[idx].type = "in" }
                    },
                    CompatActionSheetButton.default(item.type == "timing" ? "Timing off ✓" : "Timing off") {
                        if let idx = reconItems.firstIndex(where: { $0.id == item.id }) { reconItems[idx].type = "timing" }
                    },
                    .cancel()
                ])

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

struct OOPSignOffListView: View {
    @EnvironmentObject var appState: POViewModel

    private var claims: [ClaimBatch] {
        appState.signOffQueue.filter { $0.isOutOfPocket }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if claims.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No OOP claims awaiting sign-off").font(.system(size: 13)).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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
                    .padding(.horizontal, 12).padding(.vertical, 8).background(Color.white).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                .compatActionSheet(title: "Filter by Type", isPresented: $showFilterSheet, buttons:
                    ["All", "Petty Cash", "Out of Pocket"].map { f in
                        let label = f == activeFilter ? "\(f) ✓" : f
                        return CompatActionSheetButton.default(label) { activeFilter = f }
                    } + [.cancel()]
                )
                Spacer()
                Text("\(filtered.count) PENDING").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            // Claims list
            ScrollView {
                VStack(spacing: 10) {
                    if filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("No batches awaiting audit.").font(.system(size: 13)).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 40)
                        .background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    } else {
                        ForEach(filtered) { claim in ClaimRow(claim: claim) }
                    }
                }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 20)
            }
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Audit Queue"), displayMode: .inline)
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
                            Text("Float Requests").font(.system(size: 13, weight: .bold))
                        }
                        Text("\(pendingFloats.count) pending approval").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(activeSection == "floats" ? Color.goldDark : Color.borderColor, lineWidth: activeSection == "floats" ? 2 : 1))
                }.buttonStyle(PlainButtonStyle())

                Button(action: { activeSection = "batches" }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc").font(.system(size: 14)).foregroundColor(.goldDark)
                            Text("Receipt Batches & OOP").font(.system(size: 13, weight: .bold))
                        }
                        Text("\(pendingClaims.count) items").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(activeSection == "batches" ? Color.goldDark : Color.borderColor, lineWidth: activeSection == "batches" ? 2 : 1))
                }.buttonStyle(PlainButtonStyle())
            }
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
                            VStack(spacing: 8) {
                                Text("No float requests awaiting your approval.").font(.system(size: 13)).foregroundColor(.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 30)
                            .background(Color.white).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                        } else {
                            ForEach(pendingFloats) { f in FloatCard(float: f, batches: []) }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Button(action: { showBatchFilterSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                                    Text(batchFilter).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8).background(Color.white).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .compatActionSheet(title: "Filter by Type", isPresented: $showBatchFilterSheet, buttons:
                                ["All", "Petty Cash", "Out of Pocket"].map { f in
                                    let label = f == batchFilter ? "\(f) ✓" : f
                                    return CompatActionSheetButton.default(label) { batchFilter = f }
                                } + [.cancel()]
                            )
                            Spacer()
                            Text("\(filteredClaims.count) PENDING").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
                        }

                        if filteredClaims.isEmpty {
                            VStack(spacing: 8) {
                                Text("No batches awaiting approval.").font(.system(size: 13)).foregroundColor(.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 30)
                            .background(Color.white).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                        } else {
                            ForEach(filteredClaims) { claim in ClaimRow(claim: claim) }
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
            }
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Approval Queue"), displayMode: .inline)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Float Request Form
// ═══════════════════════════════════════════════════════════════════

let durationOptions = ["3 days", "5 days", "7 days", "14 days", "30 days"]
let collectionOptions = [
    ("production_office", "Collect from production office"),
    ("delivered", "Delivered to set/location"),
    ("bank_transfer", "Bank transfer"),
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

    @State private var reqAmount = ""
    @State private var duration = "7 days"
    @State private var costCode = "art_4100"
    @State private var startDate: Date?
    @State private var showDatePicker = false
    @State private var collectionMethod = "production_office"
    @State private var purpose = ""
    @State private var largePurchaseNote = ""
    @State private var submitting = false
    @State private var submitted = false
    @State private var submitError: String?
    @State private var showDurationSheet = false
    @State private var showCostCodeSheet = false
    @State private var showCollectionSheet = false

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

                // Previous Floats
                VStack(alignment: .leading, spacing: 6) {
                    Text("Previous Floats").font(.system(size: 14, weight: .bold))
                    if appState.myFloats.isEmpty {
                        Text("No previous float requests").font(.system(size: 12)).foregroundColor(.gray)
                            .frame(maxWidth: .infinity).padding(.vertical, 20)
                    } else {
                        ForEach(appState.myFloats) { f in
                            HStack {
                                Text(f.reqNumber).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                                Spacer()
                                Text(FormatUtils.formatGBP(f.reqAmount)).font(.system(size: 12, design: .monospaced))
                                Text(f.statusDisplay).font(.system(size: 9, weight: .bold)).foregroundColor(.green)
                                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.green.opacity(0.1)).cornerRadius(3)
                            }.padding(.vertical, 4)
                        }
                    }
                }
                .padding(12).background(Color.white).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // Float Details form
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Float Details").font(.system(size: 15, weight: .bold))
                        Spacer()
                        Text("NEW REQUEST").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
                    }

                    // User + Department (read-only)
                    HStack(spacing: 10) {
                        formReadOnly("USER *", appState.currentUser?.fullName ?? "—")
                        formReadOnly("DEPARTMENT *", appState.currentUser?.displayDepartment ?? "—")
                    }
                    Text("Pre-filled from your Zillit profile").font(.system(size: 10)).foregroundColor(.gray)

                    // Amount + Duration
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("REQUESTED AMOUNT *").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            TextField("£0.00", text: $reqAmount)
                                .font(.system(size: 14, design: .monospaced)).keyboardType(.decimalPad)
                                .padding(10).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            Text("Max single float: £500").font(.system(size: 9)).foregroundColor(.gray)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DURATION *").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Button(action: { showDurationSheet = true }) {
                                HStack {
                                    Text(duration).font(.system(size: 14))
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                                }.padding(10).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }.buttonStyle(BorderlessButtonStyle())
                            .compatActionSheet(title: "Duration", isPresented: $showDurationSheet, buttons:
                                durationOptions.map { d in CompatActionSheetButton.default(d == duration ? "\(d) ✓" : d) { duration = d } } + [.cancel()]
                            )
                            Text("Submit receipts before end date").font(.system(size: 9)).foregroundColor(.gray)
                        }
                    }

                    // Cost Code + Start Date
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COST CODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Button(action: { showCostCodeSheet = true }) {
                                HStack {
                                    Text(costCodeOptions.first { $0.0 == costCode }?.1 ?? "Select")
                                        .font(.system(size: 12)).foregroundColor(.primary).lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                                }.padding(10).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }.buttonStyle(BorderlessButtonStyle())
                            .compatActionSheet(title: "Cost Code", isPresented: $showCostCodeSheet, buttons:
                                costCodeOptions.map { c in CompatActionSheetButton.default(c.0 == costCode ? "\(c.1) ✓" : c.1) { costCode = c.0 } } + [.cancel()]
                            )
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("START DATE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            if startDate != nil {
                                HStack {
                                    DatePicker("", selection: Binding(
                                        get: { startDate ?? Date() },
                                        set: { startDate = $0 }
                                    ), displayedComponents: .date)
                                    .labelsHidden()
                                    Button(action: { startDate = nil }) {
                                        Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.gray)
                                    }.buttonStyle(BorderlessButtonStyle())
                                }
                            } else {
                                Button(action: { startDate = Date() }) {
                                    HStack {
                                        Text("dd/mm/yyyy").font(.system(size: 14)).foregroundColor(.gray)
                                        Spacer()
                                        Image(systemName: "calendar").font(.system(size: 12)).foregroundColor(.goldDark)
                                    }.padding(10).background(Color.bgRaised).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                                }.buttonStyle(BorderlessButtonStyle())
                            }
                        }
                    }

                    // Collection Method
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PREFERRED COLLECTION METHOD").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        Button(action: { showCollectionSheet = true }) {
                            HStack {
                                Text(collectionOptions.first { $0.0 == collectionMethod }?.1 ?? "Select")
                                    .font(.system(size: 14)).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                            }.padding(10).background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }.buttonStyle(BorderlessButtonStyle())
                        .compatActionSheet(title: "Collection Method", isPresented: $showCollectionSheet, buttons:
                            collectionOptions.map { c in CompatActionSheetButton.default(c.0 == collectionMethod ? "\(c.1) ✓" : c.1) { collectionMethod = c.0 } } + [.cancel()]
                        )
                    }

                    // Purpose
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PURPOSE/REASON").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        TextField("Please be specific. Vague descriptions may delay approval.", text: $purpose)
                            .font(.system(size: 13)).padding(10).background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    }

                    // Large purchases
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ANY LARGE INDIVIDUAL PURCHASES EXPECTED?").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        TextField("e.g. specialist paint £80, period fabric £60 — list anything over £50", text: $largePurchaseNote)
                            .font(.system(size: 13)).padding(10).background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        Text("Receipts over £200 require senior accountant sign-off.").font(.system(size: 9)).foregroundColor(.gray)
                    }
                }
                .padding(14).background(Color.white).cornerRadius(10)
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

                // Buttons
                HStack(spacing: 12) {
                    Spacer()
                    Button(action: submitFloat) {
                        HStack(spacing: 6) {
                            if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                            Text(submitted ? "Submitted" : submitting ? "Submitting..." : "Submit Float Request")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(submitted ? .white : .black)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(submitted ? Color.green : Color.gold).cornerRadius(10)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(submitting || submitted)
                }

            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 20)
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

    private func formatDate(_ d: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"; return df.string(from: d)
    }

    private func submitFloat() {
        guard let user = appState.currentUser else { return }
        guard let amount = Double(reqAmount), amount > 0 else { submitError = "Enter a valid amount"; return }
        submitting = true; submitError = nil

        let durationVal = duration.replacingOccurrences(of: " days", with: "")
        var body: [String: Any] = [
            "department_id": user.departmentId,
            "req_amount": amount,
            "duration": durationVal,
            "cost_code": costCode,
            "collection_method": collectionMethod,
            "purpose": purpose,
            "large_purchase_note": largePurchaseNote,
        ]
        if let d = startDate {
            body["start_date"] = Int64(d.timeIntervalSince1970 * 1000)
        }

        appState.submitFloatRequest(body) { success, error in
            submitting = false
            if success { submitted = true }
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
                    .padding(14).background(Color.white).cornerRadius(10)
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
                    .background(Color.white).cornerRadius(10)
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
                    .background(Color.white).cornerRadius(10)
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
                    .padding(.horizontal, 12).padding(.vertical, 8).background(Color.white).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }
                .buttonStyle(BorderlessButtonStyle())
                .compatActionSheet(title: "Filter by Type", isPresented: $showFilterSheet, buttons:
                    ["All", "Petty Cash", "Out of Pocket"].map { f in
                        CompatActionSheetButton.default(f == activeFilter ? "\(f) ✓" : f) { activeFilter = f }
                    } + [.cancel()]
                )
                Spacer()
                Text("\(filtered.count) PENDING").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 10) {
                    if filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("No claims in coding queue").font(.system(size: 13)).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 40)
                        .background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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
                    .padding(14).background(Color.white).cornerRadius(10)
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
                    .background(Color.white).cornerRadius(10)
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
                    .padding(14).background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    if !claim.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SUBMITTER NOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                            Text(claim.notes).font(.system(size: 13))
                        }
                        .padding(14).background(Color.white).cornerRadius(10)
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
            .background(Color.white)
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
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                .padding(.top, 4)
            }
        }
    }
}
