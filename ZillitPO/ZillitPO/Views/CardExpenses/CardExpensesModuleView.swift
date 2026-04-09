//
//  CardExpensesModuleView.swift
//  ZillitPO
//

import SwiftUI
import WebKit

// MARK: - Tabs

enum CardExpenseTab: String, CaseIterable, Identifiable {
    case receipts = "Receipts"
    case card = "Card"
    case approval = "Approval Queue"
    case coding = "Coding Queue"
    var id: String { rawValue }
}

enum ReceiptFilter: String, CaseIterable {
    case all = "All"
    case pendingReceipt = "Pending Receipt"
    case pendingCode = "Pending Code"
    case awaitingApproval = "Awaiting Approval"
    case approved = "Approved"
    case queried = "Queried"
    case underReview = "Under Review"
    case escalated = "Escalated"
    case posted = "Posted"
}

// MARK: - Card Expenses Module

struct CardExpensesModuleView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var activeTab: CardExpenseTab = .receipts

    private var isCoordinator: Bool { appState.cashMeta?.is_coordinator == true }

    private var visibleTabs: [CardExpenseTab] {
        if isCoordinator {
            return [.receipts, .card, .approval, .coding]
        }
        if appState.isCardApprover {
            return [.receipts, .card, .approval]
        }
        return [.receipts, .card]
    }

    var body: some View {
        Group {
            if appState.currentUser?.isAccountant == true {
                CardExpensesAccountantHub().environmentObject(appState)
            } else {
                VStack(spacing: 0) {
                    // Tab bar
                    HStack(spacing: 0) {
                        ForEach(visibleTabs) { tab in
                            let isActive = activeTab == tab
                            Button(action: { activeTab = tab }) {
                                HStack(spacing: 4) {
                                    Text(tab.rawValue).font(.system(size: 12, weight: isActive ? .semibold : .regular)).lineLimit(1)
                                    if tab == .approval {
                                        let count = appState.cardsForApproval().count
                                        if count > 0 {
                                            Text("\(count)").font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(.white).padding(.horizontal, 5).padding(.vertical, 2)
                                                .background(Color.goldDark).cornerRadius(8)
                                        }
                                    }
                                }
                                .foregroundColor(isActive ? .goldDark : .secondary)
                                .frame(maxWidth: .infinity).padding(.vertical, 10).contentShape(Rectangle())
                                .overlay(isActive ? Rectangle().fill(Color.goldDark).frame(height: 2) : nil, alignment: .bottom)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)

                    // Content
                    switch activeTab {
                    case .receipts: ReceiptsTabView().environmentObject(appState)
                    case .card: CardTabView().environmentObject(appState)
                    case .approval:
                        if isCoordinator {
                            CoordinatorApprovalQueueView().environmentObject(appState)
                        } else {
                            CardsForApprovalTabView().environmentObject(appState)
                        }
                    case .coding:
                        CardCodingQueuePage().environmentObject(appState)
                    }
                }
            }
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Card Expenses"), displayMode: .inline)
        .onAppear { appState.loadAllCardExpenseData() }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Expenses — Accountant Hub
// ═══════════════════════════════════════════════════════════════════

struct CardExpensesAccountantHub: View {
    @EnvironmentObject var appState: POViewModel

    private var inboxCount: Int {
        appState.cardTransactions.filter { ["pending", "pending_receipt"].contains($0.status.lowercased()) && !$0.hasReceipt }.count
    }
    private var pendingCount: Int {
        let txPending = appState.cardTransactions.filter {
            ["pending_code", "pending_coding", "pending_receipt"].contains($0.status.lowercased())
        }
        let manualReceipts = appState.cardReceipts.filter {
            ["pending_code", "pending_coding"].contains($0.status.lowercased())
                && $0.linkedTransactionId.isEmpty
        }
        var seen = Set<String>()
        var total = 0
        for t in txPending where seen.insert(t.id).inserted { total += 1 }
        for t in manualReceipts where seen.insert(t.id).inserted { total += 1 }
        return total
    }
    private var approvalCount: Int {
        appState.cardTransactions.filter { ["awaiting_approval", "escalated", "under_review"].contains($0.status.lowercased()) }.count
    }
    private var historyCount: Int {
        let api = appState.cardHistory.count
        return api > 0 ? api : appState.cardTransactions.filter { $0.status.lowercased() == "posted" }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                hubTile(icon: "creditcard.fill", color: .goldDark, title: "Card Register",
                        subtitle: "View & manage company cards", count: appState.userCards.count,
                        destination: AnyView(CardRegisterPage().environmentObject(appState)))

                hubTile(icon: "tray.full.fill", color: .orange, title: "Receipt Inbox",
                        subtitle: "Receipts awaiting transaction match", count: inboxCount,
                        destination: AnyView(ReceiptInboxPage().environmentObject(appState)))

                hubTile(icon: "list.bullet.rectangle.fill", color: .blue, title: "All Transactions",
                        subtitle: "Every card transaction", count: appState.cardTransactions.count,
                        destination: AnyView(AllTransactionsPage().environmentObject(appState)))

                hubTile(icon: "clock.badge.exclamationmark.fill", color: .purple, title: "Pending Coding",
                        subtitle: "Receipts awaiting budget coding", count: pendingCount,
                        destination: AnyView(PendingCodingPage().environmentObject(appState)))

                hubTile(icon: "person.badge.shield.checkmark.fill", color: .goldDark, title: "Approval Queue",
                        subtitle: "Awaiting your approval", count: approvalCount,
                        destination: AnyView(CardListPage(title: "Approval Queue", source: .approval).environmentObject(appState)))

                hubTile(icon: "wallet.pass.fill", color: Color(red: 0, green: 0.6, blue: 0.5), title: "Top-Up To Do",
                        subtitle: "Pending top-ups to action", count: appState.topUpQueue.count,
                        destination: AnyView(TopUpToDoPage().environmentObject(appState)))

                hubTile(icon: "clock.arrow.circlepath", color: .gray, title: "History",
                        subtitle: "Posted & completed transactions", count: historyCount,
                        destination: AnyView(CardListPage(title: "History", source: .history).environmentObject(appState)))

                hubTile(icon: "exclamationmark.triangle.fill", color: .red, title: "Smart Alerts",
                        subtitle: "Flagged or unusual activity", count: appState.smartAlerts.filter { $0.status.lowercased() == "active" }.count,
                        destination: AnyView(SmartAlertsPage().environmentObject(appState)))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
    }

    private func hubTile(icon: String, color: Color, title: String, subtitle: String, count: Int, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(.white)
                    .frame(width: 38, height: 38).background(color).cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.system(size: 15, weight: .semibold))
                        if count > 0 {
                            Text("\(count)").font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(color).cornerRadius(8)
                        }
                    }
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(color)
            }
            .padding(14).background(Color.white).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(PlainButtonStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Generic Card List Page (for hub tiles)
// ═══════════════════════════════════════════════════════════════════

enum CardListSource {
    case inbox, all, pending, approval, topUps, history, alerts
}

struct CardListPage: View {
    let title: String
    let source: CardListSource
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToUpload = false

    private var items: [CardTransaction] {
        switch source {
        case .inbox:
            return appState.cardTransactions.filter { ["pending", "pending_receipt"].contains($0.status.lowercased()) && !$0.hasReceipt }
        case .all:
            return appState.cardTransactions
        case .pending:
            return appState.cardTransactions.filter { ["pending_coding", "pending_code", "pending_receipt", "pending"].contains($0.status.lowercased()) }
        case .approval:
            return appState.cardTransactions.filter { ["awaiting_approval", "escalated", "under_review"].contains($0.status.lowercased()) }
        case .topUps:
            // Top-Up uses dedicated TopUpToDoPage; no fallback list here
            return []
        case .history:
            return appState.cardHistory.isEmpty
                ? appState.cardTransactions.filter { $0.status.lowercased() == "posted" }
                : appState.cardHistory
        case .alerts:
            // Smart Alerts uses dedicated SmartAlertsPage now
            return []
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 10) {
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("Nothing here yet").font(.system(size: 13)).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 50)
                        .background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    } else {
                        ForEach(items) { tx in
                            NavigationLink(destination: CardTransactionDetailPage(transaction: tx).environmentObject(appState)) {
                                CardTransactionRow(transaction: tx)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 90)
            }

            if source == .inbox {
                Button(action: { navigateToUpload = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text("Upload Receipt").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(Color.gold).cornerRadius(28)
                }
                .padding(.trailing, 20).padding(.bottom, 24)
            }
        }
        .background(Color.bgBase)
        .background(
            NavigationLink(destination: UploadReceiptPage().environmentObject(appState),
                           isActive: $navigateToUpload) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .navigationBarTitle(Text(title), displayMode: .inline)
        .onAppear {
            appState.loadCardTransactions()
            switch source {
            case .topUps: appState.loadTopUpQueue()
            case .alerts: appState.loadSmartAlerts()
            case .history: appState.loadCardHistory()
            default: break
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Register Page
// ═══════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════
// MARK: - Coordinator Approval Queue (two sections — Cards / Receipts & Transactions)
// ═══════════════════════════════════════════════════════════════════

struct CoordinatorApprovalQueueView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var section: String = "cards"
    @State private var rejectTarget: ExpenseCard?
    @State private var rejectReason = ""
    @State private var showRejectSheet = false

    private var cards: [ExpenseCard] { appState.cardsForApproval() }
    private var transactions: [CardTransaction] {
        appState.cardTransactions.filter { ["awaiting_approval", "escalated", "under_review"].contains($0.status.lowercased()) }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Two stat cards
            HStack(spacing: 10) {
                sectionCard(key: "cards", icon: "creditcard.fill", title: "Cards", subtitle: "\(cards.count) pending approval", count: cards.count)
                sectionCard(key: "tx", icon: "doc.text", title: "Receipts / Transactions", subtitle: "\(transactions.count) items", count: transactions.count)
            }
            .frame(height: 70)
            .padding(.horizontal, 16).padding(.top, 12)

            // Active section content
            if section == "cards" {
                ScrollView {
                    VStack(spacing: 12) {
                        if cards.isEmpty {
                            VStack(spacing: 8) {
                                Text("No cards pending your approval.").font(.system(size: 13)).foregroundColor(.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 50)
                        } else {
                            ForEach(cards) { card in
                                ApprovalCardRow(card: card, tierConfigs: appState.cardTierConfigRows, onApprove: {
                                    appState.approveCard(card)
                                }, onReject: {
                                    rejectTarget = card; showRejectSheet = true
                                })
                            }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 24)
                }
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        if transactions.isEmpty {
                            VStack(spacing: 8) {
                                Text("No receipts or transactions awaiting approval.").font(.system(size: 13)).foregroundColor(.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 50)
                        } else {
                            ForEach(transactions) { tx in
                                NavigationLink(destination: CardTransactionDetailPage(transaction: tx).environmentObject(appState)) {
                                    CardTransactionRow(transaction: tx)
                                }.buttonStyle(PlainButtonStyle())
                            }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 24)
                }
            }
        }
        .background(Color.bgBase)
        .onAppear {
            appState.loadAllRequestedCards()
            appState.loadCardTransactions()
        }
        .sheet(isPresented: $showRejectSheet) {
            NavigationView {
                ZStack {
                    Color.bgBase.edgesIgnoringSafeArea(.all)
                    VStack(alignment: .leading, spacing: 16) {
                        if let c = rejectTarget {
                            Text("Reject card request from \(c.holderName)").font(.system(size: 15, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reason").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                            TextField("Enter reason…", text: $rejectReason)
                                .font(.system(size: 14)).padding(10)
                                .background(Color.white).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        Spacer()
                    }.padding()
                }
                .navigationBarTitle(Text("Reject Card"), displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") { showRejectSheet = false; rejectReason = "" }.foregroundColor(.goldDark),
                    trailing: Button("Reject") {
                        guard let c = rejectTarget, !rejectReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.rejectCard(c, reason: rejectReason.trimmingCharacters(in: .whitespaces))
                        showRejectSheet = false; rejectReason = ""; rejectTarget = nil
                    }.foregroundColor(.red).font(.system(size: 16, weight: .bold))
                )
            }
        }
    }

    private func sectionCard(key: String, icon: String, title: String, subtitle: String, count: Int) -> some View {
        let isActive = section == key
        return Button(action: { section = key }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(.goldDark)
                    .frame(width: 28, height: 28).background(Color.gold.opacity(0.15)).cornerRadius(6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle().fill(Color.goldDark).frame(width: 20, height: 20)
                    Text("\(count)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isActive ? Color.goldDark : Color.borderColor, lineWidth: isActive ? 2 : 1))
        }.buttonStyle(PlainButtonStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Coding Queue Page (coordinator)
// ═══════════════════════════════════════════════════════════════════

struct CardCodingQueuePage: View {
    @EnvironmentObject var appState: POViewModel

    private var items: [CardTransaction] {
        let pending = appState.cardTransactions.filter { ["pending_coding", "pending_code"].contains($0.status.lowercased()) }
        // Coordinators only code receipts from cardholders in their own department(s)
        let allowedDeptIds: Set<String> = Set(appState.cashMeta?.coordinator_department_ids ?? [])
        let scoped: [CardTransaction] = {
            if allowedDeptIds.isEmpty { return pending }
            return pending.filter { tx in
                if allowedDeptIds.contains(tx.department) { return true }
                if let h = UsersData.byId[tx.holderId], allowedDeptIds.contains(h.departmentId) { return true }
                return false
            }
        }()
        return scoped.sorted { ($0.transactionDate > 0 ? $0.transactionDate : $0.createdAt) > ($1.transactionDate > 0 ? $1.transactionDate : $1.createdAt) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("Nothing in the coding queue").font(.system(size: 13)).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 50)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                } else {
                    ForEach(items) { tx in
                        NavigationLink(destination: CardTransactionDetailPage(transaction: tx).environmentObject(appState)) {
                            CardTransactionRow(transaction: tx)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .onAppear { appState.loadCardTransactions() }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt Inbox Page (4 sections — System Matched, No Match, Duplicate, Personal)
// ═══════════════════════════════════════════════════════════════════

struct ReceiptInboxPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var systemMatchedExpanded = true
    @State private var noMatchExpanded = true
    @State private var duplicateExpanded = true
    @State private var personalExpanded = true

    private var inboxItems: [CardTransaction] { appState.cardReceipts }

    private var systemMatched: [CardTransaction] {
        inboxItems.filter { $0.matchStatus.lowercased() == "matched" }
    }
    private var noMatch: [CardTransaction] {
        // "No Match" = unmatched receipts that aren't tied to a card transaction
        // (manually-uploaded receipts the system couldn't auto-link)
        inboxItems.filter {
            let m = $0.matchStatus.lowercased()
            return (m == "unmatched" || m.isEmpty)
                && $0.linkedTransactionId.isEmpty
                && !($0.duplicateScore != nil && !$0.duplicateDismissed)
                && !($0.personalScore != nil && !$0.personalDismissed)
        }
    }
    private var duplicates: [CardTransaction] {
        inboxItems.filter { $0.duplicateScore != nil && !$0.duplicateDismissed }
    }
    private var personals: [CardTransaction] {
        inboxItems.filter { $0.personalScore != nil && !$0.personalDismissed }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                section(
                    icon: "link",
                    title: "SYSTEM MATCHED — CONFIRM & ATTACH",
                    color: .green,
                    items: systemMatched,
                    expanded: $systemMatchedExpanded,
                    emptyText: "No system-matched receipts. Import a statement or upload receipts to trigger matching.",
                    rightAccessory: AnyView(rerunButton)
                )
                section(
                    icon: "link.badge.plus",
                    title: "NO MATCH",
                    color: .orange,
                    items: noMatch,
                    expanded: $noMatchExpanded,
                    emptyText: "No unmatched receipts.",
                    rightAccessory: AnyView(EmptyView())
                )
                section(
                    icon: "doc.on.doc",
                    title: "DUPLICATE",
                    color: .purple,
                    items: duplicates,
                    expanded: $duplicateExpanded,
                    emptyText: "No duplicate receipts detected.",
                    rightAccessory: AnyView(EmptyView())
                )
                section(
                    icon: "person.crop.circle",
                    title: "PERSONAL",
                    color: .blue,
                    items: personals,
                    expanded: $personalExpanded,
                    emptyText: "No personal expense receipts flagged.",
                    rightAccessory: AnyView(EmptyView())
                )
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Receipt Inbox"), displayMode: .inline)
        .onAppear { appState.loadAllCardReceipts() }
    }

    private var rerunButton: some View {
        Button(action: { appState.loadCardTransactions() }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10))
                Text("Re-run Match").font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.goldDark)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.gold.opacity(0.12)).cornerRadius(6)
        }.buttonStyle(BorderlessButtonStyle())
    }

    @ViewBuilder
    private func section(icon: String, title: String, color: Color, items: [CardTransaction], expanded: Binding<Bool>, emptyText: String, rightAccessory: AnyView) -> some View {
        VStack(spacing: 0) {
            Button(action: { expanded.wrappedValue.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: expanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                    Image(systemName: icon).font(.system(size: 12)).foregroundColor(color)
                    Text(title).font(.system(size: 11, weight: .bold)).tracking(0.4)
                    Spacer()
                    rightAccessory
                    Text("\(items.count) receipt\(items.count == 1 ? "" : "s")")
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
                .padding(12).contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if expanded.wrappedValue {
                Divider()
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: icon).font(.system(size: 22)).foregroundColor(.gray.opacity(0.3))
                        Text(emptyText).font(.system(size: 11)).foregroundColor(.gray).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 28).padding(.horizontal, 14)
                } else {
                    ForEach(items) { tx in
                        NavigationLink(destination: CardTransactionDetailPage(transaction: tx, allowEdit: false).environmentObject(appState)) {
                            inboxRow(tx)
                        }.buttonStyle(PlainButtonStyle())
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func inboxRow(_ tx: CardTransaction) -> some View {
        let date = tx.transactionDate > 0 ? FormatUtils.formatTimestamp(tx.transactionDate) : (tx.createdAt > 0 ? FormatUtils.formatTimestamp(tx.createdAt) : "—")
        let user = UsersData.byId[tx.holderId]
        let codeLabel: String = {
            if tx.nominalCode.isEmpty { return "—" }
            if let m = costCodeOptions.first(where: { $0.0 == tx.nominalCode }) { return m.1 }
            return tx.nominalCode.uppercased()
        }()
        return VStack(alignment: .leading, spacing: 8) {
            // Top row — merchant + amount + status
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tx.merchant.isEmpty ? "—" : tx.merchant)
                        .font(.system(size: 13, weight: .bold)).lineLimit(2)
                    Text(date).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(FormatUtils.formatGBP(tx.amount))
                        .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    statusBadge(tx)
                }
            }

            // Bottom row — holder + dept + code
            HStack(spacing: 8) {
                if let u = user {
                    ZStack {
                        Circle().fill(Color.gold.opacity(0.18)).frame(width: 22, height: 22)
                        Text(u.initials).font(.system(size: 9, weight: .bold)).foregroundColor(.goldDark)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(user?.fullName ?? (tx.holderName.isEmpty ? "—" : tx.holderName))
                        .font(.system(size: 11, weight: .semibold)).lineLimit(1)
                    if let d = user?.displayDesignation, !d.isEmpty {
                        Text(d).font(.system(size: 9)).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill").font(.system(size: 8)).foregroundColor(.goldDark)
                    Text(codeLabel).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                }
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.gold.opacity(0.1)).cornerRadius(4)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func statusBadge(_ tx: CardTransaction) -> some View {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        let (label, fg, bg): (String, Color, Color) = {
            switch tx.status.lowercased() {
            case "approved", "matched", "coded": return ("Approved", teal, teal.opacity(0.12))
            case "posted": return ("Posted", teal, teal.opacity(0.12))
            case "pending", "pending_receipt": return ("Pending Receipt", orange, orange.opacity(0.12))
            case "pending_coding", "pending_code": return ("Pending Code", orange, orange.opacity(0.12))
            default: return (tx.statusDisplay, .goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(label)
            .font(.system(size: 8, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(bg).cornerRadius(4)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Smart Alerts Page
// ═══════════════════════════════════════════════════════════════════

struct SmartAlertsPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var activeFilter = "All"
    @State private var showFilterSheet = false

    private let filters = ["All", "Anomaly", "Duplicate Risk", "Velocity", "Merchant", "Resolved"]

    private func count(for filter: String) -> Int {
        switch filter {
        case "Anomaly":        return alerts.filter { $0.type.lowercased() == "anomaly" }.count
        case "Duplicate Risk": return alerts.filter { ["duplicate_risk", "duplicate"].contains($0.type.lowercased()) }.count
        case "Velocity":       return alerts.filter { $0.type.lowercased() == "velocity" }.count
        case "Merchant":       return alerts.filter { $0.type.lowercased() == "merchant" }.count
        case "Resolved":       return alerts.filter { $0.status.lowercased() == "resolved" }.count
        default:               return alerts.count
        }
    }

    private func filterLabel(_ f: String) -> String {
        let c = count(for: f)
        return c > 0 ? "\(f) (\(c))" : f
    }

    private var alerts: [SmartAlert] { appState.smartAlerts }

    private var filtered: [SmartAlert] {
        switch activeFilter {
        case "Anomaly":        return alerts.filter { $0.type.lowercased() == "anomaly" }
        case "Duplicate Risk": return alerts.filter { ["duplicate_risk", "duplicate"].contains($0.type.lowercased()) }
        case "Velocity":       return alerts.filter { $0.type.lowercased() == "velocity" }
        case "Merchant":       return alerts.filter { $0.type.lowercased() == "merchant" }
        case "Resolved":       return alerts.filter { $0.status.lowercased() == "resolved" }
        default:               return alerts
        }
    }

    private var activeCount: Int { alerts.filter { $0.status.lowercased() == "active" }.count }
    private var resolvedThisWeek: Int {
        let weekAgo = Int64(Date().timeIntervalSince1970 * 1000) - 7 * 86_400_000
        return alerts.filter { $0.status.lowercased() == "resolved" && $0.resolvedAt >= weekAgo }.count
    }
    private var alertRate: Double {
        // Web shows 100% as detection coverage when alerts are present
        alerts.isEmpty ? 0 : 100
    }
    private var savingsFound: Double { alerts.reduce(0) { $0 + $1.savings } }

    var body: some View {
        VStack(spacing: 12) {
            // Stat cards 2x2 grid
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    statCard(label: "ACTIVE ALERTS", value: "\(activeCount)", sub: "Needs review", color: Color(red: 0.91, green: 0.29, blue: 0.48))
                    statCard(label: "RESOLVED (7D)", value: "\(resolvedThisWeek)", sub: "This session", color: Color(red: 0.0, green: 0.6, blue: 0.5))
                }
                .frame(height: 78)
                HStack(spacing: 8) {
                    statCard(label: "ALERT RATE", value: "\(String(format: "%.1f", alertRate))%", sub: "Of transactions", color: Color(red: 0.95, green: 0.55, blue: 0.15))
                    statCard(label: "SAVINGS FOUND", value: FormatUtils.formatGBP(savingsFound), sub: "Caught this period", color: Color(red: 0.0, green: 0.6, blue: 0.5))
                }
                .frame(height: 78)
            }

            // Filter dropdown
            HStack(spacing: 8) {
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                        Text(filterLabel(activeFilter)).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.white).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }
                .buttonStyle(BorderlessButtonStyle())
                .compatActionSheet(title: "Filter", isPresented: $showFilterSheet, buttons:
                    filters.map { f in
                        let label = filterLabel(f)
                        return CompatActionSheetButton.default(f == activeFilter ? "\(label) ✓" : label) { activeFilter = f }
                    } + [.cancel()]
                )
                Spacer()
            }

            // Alert list
            ScrollView {
                if filtered.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No alerts").font(.system(size: 13)).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 50)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                } else {
                    VStack(spacing: 12) {
                        ForEach(filtered) { alert in
                            alertCard(alert)
                        }
                    }.padding(.bottom, 12)
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 14)
        .background(Color.bgBase)
        .navigationBarTitle(Text("Smart Alerts"), displayMode: .inline)
        .onAppear { appState.loadSmartAlerts() }
    }

    private func statCard(label: String, value: String, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(color).lineLimit(1).minimumScaleFactor(0.6)
            Text(sub).font(.system(size: 8)).foregroundColor(.gray).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(8)
        .background(Color.white).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
    }

    @ViewBuilder
    private func alertCard(_ alert: SmartAlert) -> some View {
        let isResolved = alert.status.lowercased() == "resolved"
        let pink = Color(red: 0.91, green: 0.29, blue: 0.48)
        VStack(alignment: .leading, spacing: 12) {
            // Header — title + detected timestamp
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14)).foregroundColor(pink)
                Text(alert.title.isEmpty ? "Alert" : alert.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(pink)
                    .lineLimit(2)
                Spacer(minLength: 4)
                if alert.detectedAt > 0 {
                    Text(FormatUtils.formatTimestamp(alert.detectedAt))
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                }
            }

            // Badge row
            HStack(spacing: 6) {
                priorityBadge(alert.priority)
                statusBadge(alert.status)
                Spacer()
            }

            // Description
            if !alert.description.isEmpty {
                Text(alert.description)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Evidence box — well-formed details grid
            VStack(alignment: .leading, spacing: 6) {
                if !alert.bsControlCode.isEmpty {
                    HStack {
                        Text("BS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        Spacer()
                        Text(alert.bsControlCode).font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                }
                if !alert.cardLastFour.isEmpty {
                    Divider()
                    HStack {
                        Text("CARD").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        Spacer()
                        Text("•••• \(alert.cardLastFour)").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.blue)
                    }
                }
                if !alert.holderName.isEmpty {
                    Divider()
                    HStack {
                        Text("CARDHOLDER").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(alert.holderName).font(.system(size: 11, weight: .semibold))
                            if !alert.department.isEmpty {
                                Text(alert.department).font(.system(size: 9)).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                if alert.amount > 0 {
                    Divider()
                    HStack {
                        Text("AMOUNT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        Spacer()
                        Text(FormatUtils.formatGBP(alert.amount))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.goldDark)
                    }
                }
            }
            .padding(10)
            .background(pink.opacity(0.05)).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(pink.opacity(0.25), lineWidth: 1))

            // Actions
            if !isResolved {
                HStack(spacing: 8) {
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass").font(.system(size: 10))
                            Text("Investigate").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        .cornerRadius(6)
                    }.buttonStyle(BorderlessButtonStyle())
                    Button(action: { appState.resolveSmartAlert(alert.id) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 10))
                            Text("Resolve").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color(red: 0.0, green: 0.6, blue: 0.5)).cornerRadius(6)
                    }.buttonStyle(BorderlessButtonStyle())
                    Button(action: { appState.dismissSmartAlert(alert.id) }) {
                        Text("Dismiss").font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                            .padding(.horizontal, 8).padding(.vertical, 7)
                    }.buttonStyle(BorderlessButtonStyle())
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pink.opacity(0.3), lineWidth: 1.5))
    }

    private func priorityBadge(_ p: String) -> some View {
        let pink = Color(red: 0.91, green: 0.29, blue: 0.48)
        let (fg, bg): (Color, Color) = {
            switch p.lowercased() {
            case "high":   return (pink, pink.opacity(0.12))
            case "medium": return (Color(red: 0.95, green: 0.55, blue: 0.15), Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.12))
            case "low":    return (.gray, Color.gray.opacity(0.15))
            default:       return (.goldDark, Color.gold.opacity(0.15))
            }
        }()
        let label: String = {
            switch p.lowercased() {
            case "high":   return "High Priority"
            case "medium": return "Medium Priority"
            case "low":    return "Low Priority"
            default:       return p.capitalized
            }
        }()
        return Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 2).background(bg).cornerRadius(3)
    }

    private func statusBadge(_ s: String) -> some View {
        let pink = Color(red: 0.91, green: 0.29, blue: 0.48)
        let (fg, bg): (Color, Color) = {
            switch s.lowercased() {
            case "active":    return (pink, pink.opacity(0.12))
            case "resolved":  return (Color(red: 0.0, green: 0.6, blue: 0.5), Color(red: 0.0, green: 0.6, blue: 0.5).opacity(0.12))
            case "dismissed": return (.gray, Color.gray.opacity(0.15))
            default:          return (.goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(s.capitalized).font(.system(size: 8, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 2).background(bg).cornerRadius(3)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Pending Coding Page (grouped by cardholder)
// ═══════════════════════════════════════════════════════════════════

struct PendingCodingPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var expandedHolders: Set<String> = []

    private var pending: [CardTransaction] {
        // Card transactions waiting for receipt upload OR coding
        let txPending = appState.cardTransactions.filter {
            ["pending_code", "pending_coding", "pending_receipt"].contains($0.status.lowercased())
        }
        // Manually uploaded receipts with no linked transaction, awaiting coding
        let manualReceipts = appState.cardReceipts.filter {
            ["pending_code", "pending_coding"].contains($0.status.lowercased())
                && $0.linkedTransactionId.isEmpty
        }
        // Dedupe by id (txPending wins)
        var seen = Set<String>()
        var combined: [CardTransaction] = []
        for t in txPending { if seen.insert(t.id).inserted { combined.append(t) } }
        for t in manualReceipts { if seen.insert(t.id).inserted { combined.append(t) } }
        return combined
    }

    private var groupedByHolder: [(holderId: String, holderName: String, department: String, items: [CardTransaction])] {
        let groups = Dictionary(grouping: pending, by: { $0.holderId })
        return groups.map { (holderId, items) in
            let first = items.first
            let name = UsersData.byId[holderId]?.fullName ?? first?.holderName ?? holderId
            let dept = first?.department ?? UsersData.byId[holderId]?.displayDepartment ?? ""
            return (holderId: holderId, holderName: name, department: dept, items: items.sorted { $0.createdAt > $1.createdAt })
        }.sorted { $0.holderName < $1.holderName }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if pending.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("Nothing awaiting coding").font(.system(size: 13)).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 50)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                } else {
                    ForEach(groupedByHolder, id: \.holderId) { group in
                        holderSection(group)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Pending Coding"), displayMode: .inline)
        .onAppear {
            appState.loadAllCardReceipts()
            appState.loadCardTransactions()
            // Default expand on first load
            if expandedHolders.isEmpty, let first = groupedByHolder.first {
                expandedHolders.insert(first.holderId)
            }
        }
    }

    @ViewBuilder
    private func holderSection(_ group: (holderId: String, holderName: String, department: String, items: [CardTransaction])) -> some View {
        let isExpanded = expandedHolders.contains(group.holderId)
        let total = group.items.reduce(0) { $0 + $1.amount }
        let initials = group.holderName.split(separator: " ").compactMap { $0.first.map(String.init) }.prefix(2).joined()
        VStack(spacing: 0) {
            // Header
            Button(action: {
                if isExpanded { expandedHolders.remove(group.holderId) } else { expandedHolders.insert(group.holderId) }
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color(red: 0.91, green: 0.29, blue: 0.48)).frame(width: 28, height: 28)
                        Text(initials.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(group.holderName).font(.system(size: 13, weight: .bold))
                            if !group.department.isEmpty {
                                Text("— \(group.department)").font(.system(size: 11)).foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    Text("\(group.items.count) pending")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.12)).cornerRadius(4)
                    Text(FormatUtils.formatGBP(total))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                }
                .padding(12).contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if isExpanded {
                Divider()
                ForEach(group.items) { item in
                    NavigationLink(destination: CardTransactionDetailPage(transaction: item, allowEdit: false).environmentObject(appState)) {
                        pendingRow(item)
                    }.buttonStyle(PlainButtonStyle())
                    Divider().padding(.leading, 14)
                }
            }
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func pendingRow(_ tx: CardTransaction) -> some View {
        let date = (tx.transactionDate > 0 ? tx.transactionDate : tx.createdAt)
        let dateText = date > 0 ? FormatUtils.formatTimestamp(date) : "—"
        let user = UsersData.byId[tx.holderId]
        let ageDays: Int = {
            guard date > 0 else { return 0 }
            let secs = (Date().timeIntervalSince1970 * 1000 - Double(date)) / 1000
            return max(0, Int(secs / 86400))
        }()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tx.merchant.isEmpty ? "—" : tx.merchant)
                        .font(.system(size: 13, weight: .semibold)).lineLimit(2)
                    Text(dateText).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(FormatUtils.formatGBP(tx.amount))
                        .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    Text("Pending Code")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.12)).cornerRadius(3)
                }
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(user?.fullName ?? (tx.holderName.isEmpty ? "—" : tx.holderName))
                        .font(.system(size: 11, weight: .semibold))
                    if let d = user?.displayDesignation, !d.isEmpty {
                        Text(d).font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text("\(ageDays)d").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Top-Up To Do Page
// ═══════════════════════════════════════════════════════════════════

struct TopUpToDoPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var pendingExpanded = true
    @State private var historyExpanded = true

    private var pending: [TopUpItem] {
        appState.topUpQueue.filter { $0.status.lowercased() == "pending" }
            .sorted { $0.createdAt < $1.createdAt }  // oldest first
    }
    private var history: [TopUpItem] {
        appState.topUpQueue.filter { ["completed", "skipped"].contains($0.status.lowercased()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // PENDING TOP-UPS section
                pendingSection

                // COMPLETED & SKIPPED section
                historySection
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Top-Up To Do"), displayMode: .inline)
        .onAppear { appState.loadTopUpQueue() }
    }

    private var pendingSection: some View {
        VStack(spacing: 0) {
            Button(action: { pendingExpanded.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill").font(.system(size: 12)).foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
                    Text("PENDING TOP-UPS").font(.system(size: 11, weight: .bold)).tracking(0.4)
                    Text("\(pending.count)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(red: 0.95, green: 0.55, blue: 0.15)).cornerRadius(8)
                    Spacer()
                    Text("Oldest first · Urgent prioritised").font(.system(size: 9)).foregroundColor(.gray)
                    Image(systemName: pendingExpanded ? "chevron.up" : "chevron.down").font(.system(size: 9)).foregroundColor(.gray)
                }
                .padding(12).background(Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.06))
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if pendingExpanded {
                if pending.isEmpty {
                    Text("No pending top-ups").font(.system(size: 11)).foregroundColor(.gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                } else {
                    ForEach(pending) { item in
                        Divider()
                        NavigationLink(destination: TopUpDetailPage(item: item).environmentObject(appState)) {
                            pendingCard(item)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.3), lineWidth: 1))
    }

    private func pendingCard(_ item: TopUpItem) -> some View {
        let user = UsersData.byId[item.userId]
        let initials = (user?.initials ?? String(item.holderName.prefix(2))).uppercased()
        let spentPct = item.cardLimit > 0 ? min(1.0, item.cardSpent / item.cardLimit) : 0
        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color(red: 0.95, green: 0.55, blue: 0.15)).frame(width: 30, height: 30)
                    Text(initials).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(user?.fullName ?? item.holderName).font(.system(size: 14, weight: .bold))
                        if !item.cardLastFour.isEmpty {
                            Text("—").font(.system(size: 11)).foregroundColor(.gray)
                            Text("•••• \(item.cardLastFour)").font(.system(size: 11, design: .monospaced)).foregroundColor(.primary)
                        }
                    }
                    HStack(spacing: 4) {
                        if !item.cardLastFour.isEmpty {
                            Text("Card •••• \(item.cardLastFour)").font(.system(size: 9)).foregroundColor(.gray)
                        }
                        if !item.bsControlCode.isEmpty {
                            Text("· BS: \(item.bsControlCode)").font(.system(size: 9)).foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
            }

            // Details grid 2x2
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    detailCell(label: "CURRENT BAL", value: FormatUtils.formatGBP(item.cardBalance), color: Color(red: 0.0, green: 0.6, blue: 0.5), mono: true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CARD LIMIT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        Text(FormatUtils.formatGBP(item.cardLimit)).font(.system(size: 14, weight: .bold, design: .monospaced))
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 4).cornerRadius(2)
                                Rectangle().fill(Color(red: 0.95, green: 0.55, blue: 0.15)).frame(width: geo.size.width * CGFloat(spentPct), height: 4).cornerRadius(2)
                            }
                        }.frame(height: 4)
                        Text("Spent \(FormatUtils.formatGBP(item.cardSpent))").font(.system(size: 9)).foregroundColor(.gray)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(alignment: .top, spacing: 12) {
                    detailCell(label: "TOP-UP METHOD", value: item.method.lowercased() == "restore" ? "Restore float" : item.methodDisplay, color: .primary, mono: false)
                    detailCell(label: "TOP-UP AMOUNT", value: FormatUtils.formatGBP(item.amount), color: Color(red: 0.95, green: 0.55, blue: 0.15), mono: true)
                }
            }

            // From: receipt line
            if !item.receiptMerchant.isEmpty || item.receiptAmount > 0 {
                HStack(spacing: 4) {
                    Text("From:").font(.system(size: 10)).foregroundColor(.secondary)
                    Text(item.receiptMerchant.isEmpty ? "—" : item.receiptMerchant).font(.system(size: 10, weight: .medium))
                    if item.receiptAmount > 0 {
                        Text(FormatUtils.formatGBP(item.receiptAmount)).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11))
                        Text("Mark Topped Up").font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(red: 0.0, green: 0.6, blue: 0.5)).cornerRadius(6)
                }.buttonStyle(BorderlessButtonStyle())
                Button(action: {}) {
                    Text("Partial Top-Up").font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())
                Button(action: {}) {
                    Text("Skip").font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())
                Spacer()
            }
        }
        .padding(14)
    }

    private func detailCell(label: String, value: String, color: Color, mono: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(mono ? .system(size: 14, weight: .bold, design: .monospaced) : .system(size: 13, weight: .semibold)).foregroundColor(color)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historySection: some View {
        VStack(spacing: 0) {
            Button(action: { historyExpanded.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.5))
                    Text("COMPLETED & SKIPPED").font(.system(size: 11, weight: .bold)).tracking(0.4)
                    Text("\(history.count)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gray).cornerRadius(8)
                    Spacer()
                    Image(systemName: historyExpanded ? "chevron.up" : "chevron.down").font(.system(size: 9)).foregroundColor(.gray)
                }
                .padding(12).background(Color.bgRaised)
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if historyExpanded {
                if history.isEmpty {
                    Text("Nothing completed yet").font(.system(size: 11)).foregroundColor(.gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                } else {
                    ForEach(history) { item in
                        Divider()
                        NavigationLink(destination: TopUpDetailPage(item: item).environmentObject(appState)) {
                            historyRow(item)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func historyRow(_ item: TopUpItem) -> some View {
        let user = UsersData.byId[item.userId]
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let statusColor: Color = {
            switch item.status.lowercased() {
            case "completed": return teal
            case "partial": return Color(red: 0.95, green: 0.55, blue: 0.15)
            default: return .gray
            }
        }()
        let dateText = item.updatedAt > 0 ? FormatUtils.formatTimestamp(item.updatedAt)
                      : (item.createdAt > 0 ? FormatUtils.formatTimestamp(item.createdAt) : "—")
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(user?.fullName ?? item.holderName).font(.system(size: 12, weight: .semibold))
                    if let d = user?.displayDesignation, !d.isEmpty {
                        Text(d).font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(FormatUtils.formatGBP(item.amount))
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }
            HStack(spacing: 8) {
                if !item.cardLastFour.isEmpty {
                    Text("•••• \(item.cardLastFour)").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Text(item.method.lowercased() == "restore" ? "Restore Float"
                     : item.method.lowercased() == "expense" ? "Expense Amount"
                     : item.methodDisplay)
                    .font(.system(size: 10)).foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 3) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(item.statusDisplay).font(.system(size: 10, weight: .semibold)).foregroundColor(statusColor)
                }
                Text(dateText).font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - All Transactions Page
// ═══════════════════════════════════════════════════════════════════

struct AllTransactionsPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var searchText = ""
    @State private var activeFilter: String = "All"
    @State private var activeCard: String = "All Cards"
    @State private var activeDept: String = "All Dept"
    @State private var showFilterSheet = false
    @State private var showCardSheet = false
    @State private var showDeptSheet = false

    private let filters = ["All", "New", "Pending Receipt", "Pending Code", "Awaiting Approval", "Approved", "Rejected", "Queried", "Under Review", "Escalated", "Posted"]

    private var cardOptions: [String] {
        let cards = Set(appState.cardTransactions.compactMap { $0.cardLastFour.isEmpty ? nil : "•••• \($0.cardLastFour)" })
        return ["All Cards"] + cards.sorted()
    }
    private var deptOptions: [String] {
        let depts = Set(appState.cardTransactions.compactMap { $0.department.isEmpty ? nil : $0.department })
        return ["All Dept"] + depts.sorted()
    }

    private var filtered: [CardTransaction] {
        var list = appState.cardTransactions
        switch activeFilter {
        case "New":              list = list.filter { ["new", "imported"].contains($0.status.lowercased()) }
        case "Pending Receipt":  list = list.filter { ["pending", "pending_receipt"].contains($0.status.lowercased()) }
        case "Pending Code":     list = list.filter { ["pending_coding", "pending_code"].contains($0.status.lowercased()) }
        case "Awaiting Approval":list = list.filter { $0.status.lowercased() == "awaiting_approval" }
        case "Approved":         list = list.filter { ["approved", "matched", "coded"].contains($0.status.lowercased()) }
        case "Rejected":         list = list.filter { $0.status.lowercased() == "rejected" }
        case "Queried":          list = list.filter { $0.status.lowercased() == "queried" }
        case "Under Review":     list = list.filter { $0.status.lowercased() == "under_review" }
        case "Escalated":        list = list.filter { $0.status.lowercased() == "escalated" }
        case "Posted":           list = list.filter { $0.status.lowercased() == "posted" }
        default: break
        }
        if activeCard != "All Cards" {
            let trimmed = activeCard.replacingOccurrences(of: "•••• ", with: "")
            list = list.filter { $0.cardLastFour == trimmed }
        }
        if activeDept != "All Dept" {
            list = list.filter { $0.department == activeDept }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter { $0.merchant.lowercased().contains(q) || $0.holderName.lowercased().contains(q) || $0.nominalCode.lowercased().contains(q) }
        }
        return list.sorted { ($0.transactionDate > 0 ? $0.transactionDate : $0.createdAt) > ($1.transactionDate > 0 ? $1.transactionDate : $1.createdAt) }
    }

    private var totalGross: Double { filtered.reduce(0) { $0 + $1.amount } }

    var body: some View {
        VStack(spacing: 12) {
            // Stats row
            HStack(spacing: 8) {
                statCard(label: "TOTAL", value: "\(filtered.count)")
                statCard(label: "TOTAL VALUE", value: FormatUtils.formatGBP(totalGross))
            }.frame(height: 64)

            // Filter + search
            VStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        dropdown(label: activeFilter, icon: "line.3.horizontal.decrease", action: { showFilterSheet = true })
                            .compatActionSheet(title: "Status", isPresented: $showFilterSheet, buttons:
                                filters.map { f in CompatActionSheetButton.default(f == activeFilter ? "\(f) ✓" : f) { activeFilter = f } } + [.cancel()]
                            )
                        dropdown(label: activeCard, icon: "creditcard", action: { showCardSheet = true })
                            .compatActionSheet(title: "Card", isPresented: $showCardSheet, buttons:
                                cardOptions.map { c in CompatActionSheetButton.default(c == activeCard ? "\(c) ✓" : c) { activeCard = c } } + [.cancel()]
                            )
                        dropdown(label: activeDept, icon: "building.2", action: { showDeptSheet = true })
                            .compatActionSheet(title: "Department", isPresented: $showDeptSheet, buttons:
                                deptOptions.map { d in CompatActionSheetButton.default(d == activeDept ? "\(d) ✓" : d) { activeDept = d } } + [.cancel()]
                            )
                    }
                }
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                    TextField("Search merchant, holder, code…", text: $searchText).font(.system(size: 13))
                }.padding(10).background(Color.white).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
            }

            // Scrollable rows section
            ScrollView {
                if filtered.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No transactions").font(.system(size: 13)).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                } else {
                    VStack(spacing: 10) {
                        ForEach(filtered) { tx in
                            AllTransactionsRow(tx: tx)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 14)
        .background(Color.bgBase)
        .navigationBarTitle(Text("All Transactions"), displayMode: .inline)
        .onAppear { appState.loadCardTransactions() }
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.primary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(10)
        .background(Color.white).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
    }

    private func dropdown(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }.buttonStyle(BorderlessButtonStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Top-Up Detail Page (summary card)
// ═══════════════════════════════════════════════════════════════════

struct TopUpDetailPage: View {
    let item: TopUpItem
    @EnvironmentObject var appState: POViewModel

    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        switch item.status.lowercased() {
        case "completed": return (teal, teal.opacity(0.12))
        case "skipped":   return (.gray, Color.gray.opacity(0.15))
        case "partial":   return (orange, orange.opacity(0.12))
        case "pending":   return (.goldDark, Color.gold.opacity(0.15))
        default:          return (.gray, Color.gray.opacity(0.12))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Summary card
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack {
                        Text("Top-Up Details").font(.system(size: 15, weight: .bold))
                        Spacer()
                        let (fg, bg) = statusColors
                        Text(item.statusDisplay).font(.system(size: 10, weight: .bold)).foregroundColor(fg)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(bg).cornerRadius(4)
                    }
                    .padding(14)

                    Divider()

                    // Cardholder + card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "CARDHOLDER",
                                     value: UsersData.byId[item.userId]?.fullName ?? (item.holderName.isEmpty ? "—" : item.holderName))
                            infoCell(label: "CARD",
                                     value: item.cardLastFour.isEmpty ? "—" : "•••• \(item.cardLastFour)",
                                     mono: true)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "DEPARTMENT",
                                     value: item.department.isEmpty ? "—" : item.department)
                            infoCell(label: "BS CONTROL CODE",
                                     value: item.bsControlCode.isEmpty ? "—" : item.bsControlCode,
                                     mono: true)
                        }
                    }
                    .padding(14)

                    Divider()

                    // Amounts
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "TOP-UP AMOUNT",
                                     value: FormatUtils.formatGBP(item.amount),
                                     valueColor: Color(red: 0.95, green: 0.55, blue: 0.15), mono: true)
                            infoCell(label: "METHOD",
                                     value: item.method.lowercased() == "restore" ? "Restore float" : item.methodDisplay)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "CURRENT BALANCE",
                                     value: FormatUtils.formatGBP(item.cardBalance),
                                     valueColor: Color(red: 0.0, green: 0.6, blue: 0.5), mono: true)
                            infoCell(label: "CARD LIMIT",
                                     value: FormatUtils.formatGBP(item.cardLimit),
                                     mono: true)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "SPENT",
                                     value: FormatUtils.formatGBP(item.cardSpent), mono: true)
                            infoCell(label: "REMAINING",
                                     value: FormatUtils.formatGBP(max(0, item.cardLimit - item.cardSpent)), mono: true)
                        }
                    }
                    .padding(14)

                    // Receipt source
                    if !item.receiptMerchant.isEmpty || item.receiptAmount > 0 {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SOURCE RECEIPT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            HStack {
                                Text(item.receiptMerchant.isEmpty ? "—" : item.receiptMerchant)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                if item.receiptAmount > 0 {
                                    Text(FormatUtils.formatGBP(item.receiptAmount))
                                        .font(.system(size: 12, design: .monospaced)).foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(14)
                    }

                    // Note
                    if !item.note.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOTE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Text(item.note).font(.system(size: 12)).italic()
                        }.padding(14)
                    }

                    // Dates
                    Divider()
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "CREATED",
                                     value: item.createdAt > 0 ? FormatUtils.formatTimestamp(item.createdAt) : "—")
                            infoCell(label: "UPDATED",
                                     value: item.updatedAt > 0 ? FormatUtils.formatTimestamp(item.updatedAt) : "—")
                        }
                    }
                    .padding(14)
                }
                .background(Color.white).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Top-Up Details"), displayMode: .inline)
    }

    private func infoCell(label: String, value: String, valueColor: Color = .primary, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value)
                .font(mono ? .system(size: 14, weight: .bold, design: .monospaced) : .system(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TopUpItemRow: View {
    let item: TopUpItem

    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        switch item.status.lowercased() {
        case "completed":  return (teal, teal.opacity(0.12))
        case "skipped":    return (.gray, Color.gray.opacity(0.15))
        case "partial":    return (orange, orange.opacity(0.12))
        case "pending":    return (.goldDark, Color.gold.opacity(0.15))
        default:           return (.gray, Color.gray.opacity(0.12))
        }
    }

    private var date: String {
        item.createdAt > 0 ? FormatUtils.formatTimestamp(item.createdAt) : "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.receiptMerchant.isEmpty ? item.methodDisplay : item.receiptMerchant)
                        .font(.system(size: 14, weight: .bold)).lineLimit(2)
                    Text(date).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(FormatUtils.formatGBP(item.amount))
                        .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    let (fg, bg) = statusColors
                    Text(item.statusDisplay).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
                }
            }
            Divider()
            HStack(spacing: 10) {
                if let h = UsersData.byId[item.userId] {
                    ZStack {
                        Circle().fill(Color.gold.opacity(0.18)).frame(width: 24, height: 24)
                        Text(h.initials).font(.system(size: 9, weight: .bold)).foregroundColor(.goldDark)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(UsersData.byId[item.userId]?.fullName ?? (item.holderName.isEmpty ? "—" : item.holderName))
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(item.department.isEmpty ? "—" : item.department).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                if !item.cardLastFour.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard").font(.system(size: 9)).foregroundColor(.blue)
                        Text("•••• \(item.cardLastFour)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1)).cornerRadius(4)
                }
            }
            if !item.note.isEmpty {
                Text(item.note).font(.system(size: 10)).foregroundColor(.secondary).italic()
            }
        }
        .padding(14)
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

struct AllTransactionsRow: View {
    let tx: CardTransaction

    private var date: String {
        let ts = tx.transactionDate > 0 ? tx.transactionDate : tx.createdAt
        return ts > 0 ? FormatUtils.formatTimestamp(ts) : "—"
    }
    private var codeLabel: String {
        if tx.nominalCode.isEmpty { return "—" }
        if let m = costCodeOptions.first(where: { $0.0 == tx.nominalCode }) { return m.1 }
        return tx.nominalCode.uppercased()
    }
    private var holder: AppUser? { UsersData.byId[tx.holderId] }
    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        switch tx.status.lowercased() {
        case "approved", "matched", "coded": return (teal, teal.opacity(0.12))
        case "posted": return (teal, teal.opacity(0.12))
        case "pending", "pending_receipt": return (orange, orange.opacity(0.12))
        case "pending_coding", "pending_code": return (orange, orange.opacity(0.12))
        case "escalated": return (.red, Color.red.opacity(0.12))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private var deptText: String {
        if !tx.department.isEmpty { return tx.department }
        if let h = holder, !h.displayDepartment.isEmpty { return h.displayDepartment }
        return "—"
    }
    private var cardText: String {
        if !tx.cardLastFour.isEmpty { return "•••• \(tx.cardLastFour)" }
        return "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1 — merchant + amount + status
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tx.merchant.isEmpty ? "—" : tx.merchant)
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.primary).lineLimit(2)
                    Text(date).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(FormatUtils.formatGBP(tx.amount))
                        .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    let (fg, bg) = statusColors
                    Text(tx.statusDisplay).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
                }
            }

            Divider()

            // Row 2 — holder + dept + receipt
            HStack(spacing: 10) {
                if let h = holder {
                    ZStack {
                        Circle().fill(Color.gold.opacity(0.18)).frame(width: 24, height: 24)
                        Text(h.initials).font(.system(size: 9, weight: .bold)).foregroundColor(.goldDark)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(holder?.fullName ?? (tx.holderName.isEmpty ? "—" : tx.holderName))
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(deptText).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
            }

            // Row 3 — card + code chips
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "creditcard").font(.system(size: 9)).foregroundColor(.blue)
                    Text(cardText).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.blue)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.blue.opacity(0.1)).cornerRadius(4)

                HStack(spacing: 4) {
                    Image(systemName: "tag.fill").font(.system(size: 9)).foregroundColor(.goldDark)
                    Text(codeLabel).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.gold.opacity(0.1)).cornerRadius(4)
                Spacer()
            }
        }
        .padding(14)
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

struct CardRegisterPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var selectedCard: ExpenseCard?
    @State private var navigateToCardDetail = false
    @State private var navigateToRequestCard = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 12) {
                    if appState.userCards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "creditcard").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                            Text("No cards yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                            Text("Tap Request Card to add one").font(.system(size: 12)).foregroundColor(.gray)
                        }.frame(maxWidth: .infinity).padding(.vertical, 40)
                        .background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    } else {
                        ForEach(appState.userCards) { card in
                            Button(action: { selectedCard = card; navigateToCardDetail = true }) {
                                CardRow(card: card, isAccountant: true)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 90)
            }

            Button(action: { navigateToRequestCard = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Request Card").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.gold).cornerRadius(28)
            }
            .padding(.trailing, 20).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Card Register"), displayMode: .inline)
        .background(
            Group {
                NavigationLink(destination: Group {
                    if let c = selectedCard { CardDetailPage(card: c).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToCardDetail) { EmptyView() }.frame(width: 0, height: 0).hidden()

                NavigationLink(destination: RequestCardPage().environmentObject(appState),
                               isActive: $navigateToRequestCard) { EmptyView() }.frame(width: 0, height: 0).hidden()
            }
        )
        .onAppear { appState.loadUserCards() }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Tab 1: Receipts
// ═══════════════════════════════════════════════════════════════════

struct ReceiptsTabView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var searchText = ""
    @State private var activeFilter: ReceiptFilter = .all
    @State private var showFilterSheet = false
    @State private var navigateToDetail = false
    @State private var navigateToUpload = false
    @State private var navigateToAddCode = false
    @State private var selectedReceipt: Receipt?
    @State private var selectedTransaction: CardTransaction?
    @State private var navigateToTxDetail = false
    @State private var navigateToTxEdit = false
    @State private var codingReceipt: Receipt?
    @State private var deleteTarget: Receipt?
    @State private var showDeleteAlert = false

    private func statusMatches(_ t: CardTransaction, _ filter: ReceiptFilter) -> Bool {
        let s = t.status.lowercased()
        switch filter {
        case .all: return true
        case .pendingReceipt: return s == "pending" || s == "pending_receipt"
        case .pendingCode: return s == "pending_coding" || s == "pending_code"
        case .awaitingApproval: return s == "awaiting_approval"
        case .approved: return s == "approved" || s == "matched" || s == "coded"
        case .queried: return s == "queried"
        case .underReview: return s == "under_review"
        case .escalated: return s == "escalated"
        case .posted: return s == "posted"
        }
    }

    private func statusOrder(_ s: String) -> Int {
        switch s.lowercased() {
        case "pending", "pending_receipt": return 0
        case "pending_coding", "pending_code": return 1
        case "queried": return 2
        case "escalated": return 3
        case "under_review": return 4
        case "awaiting_approval": return 5
        case "approved", "matched", "coded": return 6
        case "posted": return 7
        default: return 8
        }
    }

    private var filtered: [CardTransaction] {
        var list = appState.myCardReceipts
        if activeFilter != .all { list = list.filter { statusMatches($0, activeFilter) } }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter { $0.merchant.lowercased().contains(q) || $0.description.lowercased().contains(q) || $0.holderName.lowercased().contains(q) }
        }
        return list.sorted { a, b in
            let oa = statusOrder(a.status)
            let ob = statusOrder(b.status)
            if oa != ob { return oa < ob }
            let da = a.transactionDate > 0 ? a.transactionDate : a.createdAt
            let db = b.transactionDate > 0 ? b.transactionDate : b.createdAt
            return da > db
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                // Filter + Search bar
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
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
                            .background(Color.white).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .compatActionSheet(title: "Filter by Status", isPresented: $showFilterSheet, buttons:
                            ReceiptFilter.allCases.map { filter in
                                let label = filter == activeFilter ? "\(filter.rawValue) ✓" : filter.rawValue
                                return CompatActionSheetButton.default(label) { activeFilter = filter }
                            } + [.cancel()]
                        )
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                        TextField("Search receipts…", text: $searchText).font(.system(size: 14))
                    }.padding(10).background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }
                .padding(.horizontal, 16).padding(.top, 12)

                ScrollView {
                    VStack(spacing: 10) {
                        if filtered.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No transactions found").font(.system(size: 13)).foregroundColor(.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 40)
                            .background(Color.white).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                        } else {
                            ForEach(filtered) { tx in
                                CardTransactionRow(
                                    transaction: tx,
                                    onTap: {
                                        selectedTransaction = tx
                                        navigateToTxDetail = true
                                    },
                                    onUploadTap: {
                                        selectedTransaction = tx
                                        navigateToTxEdit = true
                                    }
                                )
                            }
                        }
                    }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 80)
                }
            }

            // Floating upload button
            Button(action: { navigateToUpload = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Upload Receipt").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.gold).cornerRadius(28)
            }
            .padding(.trailing, 20).padding(.bottom, 24)
        }
        .background(
            Group {
                NavigationLink(destination: Group {
                    if let r = selectedReceipt { ReceiptDetailPage(receipt: r).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToDetail) { EmptyView() }.frame(width: 0, height: 0).hidden()

                NavigationLink(destination: Group {
                    if let tx = selectedTransaction { CardTransactionDetailPage(transaction: tx).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToTxDetail) { EmptyView() }.frame(width: 0, height: 0).hidden()

                NavigationLink(destination: Group {
                    if let tx = selectedTransaction { EditCardTransactionPage(transaction: tx).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToTxEdit) { EmptyView() }.frame(width: 0, height: 0).hidden()

                NavigationLink(destination: UploadReceiptPage().environmentObject(appState), isActive: $navigateToUpload) { EmptyView() }
                    .frame(width: 0, height: 0).hidden()

                NavigationLink(destination: Group {
                    if let r = codingReceipt { AddCodeLineItemsPage(receipt: r).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToAddCode) { EmptyView() }.frame(width: 0, height: 0).hidden()
            }
        )
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Receipt"),
                message: Text("Are you sure you want to delete \"\(deleteTarget?.originalName ?? "this receipt")\"? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let t = deleteTarget { appState.deleteReceipt(t) }
                    deleteTarget = nil
                },
                secondaryButton: .cancel { deleteTarget = nil }
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Tab 2: Card
// ═══════════════════════════════════════════════════════════════════

struct CardTabView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToRequestCard = false
    @State private var selectedCard: ExpenseCard?
    @State private var navigateToCardDetail = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 12) {
                    if appState.userCards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "creditcard").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                            Text("No cards yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                            Text("Request a new card to get started").font(.system(size: 12)).foregroundColor(.gray)
                        }.frame(maxWidth: .infinity).padding(.vertical, 40)
                        .background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    } else {
                        ForEach(appState.userCards) { card in
                            Button(action: {
                                selectedCard = card
                                navigateToCardDetail = true
                            }) {
                                CardRow(card: card, isAccountant: appState.currentUser?.isAccountant ?? false)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 80)
            }

            // Request new card button
            Button(action: { navigateToRequestCard = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Request Card").font(.system(size: 14, weight: .bold))
                }.foregroundColor(.black)
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.gold).cornerRadius(28)
            }.padding(.trailing, 20).padding(.bottom, 24)
        }
        .background(
            Group {
                NavigationLink(destination: RequestCardPage().environmentObject(appState), isActive: $navigateToRequestCard) { EmptyView() }
                    .frame(width: 0, height: 0).hidden()
                NavigationLink(destination: Group {
                    if let c = selectedCard { CardDetailPage(card: c).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToCardDetail) { EmptyView() }.frame(width: 0, height: 0).hidden()
            }
        )
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Detail Page
// ═══════════════════════════════════════════════════════════════════

struct CardDetailPage: View {
    let card: ExpenseCard
    @EnvironmentObject var appState: POViewModel

    private var statusColors: (Color, Color) {
        switch card.status {
        case "active": return (.green, Color.green.opacity(0.12))
        case "suspended": return (.red, Color.red.opacity(0.12))
        case "pending", "approved", "override": return (.goldDark, Color.gold.opacity(0.15))
        case "rejected": return (.red, Color.red.opacity(0.12))
        default: return (.gray, Color.gray.opacity(0.12))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "creditcard.fill").font(.system(size: 22)).foregroundColor(.goldDark)
                            .frame(width: 44, height: 44).background(Color.gold.opacity(0.15)).cornerRadius(8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.holderName.isEmpty ? "Card" : card.holderName)
                                .font(.system(size: 16, weight: .bold))
                            if !card.department.isEmpty {
                                Text(card.department).font(.system(size: 12)).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        let (fg, bg) = statusColors
                        Text(card.statusDisplay(isAccountant: appState.currentUser?.isAccountant ?? false))
                            .font(.system(size: 10, weight: .bold)).foregroundColor(fg)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(bg).cornerRadius(4)
                    }
                    if !card.lastFour.isEmpty {
                        Text("•••• •••• •••• \(card.lastFour)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    if !card.cardIssuer.isEmpty {
                        Text(card.cardIssuer.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundColor(.gray).tracking(0.5)
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                // Limits & balance
                VStack(spacing: 0) {
                    detailRow("Monthly Limit", FormatUtils.formatGBP(card.monthlyLimit))
                    Divider().padding(.leading, 14)
                    detailRow("Current Balance", FormatUtils.formatGBP(card.currentBalance))
                    if card.proposedLimit > 0 {
                        Divider().padding(.leading, 14)
                        detailRow("Proposed Limit", FormatUtils.formatGBP(card.proposedLimit))
                    }
                    Divider().padding(.leading, 14)
                    detailRow("Status", card.statusDisplay(isAccountant: appState.currentUser?.isAccountant ?? false))
                    if !card.holderName.isEmpty {
                        Divider().padding(.leading, 14)
                        detailRow("Cardholder", card.holderName)
                    }
                    if !card.department.isEmpty {
                        Divider().padding(.leading, 14)
                        detailRow("Department", card.department)
                    }
                }
                .background(Color.white).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Card Details"), displayMode: .inline)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).multilineTextAlignment(.trailing)
        }.padding(.horizontal, 14).padding(.vertical, 12)
    }
}

struct CardRow: View {
    let card: ExpenseCard
    var isAccountant: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top: card icon + status
            HStack {
                Image(systemName: "creditcard.fill").font(.system(size: 18)).foregroundColor(.goldDark)
                Spacer()
                let (fg, bg) = cardStatusColor(card.status)
                Text(card.statusDisplay(isAccountant: isAccountant)).font(.system(size: 10, weight: .semibold)).foregroundColor(fg)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
            }

            if card.status == "active" || card.status == "suspended" {
                // ── Active / Suspended Card ──
                // Card number
                HStack(spacing: 2) {
                    Text("•••• •••• ••••").font(.system(size: 15, design: .monospaced)).foregroundColor(.gray)
                    Text(card.lastFour.isEmpty ? "0000" : card.lastFour)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                }
                // Holder + designation
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.bankName.isEmpty {
                    Text(card.bankName).font(.system(size: 11)).foregroundColor(.secondary)
                }

                // BS Control
                if !card.bsControlCode.isEmpty {
                    HStack {
                        Text("BS Control").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text(card.bsControlCode).font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.bgRaised).cornerRadius(6)
                }

                // Limit / Spent
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit))/mo")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Spent").font(.system(size: 10)).foregroundColor(.secondary)
                        Text(FormatUtils.formatGBP(card.spentAmount))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                }
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.bgRaised).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(card.spendPercent > 0.8 ? Color(red: 0.91, green: 0.29, blue: 0.48) : Color.gold)
                            .frame(width: geo.size.width * CGFloat(min(card.spendPercent, 1.0)), height: 6)
                    }
                }.frame(height: 6)

            } else if card.status == "requested" {
                // ── Requested ──
                Text("Awaiting Review").font(.system(size: 13, design: .monospaced)).foregroundColor(.gray)
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                }
                if card.monthlyLimit > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }

            } else if card.status == "pending" || card.status == "approved" || card.status == "override" {
                // ── Pending Approval / Approved / In-Progress ──
                let displayLabel = card.statusDisplay(isAccountant: isAccountant)
                let color: Color = (card.status == "pending") ? .orange : isAccountant ? .green : .goldDark
                Text(displayLabel).font(.system(size: 13, design: .monospaced)).foregroundColor(color)
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                HStack(spacing: 4) {
                    if !card.holderDesignation.isEmpty { Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary) }
                    if !card.bankName.isEmpty { Text("· \(card.bankName)").font(.system(size: 11)).foregroundColor(.secondary) }
                }
                // BS Control
                if !card.bsControlCode.isEmpty {
                    HStack {
                        Text("BS Control").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text(card.bsControlCode).font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.bgRaised).cornerRadius(6)
                }
                if card.monthlyLimit > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }

            } else if card.status == "rejected" {
                // ── Rejected ──
                Text("Rejected").font(.system(size: 13, design: .monospaced)).foregroundColor(.red)
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                }
                if card.monthlyLimit > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }
                if let reason = card.rejectionReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REJECTION REASON").font(.system(size: 8, weight: .bold)).foregroundColor(Color(red: 0.91, green: 0.29, blue: 0.48)).tracking(0.4)
                        Text(reason).font(.system(size: 12)).foregroundColor(.primary)
                        if let rejBy = card.rejectedBy, !rejBy.isEmpty {
                            HStack(spacing: 4) {
                                Text("By \(UsersData.byId[rejBy]?.fullName ?? rejBy)").font(.system(size: 10)).foregroundColor(.secondary)
                                if let rejAt = card.rejectedAt, rejAt > 0 {
                                    Text("· \(FormatUtils.formatDateTime(rejAt))").font(.system(size: 10)).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.06)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.2), lineWidth: 1))
                }

            } else {
                // ── Other status ──
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
        }
        .padding(14).background(Color.white).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private func cardStatusColor(_ s: String) -> (Color, Color) {
        switch s {
        case "active": return (.green, Color.green.opacity(0.1))
        case "requested": return (.orange, Color.orange.opacity(0.1))
        case "pending": return (.goldDark, Color.gold.opacity(0.15))
        case "approved", "override": return isAccountant ? (.green, Color.green.opacity(0.1)) : (.goldDark, Color.gold.opacity(0.15))
        case "rejected": return (.red, Color.red.opacity(0.1))
        case "suspended": return (.gray, Color.gray.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

struct RequestCardPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var proposedLimit = ""
    @State private var submitting = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Icon header
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard.fill").font(.system(size: 40)).foregroundColor(.gold)
                        Text("Request New Card").font(.system(size: 18, weight: .bold))
                        Text("Your request will be sent to the accounts team for review and approval.")
                            .font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                    .background(Color.white).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                    // Form card
                    VStack(spacing: 0) {
                        formRow(label: "Card Holder", value: appState.currentUser?.fullName ?? "—")
                        Divider().padding(.leading, 14)
                        formRow(label: "Department", value: appState.currentUser?.displayDepartment ?? "—")
                        Divider().padding(.leading, 14)
                        formRow(label: "Designation", value: appState.currentUser?.displayDesignation ?? "—")
                        Divider().padding(.leading, 14)

                        // Proposed limit input
                        HStack {
                            Text("Proposed Limit").font(.system(size: 12)).foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 2) {
                                Text("£").font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark)
                                TextField("e.g. 1500", text: $proposedLimit)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.goldDark)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                            .padding(6).background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Info note
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill").font(.system(size: 14)).foregroundColor(.blue)
                        Text("The accounts team will assign the card issuer, set the final limit, and process your request through the approval chain.")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.04)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.15), lineWidth: 1))

                }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 80)
            }

            // Submit bar
            HStack(spacing: 12) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel").font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())

                Button(action: {
                    guard !submitting, let limit = Double(proposedLimit), limit > 0 else { return }
                    submitting = true
                    appState.requestNewCard(proposedLimit: limit)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(submitting ? "Submitting..." : "Submit Request")
                    }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Double(proposedLimit) ?? 0 > 0 && !submitting ? Color.gold : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(Double(proposedLimit) ?? 0 <= 0 || submitting)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.white)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Request New Card"), displayMode: .inline)
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

    private func formRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Tab 3: Cards for Approval
// ═══════════════════════════════════════════════════════════════════

struct CardsForApprovalTabView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var rejectTarget: ExpenseCard?
    @State private var rejectReason = ""
    @State private var showRejectSheet = false

    private var cards: [ExpenseCard] { appState.cardsForApproval() }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 12) {
                    if cards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                            Text("No cards pending approval").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 40)
                        .background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    } else {
                        ForEach(cards) { card in
                            ApprovalCardRow(card: card, tierConfigs: appState.cardTierConfigRows, onApprove: {
                                appState.approveCard(card)
                            }, onReject: {
                                rejectTarget = card; showRejectSheet = true
                            })
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
            }
        }
        .onAppear { appState.loadAllRequestedCards() }
        .sheet(isPresented: $showRejectSheet) {
            NavigationView {
                ZStack {
                    Color.bgBase.edgesIgnoringSafeArea(.all)
                    VStack(alignment: .leading, spacing: 16) {
                        if let c = rejectTarget {
                            Text("Reject card request from \(c.holderName)").font(.system(size: 15, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reason").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                            TextField("Enter reason…", text: $rejectReason)
                                .font(.system(size: 14)).padding(10)
                                .background(Color.white).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        Spacer()
                    }.padding()
                }
                .navigationBarTitle(Text("Reject Card"), displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") { showRejectSheet = false; rejectReason = "" }.foregroundColor(.goldDark),
                    trailing: Button("Reject") {
                        guard let c = rejectTarget, !rejectReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.rejectCard(c, reason: rejectReason.trimmingCharacters(in: .whitespaces))
                        showRejectSheet = false; rejectReason = ""; rejectTarget = nil
                    }.foregroundColor(.red).font(.system(size: 16, weight: .bold))
                )
            }
        }
    }
}

struct ApprovalCardRow: View {
    let card: ExpenseCard
    let tierConfigs: [ApprovalTierConfig]
    let onApprove: () -> Void
    let onReject: () -> Void

    private var totalTiers: Int {
        let cfg = ApprovalHelpers.resolveConfig(tierConfigs, deptId: card.departmentId, amount: card.monthlyLimit)
            ?? ApprovalHelpers.resolveConfig(tierConfigs, deptId: nil, amount: card.monthlyLimit)
            ?? ApprovalHelpers.resolveConfig(tierConfigs, deptId: nil)
        return ApprovalHelpers.getTotalTiers(cfg)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top: card icon + Pending (0/2) badge
            HStack {
                Image(systemName: "creditcard.fill").font(.system(size: 18)).foregroundColor(.goldDark)
                Spacer()
                Text("Pending (\(card.approvals.count)/\(totalTiers))")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.orange)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1)).cornerRadius(4)
            }

            // Status label
            Text("Pending Approval").font(.system(size: 13, design: .monospaced)).foregroundColor(.orange)

            // Holder name + designation + bank
            Text(card.holderFullName).font(.system(size: 15, weight: .bold))
            HStack(spacing: 4) {
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                }
                if !card.bankName.isEmpty {
                    Text("· \(card.bankName)").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }

            // BS Control
            if !card.bsControlCode.isEmpty {
                HStack {
                    Text("BS Control").font(.system(size: 11)).foregroundColor(.secondary)
                    Spacer()
                    Text(card.bsControlCode).font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.bgRaised).cornerRadius(8)
            }

            // Proposed Limit
            if card.monthlyLimit > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                    Text("\(FormatUtils.formatGBP(card.monthlyLimit))/mo")
                        .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                }
            }

            // Approval Chain circles (Level 1, Level 2, etc.)
            if totalTiers > 0 {
                HStack(spacing: 0) {
                    ForEach(1...totalTiers, id: \.self) { tier in
                        let isApproved = card.approvals.contains { $0.tierNumber == tier }
                        let isCurrent = !isApproved && (tier == 1 || card.approvals.contains { $0.tierNumber == tier - 1 })

                        if tier > 1 {
                            Rectangle()
                                .fill(card.approvals.contains { $0.tierNumber == tier - 1 } ? Color.green.opacity(0.4) : Color.gray.opacity(0.3))
                                .frame(width: 20, height: 2)
                        }

                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(isApproved ? Color.green : isCurrent ? Color.gold : Color.gray.opacity(0.25))
                                    .frame(width: 28, height: 28)
                                if isApproved {
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                } else if isCurrent {
                                    Circle().fill(Color.white).frame(width: 10, height: 10)
                                }
                            }
                            Text("Level \(tier)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(isApproved ? .green : isCurrent ? .goldDark : .gray)
                            if isApproved {
                                let approver = card.approvals.first { $0.tierNumber == tier }
                                let name = approver.flatMap { UsersData.byId[$0.userId]?.fullName } ?? ""
                                if !name.isEmpty {
                                    Text(name).font(.system(size: 8, weight: .medium)).foregroundColor(.green).lineLimit(1)
                                }
                            } else {
                                Text("Awaiting").font(.system(size: 8)).foregroundColor(isCurrent ? .goldDark : .gray)
                            }
                        }.frame(minWidth: 60)
                    }
                }
                .padding(.vertical, 4)
            }

            // Approve / Reject buttons
            HStack(spacing: 10) {
                Spacer()
                Button(action: onReject) {
                    Text("Reject").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.red).cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle())
                Button(action: onApprove) {
                    Text("Approve").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.green).cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(14).background(Color.white).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt Card (matches web card layout)
// ═══════════════════════════════════════════════════════════════════

struct ReceiptRow: View {
    let receipt: Receipt
    var onTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onViewReceipt: (() -> Void)? = nil
    var onAddCode: (() -> Void)? = nil
    @State private var showFileViewer = false

    private var isImageType: Bool {
        ["jpg", "jpeg", "png", "heic", "heif"].contains(receipt.fileType.lowercased())
    }

    private var thumbnailURL: URL? {
        guard isImageType, !receipt.filePath.isEmpty else { return nil }
        return URL(string: "\(CardExpenseRequest.baseURL)\(receipt.filePath)")
    }

    private var fileViewURL: URL? {
        guard !receipt.filePath.isEmpty else { return nil }
        return URL(string: "\(CardExpenseRequest.baseURL)\(receipt.filePath)")
    }

    private var titleText: String {
        let merchant = (receipt.merchantDetected ?? "").trimmingCharacters(in: .whitespaces)
        if !merchant.isEmpty { return merchant.uppercased() }
        let name = receipt.originalName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name.uppercased() }
        if !receipt.uploaderName.isEmpty { return receipt.uploaderName.uppercased() }
        return "RECEIPT"
    }

    private var amountValue: Double {
        if let a = receipt.amountDetected, let d = Double(a), d > 0 { return d }
        let dv = receipt.displayAmount
        return dv > 0 ? dv : 0
    }

    private var amountText: String {
        amountValue > 0 ? FormatUtils.formatGBP(amountValue) : "—"
    }

    private var dateText: String {
        if let d = receipt.dateDetected, !d.isEmpty { return d }
        if receipt.createdAt > 0 { return FormatUtils.formatTimestamp(receipt.createdAt) }
        return ""
    }

    private var subStatusText: String {
        switch receipt.matchStatus.lowercased() {
        case "approved", "matched", "coded": return "Approved — awaiting processing"
        case "posted": return "Posted to ledger"
        case "pending", "pending_receipt": return "Upload your receipt for this transaction"
        case "pending_coding", "pending_code": return "Pending budget coding"
        case "awaiting_approval": return "Awaiting approval"
        case "queried": return "Queried — please respond"
        case "under_review": return "Under review"
        case "escalated": return "Escalated for review"
        case "personal": return "Marked as personal"
        case "unmatched": return "No matching transaction found"
        default: return receipt.statusDisplay
        }
    }

    private var showUploadButton: Bool {
        let s = receipt.matchStatus.lowercased()
        return s == "pending" || s == "pending_receipt"
    }

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 8) {
                // Title row
                HStack(alignment: .top, spacing: 8) {
                    Text(titleText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    receiptStatusBadge
                }

                // Amount + date row
                HStack(spacing: 8) {
                    Text(amountText)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.goldDark)
                    if !dateText.isEmpty {
                        Text(dateText)
                            .font(.system(size: 11)).foregroundColor(.gray)
                    }
                    Spacer()
                }

                // Status sub-text
                Text(subStatusText)
                    .font(.system(size: 11)).foregroundColor(.secondary)

                // Uploader / file meta
                HStack(spacing: 6) {
                    if !receipt.uploaderName.isEmpty {
                        Text("by \(receipt.uploaderName)").font(.system(size: 10)).foregroundColor(.gray)
                    }
                    if !receipt.fileType.isEmpty {
                        Text("·").font(.system(size: 10)).foregroundColor(.gray)
                        Text(receipt.fileType.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundColor(.gray)
                    }
                    if !receipt.fileSizeDisplay.isEmpty {
                        Text("·").font(.system(size: 10)).foregroundColor(.gray)
                        Text(receipt.fileSizeDisplay).font(.system(size: 10)).foregroundColor(.gray)
                    }
                    Spacer()
                }

                // Footer action row (Upload Receipt + delete)
                if showUploadButton || (onDelete != nil && !["approved", "posted"].contains(receipt.matchStatus.lowercased())) {
                    HStack {
                        Spacer()
                        if showUploadButton {
                            Button(action: { onTap?() }) {
                                Text("Upload Receipt")
                                    .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Color.gold).cornerRadius(6)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        if let onDelete = onDelete, !["approved", "posted"].contains(receipt.matchStatus.lowercased()) {
                            Button(action: onDelete) {
                                Image(systemName: "trash").font(.system(size: 13)).foregroundColor(.gray)
                                    .padding(6)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusLabel: String {
        switch receipt.matchStatus.lowercased() {
        case "pending", "pending_receipt": return "Pending Receipt"
        case "pending_coding", "pending_code": return "Pending Code"
        case "awaiting_approval": return "Awaiting Approval"
        case "approved", "matched", "coded": return "Approved"
        case "queried": return "Queried"
        case "under_review": return "Under Review"
        case "escalated": return "Escalated"
        case "posted": return "Posted"
        case "personal": return "Personal"
        case "unmatched": return "Unmatched"
        case "duplicate": return "Duplicate"
        default: return receipt.statusDisplay
        }
    }

    private var statusBadgeColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        switch receipt.matchStatus.lowercased() {
        case "approved", "matched", "coded": return (teal, teal.opacity(0.12))
        case "posted": return (teal, teal.opacity(0.12))
        case "pending", "pending_receipt": return (orange, orange.opacity(0.12))
        case "pending_coding", "pending_code": return (orange, orange.opacity(0.12))
        case "awaiting_approval": return (.goldDark, Color.gold.opacity(0.15))
        case "queried": return (.purple, Color.purple.opacity(0.12))
        case "under_review": return (.blue, Color.blue.opacity(0.12))
        case "escalated": return (.red, Color.red.opacity(0.12))
        case "personal": return (.purple, Color.purple.opacity(0.12))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private var receiptStatusBadge: some View {
        let (fg, bg) = statusBadgeColors
        return Text(statusLabel).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 4).background(bg).cornerRadius(4)
    }

    private struct TagInfo: Hashable {
        let label: String; let icon: String?; let color: Color
        func hash(into hasher: inout Hasher) { hasher.combine(label) }
        static func == (lhs: TagInfo, rhs: TagInfo) -> Bool { lhs.label == rhs.label }
    }

    private var receiptTags: [TagInfo] {
        var tags: [TagInfo] = []
        if let type = receipt.uploadType {
            if type.contains("urgent") { tags.append(TagInfo(label: "Urgent", icon: "flame.fill", color: Color(red: 0.91, green: 0.29, blue: 0.48))) }
            if type.contains("topup") { tags.append(TagInfo(label: "Top-Up", icon: "wallet.pass.fill", color: Color(red: 0, green: 0.6, blue: 0.5))) }
        }
        if receipt.reassignCount > 0 {
            tags.append(TagInfo(label: receipt.reassignCount > 1 ? "Reassigned x\(receipt.reassignCount)" : "Reassigned",
                                icon: nil, color: .orange))
        }
        return tags
    }

    private func statusColors(_ s: String) -> (Color, Color) {
        switch s {
        case "pending": return (.orange, Color.orange.opacity(0.1))
        case "pending_coding": return (Color(red: 0.91, green: 0.29, blue: 0.48), Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.1))
        case "coded": return (.blue, Color.blue.opacity(0.1))
        case "matched": return (Color(red: 0, green: 0.6, blue: 0.5), Color(red: 0, green: 0.6, blue: 0.5).opacity(0.1))
        case "posted": return (.green, Color.green.opacity(0.1))
        case "unmatched": return (Color(red: 0.91, green: 0.29, blue: 0.48), Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.1))
        case "personal": return (Color(red: 0.91, green: 0.29, blue: 0.48), Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.1))
        case "duplicate": return (.purple, Color.purple.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt Detail Page
// ═══════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Transaction Row (matches web layout)
// ═══════════════════════════════════════════════════════════════════

struct CardTransactionRow: View {
    let transaction: CardTransaction
    var onTap: (() -> Void)? = nil
    var onUploadTap: (() -> Void)? = nil

    private var statusLabel: String { transaction.statusDisplay }

    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        switch transaction.status.lowercased() {
        case "approved", "matched", "coded": return (teal, teal.opacity(0.12))
        case "posted": return (teal, teal.opacity(0.12))
        case "pending", "pending_receipt": return (orange, orange.opacity(0.12))
        case "pending_coding", "pending_code": return (orange, orange.opacity(0.12))
        case "awaiting_approval": return (.goldDark, Color.gold.opacity(0.15))
        case "queried": return (.purple, Color.purple.opacity(0.12))
        case "under_review": return (.blue, Color.blue.opacity(0.12))
        case "escalated": return (.red, Color.red.opacity(0.12))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private var subStatusText: String {
        switch transaction.status.lowercased() {
        case "approved", "matched", "coded": return "Approved — awaiting processing"
        case "posted": return "Posted to ledger"
        case "pending", "pending_receipt": return "Upload your receipt for this transaction"
        case "pending_coding", "pending_code": return "Pending budget coding"
        case "awaiting_approval": return "Awaiting approval"
        case "queried": return "Queried — please respond"
        case "under_review": return "Under review"
        case "escalated": return "Escalated for review"
        default: return transaction.statusDisplay
        }
    }

    private var showUploadButton: Bool {
        let s = transaction.status.lowercased()
        return (s == "pending" || s == "pending_receipt") && !transaction.hasReceipt
    }

    private var titleText: String {
        let m = transaction.merchant.trimmingCharacters(in: .whitespaces)
        if !m.isEmpty { return m.uppercased() }
        if !transaction.description.isEmpty { return transaction.description.uppercased() }
        return "TRANSACTION"
    }

    private var dateText: String {
        let ts = transaction.transactionDate > 0 ? transaction.transactionDate : transaction.createdAt
        return ts > 0 ? FormatUtils.formatTimestamp(ts) : ""
    }

    @ViewBuilder
    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(titleText)
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.primary).lineLimit(2)
                    Spacer(minLength: 8)
                    let (fg, bg) = statusColors
                    Text(statusLabel).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(bg).cornerRadius(4)
                }

                HStack(spacing: 8) {
                    Text(FormatUtils.formatGBP(transaction.amount))
                        .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    if !dateText.isEmpty {
                        Text(dateText).font(.system(size: 11)).foregroundColor(.gray)
                    }
                    Spacer()
                }

                Text(subStatusText).font(.system(size: 11)).foregroundColor(.secondary)

                if showUploadButton {
                    HStack {
                        Spacer()
                        Button(action: { (onUploadTap ?? onTap)?() }) {
                            Text("Upload Receipt")
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.gold).cornerRadius(6)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
    }

    var body: some View {
        if let onTap = onTap {
            Button(action: onTap) { rowContent }.buttonStyle(PlainButtonStyle())
        } else {
            rowContent
        }
    }
}

// Disables the interactive swipe-back gesture on the parent UINavigationController
struct DisableSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Controller() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Controller: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            parent?.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            parent?.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Transaction Detail Page
// ═══════════════════════════════════════════════════════════════════

struct CardTransactionDetailPage: View {
    let transaction: CardTransaction
    var allowEdit: Bool = true
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var navigateToEdit = false

    private var live: CardTransaction {
        appState.cardTransactions.first(where: { $0.id == transaction.id }) ?? transaction
    }

    private var isLocked: Bool {
        let s = live.status.lowercased()
        return s == "approved" || s == "matched" || s == "coded" || s == "posted"
    }

    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        switch live.status.lowercased() {
        case "approved", "matched", "coded": return (teal, teal.opacity(0.12))
        case "posted": return (teal, teal.opacity(0.12))
        case "pending", "pending_receipt": return (orange, orange.opacity(0.12))
        case "pending_coding", "pending_code": return (orange, orange.opacity(0.12))
        case "awaiting_approval": return (.goldDark, Color.gold.opacity(0.15))
        case "queried": return (.purple, Color.purple.opacity(0.12))
        case "under_review": return (.blue, Color.blue.opacity(0.12))
        case "escalated": return (.red, Color.red.opacity(0.12))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private var dateText: String {
        let ts = live.transactionDate > 0 ? live.transactionDate : live.createdAt
        return ts > 0 ? FormatUtils.formatTimestamp(ts) : "—"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Summary card (everything inside a single card) ──
                    VStack(alignment: .leading, spacing: 0) {
                        // Header: title + status
                        HStack {
                            Text("Receipt Details").font(.system(size: 15, weight: .bold))
                            Spacer()
                            let (fg, bg) = statusColors
                            Text(live.statusDisplay).font(.system(size: 10, weight: .bold)).foregroundColor(fg)
                                .padding(.horizontal, 8).padding(.vertical, 4).background(bg).cornerRadius(4)
                        }
                        .padding(14)

                        Divider()

                        // Receipt preview
                        VStack(spacing: 10) {
                            Image(systemName: "doc.text").font(.system(size: 30)).foregroundColor(.gray.opacity(0.4))
                            Text(live.hasReceipt ? "Receipt attached" : "No receipt uploaded")
                                .font(.system(size: 11)).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 28)
                        .overlay(Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundColor(Color.borderColor))
                        .padding(14)

                        Divider()

                        // Info section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 14) {
                                infoCell(label: "MERCHANT", value: live.merchant.isEmpty ? "—" : live.merchant)
                                infoCell(label: "AMOUNT", value: FormatUtils.formatGBP(live.amount), valueColor: .goldDark, mono: true)
                            }
                            HStack(alignment: .top, spacing: 14) {
                                infoCell(label: "DATE", value: dateText)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("CARD HOLDER").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                                    Text(live.holderName.isEmpty ? "—" : live.holderName).font(.system(size: 13))
                                    if let u = UsersData.byId[live.holderId], !u.displayDesignation.isEmpty {
                                        Text(u.displayDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(14)

                        Divider()

                        // Description / Cost Code / Episode
                        HStack(alignment: .top, spacing: 14) {
                            infoCell(label: "DESCRIPTION", value: live.codeDescription.isEmpty ? "—" : live.codeDescription)
                            infoCell(label: "COST CODE",
                                     value: costCodeLabel(live.nominalCode),
                                     valueColor: .goldDark, mono: true)
                            infoCell(label: "EPISODE", value: live.episode.isEmpty ? "—" : live.episode)
                        }
                        .padding(14)

                        // Approval progress (always shown)
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("APPROVAL PROGRESS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            if !live.approvals.isEmpty {
                                ForEach(Array(live.approvals.enumerated()), id: \.offset) { _, a in
                                    approverRow(userId: a.userId, override: a.override)
                                }
                            } else if !live.approvedBy.isEmpty {
                                approverRow(userId: live.approvedBy, override: false)
                            } else {
                                Text("No approvals yet").font(.system(size: 11)).foregroundColor(.gray)
                            }
                        }.padding(14)

                        Divider()

                        // Submitted (always shown)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SUBMITTED").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Text(live.createdAt > 0 ? FormatUtils.formatTimestamp(live.createdAt) : "—").font(.system(size: 13))
                        }.padding(14)

                        // Line items (always shown — falls back to amount)
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LINE ITEMS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            VStack(spacing: 0) {
                                lineItemHeader
                                Divider()
                                let net = live.netAmount > 0 ? live.netAmount : live.amount
                                let tax = live.taxAmount
                                let gross = live.grossAmount > 0 ? live.grossAmount : live.amount
                                lineItemRow(
                                    code: live.nominalCode.isEmpty ? "—" : live.nominalCode.uppercased(),
                                    description: live.merchant.isEmpty ? (live.codeDescription.isEmpty ? "—" : live.codeDescription) : live.merchant,
                                    net: net, tax: tax, gross: gross, isDeduction: false
                                )
                            }
                            .background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }.padding(14)
                    }
                    .background(Color.white).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 90)
            }

            // Bottom bar with Edit Receipt button (hidden for approved/posted or when disabled)
            if allowEdit && !isLocked {
                VStack(spacing: 0) {
                    Rectangle().fill(Color.borderColor).frame(height: 1)
                    HStack {
                        Button(action: { navigateToEdit = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil").font(.system(size: 13, weight: .bold))
                                Text("Edit Receipt").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.gold)
                            .cornerRadius(10)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color(UIColor.systemGroupedBackground))
                }
            }
        }
        .navigationBarTitle(Text("Receipt Details"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                Text("Back").font(.system(size: 16))
            }.foregroundColor(.goldDark)
        })
        .background(DisableSwipeBack())
        .background(
            NavigationLink(destination: EditCardTransactionPage(transaction: live).environmentObject(appState),
                           isActive: $navigateToEdit) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.trailing).lineLimit(2)
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func infoCell(label: String, value: String, valueColor: Color = .primary, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value)
                .font(mono ? .system(size: 14, weight: .bold, design: .monospaced) : .system(size: 13))
                .foregroundColor(valueColor)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func costCodeLabel(_ code: String) -> String {
        if code.isEmpty { return "—" }
        if let m = costCodeOptions.first(where: { $0.0 == code }) { return m.1 }
        return code.uppercased()
    }

    private func approverRow(userId: String, override: Bool) -> some View {
        let user = UsersData.byId[userId]
        return HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.15)).frame(width: 20, height: 20)
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.purple)
            }
            Text(user?.fullName ?? userId).font(.system(size: 13, weight: .semibold))
            if let d = user?.displayDesignation, !d.isEmpty {
                Text("(\(d))").font(.system(size: 11)).foregroundColor(.secondary)
            }
            if override {
                Text("Override").font(.system(size: 9, weight: .bold)).foregroundColor(.purple)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.purple.opacity(0.12)).cornerRadius(4)
            }
            Spacer()
        }
    }

    private var lineItemHeader: some View {
        HStack(spacing: 8) {
            Text("CODE").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(width: 60, alignment: .leading)
            Text("DESCRIPTION").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(maxWidth: .infinity, alignment: .leading)
            Text("NET").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(width: 54, alignment: .trailing)
            Text("TAX").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(width: 48, alignment: .trailing)
            Text("GROSS").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(width: 58, alignment: .trailing)
        }.padding(.horizontal, 8).padding(.vertical, 6)
    }

    private func lineItemRow(code: String, description: String, net: Double, tax: Double, gross: Double, isDeduction: Bool) -> some View {
        HStack(spacing: 8) {
            Text(code).font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isDeduction ? .orange : .goldDark)
                .frame(width: 60, alignment: .leading).lineLimit(1)
            Text(description).font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
            Text(FormatUtils.formatGBP(net)).font(.system(size: 10, design: .monospaced)).foregroundColor(.goldDark).frame(width: 54, alignment: .trailing)
            Text(FormatUtils.formatGBP(tax)).font(.system(size: 10, design: .monospaced)).foregroundColor(.goldDark).frame(width: 48, alignment: .trailing)
            Text(FormatUtils.formatGBP(gross)).font(.system(size: 10, weight: .semibold, design: .monospaced)).frame(width: 58, alignment: .trailing)
        }.padding(.horizontal, 8).padding(.vertical, 8)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Edit Card Transaction Page (with Upload section)
// ═══════════════════════════════════════════════════════════════════

struct EditCardTransactionPage: View {
    let transaction: CardTransaction
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var merchant: String = ""
    @State private var amount: String = ""
    @State private var date: Date? = nil
    @State private var costCode: String = ""
    @State private var episode: String = ""
    @State private var codingDescription: String = ""
    @State private var fileName: String = ""
    @State private var fileData: Data?
    @State private var navigateToFilePicker = false
    @State private var showCodeSheet = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showError = false

    private var hasFile: Bool { fileData != nil && !fileName.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Upload section
                VStack(alignment: .leading, spacing: 8) {
                    Text("RECEIPT FILE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    if hasFile {
                        HStack(spacing: 8) {
                            Image(systemName: "paperclip").font(.system(size: 11)).foregroundColor(.green)
                            Text(fileName).font(.system(size: 12)).foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3)).lineLimit(1)
                            Spacer()
                            Button(action: { fileName = ""; fileData = nil }) {
                                Text("Remove").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 3).background(Color.red).cornerRadius(4)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(8).background(Color.green.opacity(0.06)).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))
                    } else {
                        Button(action: { navigateToFilePicker = true }) {
                            VStack(spacing: 6) {
                                Image(systemName: "arrow.up.doc").font(.system(size: 22)).foregroundColor(.gray.opacity(0.4))
                                Text("Upload receipt image or PDF").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                                Text("Tap to browse · JPG, PNG, PDF").font(.system(size: 10)).foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.bgRaised).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundColor(Color.borderColor))
                        }.buttonStyle(PlainButtonStyle())
                    }
                }

                // Merchant / Description
                field(label: "MERCHANT / DESCRIPTION", binding: $merchant, placeholder: "Merchant")

                // Amount + Date
                HStack(alignment: .top, spacing: 12) {
                    field(label: "AMOUNT", binding: $amount, placeholder: "0.00", keyboard: .decimalPad)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DATE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        if date != nil {
                            HStack {
                                DatePicker("", selection: Binding(
                                    get: { date ?? Date() },
                                    set: { date = $0 }
                                ), displayedComponents: .date).labelsHidden()
                                Button(action: { date = nil }) {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.gray)
                                }.buttonStyle(BorderlessButtonStyle())
                            }
                        } else {
                            Button(action: { date = Date() }) {
                                HStack {
                                    Text("dd/mm/yyyy").font(.system(size: 13)).foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "calendar").font(.system(size: 12)).foregroundColor(.goldDark)
                                }
                                .padding(8).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }

                // Budget Coding
                VStack(alignment: .leading, spacing: 10) {
                    Text("BUDGET CODING").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("COST CODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        Button(action: { showCodeSheet = true }) {
                            HStack {
                                Text(costCode.isEmpty ? "Select code..." : (costCodeOptions.first { $0.0 == costCode }?.1 ?? costCode))
                                    .font(.system(size: 13)).foregroundColor(costCode.isEmpty ? .gray : .primary)
                                Spacer()
                                Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                            }
                            .padding(8).background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }.buttonStyle(BorderlessButtonStyle())
                    }

                    HStack(spacing: 12) {
                        field(label: "EPISODE", binding: $episode, placeholder: "e.g. Ep.3")
                        field(label: "DESCRIPTION", binding: $codingDescription, placeholder: "Coding description")
                    }
                }
                .padding(12)
                .background(Color.white).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // Save button
                Button(action: save) {
                    HStack(spacing: 6) {
                        if isSaving { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(isSaving ? "Saving..." : "Save Receipt")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(isSaving ? Color.gold.opacity(0.4) : Color.gold)
                    .cornerRadius(10)
                }
                .disabled(isSaving)
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Edit Receipt"), displayMode: .inline)
        .background(
            NavigationLink(destination: ClaimFilePickerPage(onFilePicked: { name, data in
                fileName = name
                fileData = data
            }), isActive: $navigateToFilePicker) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(saveError ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
        .compatActionSheet(title: "Cost Code", isPresented: $showCodeSheet, buttons:
            ([CompatActionSheetButton.default("None") { costCode = "" }]
             + costCodeOptions.map { c in CompatActionSheetButton.default(c.1) { costCode = c.0 } })
            + [.cancel()]
        )
        .onAppear {
            merchant = transaction.merchant
            amount = transaction.amount > 0 ? String(transaction.amount) : ""
            if transaction.transactionDate > 0 {
                date = Date(timeIntervalSince1970: TimeInterval(transaction.transactionDate) / 1000)
            } else {
                date = nil
            }
            costCode = transaction.nominalCode
            episode = transaction.episode
            codingDescription = transaction.codeDescription.isEmpty ? transaction.notes : transaction.codeDescription
        }
    }

    private func field(label: String, binding: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
            TextField(placeholder, text: binding)
                .font(.system(size: 13)).keyboardType(keyboard)
                .padding(8).background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    private func save() {
        isSaving = true
        appState.updateCardTransaction(
            id: transaction.id,
            merchant: merchant,
            amount: amount,
            nominalCode: costCode,
            notes: codingDescription
        )
        // If a file was selected, upload it
        if let data = fileData, !fileName.isEmpty {
            uploadFile(data: data, name: fileName) { err in
                isSaving = false
                if let e = err { saveError = e; showError = true; return }
                appState.loadCardTransactions()
                presentationMode.wrappedValue.dismiss()
            }
        } else {
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func uploadFile(data: Data, name: String, completion: @escaping (String?) -> Void) {
        guard let user = appState.currentUser else { completion("No user"); return }
        let ext = (name as NSString).pathExtension.lowercased()
        let mimeType: String = {
            switch ext {
            case "pdf": return "application/pdf"
            case "png": return "image/png"
            default: return "image/jpeg"
            }
        }()
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "\(CardExpenseRequest.baseURL)/api/v2/card-expenses/receipts/upload") else {
            completion("Invalid URL"); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")

        var body = Data()
        func addField(_ k: String, _ v: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(v)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data); body.append("\r\n".data(using: .utf8)!)
        addField("userId", user.id)
        addField("uploaderName", user.fullName)
        addField("uploaderDepartment", user.displayDepartment)
        addField("transaction_id", transaction.id)
        addField("amount", amount)
        addField("description", merchant)
        if let d = date {
            addField("date", String(Int64(d.timeIntervalSince1970 * 1000)))
        }
        if !costCode.isEmpty { addField("nominal_code", costCode) }
        if !episode.isEmpty { addField("episode", episode) }
        if !codingDescription.isEmpty { addField("coded_description", codingDescription) }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { _, resp, err in
            DispatchQueue.main.async {
                if let err = err { completion(err.localizedDescription); return }
                if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    completion("Upload failed (\(http.statusCode))"); return
                }
                completion(nil)
            }
        }.resume()
    }
}

struct EditCardTransactionSheet: View {
    let transaction: CardTransaction
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var merchant: String = ""
    @State private var amount: String = ""
    @State private var nominalCode: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Receipt Details")) {
                    HStack {
                        Text("Merchant").foregroundColor(.secondary)
                        Spacer()
                        TextField("Merchant", text: $merchant).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Amount (£)").foregroundColor(.secondary)
                        Spacer()
                        TextField("0.00", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Nominal Code").foregroundColor(.secondary)
                        Spacer()
                        TextField("Code", text: $nominalCode).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Coding Description").foregroundColor(.secondary)
                        Spacer()
                        TextField("Notes", text: $notes).multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationBarTitle(Text("Edit Receipt"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Save") {
                    appState.updateCardTransaction(
                        id: transaction.id,
                        merchant: merchant,
                        amount: amount,
                        nominalCode: nominalCode,
                        notes: notes
                    )
                    presentationMode.wrappedValue.dismiss()
                }.font(.system(size: 16, weight: .bold))
            )
            .onAppear {
                merchant = transaction.merchant
                amount = transaction.amount > 0 ? String(transaction.amount) : ""
                nominalCode = transaction.nominalCode
                notes = transaction.notes
            }
        }
    }
}

enum ReceiptDetailSheet: String, Identifiable {
    case edit, document
    var id: String { rawValue }
}

struct EditReceiptDetailsSheet: View {
    let receipt: Receipt
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var merchant: String = ""
    @State private var amount: String = ""
    @State private var date: String = ""
    @State private var nominalCode: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Receipt Details")) {
                    HStack {
                        Text("Merchant").foregroundColor(.secondary)
                        Spacer()
                        TextField("Merchant", text: $merchant).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Amount (£)").foregroundColor(.secondary)
                        Spacer()
                        TextField("0.00", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Date").foregroundColor(.secondary)
                        Spacer()
                        TextField("DD MMM YYYY", text: $date).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Nominal Code").foregroundColor(.secondary)
                        Spacer()
                        TextField("Code", text: $nominalCode).multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationBarTitle(Text("Edit Details"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Save") {
                    appState.updateReceiptDetails(
                        id: receipt.id,
                        merchant: merchant,
                        amount: amount,
                        date: date,
                        nominalCode: nominalCode
                    )
                    presentationMode.wrappedValue.dismiss()
                }.font(.system(size: 16, weight: .bold))
            )
            .onAppear {
                merchant = receipt.merchantDetected ?? ""
                amount = receipt.amountDetected ?? ""
                date = receipt.dateDetected ?? ""
                nominalCode = receipt.nominalCode ?? ""
            }
        }
    }
}

struct ReceiptDetailPage: View {
    let receipt: Receipt
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var activeSheet: ReceiptDetailSheet?

    private var live: Receipt { appState.receipts.first(where: { $0.id == receipt.id }) ?? receipt }

    private var receiptDocumentURL: URL? {
        guard !live.filePath.isEmpty else { return nil }
        return URL(string: "\(CardExpenseRequest.baseURL)\(live.filePath)")
    }

    private var currentStep: Int {
        switch live.matchStatus {
        case "pending": return 0
        case "pending_coding": return 1
        case "coded": return 2
        case "matched": return 3
        case "posted": return 4
        default: return -1
        }
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

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 5-step progress flow
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Receipt Details").font(.system(size: 14, weight: .bold))
                            Spacer()
                        }
                        .padding(14)
                        Divider()
                        HStack(spacing: 0) {
                            stepDot(index: 0, label: "Submitted", sub: "Receipt sent")
                            stepDot(index: 1, label: "Coding", sub: "Budget coding")
                            stepDot(index: 2, label: "Coded", sub: "Audit & verify")
                            stepDot(index: 3, label: "Matched", sub: "Matched txn")
                            stepDot(index: 4, label: "Posted", sub: "Ledger / payment")
                        }
                        .padding(.horizontal, 10).padding(.vertical, 14)
                    }
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(live.displayMerchant).font(.system(size: 16, weight: .bold))
                            Spacer()
                            let sc = statusColor(live.matchStatus)
                            Text(live.statusDisplay).font(.system(size: 10, weight: .semibold)).foregroundColor(sc.0)
                                .padding(.horizontal, 8).padding(.vertical, 3).background(sc.1).cornerRadius(4)
                        }
                        HStack(spacing: 8) {
                            Button(action: { activeSheet = .document }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye.fill").font(.system(size: 10))
                                    Text("View Receipt").font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.goldDark)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.gold.opacity(0.12)).cornerRadius(4)
                            }.buttonStyle(BorderlessButtonStyle())

                            Button(action: { activeSheet = .edit }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil").font(.system(size: 10))
                                    Text("Edit Details").font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.goldDark).cornerRadius(4)
                            }.buttonStyle(BorderlessButtonStyle())
                        }

                        if live.displayAmount > 0 {
                            Text(FormatUtils.formatGBP(live.displayAmount))
                                .font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        }
                        HStack(spacing: 4) {
                            Text("by").font(.system(size: 11)).foregroundColor(.secondary)
                            Text(live.uploaderName).font(.system(size: 11, weight: .semibold))
                            if !live.uploaderDepartment.isEmpty {
                                Text("· \(live.uploaderDepartment)").font(.system(size: 11)).foregroundColor(.secondary)
                            }
                        }
                        HStack(spacing: 8) {
                            if !live.fileType.isEmpty {
                                Text(live.fileType.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundColor(.gray)
                                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.08)).cornerRadius(4)
                            }
                            if !live.fileSizeDisplay.isEmpty { Text(live.fileSizeDisplay).font(.system(size: 10)).foregroundColor(.secondary) }
                            if let t = live.uploadType, !t.isEmpty {
                                Text(t.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundColor(.blue)
                                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.blue.opacity(0.08)).cornerRadius(4)
                            }
                        }
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Details
                    VStack(spacing: 0) {
                        dRow("Merchant", live.merchantDetected ?? "—")
                        Divider().padding(.leading, 14)
                        dRow("Amount", live.amountDetected.map { "£\($0)" } ?? "—")
                        Divider().padding(.leading, 14)
                        dRow("Date", live.dateDetected ?? "—")
                        if let c = live.nominalCode, !c.isEmpty { Divider().padding(.leading, 14); dRow("Receipt Code", c) }
                        Divider().padding(.leading, 14)
                        dRow("File", live.originalName)
                        Divider().padding(.leading, 14)
                        dRow("Status", live.statusDisplay)
                    }.background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Line items
                    if !live.lineItems.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("LINE ITEMS (\(live.lineItems.count))").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                            ForEach(Array(live.lineItems.enumerated()), id: \.offset) { idx, li in
                                HStack {
                                    if let c = li.code, !c.isEmpty {
                                        Text(c).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.blue)
                                            .padding(.horizontal, 4).padding(.vertical, 1).background(Color.blue.opacity(0.08)).cornerRadius(3)
                                    }
                                    Text(li.description ?? "—").font(.system(size: 11)).lineLimit(1)
                                    Spacer()
                                    Text(FormatUtils.formatGBP(li.amountValue)).font(.system(size: 11, weight: .medium, design: .monospaced))
                                }.padding(.horizontal, 14).padding(.vertical, 6)
                                if idx < live.lineItems.count - 1 { Divider().padding(.horizontal, 14) }
                            }
                            Divider().padding(.horizontal, 14)
                            HStack { Spacer(); Text("Total: ").font(.system(size: 12, weight: .semibold))
                                Text(FormatUtils.formatGBP(live.lineItems.reduce(0) { $0 + $1.amountValue }))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                            }.padding(.horizontal, 14).padding(.vertical, 8)
                        }.background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    // History
                    if !live.history.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("HISTORY").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                            ForEach(Array(live.history.enumerated()), id: \.offset) { idx, entry in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle().fill(Color.goldDark).frame(width: 8, height: 8).padding(.top, 4)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.action ?? "").font(.system(size: 12, weight: .semibold))
                                        if let d = entry.details, !d.isEmpty { Text(d).font(.system(size: 10)).foregroundColor(.secondary) }
                                        if let ts = entry.timestamp, ts > 0 { Text(FormatUtils.formatDateTime(ts)).font(.system(size: 9)).foregroundColor(.gray) }
                                    }
                                    Spacer()
                                }.padding(.horizontal, 14).padding(.vertical, 6)
                            }
                        }.background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }
                }.padding(.horizontal, 16).padding(.top, 14)
                .padding(.bottom, (live.matchStatus == "pending" && appState.currentUser?.isAccountant == true) ? 80 : 24)
            }

            if live.matchStatus == "pending" && appState.currentUser?.isAccountant == true {
                HStack(spacing: 10) {
                    Button(action: { appState.flagReceiptPersonal(live); presentationMode.wrappedValue.dismiss() }) {
                        Text("Flag Personal").font(.system(size: 13, weight: .bold)).foregroundColor(.purple)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                    Spacer()
                    Button(action: { appState.confirmReceipt(live); presentationMode.wrappedValue.dismiss() }) {
                        Text("Confirm").font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                            .padding(.horizontal, 20).padding(.vertical, 10).background(Color.gold).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())
                }.padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(UIColor.systemGroupedBackground))
                .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
            }
        }
        .navigationBarTitle(Text("Receipt Detail"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)); Text("Back").font(.system(size: 16)) }.foregroundColor(.goldDark)
            }
        )
        .sheet(item: $activeSheet) { sheet in
            if sheet == .edit {
                EditReceiptDetailsSheet(receipt: live).environmentObject(appState)
            } else if let docURL = receiptDocumentURL {
                ReceiptDocumentViewerSheet(url: docURL, fileName: live.originalName)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill").font(.system(size: 36)).foregroundColor(.gray)
                    Text("No document available").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
                    Text("This receipt does not have an uploaded file.").font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.center)
                    Button("Close") { activeSheet = nil }
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.goldDark).padding(.top, 8)
                }.padding(32)
            }
        }
    }

    private func dRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).font(.system(size: 12)).foregroundColor(.secondary); Spacer(); Text(value).font(.system(size: 12, weight: .semibold)).lineLimit(1) }
            .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func statusColor(_ s: String) -> (Color, Color) {
        switch s {
        case "pending", "pending_coding": return (.orange, Color.orange.opacity(0.1))
        case "coded": return (.blue, Color.blue.opacity(0.1))
        case "matched": return (Color(red: 0, green: 0.6, blue: 0.5), Color(red: 0, green: 0.6, blue: 0.5).opacity(0.1))
        case "posted": return (.green, Color.green.opacity(0.1))
        case "unmatched": return (Color(red: 0.91, green: 0.29, blue: 0.48), Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.1))
        case "personal": return (.purple, Color.purple.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Add Code & Line Items Page
// ═══════════════════════════════════════════════════════════════════

struct CodingLineItem: Identifiable {
    let id = UUID()
    var description: String = ""
    var amount: String = ""
    var code: String = ""
}

struct AddCodeLineItemsPage: View {
    let receipt: Receipt
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var nominalCode: String = ""
    @State private var lineItems: [CodingLineItem] = [CodingLineItem()]
    @State private var isSaving = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Receipt info card
                    receiptInfoCard

                    // Receipt Code
                    receiptCodeSection

                    // Extracted Items
                    lineItemsSection
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 80)
            }

            // Bottom bar: Cancel + Save Coding
            HStack(spacing: 12) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel").font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())

                Button(action: saveCoding) {
                    HStack(spacing: 6) {
                        if isSaving { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(isSaving ? "Saving..." : "Save Coding")
                    }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(!isSaving && !nominalCode.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gold : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isSaving || nominalCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.white)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Add Code & Line Items"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .onAppear { prefillFromReceipt() }
    }

    // MARK: - Receipt Info

    private var receiptInfoCard: some View {
        VStack(spacing: 0) {
            Text(receipt.originalName.isEmpty ? "Receipt" : receipt.originalName)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            Divider()

            infoRow("Merchant", receipt.merchantDetected ?? "—")
            Divider().padding(.leading, 14)
            infoRow("Amount", receipt.amountDetected.map { "£\($0)" } ?? "—")
            Divider().padding(.leading, 14)
            infoRow("Date", receipt.dateDetected ?? FormatUtils.formatTimestamp(receipt.createdAt))
            Divider().padding(.leading, 14)
            infoRow("File", "\(receipt.fileType.uppercased()) · \(receipt.fileSizeDisplay)")
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(.primary).lineLimit(1)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: - Receipt Code

    private var receiptCodeSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Receipt Code").font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                if let existing = receipt.nominalCode, !existing.isEmpty {
                    Text("Extracted: \(existing)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 0.6, blue: 0.5))
                }
                TextField("e.g. 5010", text: $nominalCode)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.goldDark)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(6).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("EXTRACTED ITEMS (\(lineItems.count))")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                Spacer()
                Button(action: { lineItems.append(CodingLineItem()) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Add Line").font(.system(size: 11, weight: .semibold))
                    }.foregroundColor(.goldDark)
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            // Column headers
            HStack(spacing: 0) {
                Text("ITEM NAME").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("TOTAL").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                    .frame(width: 70, alignment: .trailing)
                Text("CODE").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                    .frame(width: 60, alignment: .leading).padding(.leading, 8)
                if lineItems.count > 1 { Spacer().frame(width: 28) }
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Color.bgRaised)

            Divider()

            // Editable rows
            ForEach(lineItems) { item in
                let isLast = item.id == lineItems.last?.id
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        TextField("Item name", text: bindingForField(item.id, \.description))
                            .font(.system(size: 12)).foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                        TextField("0.00", text: bindingForField(item.id, \.amount))
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(.primary)
                            .multilineTextAlignment(.trailing).keyboardType(.decimalPad)
                            .frame(width: 70)
                        TextField("Code", text: bindingForField(item.id, \.code))
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(.goldDark)
                            .frame(width: 60).padding(.leading, 8)
                        if lineItems.count > 1 {
                            Button(action: { removeLine(item.id) }) {
                                Image(systemName: "minus.circle.fill").font(.system(size: 14)).foregroundColor(.red.opacity(0.6))
                            }.buttonStyle(BorderlessButtonStyle()).frame(width: 28)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    if !isLast { Divider().padding(.horizontal, 14) }
                }
            }

            // Total row
            Divider()
            HStack {
                Text("Total").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                Spacer()
                let total = lineItems.reduce(0.0) { $0 + (Double($1.amount) ?? 0) }
                Text(FormatUtils.formatGBP(total))
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Actions

    private func bindingForField(_ id: UUID, _ keyPath: WritableKeyPath<CodingLineItem, String>) -> Binding<String> {
        Binding<String>(
            get: { lineItems.first(where: { $0.id == id })?[keyPath: keyPath] ?? "" },
            set: { newValue in
                if let idx = lineItems.firstIndex(where: { $0.id == id }) {
                    lineItems[idx][keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func removeLine(_ id: UUID) {
        lineItems.removeAll { $0.id == id }
    }

    private func prefillFromReceipt() {
        nominalCode = receipt.nominalCode ?? ""
        if !receipt.lineItems.isEmpty {
            lineItems = receipt.lineItems.map { li in
                CodingLineItem(
                    description: li.description ?? "",
                    amount: li.amountValue > 0 ? String(format: "%.2f", li.amountValue) : "",
                    code: li.code ?? ""
                )
            }
        } else {
            lineItems = [CodingLineItem()]
        }
    }

    private func saveCoding() {
        guard !nominalCode.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true
        let items: [[String: Any]] = lineItems.filter { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty }.map {
            ["description": $0.description, "amount": Double($0.amount) ?? 0, "code": $0.code] as [String: Any]
        }
        appState.submitReceiptCoding(receipt, nominalCode: nominalCode.trimmingCharacters(in: .whitespaces), lineItems: items) { success in
            isSaving = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Upload Receipt Page
// ═══════════════════════════════════════════════════════════════════

struct ReceiptDraft: Identifiable {
    let id = UUID()
    var fileName: String = ""
    var fileData: Data?
    var date: Date? = nil
    var amount: String = ""
    var description: String = ""
    var category: String = "materials"
    var isUrgent: Bool = false
    var requestTopUp: Bool = false
    var budgetCode: String = ""
    var episode: String = ""
    var codedDescription: String = ""
    var budgetCodingExpanded: Bool = false

    var hasFile: Bool { fileData != nil && !fileName.isEmpty }
    var displayFileName: String { fileName }
}

struct UploadReceiptPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var drafts: [ReceiptDraft] = [ReceiptDraft()]
    @State private var activeDraftIdx: Int = 0
    @State private var navigateToFilePicker = false
    @State private var showCategorySheet = false
    @State private var showCodeSheet = false

    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showError = false

    private var canSubmit: Bool {
        drafts.allSatisfy { d in
            d.hasFile && !d.amount.isEmpty && !d.description.isEmpty && (Double(d.amount) ?? 0) > 0 && d.date != nil
        }
    }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add Your Receipts").font(.system(size: 18, weight: .bold))
                        Text("Upload receipts for your card expenses").font(.system(size: 12)).foregroundColor(.secondary)
                    }

                    // Receipt cards
                    ForEach(drafts.indices, id: \.self) { idx in
                        receiptCard(idx: idx)
                    }

                    // Add Another Receipt
                    Button(action: { drafts.append(ReceiptDraft()) }) {
                        Text("+ Add Another Receipt")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.white).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundColor(Color.borderColor))
                    }.buttonStyle(BorderlessButtonStyle())

                    // Submit
                    Button(action: submitAll) {
                        HStack(spacing: 6) {
                            if isUploading { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                            Text(isUploading ? "Uploading..." : "Submit Receipts")
                        }
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(canSubmit && !isUploading ? Color.gold : Color.gold.opacity(0.4))
                        .cornerRadius(10)
                    }
                    .disabled(!canSubmit || isUploading)
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 30)
            }
        }
        .navigationBarTitle(Text("Add Your Receipts"), displayMode: .inline)
        .background(
            NavigationLink(destination: ClaimFilePickerPage(onFilePicked: { name, data in
                if drafts.indices.contains(activeDraftIdx) {
                    drafts[activeDraftIdx].fileName = name
                    drafts[activeDraftIdx].fileData = data
                }
            }), isActive: $navigateToFilePicker) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(uploadError ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
        .compatActionSheet(title: "Category", isPresented: $showCategorySheet, buttons:
            claimCategories.map { c in
                CompatActionSheetButton.default(c.1) {
                    if drafts.indices.contains(activeDraftIdx) { drafts[activeDraftIdx].category = c.0 }
                }
            } + [.cancel()]
        )
        .compatActionSheet(title: "Budget Code", isPresented: $showCodeSheet, buttons:
            ([CompatActionSheetButton.default("None") {
                if drafts.indices.contains(activeDraftIdx) { drafts[activeDraftIdx].budgetCode = "" }
            }] + costCodeOptions.map { c in
                CompatActionSheetButton.default(c.1) {
                    if drafts.indices.contains(activeDraftIdx) { drafts[activeDraftIdx].budgetCode = c.0 }
                }
            }) + [.cancel()]
        )
    }

    @ViewBuilder
    private func receiptCard(idx: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("RECEIPT \(idx + 1)").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                Spacer()
                if drafts.count > 1 {
                    Button(action: { drafts.remove(at: idx) }) {
                        Text("Remove").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(Color.red).cornerRadius(4)
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }

            // File upload
            if drafts[idx].hasFile {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip").font(.system(size: 11)).foregroundColor(.green)
                    Text(drafts[idx].displayFileName).font(.system(size: 12)).foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3)).lineLimit(1)
                    Spacer()
                    Button(action: {
                        drafts[idx].fileName = ""
                        drafts[idx].fileData = nil
                    }) {
                        Text("Remove").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3).background(Color.red).cornerRadius(4)
                    }.buttonStyle(BorderlessButtonStyle())
                }
                .padding(8).background(Color.green.opacity(0.06)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))
            } else {
                Button(action: { activeDraftIdx = idx; navigateToFilePicker = true }) {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.up.doc").font(.system(size: 22)).foregroundColor(.gray.opacity(0.4))
                        Text("Upload receipt image or PDF").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        Text("Tap to browse · JPG, PNG, PDF").font(.system(size: 10)).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.bgRaised).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundColor(Color.borderColor))
                }.buttonStyle(PlainButtonStyle())
            }

            // Date + Amount
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date of Purchase *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    if drafts[idx].date != nil {
                        HStack {
                            DatePicker("", selection: Binding(
                                get: { drafts[idx].date ?? Date() },
                                set: { drafts[idx].date = $0 }
                            ), in: ...Date(), displayedComponents: .date).labelsHidden()
                            Button(action: { drafts[idx].date = nil }) {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.gray)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    } else {
                        Button(action: { drafts[idx].date = Date() }) {
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
                    TextField("£0.00", text: Binding(get: { drafts[idx].amount }, set: { drafts[idx].amount = $0 }))
                        .font(.system(size: 13, design: .monospaced)).keyboardType(.decimalPad)
                        .padding(8).background(Color.bgRaised).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }
            }

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Description *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                TextField("What did you purchase?", text: Binding(get: { drafts[idx].description }, set: { drafts[idx].description = $0 }))
                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }

            // Category
            VStack(alignment: .leading, spacing: 4) {
                Text("Category").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                Button(action: { activeDraftIdx = idx; showCategorySheet = true }) {
                    HStack {
                        Text(claimCategories.first { $0.0 == drafts[idx].category }?.1 ?? "Materials")
                            .font(.system(size: 13)).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                    }
                    .padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())
            }

            // Mark as urgent / Request top-up
            HStack(spacing: 18) {
                Toggle(isOn: Binding(get: { drafts[idx].isUrgent }, set: { drafts[idx].isUrgent = $0 })) {
                    Text("Mark as urgent").font(.system(size: 12))
                }.toggleStyle(CheckboxToggleStyle())
                Toggle(isOn: Binding(get: { drafts[idx].requestTopUp }, set: { drafts[idx].requestTopUp = $0 })) {
                    Text("Request top-up").font(.system(size: 12))
                }.toggleStyle(CheckboxToggleStyle())
                Spacer()
            }

            // Budget Coding (collapsible)
            VStack(spacing: 0) {
                Button(action: { drafts[idx].budgetCodingExpanded.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: drafts[idx].budgetCodingExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8)).foregroundColor(.gray)
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                        Text("Budget Coding").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.secondary)
                        Text("Optional — leave blank if unsure").font(.system(size: 10)).foregroundColor(.gray)
                        Spacer()
                        if !drafts[idx].budgetCode.isEmpty {
                            Text(drafts[idx].budgetCode).font(.system(size: 10, design: .monospaced)).foregroundColor(.green)
                        }
                    }
                    .padding(10).background(Color.bgRaised).contentShape(Rectangle())
                }.buttonStyle(PlainButtonStyle())

                if drafts[idx].budgetCodingExpanded {
                    VStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COST CODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Button(action: { activeDraftIdx = idx; showCodeSheet = true }) {
                                HStack {
                                    Text(drafts[idx].budgetCode.isEmpty ? "Select code" : (costCodeOptions.first { $0.0 == drafts[idx].budgetCode }?.1 ?? drafts[idx].budgetCode))
                                        .font(.system(size: 13)).foregroundColor(drafts[idx].budgetCode.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                                }
                                .padding(8).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("EPISODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                                TextField("e.g. Ep.3", text: Binding(get: { drafts[idx].episode }, set: { drafts[idx].episode = $0 }))
                                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DESCRIPTION").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                                TextField("Coding description (optional)", text: Binding(get: { drafts[idx].codedDescription }, set: { drafts[idx].codedDescription = $0 }))
                                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                        }
                    }
                    .padding(10)
                    .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
                }
            }
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
        }
        .padding(12).background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func submitAll() {
        guard canSubmit else { return }
        isUploading = true
        let group = DispatchGroup()
        var firstError: String?
        for d in drafts {
            group.enter()
            uploadOne(d) { err in
                if let e = err, firstError == nil { firstError = e }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            isUploading = false
            if let e = firstError { uploadError = e; showError = true; return }
            appState.loadCardTransactions()
            appState.loadCardExpenseReceipts()
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func uploadOne(_ d: ReceiptDraft, completion: @escaping (String?) -> Void) {
        guard let user = appState.currentUser else { completion("No user"); return }
        guard let data = d.fileData else { completion("Failed to read file"); return }
        let fileName = d.fileName.isEmpty ? "receipt.jpg" : d.fileName
        let ext = (fileName as NSString).pathExtension.lowercased()
        let mimeType: String = {
            switch ext {
            case "pdf": return "application/pdf"
            case "png": return "image/png"
            case "heic", "heif": return "image/heic"
            default: return "image/jpeg"
            }
        }()

        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "\(CardExpenseRequest.baseURL)/api/v2/card-expenses/receipts/upload") else {
            completion("Invalid URL"); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")

        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data); body.append("\r\n".data(using: .utf8)!)
        addField("userId", user.id)
        addField("uploaderName", user.fullName)
        addField("uploaderDepartment", user.displayDepartment)
        addField("amount", d.amount)
        addField("description", d.description)
        addField("category", d.category)
        if let dt = d.date {
            addField("date", String(Int64(dt.timeIntervalSince1970 * 1000)))
        }
        if !d.budgetCode.isEmpty { addField("nominal_code", d.budgetCode) }
        if !d.episode.isEmpty { addField("episode", d.episode) }
        if !d.codedDescription.isEmpty { addField("coded_description", d.codedDescription) }
        if d.isUrgent { addField("uploadType", "urgent") }
        if d.requestTopUp { addField("uploadType", "topup") }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { _, response, error in
            DispatchQueue.main.async {
                if let error = error { completion(error.localizedDescription); return }
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    completion("Upload failed (\(http.statusCode))"); return
                }
                completion(nil)
            }
        }.resume()
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
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14)).foregroundColor(configuration.isOn ? .goldDark : .gray)
                configuration.label
            }
        }.buttonStyle(BorderlessButtonStyle())
    }
}

// MARK: - Receipt Image Picker

struct ReceiptImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .photoLibrary; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ReceiptImagePicker
        init(_ parent: ReceiptImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage; parent.isPresented = false
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.isPresented = false }
    }
}

// MARK: - Receipt Camera Page

struct ReceiptCameraPage: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isActive: Bool
    var onCapture: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ReceiptCameraPage
        init(_ parent: ReceiptCameraPage) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage; parent.isActive = false; parent.onCapture()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.isActive = false }
    }
}

struct ReceiptCameraPageWrapper: View {
    @Binding var selectedImage: UIImage?
    @Binding var isActive: Bool
    var onCapture: () -> Void
    var body: some View {
        ReceiptCameraPage(selectedImage: $selectedImage, isActive: $isActive, onCapture: onCapture)
            .edgesIgnoringSafeArea(.all).navigationBarTitle("", displayMode: .inline).navigationBarHidden(true)
    }
}

// MARK: - Receipt Document Picker

struct ReceiptDocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileName: String?
    @Binding var selectedFileURL: URL?
    @Binding var isPresented: Bool
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            p = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .jpeg, .png, .image], asCopy: true)
        } else {
            p = UIDocumentPickerViewController(documentTypes: ["public.pdf", "public.jpeg", "public.png", "public.image"], in: .import)
        }
        p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: ReceiptDocumentPicker
        init(_ parent: ReceiptDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                guard ["pdf", "jpg", "jpeg", "png", "heic", "heif"].contains(url.pathExtension.lowercased()) else { parent.isPresented = false; return }
                parent.selectedFileURL = url; parent.selectedFileName = url.lastPathComponent
            }
            parent.isPresented = false
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { parent.isPresented = false }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt Thumbnail (async image loader, iOS 13 compatible)
// ═══════════════════════════════════════════════════════════════════

class ReceiptImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var failed = false

    func load(url: URL) {
        var request = URLRequest(url: url)
        request.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let data = data, let img = UIImage(data: data) {
                    self?.image = img
                } else {
                    self?.failed = true
                }
            }
        }.resume()
    }
}

struct ReceiptThumbnailView: View {
    let url: URL
    @ObservedObject private var loader = ReceiptImageLoader()

    var body: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable().scaledToFill()
            } else if loader.failed {
                Image(systemName: "photo.fill")
                    .font(.system(size: 28)).foregroundColor(.gray.opacity(0.4))
            } else {
                ActivityIndicator(isAnimating: true).frame(width: 20, height: 20)
            }
        }
        .onAppear { loader.load(url: url) }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt Document Viewer (PDF / Image)
// ═══════════════════════════════════════════════════════════════════

struct ReceiptDocumentViewerSheet: View {
    let url: URL
    var fileName: String = "Receipt"
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ReceiptWebViewContent(url: url)
                .edgesIgnoringSafeArea(.bottom)
                .navigationBarTitle(Text(fileName), displayMode: .inline)
                .navigationBarItems(trailing:
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark)
                )
        }
    }
}

struct ReceiptWebViewContent: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .systemGroupedBackground
        var request = URLRequest(url: url)
        request.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
