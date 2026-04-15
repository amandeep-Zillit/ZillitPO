//
//  CardExpensesModuleView.swift
//  ZillitPO
//

import SwiftUI
import WebKit

// MARK: - Tabs

enum CardExpenseTab: String, CaseIterable, Identifiable {
    case receipts = "My Transactions"
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

    private var isCoordinator: Bool { appState.cardExpenseMeta.isCoordinator }

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
                    // Tab bar — full width for user/approver, scrollable for coordinator
                    if isCoordinator {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(visibleTabs) { tab in
                                    cardTabButton(tab)
                                }
                            }
                        }
                        .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)
                    } else {
                        HStack(spacing: 0) {
                            ForEach(visibleTabs) { tab in
                                cardTabButton(tab).frame(maxWidth: .infinity)
                            }
                        }
                        .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)
                    }

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

    @ViewBuilder
    private func cardTabButton(_ tab: CardExpenseTab) -> some View {
        let isActive = activeTab == tab
        Button(action: { activeTab = tab }) {
            HStack(spacing: 4) {
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                if tab == .approval {
                    let count = appState.cardsForApproval().count
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.goldDark).cornerRadius(8)
                    }
                }
            }
            .foregroundColor(isActive ? .goldDark : .secondary)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .contentShape(Rectangle())
            .overlay(isActive ? Rectangle().fill(Color.goldDark).frame(height: 2) : nil, alignment: .bottom)
        }.buttonStyle(BorderlessButtonStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Expenses — Accountant Hub
// ═══════════════════════════════════════════════════════════════════

struct CardExpensesAccountantHub: View {
    @EnvironmentObject var appState: POViewModel

    private var meta: CardExpenseMeta { appState.cardExpenseMeta }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                hubTile(icon: "creditcard.fill", color: .goldDark, title: "Card Register",
                        subtitle: "View & manage company cards",
                        count: meta.cardRegister > 0 ? meta.cardRegister : appState.userCards.count,
                        destination: AnyView(CardRegisterPage().environmentObject(appState)))

                hubTile(icon: "tray.full.fill", color: .orange, title: "Receipt Inbox",
                        subtitle: "Receipts awaiting transaction match",
                        count: meta.receiptInbox,
                        destination: AnyView(ReceiptInboxPage().environmentObject(appState)))

                hubTile(icon: "list.bullet.rectangle.fill", color: .blue, title: "All Transactions",
                        subtitle: "Every card transaction",
                        count: meta.allTransactions,
                        destination: AnyView(AllTransactionsPage().environmentObject(appState)))

                hubTile(icon: "clock.badge.exclamationmark.fill", color: .purple, title: "Pending Coding",
                        subtitle: "Receipts awaiting budget coding",
                        count: meta.pendingCoding,
                        destination: AnyView(PendingCodingPage().environmentObject(appState)))

                hubTile(icon: "person.badge.shield.checkmark.fill", color: .goldDark, title: "Approval Queue",
                        subtitle: "Awaiting your approval",
                        count: meta.approvalQueue,
                        destination: AnyView(AccountantApprovalQueuePage().environmentObject(appState)))

                hubTile(icon: "wallet.pass.fill", color: Color(red: 0, green: 0.6, blue: 0.5), title: "Top-Up To Do",
                        subtitle: "Pending top-ups to action",
                        count: meta.topUps,
                        destination: AnyView(TopUpToDoPage().environmentObject(appState)))

                hubTile(icon: "clock.arrow.circlepath", color: .gray, title: "History",
                        subtitle: "Posted & completed transactions",
                        count: meta.history,
                        destination: AnyView(CardListPage(title: "History", source: .history).environmentObject(appState)))

                hubTile(icon: "exclamationmark.triangle.fill", color: .red, title: "Smart Alerts",
                        subtitle: "Flagged or unusual activity",
                        count: meta.smartAlerts,
                        destination: AnyView(SmartAlertsPage().environmentObject(appState)))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .onAppear { appState.loadCardExpenseMeta() }
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
            .padding(14).background(Color.bgSurface).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(PlainButtonStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Assign Physical Card Page
// ═══════════════════════════════════════════════════════════════════

struct AssignPhysicalCardPage: View {
    let card: ExpenseCard
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var rawDigits: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false

    private static let teal = Color(red: 0, green: 0.6, blue: 0.5)

    // Format raw digits into grouped "XXXX XXXX XXXX XXXX"
    private var formatted: String {
        stride(from: 0, to: rawDigits.count, by: 4).map { i -> String in
            let start = rawDigits.index(rawDigits.startIndex, offsetBy: i)
            let end   = rawDigits.index(start, offsetBy: min(4, rawDigits.count - i))
            return String(rawDigits[start..<end])
        }.joined(separator: " ")
    }

    private var canSubmit: Bool { rawDigits.count == 16 && !isSubmitting }

    private var maskedDigital: String {
        guard let num = card.digitalCardNumber, !num.isEmpty else { return "No digital card" }
        let digits = num.filter { $0.isNumber }
        guard digits.count >= 4 else { return num }
        let last4 = String(digits.suffix(4))
        let groups = Int(ceil(Double(digits.count) / 4.0))
        let masked = Array(repeating: "••••", count: groups - 1).joined(separator: " ")
        return masked + " " + last4
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Card Holder / Department ──
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CARD HOLDER")
                            .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                        Text(card.holderFullName.isEmpty ? "—" : card.holderFullName)
                            .font(.system(size: 15, weight: .bold))
                        if !card.holderDesignation.isEmpty {
                            Text(card.holderDesignation)
                                .font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("DEPARTMENT")
                            .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                        Text(card.department.isEmpty ? "—" : card.department)
                            .font(.system(size: 15, weight: .bold))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(Color.bgSurface).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                // ── Current Digital Card preview ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRENT DIGITAL CARD")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AssignPhysicalCardPage.teal).tracking(0.5)
                    Text(maskedDigital)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AssignPhysicalCardPage.teal.opacity(0.05))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(AssignPhysicalCardPage.teal, lineWidth: 1.5))

                // ── Physical Card Number input ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("PHYSICAL CARD NUMBER (16 DIGITS)")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.3)

                    ZStack(alignment: .leading) {
                        if rawDigits.isEmpty {
                            Text("0000  0000  0000  0000")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundColor(Color(.systemGray3))
                                .padding(.horizontal, 14).padding(.vertical, 14)
                        }
                        TextField("", text: Binding(
                            get: { formatted },
                            set: { new in rawDigits = String(new.filter { $0.isNumber }.prefix(16)) }
                        ))
                        .keyboardType(.numberPad)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .padding(14)
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }

                // ── Warning banner ──
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14)).foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Assigning a physical card will replace the digital card. The digital card should be ")
                            .font(.system(size: 12))
                        + Text("dismissed or deactivated")
                            .font(.system(size: 12, weight: .bold))
                        + Text(" through the card issuer portal.")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(red: 0.55, green: 0.30, blue: 0))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.35), lineWidth: 1))

                Spacer(minLength: 24)

                // ── Assign button ──
                Button(action: assignCard) {
                    HStack(spacing: 8) {
                        if isSubmitting { ActivityIndicator(isAnimating: true) }
                        Text(isSubmitting ? "Assigning…" : "Assign Physical Card")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSubmit ? Color.gold : Color(.systemGray4))
                    .foregroundColor(canSubmit ? .black : Color(.systemGray2))
                    .cornerRadius(12)
                }
                .disabled(!canSubmit)
            }
            .padding(20)
        }
        .background(Color.bgBase)
        .navigationBarTitle("Assign Physical Card", displayMode: .inline)
        .alert(isPresented: $showSuccess) {
            Alert(
                title: Text("Card Assigned"),
                message: Text("Physical card has been assigned successfully."),
                dismissButton: .default(Text("Done")) { presentationMode.wrappedValue.dismiss() }
            )
        }
    }

    private func assignCard() {
        guard canSubmit else { return }
        isSubmitting = true
        // Call activateCard — this assigns the physical card number AND flips status to active.
        appState.activateCard(id: card.id, cardNumber: rawDigits) { success in
            isSubmitting = false
            if success { showSuccess = true }
        }
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

    private var isLoadingForSource: Bool {
        switch source {
        case .history:                        return appState.isLoadingCardHistory
        case .inbox, .all, .pending, .approval: return appState.isLoadingCardTxns
        default:                              return false
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 10) {
                    if isLoadingForSource && items.isEmpty {
                        LoaderView()
                    } else if items.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "tray").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("Nothing here yet").font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 480)
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
            // Each tile page only loads its own API
            switch source {
            case .topUps: appState.loadTopUpQueue()
            case .alerts: appState.loadSmartAlerts()
            case .history: appState.loadCardHistory()
            case .approval, .all, .pending, .inbox: appState.loadCardTransactions()
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
    /// Override-card sheet state. The button is gated behind
    /// `appState.cashMeta?.can_override == true`; when the user lacks the
    /// permission these stay unused and the button is hidden.
    @State private var overrideTarget: ExpenseCard?
    @State private var overrideReason = ""
    @State private var showOverrideSheet = false

    /// Shim a card into a PurchaseOrder so we can reuse the existing
    /// `ApprovalHelpers.getVisibility` (which is keyed on POs).
    private func cardAsPO(_ card: ExpenseCard) -> PurchaseOrder {
        var po = PurchaseOrder()
        po.id = card.id
        po.userId = card.holderId
        po.departmentId = card.departmentId
        po.status = "PENDING"
        po.approvals = card.approvals
        po.netAmount = card.monthlyLimit
        return po
    }

    private var cards: [ExpenseCard] { appState.cardsForApproval() }
    private var transactions: [CardTransaction] { appState.cardApprovalQueueItems }

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
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "creditcard").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No cards pending your approval.").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 400)
                        } else {
                            ForEach(cards) { card in
                                let cardVis = ApprovalHelpers
                                    .resolveConfig(appState.cardTierConfigRows,
                                                   deptId: card.departmentId,
                                                   amount: card.monthlyLimit)
                                    .map { ApprovalHelpers.getVisibility(po: cardAsPO(card), config: $0, userId: appState.userId) }
                                let canApproveCard = cardVis?.canApprove ?? false
                                let canOverrideCard = (appState.cashMeta?.can_override == true)
                                ApprovalCardRow(
                                    card: card,
                                    tierConfigs: appState.cardTierConfigRows,
                                    canApprove: canApproveCard,
                                    canOverride: canOverrideCard,
                                    onApprove: { appState.approveCard(card) },
                                    onReject: { rejectTarget = card; showRejectSheet = true },
                                    onOverride: canOverrideCard ? { overrideTarget = card; showOverrideSheet = true } : nil
                                )
                            }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 24)
                }
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        if appState.isLoadingCardApprovals && appState.cardApprovalQueueItems.isEmpty {
                            LoaderView()
                        } else if transactions.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No receipts or transactions awaiting approval.").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 400)
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
            appState.loadAllRequestedCards()    // GET /card-expenses/cards?status=pending&for_approval=true
            appState.loadCardApprovalQueue()    // GET /card-expenses/approvals
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
                                .background(Color.bgSurface).cornerRadius(8)
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
        .sheet(isPresented: $showOverrideSheet) {
            NavigationView {
                ZStack {
                    Color.bgBase.edgesIgnoringSafeArea(.all)
                    VStack(alignment: .leading, spacing: 16) {
                        if let c = overrideTarget {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "bolt.fill").font(.system(size: 14)).foregroundColor(.orange)
                                Text("This will approve the card for \(c.holderFullName), bypassing the normal approval chain.")
                                    .font(.system(size: 12)).foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.08)).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Override reason (optional)").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                            TextField("Reason…", text: $overrideReason)
                                .font(.system(size: 14)).padding(10)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        Spacer()
                    }.padding()
                }
                .navigationBarTitle(Text("Override Card Approval"), displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") { showOverrideSheet = false; overrideReason = ""; overrideTarget = nil }.foregroundColor(.goldDark),
                    trailing: Button("Override") {
                        guard let c = overrideTarget else { return }
                        appState.overrideCard(c)
                        showOverrideSheet = false; overrideReason = ""; overrideTarget = nil
                    }.foregroundColor(.orange).font(.system(size: 16, weight: .bold))
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
            .background(Color.bgSurface).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isActive ? Color.goldDark : Color.borderColor, lineWidth: isActive ? 2 : 1))
        }.buttonStyle(PlainButtonStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Coding Queue Page (coordinator)
// ═══════════════════════════════════════════════════════════════════

struct CardCodingQueuePage: View {
    @EnvironmentObject var appState: POViewModel

    private var items: [PendingCodingItem] {
        let all = appState.pendingCodingItems
        let allowedDeptIds: Set<String> = Set(appState.cardExpenseMeta.coordinatorDeptIds)
        guard !allowedDeptIds.isEmpty else { return all }
        return all.filter { item in
            if let deptId = item.departmentId, allowedDeptIds.contains(deptId) { return true }
            if let user = UsersData.byId[item.userId], allowedDeptIds.contains(user.departmentId) { return true }
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if appState.isLoadingPendingCoding && appState.pendingCodingItems.isEmpty {
                    LoaderView()
                } else if items.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "doc.text.magnifyingglass").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("Nothing in the coding queue").font(.system(size: 13)).foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: 480)
                } else {
                    ForEach(items) { item in
                        NavigationLink(destination: PendingCodingDetailPage(item: item).environmentObject(appState)) {
                            codingRow(item)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .onAppear { appState.loadPendingCoding() }   // GET /card-expenses/receipts/pending-coding
    }

    private func codingRow(_ item: PendingCodingItem) -> some View {
        let dateText = item.date > 0
            ? FormatUtils.formatTimestamp(item.date)
            : (item.createdAt > 0 ? FormatUtils.formatTimestamp(item.createdAt) : "—")
        let user = UsersData.byId[item.userId]
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.description.isEmpty ? "—" : item.description)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary).lineLimit(2)
                HStack(spacing: 6) {
                    Text(user?.fullName ?? item.userName)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    if !item.userDepartment.isEmpty {
                        Text("· \(item.userDepartment)")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                Text(dateText).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(FormatUtils.formatGBP(item.amount))
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                Text(item.statusDisplay)
                    .font(.system(size: 9, weight: .semibold)).foregroundColor(.orange)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12)).cornerRadius(4)
                if item.isUrgent {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10)).foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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
    @State private var selectedReceipt: Receipt? = nil
    @State private var navigateToDetail = false
    @State private var showManualMatch = false
    @State private var matchingReceiptId = ""

    private var inboxItems: [Receipt] { appState.inboxReceipts }

    // System Matched = status explicitly indicates a system-found match awaiting confirmation.
    // "matched" is included: the web treats it as auto-matched pending user confirmation.
    // linkedMerchant/linkedAmt on "unmatched" receipts is just transaction metadata — not a suggestion.
    private static let suggestedStatuses: Set<String> = [
        "suggested_match", "matched", "auto_matched", "system_matched",
        "match_suggested", "pending_match", "pending_confirmation",
        "auto_match", "suggestion"
    ]

    private func isSystemMatch(_ r: Receipt) -> Bool {
        ReceiptInboxPage.suggestedStatuses.contains(r.matchStatus.lowercased())
    }

    /// A confirmed receipt has history entries indicating the match was already acted on.
    private func isAlreadyConfirmed(_ r: Receipt) -> Bool {
        r.history.contains { entry in
            let a = (entry.action ?? "").lowercased()
            return a.contains("confirmed") || a.contains("match confirmed")
        }
    }

    private var systemMatched: [Receipt] {
        inboxItems.filter { isSystemMatch($0) }
    }
    // No Match — unmatched receipts with no transaction link (user-uploaded, no match found).
    private var noMatch: [Receipt] {
        inboxItems.filter { r in
            r.matchStatus.lowercased() == "unmatched" &&
            (r.transactionId == nil || r.transactionId!.isEmpty)
        }
    }
    private var duplicates: [Receipt] {
        inboxItems.filter { $0.duplicateScore != nil && !$0.duplicateDismissed }
    }
    private var personals: [Receipt] {
        inboxItems.filter { $0.personalScore != nil && !$0.personalDismissed }
    }

    var body: some View {
        Group {
            if appState.isLoadingInboxReceipts && inboxItems.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        section(
                            icon: "sparkles",
                            title: "System Matched",
                            subtitle: "Confirm & Attach",
                            color: Color(red: 0.1, green: 0.6, blue: 0.3),
                            items: systemMatched,
                            expanded: $systemMatchedExpanded,
                            emptyText: "No system-matched receipts.",
                            trailing: AnyView(rerunButton),
                            sectionKind: .systemMatched,
                            onTap: { r in selectedReceipt = r; navigateToDetail = true }
                        )
                        section(
                            icon: "questionmark.circle",
                            title: "No Match",
                            subtitle: "Manual matching required",
                            color: Color(red: 0.95, green: 0.55, blue: 0.15),
                            items: noMatch,
                            expanded: $noMatchExpanded,
                            emptyText: "No unmatched receipts.",
                            trailing: AnyView(EmptyView()),
                            sectionKind: .noMatch,
                            onTap: { r in selectedReceipt = r; navigateToDetail = true }
                        )
                        section(
                            icon: "doc.on.doc.fill",
                            title: "Duplicate",
                            subtitle: "Review before posting",
                            color: .purple,
                            items: duplicates,
                            expanded: $duplicateExpanded,
                            emptyText: "No duplicate receipts detected.",
                            trailing: AnyView(EmptyView()),
                            sectionKind: .duplicate,
                            onTap: { r in selectedReceipt = r; navigateToDetail = true }
                        )
                        section(
                            icon: "person.crop.circle.fill",
                            title: "Personal",
                            subtitle: "Flagged as personal expense",
                            color: .blue,
                            items: personals,
                            expanded: $personalExpanded,
                            emptyText: "No personal receipts flagged.",
                            trailing: AnyView(EmptyView()),
                            sectionKind: .personal,
                            onTap: { r in selectedReceipt = r; navigateToDetail = true }
                        )
                    }
                    .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 28)
                }
                .background(Color.bgBase)
                .background(
                    NavigationLink(
                        destination: Group {
                            if let r = selectedReceipt {
                                ReceiptDetailPage(receipt: r).environmentObject(appState)
                            } else { EmptyView() }
                        },
                        isActive: $navigateToDetail
                    ) { EmptyView() }.frame(width: 0, height: 0).hidden()
                )
            }
        }
        .navigationBarTitle(Text("Receipt Inbox"), displayMode: .inline)
        .onAppear { appState.loadInboxReceipts(); appState.loadCardTransactions() }
        .sheet(isPresented: $showManualMatch) {
            ManualMatchSheet(receiptId: matchingReceiptId, isPresented: $showManualMatch)
                .environmentObject(appState)
        }
    }

    private var rerunButton: some View {
        Button(action: { appState.loadInboxReceipts() }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10, weight: .semibold))
                Text("Re-run").font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.goldDark)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.gold.opacity(0.12)).cornerRadius(6)
        }.buttonStyle(BorderlessButtonStyle())
    }

    private enum InboxSectionKind { case systemMatched, noMatch, duplicate, personal }

    @ViewBuilder
    private func section(icon: String, title: String, subtitle: String, color: Color, items: [Receipt], expanded: Binding<Bool>, emptyText: String, trailing: AnyView, sectionKind: InboxSectionKind, onTap: @escaping (Receipt) -> Void) -> some View {
        VStack(spacing: 0) {
            // ── Section heading ──────────────────────────────────
            Button(action: { expanded.wrappedValue.toggle() }) {
                HStack(spacing: 0) {
                    // Colored left accent bar
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: 4).padding(.vertical, 14)

                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(color)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.primary)
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        trailing

                        Text("\(items.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(color)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(color.opacity(0.1)).cornerRadius(10)

                        Image(systemName: expanded.wrappedValue ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 14)
                }
                .background(Color.bgSurface)
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if expanded.wrappedValue {
                Divider()
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: icon).font(.system(size: 24)).foregroundColor(.gray.opacity(0.25))
                        Text(emptyText).font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 32).padding(.horizontal, 20)
                } else {
                    ForEach(items) { r in
                        inboxRow(r, sectionKind: sectionKind)
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(r) }
                    }
                }
            }
        }
        .background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private func inboxRow(_ r: Receipt, sectionKind: InboxSectionKind) -> some View {
        let receiptDate = r.transactionDate > 0 ? FormatUtils.formatTimestamp(r.transactionDate)
            : (r.createdAt > 0 ? FormatUtils.formatTimestamp(r.createdAt) : "—")
        let user = UsersData.byId[r.uploaderId]
        let holderName = user?.fullName ?? (r.uploaderName.isEmpty ? "—" : r.uploaderName)
        let designation = user?.displayDesignation ?? ""
        let nominalCode = r.nominalCode ?? ""
        let codeLabel: String = {
            if nominalCode.isEmpty { return "" }
            if let m = costCodeOptions.first(where: { $0.0 == nominalCode }) {
                return "\(nominalCode.uppercased().replacingOccurrences(of: "_", with: "-")) — \(m.1)"
            }
            return nominalCode.uppercased().replacingOccurrences(of: "_", with: "-")
        }()
        let isSystemMatched = sectionKind == .systemMatched
        let isNoMatch = sectionKind == .noMatch
        let isDuplicate = sectionKind == .duplicate
        let isPersonal = sectionKind == .personal
        let hasLinkedTxn = !r.linkedMerchant.isEmpty || r.linkedAmount != nil
        let wfLower = r.workflowStatus.lowercased()
        let isPosted = wfLower == "posted" || wfLower == "approved" || wfLower == "confirmed"
        let isConfirmed = isAlreadyConfirmed(r)
        let showAttach = isSystemMatched && !isPosted && !isConfirmed

        return VStack(alignment: .leading, spacing: 0) {

            // ── Main row ──────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                // Left: avatar
                ZStack {
                    Circle().fill(Color.gold.opacity(0.15)).frame(width: 36, height: 36)
                    Text((user?.initials ?? String(holderName.prefix(2))).uppercased())
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.goldDark)
                }

                // Centre: merchant + date + holder
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(r.displayMerchant.isEmpty ? "Receipt" : r.displayMerchant)
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.primary).lineLimit(1)
                        if let score = r.matchScore {
                            Text("\(Int(score * 100))%")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(red: 0.0, green: 0.55, blue: 0.35))
                                .padding(.horizontal, 4).padding(.vertical, 2)
                                .background(Color.green.opacity(0.1)).cornerRadius(3)
                        }
                        if r.isUrgent {
                            Text("URGENT")
                                .font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.red).cornerRadius(3)
                        }
                    }
                    Text(receiptDate)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text(holderName).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary).lineLimit(1)
                        if !designation.isEmpty {
                            Text("· \(designation)").font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 4)

                // Right: amount + status
                VStack(alignment: .trailing, spacing: 5) {
                    Text(FormatUtils.formatGBP(r.displayAmount))
                        .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    inboxStatusBadge(r)
                }
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, hasLinkedTxn || !codeLabel.isEmpty ? 6 : 10)

            // ── Code pill ─────────────────────────────────────────
            if !codeLabel.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill").font(.system(size: 9)).foregroundColor(.goldDark)
                    Text(codeLabel).font(.system(size: 10, weight: .semibold)).foregroundColor(.goldDark).lineLimit(1)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.gold.opacity(0.1)).cornerRadius(5)
                .padding(.horizontal, 14).padding(.bottom, hasLinkedTxn ? 6 : 10)
            }

            // ── Linked transaction strip ──────────────────────────
            if hasLinkedTxn {
                HStack(spacing: 6) {
                    Image(systemName: "link").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        if !r.linkedMerchant.isEmpty {
                            Text(r.linkedMerchant).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                        }
                        HStack(spacing: 6) {
                            if let amt = r.linkedAmount {
                                Text(FormatUtils.formatGBP(amt))
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.secondary)
                            }
                            if !r.linkedCardLast4.isEmpty {
                                Text("···· \(r.linkedCardLast4)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                            }
                            if let ld = r.linkedDate, ld > 0 {
                                Text(FormatUtils.formatTimestamp(ld)).font(.system(size: 10)).foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.gray.opacity(0.04))
                .padding(.horizontal, 14).padding(.bottom, 8)
            }

            // ── Action buttons ────────────────────────────────────
            Divider()
            HStack(spacing: 10) {
                if isSystemMatched {
                    if showAttach {
                        Button(action: { appState.attachInboxReceipt(r.id) }) {
                            HStack(spacing: 5) {
                                Image(systemName: "paperclip").font(.system(size: 11, weight: .semibold))
                                Text("Attach").font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(Color.orange).cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }

                if isNoMatch {
                    Button(action: { matchingReceiptId = r.id; showManualMatch = true }) {
                        Text("Manual Match")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                }

                if isDuplicate {
                    Button(action: { appState.confirmReceipt(r) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                            Text("Keep").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(Color(red: 0.0, green: 0.6, blue: 0.5)).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())

                    Button(action: { appState.deleteReceipt(r) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash").font(.system(size: 11, weight: .semibold))
                            Text("Remove").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(Color.red).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())
                }

                if isPersonal {
                    Button(action: { appState.confirmReceipt(r) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "briefcase").font(.system(size: 11, weight: .semibold))
                            Text("Mark Business").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(Color(red: 0.0, green: 0.6, blue: 0.5)).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())

                    Button(action: { appState.flagReceiptPersonal(r) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "person.fill").font(.system(size: 11, weight: .semibold))
                            Text("Confirm Personal").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
    }

    private func inboxStatusBadge(_ r: Receipt) -> some View {
        let teal   = Color(red: 0.0,  green: 0.6,  blue: 0.5)
        let navy   = Color(red: 0.05, green: 0.15, blue: 0.42)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        // Use workflowStatus for display; fall back to matchStatus
        let s = r.workflowStatus.isEmpty ? r.matchStatus : r.workflowStatus
        let (label, fg, bg): (String, Color, Color) = {
            switch s.lowercased() {
            case "pending_coding", "pending_code", "pending code": return ("Pending Code",      navy, navy.opacity(0.12))
            case "coded":                                       return ("Coded",             teal,   teal.opacity(0.12))
            case "posted":                                      return ("Posted",            Color(red: 0.1, green: 0.6, blue: 0.3), Color.green.opacity(0.1))
            case "approved":                                    return ("Approved",          teal,   teal.opacity(0.12))
            case "awaiting_approval", "pending_approval",
                 "submitted", "under_review":                   return ("Awaiting Approval", orange, orange.opacity(0.12))
            case "matched", "suggested_match":                  return ("Matched",           teal,   teal.opacity(0.12))
            case "unmatched":                                   return ("No Match",          orange, orange.opacity(0.12))
            case "duplicate":                                   return ("Duplicate",         Color.purple, Color.purple.opacity(0.12))
            case "personal":                                    return ("Personal",          Color.blue,   Color.blue.opacity(0.12))
            case "pending", "pending_receipt", "":              return ("Pending",           orange, orange.opacity(0.12))
            default:                                            return (s.replacingOccurrences(of: "_", with: " ").capitalized, Color.gray, Color.gray.opacity(0.1))
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(bg).cornerRadius(5)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Smart Alerts Page
// ═══════════════════════════════════════════════════════════════════

struct SmartAlertsPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var activeFilter = "All"
    @State private var showFilterSheet = false
    @State private var navigateToAlertId: String? = nil

    private let filters = ["All", "Anomaly", "Duplicate Risk", "Velocity", "Merchant", "Under Investigation", "Resolved"]
    private let pink   = Color(red: 0.91, green: 0.29, blue: 0.48)
    private let teal   = Color(red: 0.0,  green: 0.6,  blue: 0.5)
    private let orange = Color(red: 0.95, green: 0.55, blue: 0.15)

    private var alerts: [SmartAlert] { appState.smartAlerts }

    private var filtered: [SmartAlert] {
        switch activeFilter {
        case "Anomaly":        return alerts.filter { $0.type.lowercased() == "anomaly" }
        case "Duplicate Risk": return alerts.filter { ["duplicate_risk","duplicate"].contains($0.type.lowercased()) }
        case "Velocity":       return alerts.filter { $0.type.lowercased() == "velocity" }
        case "Merchant":       return alerts.filter { $0.type.lowercased() == "merchant" }
        case "Under Investigation": return alerts.filter { $0.status.lowercased() == "under_investigation" }
        case "Resolved":       return alerts.filter { $0.status.lowercased() == "resolved" }
        default:               return alerts
        }
    }

    var body: some View {
        Group {
            if appState.isLoadingSmartAlerts && alerts.isEmpty {
                // Full-page loader — replaces stats row so user sees spinner immediately
                VStack { Spacer(); LoaderView(); Spacer() }
                    .background(Color.bgBase)
            } else {
                ScrollView {
                    VStack(spacing: 14) {

                        // ── Filter ──
                        HStack(spacing: 8) {
                            Button(action: { showFilterSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "line.3.horizontal.decrease")
                                        .font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                                    Text(activeFilter)
                                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.bgSurface).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .selectionActionSheet(
                                title: "Filter Alerts",
                                isPresented: $showFilterSheet,
                                options: filters,
                                isSelected: { $0 == activeFilter },
                                label: { $0 },
                                onSelect: { activeFilter = $0 }
                            )
                            Spacer()
                        }

                        // ── Alert list ──
                        if filtered.isEmpty {
                            VStack(spacing: 10) {
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark.shield.fill").font(.system(size: 32)).foregroundColor(.gray.opacity(0.25))
                                Text("No alerts").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                                Text("All clear for this filter").font(.system(size: 12)).foregroundColor(.gray)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 420)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(filtered) { alert in
                                    alertCard(alert)
                                }
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 16).padding(.top, 14)
                }
                .background(Color.bgBase)
            }
        }
        .navigationBarTitle(Text("Smart Alerts"), displayMode: .inline)
        .onAppear { appState.loadSmartAlerts() }
    }

    // MARK: - Alert card
    private func isTopUpAlert(_ alert: SmartAlert) -> Bool {
        let s = alert.status.lowercased()
        let t = alert.type.lowercased()
        return s.contains("top_up") || s.contains("topup") || s.contains("top-up")
            || t.contains("top_up") || t.contains("topup") || t.contains("top-up")
    }

    private func alertCard(_ alert: SmartAlert) -> some View {
        let pink   = self.pink
        let orange = self.orange
        let isActive = alert.status.lowercased() == "active" || alert.status.lowercased() == "under_investigation"
        let isInvestigating = alert.status.lowercased() == "under_investigation"
        let isPendingTopUp = isTopUpAlert(alert)
        let headerColor: Color = isPendingTopUp ? .purple : pink
        let barColor: Color = {
            if isPendingTopUp { return .purple }
            switch alert.priority.lowercased() {
            case "high":   return pink
            case "medium": return orange
            case "low":    return Color(red: 0.3, green: 0.6, blue: 0.3)
            default:       return Color(red: 0.4, green: 0.5, blue: 0.9)
            }
        }()
        let iconName = isPendingTopUp ? "arrow.up.circle.fill"
            : ((alert.priority.lowercased() == "high" || alert.priority.lowercased() == "medium")
                ? "exclamationmark.circle.fill" : "info.circle.fill")

        return VStack(alignment: .leading, spacing: 0) {

                // ── Header ──
                VStack(alignment: .leading, spacing: 6) {
                    // Title row — colour driven by status
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: iconName)
                            .font(.system(size: 13)).foregroundColor(headerColor)
                        Text(alert.title.isEmpty ? "Alert" : alert.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(headerColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Badges + detected time on same row
                    HStack(spacing: 6) {
                        priorityBadge(alert.priority)
                        statusBadge(alert.status)
                        Spacer()
                        if alert.detectedAt > 0 {
                            Text(FormatUtils.formatDateTime(alert.detectedAt))
                                .font(.system(size: 10)).foregroundColor(.gray)
                        }
                    }
                }
                .padding(.leading, 16).padding(.trailing, 12).padding(.top, 12).padding(.bottom, 8)

                Divider()

                // ── Description ──
                if !alert.alertDescription.isEmpty {
                    Text(alert.alertDescription)
                        .font(.system(size: 12)).foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 16).padding(.trailing, 12).padding(.top, 8).padding(.bottom, 6)
                }

                // ── Details strip (type · cardholder · department) ──
                HStack(spacing: 0) {
                    if !alert.typeDisplay.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 9)).foregroundColor(.goldDark)
                            Text(alert.typeDisplay)
                                .font(.system(size: 10, weight: .semibold)).foregroundColor(.goldDark)
                        }
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.gold.opacity(0.12)).cornerRadius(4)
                    }
                    if !alert.holderName.isEmpty {
                        Text("  ·  ").font(.system(size: 10)).foregroundColor(.secondary)
                        Image(systemName: "person.fill")
                            .font(.system(size: 9)).foregroundColor(.secondary)
                        Text(" \(alert.holderName)")
                            .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                    }
                    if !alert.department.isEmpty {
                        Text("  ·  ").font(.system(size: 10)).foregroundColor(.secondary)
                        Text(alert.department)
                            .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 16).padding(.trailing, 12).padding(.bottom, 8)

                // ── Transaction preview card ──
                if alert.hasTransactionData {
                    VStack(alignment: .leading, spacing: 4) {
                        // Label line
                        if !alert.transactionLabel.isEmpty {
                            Text(alert.transactionLabel)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        // Meta line: ••••7733 · Sophie Turner (Catering Manager) · £285.70
                        HStack(spacing: 4) {
                            Text(alert.holderDisplay)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            if alert.effectiveAmount > 0 {
                                Text("·")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(FormatUtils.formatGBP(alert.effectiveAmount))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(barColor)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(6)
                    .padding(.leading, 16).padding(.trailing, 12).padding(.bottom, 10)
                }

                // ── Action buttons ──
                if isActive {
                    HStack(spacing: 0) {
                        NavigationLink(
                            destination: SmartAlertDetailPage(alert: alert).environmentObject(appState),
                            tag: alert.id,
                            selection: $navigateToAlertId
                        ) { EmptyView() }.frame(width: 0, height: 0).hidden()

                        if isInvestigating {
                            // Under Investigation — tap to revert back to active
                            Button(action: { appState.revertSmartAlert(alert.id) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye.fill").font(.system(size: 11, weight: .medium))
                                    Text("Under Investigation").font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.orange).cornerRadius(6)
                            }.buttonStyle(BorderlessButtonStyle())
                        } else {
                            // Active state — show Investigate, Resolve, Dismiss
                            Button(action: { appState.investigateSmartAlert(alert.id) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .medium))
                                    Text("Investigate").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.bgSurface)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }.buttonStyle(BorderlessButtonStyle())

                            Spacer().frame(width: 8)

                            Button(action: { appState.resolveSmartAlert(alert.id) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 11, weight: .medium))
                                    Text("Resolve").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(teal).cornerRadius(6)
                            }.buttonStyle(BorderlessButtonStyle())

                            Spacer().frame(width: 12)

                            Button(action: { appState.dismissSmartAlert(alert.id) }) {
                                Text("Dismiss")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }.buttonStyle(BorderlessButtonStyle())
                        }

                        Spacer()
                    }
                    .padding(.leading, 16).padding(.trailing, 12).padding(.bottom, 12)
                } else {
                    Spacer().frame(height: 4)
                }
        }
        .background(
            HStack(spacing: 0) {
                Rectangle().fill(barColor).frame(width: 4)
                Spacer()
            }
        )
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(barColor.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Badges
    private func priorityBadge(_ p: String) -> some View {
        let (fg, bg): (Color, Color) = {
            switch p.lowercased() {
            case "high":   return (pink, pink.opacity(0.12))
            case "medium": return (orange, orange.opacity(0.12))
            case "low":    return (.gray, Color.gray.opacity(0.12))
            default:       return (.goldDark, Color.gold.opacity(0.15))
            }
        }()
        let label: String = {
            switch p.lowercased() {
            case "high": return "High Priority"
            case "medium": return "Medium Priority"
            case "low": return "Low Priority"
            default: return p.capitalized
            }
        }()
        return Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 3).background(bg).cornerRadius(4)
    }

    private func statusBadge(_ s: String) -> some View {
        let teal   = self.teal
        let lower = s.lowercased()
        let isTopUp = lower.contains("top_up") || lower.contains("topup") || lower.contains("top-up")
        let (label, fg, bg): (String, Color, Color) = {
            if isTopUp { return ("Pending Top-Up", Color.purple, Color.purple.opacity(0.12)) }
            switch lower {
            case "active":
                return ("Active", Color(red: 0.0, green: 0.6, blue: 0.3), Color(red: 0.0, green: 0.6, blue: 0.3).opacity(0.12))
            case "investigating":
                return ("Under Investigation", .orange, Color.orange.opacity(0.12))
            case "resolved":
                return ("Resolved", teal, teal.opacity(0.12))
            case "dismissed":
                return ("Dismissed", .gray, Color.gray.opacity(0.12))
            default:
                return (s.capitalized, .goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 3).background(bg).cornerRadius(4)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Smart Alert Detail Page
// ═══════════════════════════════════════════════════════════════════

struct SmartAlertDetailPage: View {
    let alert: SmartAlert
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    private var live: SmartAlert {
        appState.smartAlerts.first(where: { $0.id == alert.id }) ?? alert
    }

    private var isResolved: Bool { live.status.lowercased() == "resolved" }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Summary card
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Alert Details").font(.system(size: 15, weight: .bold))
                        Spacer()
                        priorityBadge(live.priority)
                        statusBadge(live.status)
                    }
                    .padding(14)

                    Divider()

                    // Title + description
                    VStack(alignment: .leading, spacing: 8) {
                        let s = live.status.lowercased(); let t = live.type.lowercased()
                        let isPendingTopUp = s.contains("top_up") || s.contains("topup") || s.contains("top-up")
                            || t.contains("top_up") || t.contains("topup") || t.contains("top-up")
                        let detailHeaderColor: Color = isPendingTopUp ? .purple : Color(red: 0.91, green: 0.29, blue: 0.48)
                        let detailIconName = isPendingTopUp ? "arrow.up.circle.fill" : "exclamationmark.circle.fill"
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: detailIconName).font(.system(size: 16))
                                .foregroundColor(detailHeaderColor)
                            Text(live.title.isEmpty ? "Alert" : live.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(detailHeaderColor)
                        }
                        if !live.alertDescription.isEmpty {
                            Text(live.alertDescription)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)

                    Divider()

                    // Details grid
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "TYPE", value: live.typeDisplay)
                            infoCell(label: "AMOUNT",
                                     value: live.amount > 0 ? FormatUtils.formatGBP(live.amount) : "—",
                                     valueColor: .goldDark, mono: true)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "CARD",
                                     value: live.cardLastFour.isEmpty ? "—" : "•••• \(live.cardLastFour)",
                                     mono: true)
                            infoCell(label: "BS CONTROL CODE",
                                     value: live.bsControlCode.isEmpty ? "—" : live.bsControlCode,
                                     mono: true)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "CARDHOLDER",
                                     value: live.holderName.isEmpty ? "—" : live.holderName)
                            infoCell(label: "DEPARTMENT",
                                     value: live.department.isEmpty ? "—" : live.department)
                        }
                        if live.detectedAt > 0 || live.resolvedAt > 0 {
                            HStack(alignment: .top, spacing: 12) {
                                infoCell(label: "DETECTED",
                                         value: live.detectedAt > 0 ? FormatUtils.formatTimestamp(live.detectedAt) : "—")
                                infoCell(label: "RESOLVED",
                                         value: live.resolvedAt > 0 ? FormatUtils.formatTimestamp(live.resolvedAt) : "—")
                            }
                        }
                        if live.savings > 0 {
                            HStack(alignment: .top, spacing: 12) {
                                infoCell(label: "SAVINGS",
                                         value: FormatUtils.formatGBP(live.savings),
                                         valueColor: Color(red: 0.0, green: 0.6, blue: 0.5), mono: true)
                                Spacer()
                            }
                        }
                    }
                    .padding(14)
                }
                .background(Color.bgSurface).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.3), lineWidth: 1.5))

                // Actions
                if !isResolved {
                    HStack(spacing: 10) {
                        Button(action: {
                            appState.resolveSmartAlert(live.id)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 12))
                                Text("Resolve").font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.0, green: 0.6, blue: 0.5)).cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                        Button(action: {
                            appState.dismissSmartAlert(live.id)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Dismiss").font(.system(size: 13, weight: .bold)).foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                                .cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Alert Details"), displayMode: .inline)
    }

    private func infoCell(label: String, value: String, valueColor: Color = .primary, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value)
                .font(mono ? .system(size: 14, weight: .bold, design: .monospaced) : .system(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
        }.frame(maxWidth: .infinity, alignment: .leading)
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
            case "high":   return "High"
            case "medium": return "Medium"
            case "low":    return "Low"
            default:       return p.capitalized
            }
        }()
        return Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
    }

    private func statusBadge(_ s: String) -> some View {
        let pink = Color(red: 0.91, green: 0.29, blue: 0.48)
        let lower = s.lowercased()
        let isTopUp = lower.contains("top_up") || lower.contains("topup") || lower.contains("top-up")
        let (label, fg, bg): (String, Color, Color) = {
            if isTopUp { return ("Pending Top-Up", Color.purple, Color.purple.opacity(0.12)) }
            switch lower {
            case "active":
                return ("Active", pink, pink.opacity(0.12))
            case "investigating":
                return ("Under Investigation", .orange, Color.orange.opacity(0.12))
            case "resolved":
                return ("Resolved", Color(red: 0.0, green: 0.6, blue: 0.5), Color(red: 0.0, green: 0.6, blue: 0.5).opacity(0.12))
            case "dismissed":
                return ("Dismissed", Color.gray, Color.gray.opacity(0.15))
            default:
                return (s.capitalized, .goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Pending Coding Page (grouped by cardholder)
// ═══════════════════════════════════════════════════════════════════

struct PendingCodingPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var expandedHolders: Set<String> = []

    private var items: [PendingCodingItem] { appState.pendingCodingItems }

    private var groupedByHolder: [(userId: String, userName: String, department: String, items: [PendingCodingItem])] {
        let groups = Dictionary(grouping: items, by: { $0.userId })
        return groups.map { (userId, items) in
            let first = items.first
            return (
                userId: userId,
                userName: first?.userName ?? userId,
                department: first?.userDepartment ?? "",
                items: items.sorted { $0.createdAt > $1.createdAt }
            )
        }.sorted { $0.userName < $1.userName }
    }

    var body: some View {
        Group {
            if appState.isLoadingPendingCoding && items.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
                    .background(Color.bgBase)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if items.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("Nothing awaiting coding").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
                        } else {
                            ForEach(groupedByHolder, id: \.userId) { group in
                                holderSection(group)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
                }
                .background(Color.bgBase)
            }
        }
        .navigationBarTitle(Text("Pending Coding"), displayMode: .inline)
        .onAppear {
            appState.loadPendingCoding()
            if expandedHolders.isEmpty, let first = groupedByHolder.first {
                expandedHolders.insert(first.userId)
            }
        }
    }

    @ViewBuilder
    private func holderSection(_ group: (userId: String, userName: String, department: String, items: [PendingCodingItem])) -> some View {
        let isExpanded = expandedHolders.contains(group.userId)
        let total = group.items.reduce(0) { $0 + $1.amount }
        let initials = group.userName.split(separator: " ").compactMap { $0.first.map(String.init) }.prefix(2).joined()
        VStack(spacing: 0) {
            Button(action: {
                if isExpanded { expandedHolders.remove(group.userId) } else { expandedHolders.insert(group.userId) }
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color(red: 0.91, green: 0.29, blue: 0.48)).frame(width: 28, height: 28)
                        Text(initials.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(group.userName).font(.system(size: 13, weight: .bold))
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
                    NavigationLink(destination: PendingCodingDetailPage(item: item).environmentObject(appState)) {
                        pendingRow(item)
                    }.buttonStyle(PlainButtonStyle())
                    Divider().padding(.leading, 14)
                }
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func pendingRow(_ item: PendingCodingItem) -> some View {
        let dateText = item.date > 0 ? FormatUtils.formatTimestamp(item.date) : (item.createdAt > 0 ? FormatUtils.formatTimestamp(item.createdAt) : "—")
        let user = UsersData.byId[item.userId]
        let ageDays: Int = {
            let ref = item.createdAt > 0 ? item.createdAt : item.date
            guard ref > 0 else { return 0 }
            let secs = (Date().timeIntervalSince1970 * 1000 - Double(ref)) / 1000
            return max(0, Int(secs / 86400))
        }()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.description.isEmpty ? "—" : item.description)
                        .font(.system(size: 13, weight: .semibold)).lineLimit(2)
                    Text(dateText).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(FormatUtils.formatGBP(item.amount))
                        .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    pendingStatusBadge(item.status)
                }
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(user?.fullName ?? item.userName)
                        .font(.system(size: 11, weight: .semibold))
                    if let d = user?.displayDesignation, !d.isEmpty {
                        Text(d).font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if !item.processingFlags.isEmpty {
                    Image(systemName: "flag.fill").font(.system(size: 9)).foregroundColor(.orange)
                }
                if item.isUrgent {
                    Image(systemName: "exclamationmark.circle.fill").font(.system(size: 9)).foregroundColor(.red)
                }
                Text("\(ageDays)d").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func pendingStatusBadge(_ status: String) -> some View {
        let (label, color): (String, Color) = {
            switch status.lowercased() {
            case "pending_code", "pending_coding", "pending code": return ("Needs Coding", Color(red: 0.05, green: 0.15, blue: 0.42))
            case "pending_receipt": return ("No Receipt", Color.purple)
            default:                return (status.replacingOccurrences(of: "_", with: " ").capitalized, Color.gray)
            }
        }()
        return Text(label)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12)).cornerRadius(3)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Pending Coding Detail Page
// ═══════════════════════════════════════════════════════════════════

struct PendingCodingDetailPage: View {
    let item: PendingCodingItem
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    private var live: PendingCodingItem {
        appState.pendingCodingItems.first(where: { $0.id == item.id }) ?? item
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(live.description.isEmpty ? "—" : live.description)
                                .font(.system(size: 17, weight: .bold)).lineLimit(3)
                            HStack(spacing: 6) {
                                Text(live.statusDisplay)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor({
                                        let s = live.status.lowercased()
                                        if s == "pending_receipt" { return Color.purple }
                                        if ["pending_code","pending_coding","pending code"].contains(s) { return Color(red: 0.05, green: 0.15, blue: 0.42) }
                                        return Color(red: 0.95, green: 0.55, blue: 0.15)
                                    }())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background({
                                        let s = live.status.lowercased()
                                        if s == "pending_receipt" { return Color.purple.opacity(0.12) }
                                        if ["pending_code","pending_coding","pending code"].contains(s) { return Color(red: 0.05, green: 0.15, blue: 0.42).opacity(0.12) }
                                        return Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.12)
                                    }())
                                    .cornerRadius(4)
                                if live.isUrgent {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 10))
                                        Text("Urgent").font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.red.opacity(0.1)).cornerRadius(4)
                                }
                            }
                        }
                        Spacer()
                        Text(FormatUtils.formatGBP(live.amount))
                            .font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill").font(.system(size: 11)).foregroundColor(.secondary)
                        Text(live.userName).font(.system(size: 12, weight: .semibold))
                        if !live.userDepartment.isEmpty {
                            Text("· \(live.userDepartment)").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(14).background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // Processing flags
                if !live.processingFlags.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("PROCESSING FLAGS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                        ForEach(Array(live.processingFlags.enumerated()), id: \.offset) { idx, flag in
                            let flagColor: Color = {
                                switch flag.flag?.lowercased() {
                                case "review": return .purple
                                case "query":  return .orange
                                case "deduct": return .red
                                default:       return .gray
                                }
                            }()
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "flag.fill").font(.system(size: 12)).foregroundColor(flagColor)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(flag.title ?? "Flag").font(.system(size: 13, weight: .semibold))
                                    if let desc = flag.description, !desc.isEmpty {
                                        Text(desc).font(.system(size: 11)).foregroundColor(.secondary)
                                    }
                                    HStack(spacing: 6) {
                                        if let pt = flag.processType {
                                            Text(pt.replacingOccurrences(of: "_", with: " ").capitalized)
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(flagColor)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(flagColor.opacity(0.1)).cornerRadius(3)
                                        }
                                        if let tv = flag.thresholdValue, let tt = flag.thresholdType {
                                            let label = tt == "percentage" ? "\(Int(tv))%" : FormatUtils.formatGBP(tv)
                                            Text("Threshold: \(label)")
                                                .font(.system(size: 9)).foregroundColor(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            if idx < live.processingFlags.count - 1 { Divider().padding(.leading, 44) }
                        }
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                }

                // Details
                VStack(spacing: 0) {
                    detailRow("Date", live.date > 0 ? FormatUtils.formatTimestamp(live.date) : "—")
                    Divider().padding(.leading, 14)
                    detailRow("Status", live.statusDisplay)
                    if let code = live.nominalCode, !code.isEmpty {
                        Divider().padding(.leading, 14)
                        detailRow("Nominal Code", code)
                    }
                    if let ep = live.episode, !ep.isEmpty {
                        Divider().padding(.leading, 14)
                        detailRow("Episode", ep)
                    }
                    if let cd = live.codeDescription, !cd.isEmpty {
                        Divider().padding(.leading, 14)
                        detailRow("Code Notes", cd)
                    }
                    if let txId = live.transactionId {
                        Divider().padding(.leading, 14)
                        detailRow("Transaction ID", txId)
                    }
                    if !live.matchStatus.isEmpty {
                        Divider().padding(.leading, 14)
                        detailRow("Match Status", live.matchStatus.replacingOccurrences(of: "_", with: " ").capitalized)
                    }
                    Divider().padding(.leading, 14)
                    detailRow("Submitted", live.createdAt > 0 ? FormatUtils.formatTimestamp(live.createdAt) : "—")
                }
                .background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // Receipt attachment
                if let att = live.receiptAttachment, let name = att.name, !name.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "paperclip").font(.system(size: 14)).foregroundColor(.goldDark)
                        Text(name).font(.system(size: 13)).lineLimit(1)
                        Spacer()
                        Text("Attached").font(.system(size: 10, weight: .semibold)).foregroundColor(.green)
                    }
                    .padding(14).background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }

                // History
                if !live.history.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("HISTORY").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                        ForEach(Array(live.history.enumerated()), id: \.offset) { _, entry in
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(Color.goldDark).frame(width: 8, height: 8).padding(.top, 4)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.action ?? "").font(.system(size: 12, weight: .semibold))
                                    Text(entry.actionByName).font(.system(size: 10)).foregroundColor(.secondary)
                                    if let ts = entry.actionAt, ts > 0 {
                                        Text(FormatUtils.formatDateTime(ts)).font(.system(size: 9)).foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                            }.padding(.horizontal, 14).padding(.vertical, 6)
                        }
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Coding Detail"), displayMode: .inline)
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

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 120, alignment: .leading)
            Text(value).font(.system(size: 12, weight: .medium)).lineLimit(2)
            Spacer()
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Accountant Approval Queue Page
// ═══════════════════════════════════════════════════════════════════

struct AccountantApprovalQueuePage: View {
    @EnvironmentObject var appState: POViewModel

    @State private var overrideTarget: CardTransaction? = nil
    @State private var overrideReason: String = ""
    @State private var isOverriding: Bool = false
    @State private var showOverrideSheet: Bool = false

    private var items: [CardTransaction] { appState.cardApprovalQueueItems }

    private var groupedByStatus: [(status: String, label: String, color: Color, items: [CardTransaction])] {
        let order: [(String, String, Color)] = [
            ("awaiting_approval", "Awaiting Approval", .goldDark),
            ("escalated",         "Escalated",         .red),
            ("under_review",      "Under Review",      .purple),
        ]
        return order.compactMap { (status, label, color) in
            let group = items.filter { $0.status.lowercased() == status }
            guard !group.isEmpty else { return nil }
            return (status: status, label: label, color: color, items: group.sorted { $0.transactionDate > $1.transactionDate })
        }
    }

    var body: some View {
        Group {
            if appState.isLoadingCardApprovals && items.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
                    .background(Color.bgBase)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if items.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark.shield").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No items awaiting approval").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
                        } else {
                            ForEach(groupedByStatus, id: \.status) { group in
                                approvalSection(group)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
                }
                .background(Color.bgBase)
            }
        }
        .navigationBarTitle(Text("Approval Queue"), displayMode: .inline)
        .onAppear { appState.loadCardApprovalQueue() }
        .sheet(isPresented: $showOverrideSheet) {
            overrideSheet
        }
    }

    @ViewBuilder
    private func approvalSection(_ group: (status: String, label: String, color: Color, items: [CardTransaction])) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(group.color).frame(width: 8, height: 8)
                Text(group.label.uppercased())
                    .font(.system(size: 10, weight: .bold)).tracking(0.5)
                Text("\(group.items.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(group.color).cornerRadius(8)
                Spacer()
                Text(FormatUtils.formatGBP(group.items.reduce(0) { $0 + $1.amount }))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(group.color)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(group.color.opacity(0.06))

            Divider()
            ForEach(group.items) { tx in
                HStack(spacing: 0) {
                    NavigationLink(destination: CardTransactionDetailPage(transaction: tx).environmentObject(appState)) {
                        approvalRow(tx, color: group.color)
                    }.buttonStyle(PlainButtonStyle())

                    // Override button
                    Button(action: {
                        overrideTarget = tx
                        overrideReason = ""
                        showOverrideSheet = true
                    }) {
                        VStack(spacing: 3) {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.system(size: 13))
                            Text("Override")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 64)
                        .frame(maxHeight: .infinity)
                        .background(Color(red: 0.95, green: 0.55, blue: 0.15))
                    }.buttonStyle(BorderlessButtonStyle())
                }
                .frame(minHeight: 64)
                if tx.id != group.items.last?.id { Divider().padding(.leading, 14) }
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(group.color.opacity(0.25), lineWidth: 1))
        .clipped()
    }

    private func approvalRow(_ tx: CardTransaction, color: Color) -> some View {
        let dateText = tx.transactionDate > 0 ? FormatUtils.formatTimestamp(tx.transactionDate)
                     : tx.createdAt > 0 ? FormatUtils.formatTimestamp(tx.createdAt) : "—"
        let user = UsersData.byId[tx.holderId]
        let ageDays: Int = {
            let ref = tx.createdAt > 0 ? tx.createdAt : tx.transactionDate
            guard ref > 0 else { return 0 }
            let secs = (Date().timeIntervalSince1970 * 1000 - Double(ref)) / 1000
            return max(0, Int(secs / 86400))
        }()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tx.merchant.isEmpty ? (tx.description.isEmpty ? "—" : tx.description) : tx.merchant)
                            .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        if tx.isUrgent {
                            Text("Urgent")
                                .font(.system(size: 8, weight: .bold)).foregroundColor(.red)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.red.opacity(0.1)).cornerRadius(3)
                        }
                    }
                    Text(dateText).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(FormatUtils.formatGBP(tx.amount))
                        .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(color)
                    if !tx.nominalCode.isEmpty {
                        Text(tx.nominalCode)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.08)).cornerRadius(3)
                    }
                }
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(user?.fullName ?? (tx.holderName.isEmpty ? "—" : tx.holderName))
                        .font(.system(size: 11, weight: .semibold))
                    if !tx.department.isEmpty {
                        Text(tx.department).font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if tx.hasReceipt {
                    Image(systemName: "paperclip").font(.system(size: 10)).foregroundColor(.green)
                }
                Text("\(ageDays)d").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var overrideSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                if let tx = overrideTarget {
                    // Item summary
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ITEM").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tx.merchant.isEmpty ? tx.description : tx.merchant)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(tx.holderName.isEmpty ? "—" : tx.holderName)
                                    .font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(FormatUtils.formatGBP(tx.amount))
                                .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        }
                        .padding(14).background(Color(.systemGray6)).cornerRadius(10)
                    }

                    // Reason field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REASON FOR OVERRIDE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                        TextField("e.g. Approver unavailable, deadline critical…", text: $overrideReason)
                            .font(.system(size: 13))
                            .padding(12)
                            .background(Color.bgSurface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    Spacer()

                    // Confirm button
                    Button(action: submitOverride) {
                        HStack(spacing: 6) {
                            if isOverriding {
                                ActivityIndicator(isAnimating: true)
                            }
                            Text(isOverriding ? "Overriding…" : "Confirm Override")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding
                                    ? Color.gray.opacity(0.3) : Color(red: 0.95, green: 0.55, blue: 0.15))
                        .foregroundColor(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding
                                         ? .gray : .white)
                        .cornerRadius(12)
                    }
                    .disabled(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding)
                }
            }
            .padding(20)
            .background(Color.bgBase.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Override Approval", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                showOverrideSheet = false
            }.foregroundColor(.goldDark))
        }
    }

    private func submitOverride() {
        guard let tx = overrideTarget, !overrideReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isOverriding = true
        appState.overrideApprovalItem(tx.id, reason: overrideReason) { success in
            isOverriding = false
            if success { showOverrideSheet = false }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Top-Up To Do Page
// ═══════════════════════════════════════════════════════════════════

struct TopUpToDoPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var pendingExpanded = true
    @State private var historyExpanded = true
    @State private var showPartialSheet = false
    @State private var partialAmount = ""
    @State private var partialItemId = ""

    private var pending: [TopUpItem] {
        appState.topUpQueue.filter { $0.status.lowercased() == "pending" }
            .sorted { $0.createdAt < $1.createdAt }  // oldest first
    }
    private var history: [TopUpItem] {
        // Include partials alongside completed/skipped (partial renders with Skipped label)
        appState.topUpQueue.filter { ["completed", "skipped", "partial"].contains($0.status.lowercased()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if appState.isLoadingTopUps && appState.topUpQueue.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
                    .background(Color.bgBase)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        pendingSection
                        historySection
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
                }
                .background(Color.bgBase)
            }
        }
        .navigationBarTitle(Text("Top-Up To Do"), displayMode: .inline)
        .onAppear { appState.loadTopUpQueue() }
        .sheet(isPresented: $showPartialSheet) {
            PartialTopUpSheet(itemId: partialItemId, isPresented: $showPartialSheet)
                .environmentObject(appState)
        }
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
        .background(Color.bgSurface).cornerRadius(10)
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
                Button(action: { appState.markTopUpCompleted(item.id, amount: item.amount) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11))
                        Text("Mark Topped Up").font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(red: 0.0, green: 0.6, blue: 0.5)).cornerRadius(6)
                }.buttonStyle(BorderlessButtonStyle())
                Button(action: { partialItemId = item.id; partialAmount = ""; showPartialSheet = true }) {
                    Text("Partial Top-Up").font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.bgSurface)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
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
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func historyRow(_ item: TopUpItem) -> some View {
        let user = UsersData.byId[item.userId]
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let s = item.status.lowercased()
        let statusColor: Color = s == "completed" ? teal : .gray
        let statusLabel: String = s == "completed" ? "Completed" : "Skipped"
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
                    Text(statusLabel).font(.system(size: 10, weight: .semibold)).foregroundColor(statusColor)
                }
                Text(dateText).font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Manual Match Sheet
// ═══════════════════════════════════════════════════════════════════

struct ManualMatchSheet: View {
    @EnvironmentObject var appState: POViewModel
    let receiptId: String
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var matching = false

    private var transactions: [CardTransaction] {
        let q = searchText.lowercased()
        let all = appState.cardTransactions
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.merchant.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.cardLastFour.contains(q)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                    TextField("Search transactions...", text: $searchText).font(.system(size: 13))
                }
                .padding(10).background(Color.bgSurface).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

                if appState.isLoadingCardTxns {
                    VStack { Spacer(); LoaderView(); Spacer() }
                } else if transactions.isEmpty {
                    VStack { Spacer(); Text("No transactions found").font(.system(size: 13)).foregroundColor(.secondary); Spacer() }
                } else {
                    List {
                        ForEach(transactions) { tx in
                            Button(action: { matchTransaction(tx) }) {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tx.merchant.isEmpty ? tx.description : tx.merchant)
                                            .font(.system(size: 14, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                                        HStack(spacing: 6) {
                                            if !tx.cardLastFour.isEmpty {
                                                Text("•••• \(tx.cardLastFour)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                                            }
                                            if tx.transactionDate > 0 {
                                                Text(FormatUtils.formatTimestamp(tx.transactionDate)).font(.system(size: 10)).foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Text(FormatUtils.formatGBP(tx.amount))
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }.listStyle(GroupedListStyle())
                }
            }
            .background(Color.bgBase)
            .navigationBarTitle(Text("Match to Transaction"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") { isPresented = false }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark))
        }
    }

    private func matchTransaction(_ tx: CardTransaction) {
        matching = true
        appState.matchReceipt(receiptId, transactionId: tx.id) { _ in
            matching = false
            isPresented = false
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Partial Top-Up Sheet
// ═══════════════════════════════════════════════════════════════════

struct PartialTopUpSheet: View {
    @EnvironmentObject var appState: POViewModel
    let itemId: String
    @Binding var isPresented: Bool
    @State private var amount = ""
    @State private var note = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PARTIAL AMOUNT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                    HStack(spacing: 2) {
                        Text("£").font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark)
                        TextField("0.00", text: $amount)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.goldDark)
                            .keyboardType(.decimalPad)
                    }
                    .padding(10).background(Color.bgRaised).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("NOTE (OPTIONAL)").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                    TextField("Reason for partial top-up...", text: $note)
                        .font(.system(size: 13))
                        .padding(10).background(Color.bgRaised).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }

                Button(action: submit) {
                    Text("Confirm Partial Top-Up")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background((Double(amount) ?? 0) > 0 ? Color.gold : Color.gold.opacity(0.4))
                        .cornerRadius(10)
                }
                .disabled((Double(amount) ?? 0) <= 0)

                Spacer()
            }
            .padding(20)
            .background(Color.bgBase.edgesIgnoringSafeArea(.all))
            .navigationBarTitle(Text("Partial Top-Up"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") { isPresented = false }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark))
        }
    }

    private func submit() {
        guard let amt = Double(amount), amt > 0 else { return }
        appState.markTopUpCompleted(itemId, amount: amt, note: note.isEmpty ? "Partial" : note)
        isPresented = false
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - All Transactions Page
// ═══════════════════════════════════════════════════════════════════

struct AllTransactionsPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var searchText = ""
    @State private var isSearching = false
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

            // Filters / Search row — search icon expands into full search field, hiding chips
            if isSearching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13)).foregroundColor(.gray)
                    TextField("Search merchant, holder, code…", text: $searchText)
                        .font(.system(size: 13))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15)).foregroundColor(Color(.systemGray3))
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                    Button(action: { withAnimation(.easeInOut(duration: 0.22)) { isSearching = false; searchText = "" } }) {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.goldDark)
                    }.buttonStyle(BorderlessButtonStyle())
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.bgSurface).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldDark, lineWidth: 1.5))
            } else {
                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            dropdown(label: activeFilter, icon: "line.3.horizontal.decrease", action: { showFilterSheet = true })
                                .selectionActionSheet(
                                    title: "Status",
                                    isPresented: $showFilterSheet,
                                    options: filters,
                                    isSelected: { $0 == activeFilter },
                                    label: { $0 },
                                    onSelect: { activeFilter = $0 }
                                )
                            dropdown(label: activeCard, icon: "creditcard", action: { showCardSheet = true })
                                .selectionActionSheet(
                                    title: "Card",
                                    isPresented: $showCardSheet,
                                    options: cardOptions,
                                    isSelected: { $0 == activeCard },
                                    label: { $0 },
                                    onSelect: { activeCard = $0 }
                                )
                            dropdown(label: activeDept, icon: "building.2", action: { showDeptSheet = true })
                                .selectionActionSheet(
                                    title: "Department",
                                    isPresented: $showDeptSheet,
                                    options: deptOptions,
                                    isSelected: { $0 == activeDept },
                                    label: { $0 },
                                    onSelect: { activeDept = $0 }
                                )
                        }
                    }
                    // Search icon — always pinned at trailing edge
                    Button(action: { withAnimation(.easeInOut(duration: 0.22)) { isSearching = true } }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .medium)).foregroundColor(.goldDark)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(Color.bgSurface).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }

            // Scrollable rows section
            ScrollView {
                if appState.isLoadingCardTxns && appState.cardTransactions.isEmpty {
                    LoaderView()
                } else if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "tray").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No transactions").font(.system(size: 13)).foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: 480)
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
        .background(Color.bgSurface).cornerRadius(8)
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
            .background(Color.bgSurface).cornerRadius(6)
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
                .background(Color.bgSurface).cornerRadius(12)
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
        .background(Color.bgSurface).cornerRadius(10)
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
        let navy  = Color(red: 0.05, green: 0.15, blue: 0.42)
        switch tx.status.lowercased() {
        case "approved", "matched", "coded": return (teal, teal.opacity(0.12))
        case "posted": return (teal, teal.opacity(0.12))
        case "pending", "pending_receipt": return (orange, orange.opacity(0.12))
        case "pending_coding", "pending_code", "pending code": return (navy, navy.opacity(0.12))
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
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

struct CardRegisterPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToCardId: String? = nil
    @State private var navigateToRequestCard = false
    @State private var cardToAssign: ExpenseCard? = nil
    @State private var navigateToAssign = false
    @State private var rejectTargetCard: ExpenseCard? = nil
    @State private var rejectCardReason: String = ""
    @State private var showInlineRejectSheet = false
    @State private var cardToActivate: ExpenseCard? = nil
    @State private var navigateToActivate = false
    /// Search + status filter state — mirrors the web's CardRegisterPage.
    @State private var searchText: String = ""
    @State private var statusFilter: String = "all"
    @State private var showStatusFilterSheet: Bool = false

    /// Status filter options — keys match the web's STATUS_FILTERS.
    private let statusFilters: [(key: String, label: String)] = [
        ("all",        "All Status"),
        ("active",     "Active"),
        ("approved",   "Approved"),
        ("override",   "Override"),
        ("pending",    "Pending Approval"),
        ("requested",  "Requested"),
        ("rejected",   "Rejected"),
        ("suspended",  "Suspended"),
    ]

    private var statusFilterLabel: String {
        statusFilters.first { $0.key == statusFilter }?.label ?? "All Status"
    }

    /// Filter by status + free-text search — mirrors the web's filter logic
    /// (holder name, department, BS code, card issuer, last 4).
    private var filteredCards: [ExpenseCard] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return appState.userCards.filter { c in
            // Status filter
            if statusFilter != "all" && c.status.lowercased() != statusFilter {
                return false
            }
            // Search
            guard !q.isEmpty else { return true }
            let holder = c.holderFullName.lowercased()
            let dept   = c.department.lowercased()
            let bs     = c.bsControlCode.lowercased()
            let issuer = (c.bankAccount?.name ?? c.cardIssuer).lowercased()
            let last4  = c.lastFour.lowercased()
            return holder.contains(q)
                || dept.contains(q)
                || bs.contains(q)
                || issuer.contains(q)
                || last4.contains(q)
        }
    }

    private var tierCount: Int { appState.cardTierConfigRows.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // ── Fixed search + status filter toolbar ───────────────
                // (Stays pinned at the top while the card list scrolls.)
                HStack(spacing: 8) {
                    // Search
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray).font(.system(size: 12))
                        TextField("Search holder, dept, BS code, last 4…", text: $searchText)
                            .font(.system(size: 13))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12)).foregroundColor(.gray)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color.bgSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                    // Status filter
                    Button(action: { showStatusFilterSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                            Text(statusFilterLabel)
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .selectionActionSheet(
                        title: "Filter by Status",
                        isPresented: $showStatusFilterSheet,
                        options: statusFilters.map { $0.key },
                        isSelected: { $0 == statusFilter },
                        label: { key in statusFilters.first { $0.key == key }?.label ?? key },
                        onSelect: { statusFilter = $0 }
                    )
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

                // ── Scrollable card list ────────────────────────────────
                ScrollView {
                    VStack(spacing: 12) {

                        // MARK: Cards Section
                        if appState.isLoadingCards && appState.userCards.isEmpty {
                            LoaderView()
                        } else if appState.userCards.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "creditcard").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                                Text("No cards yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                                Text("Tap Request Card to add one").font(.system(size: 12)).foregroundColor(.gray)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
                        } else if filteredCards.isEmpty {
                            // Search/filter applied but no matches
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "magnifyingglass").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text(searchText.isEmpty
                                     ? "No cards match this filter"
                                     : "No cards match \"\(searchText)\"")
                                    .font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 320)
                        } else {
                            // Hidden NavigationLink for Assign Physical Card
                            NavigationLink(
                                destination: Group {
                                    if let c = cardToAssign {
                                        AssignPhysicalCardPage(card: c).environmentObject(appState)
                                    } else { EmptyView() }
                                },
                                isActive: $navigateToAssign
                            ) { EmptyView() }
                            .frame(width: 0, height: 0).hidden()

                            ForEach(filteredCards) { card in
                                ZStack(alignment: .topLeading) {
                                    NavigationLink(
                                        destination: CardDetailPage(card: card).environmentObject(appState),
                                        tag: card.id,
                                        selection: $navigateToCardId
                                    ) { EmptyView() }
                                    .frame(width: 0, height: 0).hidden()

                                    CardRow(
                                        card: card,
                                        isAccountant: true,
                                        tierCount: tierCount,
                                        resolvedBankName: {
                                            if let bankId = card.bankAccount?.id, !bankId.isEmpty {
                                                return appState.bankAccounts.first { $0.id == bankId }?.name
                                            }
                                            return nil
                                        }(),
                                        onAssignPhysical: nil,
                                        onApprove: nil,
                                        onReject: nil,
                                        onOverride: nil,
                                        onActivate: {
                                            cardToActivate = card
                                            navigateToActivate = true
                                        }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture { navigateToCardId = card.id }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 90)
                }
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
        .sheet(isPresented: $showInlineRejectSheet, onDismiss: { rejectCardReason = "" }) {
            NavigationView {
                ZStack {
                    Color.bgBase.edgesIgnoringSafeArea(.all)
                    VStack(alignment: .leading, spacing: 16) {
                        if let c = rejectTargetCard {
                            Text("Reject card request from \(c.holderFullName)")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reason").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                            TextField("Enter reason…", text: $rejectCardReason)
                                .font(.system(size: 14)).padding(10)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        Spacer()
                    }.padding()
                }
                .navigationBarTitle(Text("Reject Card"), displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") { showInlineRejectSheet = false }.foregroundColor(.goldDark),
                    trailing: Button("Reject") {
                        let reason = rejectCardReason.trimmingCharacters(in: .whitespaces)
                        guard !reason.isEmpty, let c = rejectTargetCard else { return }
                        appState.rejectCard(c, reason: reason)
                        showInlineRejectSheet = false
                    }.foregroundColor(.red).font(.system(size: 16, weight: .bold))
                )
            }
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let c = cardToActivate {
                        ActivateCardPage(card: c).environmentObject(appState)
                    } else { EmptyView() }
                },
                isActive: $navigateToActivate
            ) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            NavigationLink(destination: RequestCardPage().environmentObject(appState),
                           isActive: $navigateToRequestCard) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .onAppear {
            appState.loadUserCards()
            if appState.bankAccounts.isEmpty { appState.loadBankAccounts() }
        }
    }
}

struct BankAccountRow: View {
    let account: ProductionBankAccount
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.13, green: 0.37, blue: 0.8).opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.13, green: 0.37, blue: 0.8))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(account.accountHolderName)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("••\(String(account.accountNumber.suffix(4)))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        if let sc = account.sortCode {
                            Text(sc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                    VStack(spacing: 0) {
                        if let iban = account.ibanNumber, !iban.isEmpty {
                            bankDetailRow(label: "IBAN", value: iban)
                        }
                        if let swift = account.swiftCode, !swift.isEmpty {
                            bankDetailRow(label: "SWIFT / BIC", value: swift)
                        }
                        if let nominal = account.nominalCode, !nominal.isEmpty {
                            bankDetailRow(label: "Nominal Code", value: nominal)
                        }
                        if let ap = account.accPayableCode, !ap.isEmpty {
                            bankDetailRow(label: "A/P Code", value: ap)
                        }
                        if let prefix = account.paymentPrefix, !prefix.isEmpty {
                            bankDetailRow(label: "Payment Prefix", value: prefix)
                        }
                        ForEach(account.additionalDetails, id: \.field) { detail in
                            bankDetailRow(label: detail.field, value: detail.value)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemBackground))
                }
            }
        }
    }

    private func bankDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.vertical, 5)
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
                // Search + Filter in one line
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                        TextField("Search receipts…", text: $searchText).font(.system(size: 14))
                    }
                    .padding(10).background(Color.bgSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                    Button(action: { showFilterSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                            Text(activeFilter.rawValue)
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
                        options: ReceiptFilter.allCases,
                        isSelected: { $0 == activeFilter },
                        label: { $0.rawValue },
                        onSelect: { activeFilter = $0 }
                    )
                }
                .padding(.horizontal, 16).padding(.top, 12)

                ScrollView {
                    VStack(spacing: 10) {
                        if appState.isLoadingReceipts && appState.myCardReceipts.isEmpty {
                            LoaderView()
                        } else if filtered.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No transactions found").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
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
        .onAppear {
            // Receipts tab loads its own data only
            appState.loadMyCardReceipts()
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
                    if appState.isLoadingCards && appState.userCards.isEmpty {
                        LoaderView()
                    } else if appState.userCards.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "creditcard").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                            Text("No cards yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                            Text("Request a new card to get started").font(.system(size: 12)).foregroundColor(.gray)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 480)
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
        .onAppear { appState.loadUserCards() }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Detail Page
// ═══════════════════════════════════════════════════════════════════

struct CardDetailPage: View {
    let card: ExpenseCard
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var liveCard: ExpenseCard? = nil
    @State private var showRejectSheet = false
    @State private var rejectReason = ""
    @State private var showCardNumber = false
    @State private var navigateToAssign = false
    @State private var navigateToEdit = false
    @State private var navigateToHistory = false
    @State private var navigateToActivate = false
    @State private var deleting = false

    enum StatusOperation { case suspending, reactivating }
    @State private var pendingOperation: StatusOperation? = nil

    enum ActiveAlert: Identifiable {
        case deleteConfirm, suspendConfirm, reactivateConfirm
        var id: Int { hashValue }
    }
    @State private var activeAlert: ActiveAlert? = nil

    private var displayCard: ExpenseCard { liveCard ?? card }
    private var isAccountant: Bool { appState.currentUser?.isAccountant ?? false }
    /// True only while the card is still awaiting tier approvals.
    /// Approved / override / active / suspended / rejected cards have finished the approval workflow
    /// and should not show the "Pending Approval" section or action buttons.
    private var isPendingApproval: Bool { displayCard.status.lowercased() == "pending" }
    private var isOwnCard: Bool { displayCard.holderId == appState.userId }
    private var canEditRequest: Bool {
        // User can edit their own card while still in requested/pending state (not yet approved/active).
        // Accountants can also edit any card while it's in requested/pending state.
        let editableStatuses: Set<String> = ["requested", "pending"]
        guard editableStatuses.contains(displayCard.status.lowercased()) else { return false }
        return isOwnCard || isAccountant
    }

    private var totalTiers: Int {
        let cfg = ApprovalHelpers.resolveConfig(appState.cardTierConfigRows, deptId: displayCard.departmentId, amount: displayCard.monthlyLimit)
            ?? ApprovalHelpers.resolveConfig(appState.cardTierConfigRows, deptId: nil, amount: displayCard.monthlyLimit)
            ?? ApprovalHelpers.resolveConfig(appState.cardTierConfigRows, deptId: nil)
        let fromConfig = ApprovalHelpers.getTotalTiers(cfg)
        if fromConfig > 0 { return fromConfig }
        let maxApproved = displayCard.approvals.map { $0.tierNumber }.max() ?? 0
        return max(maxApproved + 1, 2)
    }

    /// True only when the current user can approve at this card's
    /// active tier (mirrors the web's `vis.canApprove`). Drives the
    /// inline Approve / Reject buttons in the Pending Approval panel.
    private var canApproveCard: Bool {
        guard let cfg = ApprovalHelpers.resolveConfig(
            appState.cardTierConfigRows,
            deptId: displayCard.departmentId,
            amount: displayCard.monthlyLimit
        ) else { return false }
        var po = PurchaseOrder()
        po.id = displayCard.id
        po.userId = displayCard.holderId
        po.departmentId = displayCard.departmentId
        po.status = "PENDING"
        po.approvals = displayCard.approvals
        po.netAmount = displayCard.monthlyLimit
        return ApprovalHelpers.getVisibility(po: po, config: cfg, userId: appState.userId).canApprove
    }

    /// True when the user has card-override privilege.
    private var canOverrideCard: Bool { appState.cashMeta?.can_override == true }

    private var approverName: String {
        guard let id = displayCard.approvedBy, !id.isEmpty else { return "" }
        return UsersData.byId[id]?.fullName ?? id
    }

    private var resolvedBankAccount: ProductionBankAccount? {
        if let bankId = displayCard.bankAccount?.id, !bankId.isEmpty {
            return appState.bankAccounts.first { $0.id == bankId }
        }
        return nil
    }

    private var resolvedBankName: String {
        resolvedBankAccount?.name ?? displayCard.bankName
    }

    private var resolvedSortCode: String {
        resolvedBankAccount?.sortCode ?? ""
    }

    private var resolvedAccountNumber: String {
        let num = resolvedBankAccount?.accountNumber ?? ""
        guard !num.isEmpty else { return "—" }
        if num.count > 4 {
            let masked = String(repeating: "•", count: num.count - 4)
            return masked + num.suffix(4)
        }
        return num
    }

    private var cardStatusBadge: some View {
        let status = displayCard.status.lowercased()
        let (label, fg, bg): (String, Color, Color) = {
            let purple = Color(red: 0.5, green: 0.1, blue: 0.8)
            switch status {
            case "active":
                return displayCard.isDigitalOnly ? ("Digital Active", Color(red: 0.0, green: 0.6, blue: 0.7), Color(red: 0.0, green: 0.6, blue: 0.7).opacity(0.15))
                                                 : ("Active", .green, Color.green.opacity(0.15))
            case "suspended":    return ("Suspended", purple, purple.opacity(0.15))
            case "requested":    return ("Requested", .orange, Color.orange.opacity(0.15))
            case "pending":      return ("Pending Approval", .orange, Color.orange.opacity(0.15))
            case "approved",
                 "override":     return ("Approved", .green, Color.green.opacity(0.15))
            case "rejected":     return ("Rejected", .red, Color.red.opacity(0.15))
            default:             return (status.capitalized, .goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(bg).cornerRadius(5)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                    // ── Card number + holder subtitle ──
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 10) {
                            let fullNumber = displayCard.digitalCardNumber ?? displayCard.physicalCardNumber
                            if showCardNumber, let num = fullNumber, !num.isEmpty {
                                Text(formatCardNum(num))
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(.goldDark)
                            } else {
                                HStack(spacing: 4) {
                                    Text("•••• •••• ••••").font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                                    Text(displayCard.lastFour.isEmpty ? "——" : displayCard.lastFour)
                                        .font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                                }
                            }
                            Button(action: { showCardNumber.toggle() }) {
                                Image(systemName: showCardNumber ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(showCardNumber ? .secondary : .goldDark)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                            cardStatusBadge
                        }
                        let subtitle = [displayCard.holderFullName, displayCard.holderDesignation, resolvedBankName]
                            .filter { !$0.isEmpty }.joined(separator: " · ")
                        if !subtitle.isEmpty {
                            Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 18)

                    // ── Stats + Utilisation only when the card is active / suspended ──
                    // For pending, requested, approved, rejected states, spending data is meaningless.
                    let statusLower = displayCard.status.lowercased()
                    let showSpending = statusLower == "active" || statusLower == "suspended"

                    if showSpending {
                        // ── Stats: Card Limit | Available | Total Spent ──
                        HStack(spacing: 0) {
                            statCol("CARD LIMIT",   FormatUtils.formatGBP(displayCard.monthlyLimit),   .goldDark)
                            statCol("AVAILABLE",    FormatUtils.formatGBP(displayCard.currentBalance), Color(red: 0, green: 0.6, blue: 0.5))
                            statCol("TOTAL SPENT",  FormatUtils.formatGBP(displayCard.spentAmount),    .primary)
                        }
                        .padding(.horizontal, 20).padding(.bottom, 14)

                        // ── Utilisation bar (only when a limit is set) ──
                        if displayCard.monthlyLimit > 0 {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("UTILISATION").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                    Spacer()
                                    Text("\(Int(displayCard.spendPercent * 100))%").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5)).frame(height: 6)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(displayCard.spendPercent > 0.8 ? Color.red : Color.goldDark)
                                            .frame(width: max(geo.size.width * CGFloat(min(displayCard.spendPercent, 1.0)), 0), height: 6)
                                    }
                                }.frame(height: 6)
                                HStack {
                                    Text("Spent: \(FormatUtils.formatGBP(displayCard.spentAmount))").font(.system(size: 10)).foregroundColor(.secondary)
                                    Spacer()
                                    Text("Limit: \(FormatUtils.formatGBP(displayCard.monthlyLimit))").font(.system(size: 10)).foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 20).padding(.bottom, 20)
                        }
                    } else if displayCard.monthlyLimit > 0 {
                        // For non-active states, just show the proposed limit compactly
                        HStack {
                            Text("PROPOSED LIMIT").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                            Spacer()
                            Text(FormatUtils.formatGBP(displayCard.monthlyLimit))
                                .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        }
                        .padding(.horizontal, 20).padding(.bottom, 20)
                    }

                    // ── Detail grid (only visible rows) ──
                    let hasHolder  = !displayCard.holderFullName.isEmpty
                    let hasDept    = !displayCard.department.isEmpty
                    let hasBSCode  = !displayCard.bsControlCode.isEmpty
                    let hasIssuer  = !resolvedBankName.isEmpty
                    let hasAccNum  = resolvedAccountNumber != "—"
                    let hasDigital = !(displayCard.digitalCardNumber  ?? "").isEmpty
                    let hasPhysical = !(displayCard.physicalCardNumber ?? "").isEmpty

                    if hasHolder || hasDept || hasBSCode || hasIssuer {
                        Divider()
                        VStack(spacing: 0) {

                            // Row: CARD HOLDER / DEPARTMENT
                            if hasHolder || hasDept {
                                HStack(alignment: .top, spacing: 16) {
                                    if hasHolder {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("CARD HOLDER")
                                                .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                            Text(displayCard.holderFullName).font(.system(size: 14, weight: .semibold))
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    if hasDept {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("DEPARTMENT")
                                                .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                            Text(displayCard.department).font(.system(size: 14, weight: .semibold))
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.horizontal, 20).padding(.vertical, 12)
                            }

                            // Row: BS CONTROL CODE / CARD ISSUER
                            if hasBSCode || hasIssuer {
                                if hasHolder || hasDept { Divider().padding(.horizontal, 20) }
                                HStack(alignment: .top, spacing: 16) {
                                    if hasBSCode {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("BS CONTROL CODE")
                                                .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                            Text(displayCard.bsControlCode).font(.system(size: 14, weight: .semibold))
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    if hasIssuer {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("CARD ISSUER")
                                                .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                            Text(resolvedBankName).font(.system(size: 14, weight: .semibold))
                                            if !resolvedSortCode.isEmpty {
                                                HStack(spacing: 4) {
                                                    Text("Sort:").font(.system(size: 10)).foregroundColor(.secondary)
                                                    Text(resolvedSortCode).font(.system(size: 10, weight: .medium, design: .monospaced))
                                                }
                                            }
                                            if hasAccNum {
                                                HStack(spacing: 4) {
                                                    Text("Acc:").font(.system(size: 10)).foregroundColor(.secondary)
                                                    Text(resolvedAccountNumber).font(.system(size: 10, weight: .medium, design: .monospaced))
                                                }
                                            }
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.horizontal, 20).padding(.vertical, 12)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // ── Digital / Physical card numbers (only if present) ──
                    if hasDigital || hasPhysical {
                        Divider()
                        HStack(alignment: .top, spacing: 0) {
                            if hasDigital {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("DIGITAL CARD")
                                        .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                    Text(showCardNumber ? formatCardNum(displayCard.digitalCardNumber) : maskedCardNum(displayCard.digitalCardNumber))
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if hasPhysical {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("PHYSICAL CARD")
                                        .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                    Text(showCardNumber ? formatCardNum(displayCard.physicalCardNumber) : maskedCardNum(displayCard.physicalCardNumber))
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                    // ── Assign Physical Card (digital-only cards) ──
                    if displayCard.isDigitalOnly {
                        NavigationLink(
                            destination: AssignPhysicalCardPage(card: displayCard).environmentObject(appState),
                            isActive: $navigateToAssign
                        ) { EmptyView() }
                        .frame(width: 0, height: 0).hidden()

                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("PHYSICAL CARD").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                Text("No physical card assigned yet").font(.system(size: 13)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { navigateToAssign = true }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "creditcard.and.123").font(.system(size: 11, weight: .semibold))
                                    Text("Assign Physical Card").font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(Color.orange).cornerRadius(8)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                    // ── Justification ──
                    if !displayCard.justification.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 5) {
                            Text("JUSTIFICATION").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                            Text(displayCard.justification).font(.system(size: 14))
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                    // ── Pending approval chain + action buttons (accountant only) ──
                    if isPendingApproval && isAccountant {
                        Divider()
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Pending Approval")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.orange)

                            if totalTiers > 0 {
                                HStack(spacing: 0) {
                                    ForEach(1...totalTiers, id: \.self) { tier in
                                        let isApproved = displayCard.approvals.contains { $0.tierNumber == tier }
                                        let isCurrent  = !isApproved && (tier == 1 || displayCard.approvals.contains { $0.tierNumber == tier - 1 })
                                        if tier > 1 {
                                            Rectangle()
                                                .fill(displayCard.approvals.contains { $0.tierNumber == tier - 1 } ? Color.green.opacity(0.4) : Color.gray.opacity(0.3))
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
                                            Text("Level \(tier)").font(.system(size: 9, weight: .semibold))
                                                .foregroundColor(isApproved ? .green : isCurrent ? .goldDark : .gray)
                                            if isApproved {
                                                let u = displayCard.approvals.first(where: { $0.tierNumber == tier }).flatMap { UsersData.byId[$0.userId] }
                                                if let user = u {
                                                    Text(user.fullName).font(.system(size: 8, weight: .medium)).foregroundColor(.green).lineLimit(1)
                                                    if !user.displayDesignation.isEmpty {
                                                        Text(user.displayDesignation).font(.system(size: 7)).foregroundColor(.green.opacity(0.8)).lineLimit(1)
                                                    }
                                                }
                                            } else {
                                                Text("Awaiting").font(.system(size: 8)).foregroundColor(isCurrent ? .goldDark : .gray)
                                            }
                                        }.frame(minWidth: 60)
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            // Action buttons — gated by per-card permissions:
                            //   • Override: only for users with card-override privilege.
                            //   • Approve / Reject: only when it's the current user's
                            //     turn at the active approval tier.
                            // A non-approver accountant who has override privilege
                            // sees only the Override button (matches the web).
                            if canApproveCard || canOverrideCard {
                                HStack(spacing: 10) {
                                    Spacer()
                                    if canOverrideCard {
                                        Button(action: { appState.overrideCard(displayCard); presentationMode.wrappedValue.dismiss() }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold))
                                                Text("Override").font(.system(size: 13, weight: .bold))
                                            }
                                            .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(Color.orange).cornerRadius(8)
                                        }.buttonStyle(BorderlessButtonStyle())
                                    }
                                    if canApproveCard {
                                        Button(action: { showRejectSheet = true }) {
                                            Text("Reject").font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 10)
                                                .background(Color.red).cornerRadius(8)
                                        }.buttonStyle(BorderlessButtonStyle())
                                        Button(action: { appState.approveCard(displayCard); presentationMode.wrappedValue.dismiss() }) {
                                            Text("Approve").font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 10)
                                                .background(Color.green).cornerRadius(8)
                                        }.buttonStyle(BorderlessButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                    // Edit (+ Delete for users) buttons — shown while card is in requested/pending state.
                    // Users see Delete + Edit (they can cancel their own request).
                    // Accountants see just Edit (they can modify details on behalf of requester).
                    if canEditRequest {
                        Divider()
                        HStack(spacing: 10) {
                            if !isAccountant {
                                Button(action: { activeAlert = .deleteConfirm }) {
                                    HStack(spacing: 6) {
                                        if deleting {
                                            ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: "trash").font(.system(size: 12, weight: .bold))
                                        }
                                        Text(deleting ? "Deleting…" : "Delete").font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red).cornerRadius(8)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .disabled(deleting)
                            }

                            Button(action: { navigateToEdit = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil").font(.system(size: 12, weight: .bold))
                                    Text("Edit Request").font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.gold).cornerRadius(8)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                    if !approverName.isEmpty {
                        Text("Approved by \(approverName)")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                    }

                    // Activate Card — accountant only, when status is approved/override (not yet active)
                    if isAccountant && (displayCard.status.lowercased() == "approved" || displayCard.status.lowercased() == "override") {
                        Divider()
                        Button(action: { navigateToActivate = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "creditcard.and.123").font(.system(size: 12, weight: .bold))
                                let hasNum = !(displayCard.physicalCardNumber ?? "").isEmpty || !(displayCard.digitalCardNumber ?? "").isEmpty
                                Text(hasNum ? "Activate Card" : "Activate & Assign Card Number")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange).cornerRadius(10)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                    // Suspend / Reactivate — accountant only, when card is active or suspended.
                    // While an operation is in flight, pin the button to the operation being
                    // performed so labels don't flip mid-request (optimistic status update
                    // would otherwise swap Suspend ↔ Re-activate while the spinner is showing).
                    if isAccountant && (displayCard.status.lowercased() == "active" || displayCard.status.lowercased() == "suspended" || pendingOperation != nil) {
                        Divider()
                        Group {
                            let showingSuspend: Bool = {
                                if let op = pendingOperation { return op == .suspending }
                                return displayCard.status.lowercased() == "active"
                            }()

                            if showingSuspend {
                                Button(action: { activeAlert = .suspendConfirm }) {
                                    HStack(spacing: 6) {
                                        if pendingOperation == .suspending {
                                            ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: "pause.circle.fill").font(.system(size: 12, weight: .semibold))
                                        }
                                        Text(pendingOperation == .suspending ? "Suspending…" : "Suspend Card").font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.orange).cornerRadius(10)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .disabled(pendingOperation != nil)
                            } else {
                                Button(action: { activeAlert = .reactivateConfirm }) {
                                    HStack(spacing: 6) {
                                        if pendingOperation == .reactivating {
                                            ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: "play.circle.fill").font(.system(size: 12, weight: .semibold))
                                        }
                                        Text(pendingOperation == .reactivating ? "Reactivating…" : "Re-activate Card").font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.green).cornerRadius(10)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .disabled(pendingOperation != nil)
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                Spacer(minLength: 20)
            }
        }
        .background(Color.bgSurface)
        .navigationBarTitle(Text("Card Details"), displayMode: .inline)
        .navigationBarItems(trailing:
            Button(action: { navigateToHistory = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 14, weight: .semibold))
                    Text("History").font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.goldDark)
            }
        )
        .background(
            NavigationLink(destination: EditCardRequestPage(card: displayCard).environmentObject(appState),
                           isActive: $navigateToEdit) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            NavigationLink(destination: CardHistoryPage(cardId: displayCard.id, cardLabel: displayCard.holderFullName).environmentObject(appState),
                           isActive: $navigateToHistory) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            NavigationLink(destination: ActivateCardPage(card: displayCard).environmentObject(appState),
                           isActive: $navigateToActivate) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .deleteConfirm:
                return Alert(
                    title: Text("Delete Card Request?"),
                    message: Text("This will permanently delete your card request. This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleting = true
                        appState.deleteCardRequest(id: displayCard.id) { success in
                            deleting = false
                            if success { presentationMode.wrappedValue.dismiss() }
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .suspendConfirm:
                return Alert(
                    title: Text("Suspend Card?"),
                    message: Text("The card will be temporarily disabled. You can re-activate it anytime."),
                    primaryButton: .destructive(Text("Suspend")) {
                        pendingOperation = .suspending
                        appState.suspendCard(id: displayCard.id) { _ in
                            pendingOperation = nil
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .reactivateConfirm:
                return Alert(
                    title: Text("Re-activate Card?"),
                    message: Text("The card will be re-enabled for spending."),
                    primaryButton: .default(Text("Re-activate")) {
                        pendingOperation = .reactivating
                        appState.reactivateCard(id: displayCard.id) { _ in
                            pendingOperation = nil
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            appState.loadCard(card.id) { fetched in liveCard = fetched }
            if appState.bankAccounts.isEmpty { appState.loadBankAccounts() }
        }
        .onReceive(appState.$userCards) { cards in
            if let updated = cards.first(where: { $0.id == card.id }) {
                liveCard = updated
            }
        }
        .onReceive(appState.$allCards) { cards in
            if let updated = cards.first(where: { $0.id == card.id }) {
                liveCard = updated
            }
        }
        .sheet(isPresented: $showRejectSheet) {
            NavigationView {
                ZStack {
                    Color.bgBase.edgesIgnoringSafeArea(.all)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reject card request from \(displayCard.holderName)")
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
                .navigationBarTitle(Text("Reject Card"), displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") { showRejectSheet = false; rejectReason = "" }.foregroundColor(.goldDark),
                    trailing: Button("Reject") {
                        guard !rejectReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.rejectCard(displayCard, reason: rejectReason.trimmingCharacters(in: .whitespaces))
                        showRejectSheet = false; rejectReason = ""
                        presentationMode.wrappedValue.dismiss()
                    }.foregroundColor(.red).font(.system(size: 16, weight: .bold))
                )
            }
        }
    }

    private func statCol(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailGrid(_ l1: String, _ v1: String, _ l2: String, _ v2: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l1).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                Text(v1.isEmpty ? "—" : v1).font(.system(size: 14, weight: .semibold))
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !l2.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l2).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                    Text(v2.isEmpty ? "—" : v2).font(.system(size: 14, weight: .semibold))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private func formatCardNum(_ raw: String?) -> String {
        guard let s = raw, !s.isEmpty else { return "—" }
        let digits = s.filter { $0.isNumber }
        guard !digits.isEmpty else { return s }
        return stride(from: 0, to: digits.count, by: 4).map { i -> String in
            let start = digits.index(digits.startIndex, offsetBy: i)
            let end   = digits.index(start, offsetBy: min(4, digits.count - i))
            return String(digits[start..<end])
        }.joined(separator: " ")
    }

    private func maskedCardNum(_ raw: String?) -> String {
        guard let s = raw, !s.isEmpty else { return "—" }
        let digits = s.filter { $0.isNumber }
        guard digits.count >= 4 else { return "••••" }
        let last4 = String(digits.suffix(4))
        let groupCount = Int(ceil(Double(digits.count) / 4.0))
        let masked = Array(repeating: "••••", count: groupCount - 1).joined(separator: " ")
        return masked + " " + last4
    }
}

struct CardRow: View {
    let card: ExpenseCard
    var isAccountant: Bool = false
    var tierCount: Int = 0
    var resolvedBankName: String? = nil
    /// Whether the current user is in the active tier of this card's
    /// approval chain (mirrors the web's `vis.canApprove`). When false,
    /// the inline Approve / Reject buttons are hidden — matches the
    /// web behaviour where an accountant who can override but isn't a
    /// tier approver only sees the Override button.
    var canApprove: Bool = false
    var onAssignPhysical: (() -> Void)? = nil
    var onApprove: (() -> Void)? = nil
    var onReject: (() -> Void)? = nil
    var onOverride: (() -> Void)? = nil
    var onActivate: (() -> Void)? = nil

    private var displayBankName: String { resolvedBankName ?? card.bankName }
    private var totalTiers: Int { max(tierCount, card.approvals.count + (card.status == "pending" ? 1 : 0)) }
    private var approvedCount: Int { card.approvals.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Top row: icon + badges ──
            HStack(spacing: 6) {
                Image(systemName: "creditcard.fill").font(.system(size: 16)).foregroundColor(.goldDark)
                Spacer()
                if card.isDigitalOnly, let action = onAssignPhysical {
                    Button(action: action) {
                        HStack(spacing: 4) {
                            Image(systemName: "creditcard.and.123").font(.system(size: 9, weight: .semibold))
                            Text("Assign Physical Card").font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.orange).cornerRadius(4)
                    }.buttonStyle(BorderlessButtonStyle())
                }
                let (fg, bg) = cardStatusColor(card.status)
                let badgeLabel: String = {
                    if (card.status == "pending" || card.status == "approved") && totalTiers > 0 {
                        return "\(card.statusDisplay(isAccountant: isAccountant)) (\(approvedCount)/\(totalTiers))"
                    }
                    return card.statusDisplay(isAccountant: isAccountant)
                }()
                Text(badgeLabel).font(.system(size: 10, weight: .semibold)).foregroundColor(fg)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
            }

            if card.status == "active" || card.status == "suspended" {
                // ── Active / Suspended ──
                HStack(spacing: 4) {
                    Text("•••• •••• ••••").font(.system(size: 14, design: .monospaced)).foregroundColor(.gray)
                    Text(card.lastFour.isEmpty ? "0000" : card.lastFour)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !displayBankName.isEmpty {
                    Text(displayBankName).font(.system(size: 12)).foregroundColor(.secondary)
                }
                if !card.bsControlCode.isEmpty {
                    HStack {
                        Text("BS Control").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text(card.bsControlCode).font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.bgRaised).cornerRadius(6)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit))/mo")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Balance").font(.system(size: 10)).foregroundColor(.secondary)
                        Text(FormatUtils.formatGBP(card.currentBalance))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.bgRaised).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(card.spendPercent > 0.8 ? Color(red: 0.91, green: 0.29, blue: 0.48) : Color.gold)
                            .frame(width: geo.size.width * CGFloat(min(card.spendPercent, 1.0)), height: 5)
                    }
                }.frame(height: 5)

            } else if card.status == "requested" {
                // ── Requested ──
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 12)).foregroundColor(.secondary)
                }
                if card.monthlyLimit > 0 || card.proposedLimit > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        // Prefer monthly_limit (the field PATCH updates). Fall back
                        // to proposed_limit only when monthly_limit is unset.
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit > 0 ? card.monthlyLimit : card.proposedLimit))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }

            } else if card.status == "pending" || card.status == "approved" || card.status == "override" {
                // ── Pending / Approved ──
                let isFullyApproved = card.status == "approved" || card.status == "override"
                Text(isFullyApproved ? "Approved" : "Pending Approval")
                    .font(.system(size: 12, weight: .medium)).italic()
                    .foregroundColor(isFullyApproved ? .green : .orange)
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                HStack(spacing: 4) {
                    if !card.holderDesignation.isEmpty {
                        Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    if !displayBankName.isEmpty {
                        Text(card.holderDesignation.isEmpty ? displayBankName : "· \(displayBankName)")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                if !card.bsControlCode.isEmpty {
                    HStack {
                        Text("BS Control").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text(card.bsControlCode).font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.bgRaised).cornerRadius(6)
                }
                if card.monthlyLimit > 0 || card.proposedLimit > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        // Prefer monthly_limit (the field PATCH updates). Fall back
                        // to proposed_limit only when monthly_limit is unset.
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit > 0 ? card.monthlyLimit : card.proposedLimit))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }

                // Approval progress circles — only in detail page (when action callbacks are set)
                if totalTiers > 0 && onApprove != nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(1...totalTiers, id: \.self) { tier in
                                let isApproved = card.approvals.contains { $0.tierNumber == tier }
                                let isCurrent = !isApproved && tier == approvedCount + 1
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .stroke(isApproved ? Color.green : isCurrent ? Color.orange : Color.gray.opacity(0.3), lineWidth: 2)
                                            .frame(width: 34, height: 34)
                                        if isApproved {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold)).foregroundColor(.green)
                                        } else {
                                            Circle()
                                                .fill(isCurrent ? Color.orange.opacity(0.15) : Color.clear)
                                                .frame(width: 28, height: 28)
                                        }
                                    }
                                    Text("Level \(tier)").font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(isApproved ? .green : isCurrent ? .orange : .gray)
                                    if isApproved, let approverEntry = card.approvals.first(where: { $0.tierNumber == tier }),
                                       let user = UsersData.byId[approverEntry.userId] {
                                        Text(user.fullName).font(.system(size: 8, weight: .medium)).foregroundColor(.green).lineLimit(1)
                                        if !user.displayDesignation.isEmpty {
                                            Text(user.displayDesignation).font(.system(size: 7)).foregroundColor(.green.opacity(0.8)).lineLimit(1)
                                        }
                                    } else {
                                        Text("Awaiting").font(.system(size: 8))
                                            .foregroundColor(isCurrent ? .orange : .gray)
                                    }
                                }
                                .frame(minWidth: 64)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Inline action buttons (mirrors the web logic):
                //   • Override → only when the caller passed an
                //     `onOverride` handler (i.e. user has card-override
                //     permission).
                //   • Approve / Reject → only when the user is in the
                //     active tier of this card's approval chain
                //     (`canApprove == true`). If a non-approver
                //     accountant has override privilege, only the
                //     Override button shows.
                let showApprove = canApprove && onApprove != nil
                let showReject  = canApprove && onReject  != nil
                let showOverride = onOverride != nil
                if showApprove || showReject || showOverride {
                    HStack(spacing: 8) {
                        Spacer()
                        if showOverride, let ov = onOverride {
                            Button(action: ov) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold))
                                    Text("Override").font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.orange).cornerRadius(7)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        if showReject, let rj = onReject {
                            Button(action: rj) {
                                Text("Reject").font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.red).cornerRadius(7)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        if showApprove, let ap = onApprove {
                            Button(action: ap) {
                                Text("Approve").font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.green).cornerRadius(7)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }

                // Activate button (full-width) — accountant side, card is approved
                if isAccountant, card.status == "approved" || card.status == "override", let act = onActivate {
                    Button(action: act) {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard.and.123").font(.system(size: 12, weight: .bold))
                            let hasNumber = !(card.physicalCardNumber ?? "").isEmpty
                            Text(hasNumber ? "Activate Card" : "Activate & Assign Card Number")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange).cornerRadius(10)
                    }.buttonStyle(BorderlessButtonStyle())
                }

            } else if card.status == "rejected" {
                // ── Rejected ──
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 12)).foregroundColor(.secondary)
                }
                if card.monthlyLimit > 0 || card.proposedLimit > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        // Prefer monthly_limit (the field PATCH updates). Fall back
                        // to proposed_limit only when monthly_limit is unset.
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit > 0 ? card.monthlyLimit : card.proposedLimit))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }
                if let reason = card.rejectionReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REJECTION REASON").font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(red: 0.91, green: 0.29, blue: 0.48)).tracking(0.4)
                        Text(reason).font(.system(size: 12)).foregroundColor(.primary)
                        if let rejBy = card.rejectedBy, !rejBy.isEmpty {
                            HStack(spacing: 4) {
                                Text("By \(UsersData.byId[rejBy]?.fullName ?? rejBy)")
                                    .font(.system(size: 10)).foregroundColor(.secondary)
                                if let rejAt = card.rejectedAt, rejAt > 0 {
                                    Text("· \(FormatUtils.formatDateTime(rejAt))")
                                        .font(.system(size: 10)).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.06)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.2), lineWidth: 1))
                }

            } else {
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private func cardStatusColor(_ s: String) -> (Color, Color) {
        switch s {
        case "active":
            return card.isDigitalOnly ? (Color(red: 0.0, green: 0.6, blue: 0.7), Color(red: 0.0, green: 0.6, blue: 0.7).opacity(0.1))
                                      : (.green, Color.green.opacity(0.1))
        case "requested": return (.orange, Color.orange.opacity(0.1))
        case "pending":   return (.orange, Color.orange.opacity(0.1))
        case "approved", "override": return isAccountant ? (.green, Color.green.opacity(0.1)) : (.goldDark, Color.gold.opacity(0.15))
        case "rejected":  return (.red, Color.red.opacity(0.1))
        case "suspended": return (Color(red: 0.5, green: 0.1, blue: 0.8), Color(red: 0.5, green: 0.1, blue: 0.8).opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

struct RequestCardPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    private var isAccountant: Bool { appState.currentUser?.isAccountant == true }

    // Card holder (accountant picks any user; non-accountant locked to self)
    @State private var selectedUserId: String = ""
    @State private var userSearch: String = ""
    @State private var showUserDropdown = false

    // Bank account
    @State private var selectedBankId: String = ""
    @State private var bankSearch: String = ""
    @State private var showBankDropdown = false

    // Other fields
    @State private var proposedLimit: String = ""
    @State private var bsControlCode: String = ""
    @State private var justification: String = ""
    @State private var submitting = false

    private var effectiveUser: AppUser? {
        if isAccountant { return UsersData.byId[selectedUserId] }
        return appState.currentUser
    }
    private var departmentDisplay: String { effectiveUser?.displayDepartment ?? "" }

    private var filteredUsers: [AppUser] {
        let all = UsersData.allUsers.filter { !$0.isAccountant }
        let q = userSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.fullName.lowercased().contains(q) ||
            $0.displayDepartment.lowercased().contains(q) ||
            $0.displayDesignation.lowercased().contains(q)
        }
    }
    private var filteredBanks: [ProductionBankAccount] {
        let q = bankSearch.lowercased()
        guard !q.isEmpty else { return appState.bankAccounts }
        return appState.bankAccounts.filter { $0.name.lowercased().contains(q) || $0.accountNumber.lowercased().contains(q) }
    }

    private var isValid: Bool {
        let hasHolder = isAccountant ? !selectedUserId.isEmpty : true
        return hasHolder && (Double(proposedLimit) ?? 0) > 0
    }

    var body: some View {
        if isAccountant {
            accountantForm
        } else {
            userForm
        }
    }

    // ── Non-accountant: original simple form ─────────────────────────
    private var userForm: some View {
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
                    .background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                    // Read-only info + limit input
                    VStack(spacing: 0) {
                        simpleRow(label: "Card Holder",  value: appState.currentUser?.fullName ?? "—")
                        Divider().padding(.leading, 14)
                        simpleRow(label: "Department",   value: appState.currentUser?.displayDepartment ?? "—")
                        Divider().padding(.leading, 14)
                        simpleRow(label: "Designation",  value: appState.currentUser?.displayDesignation ?? "—")
                        Divider().padding(.leading, 14)
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
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill").font(.system(size: 14)).foregroundColor(.blue)
                        Text("The accounts team will assign the card issuer, set the final limit, and process your request through the approval chain.")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.04)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.15), lineWidth: 1))
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 80)
            }

            HStack(spacing: 12) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel").font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())

                Button(action: submit) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(submitting ? "Submitting..." : "Submit Request")
                    }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background((Double(proposedLimit) ?? 0) > 0 && !submitting ? Color.gold : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled((Double(proposedLimit) ?? 0) <= 0 || submitting)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.bgSurface)
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

    // ── Accountant: full form (user picker, bank, BS code, justification) ──
    private var accountantForm: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 0) {
                    // CARD HOLDER
                    fieldLabel("CARD HOLDER")
                    VStack(alignment: .leading, spacing: 0) {
                        // ── Search / selected-user row ──
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11)).foregroundColor(.gray)
                            if showUserDropdown || selectedUserId.isEmpty {
                                TextField("Search by name or department...", text: $userSearch,
                                          onEditingChanged: { editing in
                                              showUserDropdown = editing
                                              if editing { showBankDropdown = false }
                                          })
                                .font(.system(size: 13))
                            } else {
                                if let u = effectiveUser {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(u.fullName)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.primary).lineLimit(1)
                                        Text("\(u.displayDepartment)\(u.displayDesignation.isEmpty ? "" : " · \(u.displayDesignation)")")
                                            .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Button(action: {
                                    selectedUserId = ""; userSearch = ""
                                    showUserDropdown = true
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 13)).foregroundColor(.gray.opacity(0.5))
                                }.buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .background(Color.bgSurface)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                            showUserDropdown ? Color.goldDark : Color.borderColor,
                            lineWidth: showUserDropdown ? 1.5 : 1
                        ))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !showUserDropdown && !selectedUserId.isEmpty {
                                selectedUserId = ""; userSearch = ""; showUserDropdown = true
                            }
                        }

                        // ── Inline user list ──
                        if showUserDropdown {
                            Group {
                                if filteredUsers.isEmpty {
                                    Text("No users found")
                                        .font(.system(size: 12)).foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(14)
                                        .background(Color.bgSurface)
                                } else {
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 0) {
                                            ForEach(filteredUsers) { u in
                                                Button(action: {
                                                    selectedUserId = u.id
                                                    userSearch = ""
                                                    showUserDropdown = false
                                                    #if canImport(UIKit)
                                                    UIApplication.shared.sendAction(
                                                        #selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                                                    #endif
                                                }) {
                                                    HStack(spacing: 10) {
                                                        ZStack {
                                                            Circle().fill(Color.gold.opacity(0.18))
                                                                .frame(width: 30, height: 30)
                                                            Text(u.initials)
                                                                .font(.system(size: 10, weight: .bold))
                                                                .foregroundColor(.goldDark)
                                                        }
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(u.fullName)
                                                                .font(.system(size: 13, weight: .medium))
                                                                .foregroundColor(.primary).lineLimit(1)
                                                            HStack(spacing: 4) {
                                                                Text(u.displayDepartment)
                                                                    .font(.system(size: 10))
                                                                    .foregroundColor(.secondary).lineLimit(1)
                                                                if !u.displayDesignation.isEmpty {
                                                                    Text("·").font(.system(size: 10)).foregroundColor(.secondary)
                                                                    Text(u.displayDesignation)
                                                                        .font(.system(size: 10))
                                                                        .foregroundColor(.secondary).lineLimit(1)
                                                                }
                                                            }
                                                        }
                                                        Spacer()
                                                        if selectedUserId == u.id {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 11, weight: .bold))
                                                                .foregroundColor(.goldDark)
                                                        }
                                                    }
                                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(selectedUserId == u.id
                                                                ? Color.gold.opacity(0.06) : Color.bgSurface)
                                                    .contentShape(Rectangle())
                                                }
                                                .buttonStyle(BorderlessButtonStyle())
                                                if u.id != filteredUsers.last?.id {
                                                    Divider().padding(.horizontal, 8)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 220)
                                }
                            }
                            .background(Color.bgSurface)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            .padding(.top, 4)
                        }
                    }

                    Spacer().frame(height: 14)

                    // DEPARTMENT
                    fieldLabel("DEPARTMENT")
                    HStack {
                        Text(departmentDisplay.isEmpty ? "Auto-filled from user" : departmentDisplay)
                            .font(.system(size: 14))
                            .foregroundColor(departmentDisplay.isEmpty ? .secondary : .primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                    Spacer().frame(height: 14)

                    // CARD ISSUER
                    fieldLabel("CARD ISSUER (BANK ACCOUNT)")
                    VStack(spacing: 0) {
                        Button(action: {
                            showUserDropdown = false
                            withAnimation { showBankDropdown.toggle() }
                        }) {
                            HStack {
                                if let bank = appState.bankAccounts.first(where: { $0.id == selectedBankId }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bank.name).font(.system(size: 14, weight: .semibold))
                                        if !bank.accountNumber.isEmpty {
                                            Text("Account: \(bank.accountNumber)").font(.system(size: 11)).foregroundColor(.secondary)
                                        }
                                    }
                                } else {
                                    Text("Search bank account...").font(.system(size: 14)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: showBankDropdown ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(Color.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .buttonStyle(BorderlessButtonStyle())

                        if showBankDropdown {
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(.secondary)
                                    TextField("Search...", text: $bankSearch).font(.system(size: 13))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(Color(UIColor.secondarySystemBackground))
                                Divider()
                                if appState.bankAccounts.isEmpty {
                                    Text("No bank accounts found").font(.system(size: 12)).foregroundColor(.secondary).padding(14)
                                } else {
                                    ForEach(filteredBanks.prefix(6)) { bank in
                                        Button(action: {
                                            selectedBankId = bank.id; bankSearch = ""
                                            withAnimation { showBankDropdown = false }
                                        }) {
                                            HStack(spacing: 10) {
                                                Image(systemName: "building.columns.fill")
                                                    .font(.system(size: 13)).foregroundColor(.goldDark).frame(width: 28)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(bank.name).font(.system(size: 13, weight: .semibold))
                                                    if !bank.accountNumber.isEmpty {
                                                        Text(bank.accountNumber).font(.system(size: 11)).foregroundColor(.secondary)
                                                    }
                                                }
                                                Spacer()
                                                if selectedBankId == bank.id {
                                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.goldDark)
                                                }
                                            }
                                            .padding(.horizontal, 14).padding(.vertical, 9)
                                            .background(selectedBankId == bank.id ? Color.gold.opacity(0.06) : Color.bgSurface)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                        Divider().padding(.leading, 52)
                                    }
                                }
                            }
                            .background(Color.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            .cornerRadius(8)
                        }
                    }

                    Spacer().frame(height: 14)

                    // PROPOSED LIMIT + BS CONTROL CODE
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("PROPOSED LIMIT")
                            HStack(spacing: 4) {
                                Text("£").font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark)
                                TextField("1,500", text: $proposedLimit)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .keyboardType(.decimalPad)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 12)
                            .background(Color.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("BS CONTROL CODE")
                            TextField("e.g. 1145", text: $bsControlCode)
                                .font(.system(size: 14))
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 12).padding(.vertical, 12)
                                .background(Color.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Spacer().frame(height: 14)

                    // JUSTIFICATION
                    fieldLabel("JUSTIFICATION")
                    MultilineTextView(text: $justification, placeholder: "Reason for card request...")
                        .frame(minHeight: 90)
                        .background(Color.bgSurface)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 90)
            }
            .onTapGesture { showUserDropdown = false; showBankDropdown = false }

            Button(action: submit) {
                HStack(spacing: 6) {
                    if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                    Text(submitting ? "Submitting..." : "Submit Request").font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(isValid && !submitting ? .black : .white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(isValid && !submitting ? Color.gold : Color.gray.opacity(0.35))
                .cornerRadius(10)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(!isValid || submitting)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.bgSurface)
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
        .onAppear { appState.loadBankAccounts() }
    }

    private func submit() {
        guard isValid, !submitting else { return }
        submitting = true
        let uid = isAccountant ? selectedUserId : (appState.currentUser?.id ?? "")
        let user = UsersData.byId[uid] ?? appState.currentUser
        appState.requestNewCard(
            userId: uid,
            holderName: user?.fullName ?? "",
            departmentName: user?.displayDepartment ?? "",
            bankAccountId: selectedBankId,
            proposedLimit: Double(proposedLimit) ?? 0,
            bsControlCode: bsControlCode,
            justification: justification
        )
        presentationMode.wrappedValue.dismiss()
    }

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.bottom, 4)
    }

    private func simpleRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Edit Card Request Page (user edits their own pending request)
// ═══════════════════════════════════════════════════════════════════

struct EditCardRequestPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    let card: ExpenseCard

    @State private var proposedLimit: String = ""
    @State private var bsControlCode: String = ""
    @State private var justification: String = ""
    @State private var selectedBankId: String = ""
    @State private var showBankSheet = false
    @State private var submitting = false

    private var isAccountant: Bool { appState.currentUser?.isAccountant ?? false }

    private var canSave: Bool {
        (Double(proposedLimit) ?? 0) > 0 && !submitting
    }

    private var holderName: String {
        if !card.holderFullName.isEmpty { return card.holderFullName }
        if let u = UsersData.byId[card.holderId], !u.fullName.isEmpty { return u.fullName }
        return appState.currentUser?.fullName ?? "—"
    }

    private var departmentName: String {
        if !card.department.isEmpty { return card.department }
        if let u = UsersData.byId[card.holderId], !u.displayDepartment.isEmpty { return u.displayDepartment }
        return appState.currentUser?.displayDepartment ?? "—"
    }

    private var selectedBankName: String {
        if let b = appState.bankAccounts.first(where: { $0.id == selectedBankId }) { return b.name }
        return card.bankAccount?.name ?? ""
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        // Card Holder (read-only)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CARD HOLDER").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            Text(holderName)
                                .font(.system(size: 14)).foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10).background(Color.bgRaised).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        // Department (read-only)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DEPARTMENT").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            Text(departmentName)
                                .font(.system(size: 14)).foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10).background(Color.bgRaised).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                    }

                    // Accountant extras: Card Issuer (Bank), BS Control, Justification
                    if isAccountant {
                        // Bank Account picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CARD ISSUER (BANK ACCOUNT)").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            Button(action: { showBankSheet = true }) {
                                HStack {
                                    Text(selectedBankName.isEmpty ? "Select bank" : selectedBankName)
                                        .font(.system(size: 13))
                                        .foregroundColor(selectedBankName.isEmpty ? .gray : .primary)
                                    Spacer()
                                    if !selectedBankId.isEmpty {
                                        Button(action: { selectedBankId = "" }) {
                                            Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundColor(.gray.opacity(0.6))
                                        }.buttonStyle(BorderlessButtonStyle())
                                    } else {
                                        Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                                    }
                                }
                                .padding(10).background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .selectionActionSheet(
                                title: "Select Bank Account",
                                isPresented: $showBankSheet,
                                options: appState.bankAccounts.map { $0.id },
                                isSelected: { id in
                                    appState.bankAccounts.first { $0.id == id }?.name == selectedBankName
                                },
                                label: { id in
                                    appState.bankAccounts.first { $0.id == id }?.name ?? id
                                },
                                onSelect: { selectedBankId = $0 }
                            )
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        // Proposed Limit (editable)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PROPOSED LIMIT").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            TextField("0", text: $proposedLimit)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .keyboardType(.decimalPad)
                                .padding(10).background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)

                        // BS Control Code (accountant only — show next to limit)
                        if isAccountant {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("BS CONTROL CODE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                                TextField("e.g. 1145", text: $bsControlCode)
                                    .font(.system(size: 14))
                                    .padding(10).background(Color.bgSurface).cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Justification (accountant only — multi-line)
                    if isAccountant {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("JUSTIFICATION").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            MultilineTextView(text: $justification, placeholder: "Reason for card request...")
                                .frame(minHeight: 90)
                                .background(Color.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(20).padding(.bottom, 90)
            }

            // Footer — Submit button (label differs by role)
            HStack {
                Spacer()
                Button(action: save) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                        Text(submitting ? "Submitting…" : (isAccountant ? "Submit for Approval" : "Re-submit"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(canSave ? Color.orange : Color.orange.opacity(0.4))
                    .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(!canSave)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Edit Card Details"), displayMode: .inline)
        .onAppear {
            proposedLimit  = card.monthlyLimit > 0 ? String(format: "%.0f", card.monthlyLimit) : ""
            bsControlCode  = card.bsControlCode
            justification  = card.justification
            selectedBankId = card.bankAccount?.id ?? ""
            if appState.bankAccounts.isEmpty { appState.loadBankAccounts() }
        }
    }

    private func save() {
        guard let amt = Double(proposedLimit), amt > 0 else { return }
        submitting = true
        appState.updateCardRequest(
            id: card.id,
            proposedLimit: amt,
            bsControlCode: isAccountant ? bsControlCode : card.bsControlCode,
            justification: isAccountant ? justification : card.justification,
            bankAccountId: isAccountant ? selectedBankId : (card.bankAccount?.id ?? "")
        ) { _ in
            submitting = false
            // Always dismiss — optimistic update has already applied the new values
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Activate Card Page
// ═══════════════════════════════════════════════════════════════════

struct ActivateCardPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    let card: ExpenseCard

    @State private var selectedType: POViewModel.CardType? = .digital
    @State private var cardNumber: String = ""
    @State private var submitting = false
    @State private var showSuccess = false

    private var rawDigits: String { cardNumber.filter { $0.isNumber } }
    private var isValid: Bool { rawDigits.count == 16 }
    private var canSubmit: Bool { selectedType != nil && isValid && !submitting }

    private var submitLabel: String {
        switch selectedType {
        case .physical: return submitting ? "Activating…" : "Activate Physical Card"
        case .digital:  return submitting ? "Activating…" : "Activate Digital Card"
        case .none:     return "Activate Card"
        }
    }

    private var holderName: String {
        if !card.holderFullName.isEmpty { return card.holderFullName }
        if let u = UsersData.byId[card.holderId] { return u.fullName }
        return "—"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Intro
                    (Text("Assign a card type, card number and activate the card for ")
                        .font(.system(size: 14)).foregroundColor(.primary)
                     + Text(holderName)
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                     + Text(".").font(.system(size: 14)).foregroundColor(.primary))
                        .fixedSize(horizontal: false, vertical: true)

                    // Card type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CARD TYPE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                        HStack(spacing: 10) {
                            cardTypeOption(type: .digital, label: "Digital Card")
                            cardTypeOption(type: .physical, label: "Physical Card")
                        }
                    }

                    // Card number (shown once a type is picked)
                    if let type = selectedType {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(type == .physical ? "CARD NUMBER (16 DIGITS)" : "VIRTUAL CARD NUMBER (16 DIGITS)")
                                .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            TextField("0000  0000  0000  0000", text: Binding(
                                get: { cardNumber },
                                set: { newValue in
                                    let digits = newValue.filter { $0.isNumber }
                                    let trimmed = String(digits.prefix(16))
                                    cardNumber = formatCardNumber(trimmed)
                                }
                            ))
                                .font(.system(size: 15, design: .monospaced))
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            Text("\(rawDigits.count)/16 digits")
                                .font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(20).padding(.bottom, 100)
            }

            // Footer — full-width submit
            Button(action: submit) {
                HStack(spacing: 6) {
                    if submitting { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                    Text(submitLabel).font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmit ? Color.orange : Color.gray.opacity(0.4))
                .cornerRadius(10)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(!canSubmit)
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Activate Card"), displayMode: .inline)
        .alert(isPresented: $showSuccess) {
            Alert(
                title: Text("Card Activated"),
                message: Text("\(holderName)'s card is now active."),
                dismissButton: .default(Text("Done")) { presentationMode.wrappedValue.dismiss() }
            )
        }
    }

    @ViewBuilder
    private func cardTypeOption(type: POViewModel.CardType, label: String) -> some View {
        let isSelected = selectedType == type
        Button(action: { selectedType = type }) {
            VStack(spacing: 6) {
                Image(systemName: "creditcard")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(isSelected ? .goldDark : .secondary)
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .goldDark : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? Color.gold.opacity(0.08) : Color.bgRaised)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.goldDark : Color.borderColor, lineWidth: isSelected ? 1.5 : 1))
        }.buttonStyle(BorderlessButtonStyle())
    }

    private func formatCardNumber(_ digits: String) -> String {
        // Group in 4s: "1234  5678  ..."
        guard !digits.isEmpty else { return "" }
        let groups = stride(from: 0, to: digits.count, by: 4).map { i -> String in
            let start = digits.index(digits.startIndex, offsetBy: i)
            let end = digits.index(start, offsetBy: min(4, digits.count - i))
            return String(digits[start..<end])
        }
        return groups.joined(separator: "  ")
    }

    private func submit() {
        guard let type = selectedType, isValid else { return }
        submitting = true
        appState.activateCard(id: card.id, cardNumber: rawDigits, cardType: type) { success in
            submitting = false
            if success { showSuccess = true }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card History Page
// ═══════════════════════════════════════════════════════════════════

struct CardHistoryPage: View {
    @EnvironmentObject var appState: POViewModel
    let cardId: String
    let cardLabel: String

    @State private var entries: [CardHistoryEntry] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            if isLoading {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                    Text("No history yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                    Text("Actions on this card will appear here.")
                        .font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !cardLabel.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "creditcard.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                                Text(cardLabel)
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
        .navigationBarTitle(Text("Card History"), displayMode: .inline)
        .onAppear {
            appState.loadCardHistoryById(cardId) { fetched in
                entries = fetched.sorted { $0.timestamp > $1.timestamp }
                isLoading = false
            }
        }
    }

    private func actionColor(_ action: String) -> Color {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return .green }
        if a.contains("reject") { return .red }
        if a.contains("override") { return .orange }
        if a.contains("submit") || a.contains("request") || a.contains("upload") { return .goldDark }
        if a.contains("escalat") { return .red }
        if a.contains("post") { return Color(red: 0.1, green: 0.6, blue: 0.3) }
        if a.contains("delete") || a.contains("remov") { return .red }
        return .goldDark
    }

    private func actionIcon(_ action: String) -> String {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return "checkmark.circle.fill" }
        if a.contains("reject") { return "xmark.circle.fill" }
        if a.contains("override") { return "bolt.fill" }
        if a.contains("submit") || a.contains("request") { return "paperplane.fill" }
        if a.contains("upload") { return "arrow.up.circle.fill" }
        if a.contains("escalat") { return "exclamationmark.triangle.fill" }
        if a.contains("post") { return "tray.and.arrow.down.fill" }
        if a.contains("delete") || a.contains("remov") { return "trash.fill" }
        if a.contains("update") || a.contains("edit") || a.contains("amend") { return "pencil.circle.fill" }
        return "circle.fill"
    }

    private func historyRow(_ entry: CardHistoryEntry, isLast: Bool) -> some View {
        let color = actionColor(entry.action)
        return HStack(alignment: .top, spacing: 12) {
            // Timeline: icon + vertical line
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: actionIcon(entry.action))
                        .font(.system(size: 11, weight: .bold)).foregroundColor(color)
                }
                if !isLast {
                    Rectangle().fill(Color.borderColor).frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 2)
                }
            }
            .frame(width: 28)

            // Card content
            VStack(alignment: .leading, spacing: 6) {
                // Header: action + tier badge
                HStack(spacing: 6) {
                    Text(entry.action.isEmpty ? "—" : entry.action)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    if let tier = entry.tierNumber, tier > 0 {
                        Text("Tier \(tier)")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(color.opacity(0.12)).cornerRadius(4)
                    }
                    Spacer()
                }

                // Actor
                if !entry.actionByName.isEmpty || !entry.actionBy.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill").font(.system(size: 9)).foregroundColor(.secondary)
                        Text("by \(entry.actionByName.isEmpty ? entry.actionBy : entry.actionByName)")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }

                // Details
                if !entry.details.isEmpty {
                    Text(entry.details)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Field change (old → new)
                if !entry.oldValue.isEmpty || !entry.newValue.isEmpty {
                    HStack(spacing: 6) {
                        if !entry.field.isEmpty {
                            Text(entry.field.uppercased())
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        }
                        if !entry.oldValue.isEmpty {
                            Text(entry.oldValue).font(.system(size: 11, design: .monospaced)).foregroundColor(.red)
                                .strikethrough()
                        }
                        if !entry.oldValue.isEmpty && !entry.newValue.isEmpty {
                            Image(systemName: "arrow.right").font(.system(size: 9)).foregroundColor(.gray)
                        }
                        if !entry.newValue.isEmpty {
                            Text(entry.newValue).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.green)
                        }
                    }
                }

                // Reason
                if !entry.reason.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "quote.bubble").font(.system(size: 9)).foregroundColor(.secondary)
                        Text("Reason: \(entry.reason)")
                            .font(.system(size: 11)).foregroundColor(.secondary).italic()
                    }
                }

                // Timestamp (date + time)
                if entry.timestamp > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.gray)
                        Text(FormatUtils.formatDateTime(entry.timestamp))
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
// MARK: - Tab 3: Cards for Approval
// ═══════════════════════════════════════════════════════════════════

struct CardsForApprovalTabView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var rejectTarget: ExpenseCard?
    @State private var rejectReason = ""
    @State private var showRejectSheet = false
    /// Override sheet state — only relevant when the user has card-
    /// override permission. Hidden otherwise.
    @State private var overrideTarget: ExpenseCard?
    @State private var overrideReason = ""
    @State private var showOverrideSheet = false

    private var cards: [ExpenseCard] { appState.cardsForApproval() }

    /// Per-card visibility check — returns `true` only when the current
    /// user is allowed to approve at this card's active tier. Used to
    /// gate the inline Approve / Reject buttons on every row.
    private func canApprove(_ card: ExpenseCard) -> Bool {
        guard let cfg = ApprovalHelpers.resolveConfig(
            appState.cardTierConfigRows,
            deptId: card.departmentId,
            amount: card.monthlyLimit
        ) else { return false }
        var po = PurchaseOrder()
        po.id = card.id
        po.userId = card.holderId
        po.departmentId = card.departmentId
        po.status = "PENDING"
        po.approvals = card.approvals
        po.netAmount = card.monthlyLimit
        return ApprovalHelpers.getVisibility(po: po, config: cfg, userId: appState.userId).canApprove
    }

    /// Whether the current user has card-override privilege.
    private var canOverride: Bool { appState.cashMeta?.can_override == true }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 12) {
                    if cards.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark.seal").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                            Text("No cards pending approval").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 480)
                    } else {
                        ForEach(cards) { card in
                            ApprovalCardRow(
                                card: card,
                                tierConfigs: appState.cardTierConfigRows,
                                canApprove: canApprove(card),
                                canOverride: canOverride,
                                onApprove: { appState.approveCard(card) },
                                onReject: { rejectTarget = card; showRejectSheet = true },
                                onOverride: canOverride ? {
                                    overrideTarget = card; showOverrideSheet = true
                                } : nil
                            )
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
                                .background(Color.bgSurface).cornerRadius(8)
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
        .sheet(isPresented: $showOverrideSheet) {
            NavigationView {
                ZStack {
                    Color.bgBase.edgesIgnoringSafeArea(.all)
                    VStack(alignment: .leading, spacing: 16) {
                        if let c = overrideTarget {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "bolt.fill").font(.system(size: 14)).foregroundColor(.orange)
                                Text("This will approve the card for \(c.holderFullName), bypassing the normal approval chain.")
                                    .font(.system(size: 12)).foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.08)).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Override reason (optional)").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                            TextField("Reason…", text: $overrideReason)
                                .font(.system(size: 14)).padding(10)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        Spacer()
                    }.padding()
                }
                .navigationBarTitle(Text("Override Card Approval"), displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") { showOverrideSheet = false; overrideReason = ""; overrideTarget = nil }.foregroundColor(.goldDark),
                    trailing: Button("Override") {
                        guard let c = overrideTarget else { return }
                        appState.overrideCard(c)
                        showOverrideSheet = false; overrideReason = ""; overrideTarget = nil
                    }.foregroundColor(.orange).font(.system(size: 16, weight: .bold))
                )
            }
        }
    }
}

struct ApprovalCardRow: View {
    let card: ExpenseCard
    let tierConfigs: [ApprovalTierConfig]
    /// Whether the current user can approve at this card's active tier
    /// (mirrors the web's `vis.canApprove`). Defaults to `false` so the
    /// Approve / Reject buttons stay hidden until the caller opts in
    /// explicitly with the right per-card visibility check.
    var canApprove: Bool = false
    /// Whether the current user has card-override privilege. When true,
    /// an Override button is shown alongside Approve / Reject.
    var canOverride: Bool = false
    let onApprove: () -> Void
    let onReject: () -> Void
    /// Optional override handler — only invoked when `canOverride` is
    /// true and the caller wires it up.
    var onOverride: (() -> Void)? = nil

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
                                let approverUser = card.approvals.first(where: { $0.tierNumber == tier }).flatMap { UsersData.byId[$0.userId] }
                                if let user = approverUser {
                                    Text(user.fullName).font(.system(size: 8, weight: .medium)).foregroundColor(.green).lineLimit(1)
                                    if !user.displayDesignation.isEmpty {
                                        Text(user.displayDesignation).font(.system(size: 7)).foregroundColor(.green.opacity(0.8)).lineLimit(1)
                                    }
                                }
                            } else {
                                Text("Awaiting").font(.system(size: 8)).foregroundColor(isCurrent ? .goldDark : .gray)
                            }
                        }.frame(minWidth: 60)
                    }
                }
                .padding(.vertical, 4)
            }

            // Action buttons — gated by the user's actual permissions.
            //   • Override: shown when `canOverride` AND a handler exists
            //   • Approve / Reject: shown only when `canApprove` is true
            // If the user can't approve but can override, only the
            // Override button appears (matches the web).
            let showOverride = canOverride && onOverride != nil
            if canApprove || showOverride {
                HStack(spacing: 10) {
                    Spacer()
                    if showOverride, let ov = onOverride {
                        Button(action: ov) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold))
                                Text("Override").font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.orange).cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                    if canApprove {
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
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(12)
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
            .background(Color.bgSurface).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusLabel: String {
        switch receipt.matchStatus.lowercased() {
        case "pending", "pending_receipt": return "Pending Receipt"
        case "pending_coding", "pending_code", "pending code": return "Pending Code"
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
        let navy  = Color(red: 0.05, green: 0.15, blue: 0.42)
        switch receipt.matchStatus.lowercased() {
        case "approved", "matched", "coded": return (teal, teal.opacity(0.12))
        case "posted": return (teal, teal.opacity(0.12))
        case "pending", "pending_receipt": return (orange, orange.opacity(0.12))
        case "pending_coding", "pending_code", "pending code": return (navy, navy.opacity(0.12))
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
        case "pending_coding", "pending_code", "pending code": return (Color(red: 0.05, green: 0.15, blue: 0.42), Color(red: 0.05, green: 0.15, blue: 0.42).opacity(0.1))
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
        let navy  = Color(red: 0.05, green: 0.15, blue: 0.42)
        switch transaction.status.lowercased() {
        case "approved", "matched", "coded": return (teal, teal.opacity(0.12))
        case "posted": return (teal, teal.opacity(0.12))
        case "pending", "pending_receipt": return (orange, orange.opacity(0.12))
        case "pending_coding", "pending_code", "pending code": return (navy, navy.opacity(0.12))
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
            .background(Color.bgSurface).cornerRadius(10)
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
    @State private var showOverrideSheet = false
    @State private var overrideReason = ""
    @State private var isOverriding = false

    private var live: CardTransaction {
        appState.cardTransactions.first(where: { $0.id == transaction.id })
            ?? appState.cardApprovalQueueItems.first(where: { $0.id == transaction.id })
            ?? transaction
    }

    private var isInApprovalQueue: Bool {
        appState.cardApprovalQueueItems.contains(where: { $0.id == transaction.id })
    }

    private var isLocked: Bool {
        let s = live.status.lowercased()
        return s == "approved" || s == "matched" || s == "coded" || s == "posted"
    }

    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        let navy  = Color(red: 0.05, green: 0.15, blue: 0.42)
        switch live.status.lowercased() {
        case "approved", "matched", "coded": return (teal, teal.opacity(0.12))
        case "posted": return (teal, teal.opacity(0.12))
        case "pending", "pending_receipt": return (orange, orange.opacity(0.12))
        case "pending_coding", "pending_code", "pending code": return (navy, navy.opacity(0.12))
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
                        // Header: title + status + urgent
                        HStack(spacing: 8) {
                            Text("Receipt Details").font(.system(size: 15, weight: .bold))
                            Spacer()
                            if live.isUrgent {
                                HStack(spacing: 3) {
                                    Image(systemName: "flame.fill").font(.system(size: 9))
                                    Text("Urgent").font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 7).padding(.vertical, 4)
                                .background(Color.red.opacity(0.1)).cornerRadius(4)
                            }
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
                                    approverRow(userId: a.userId, tierNumber: a.tierNumber, override: a.override)
                                }
                            } else if !live.approvedBy.isEmpty {
                                approverRow(userId: live.approvedBy, tierNumber: 1, override: false)
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
                    .background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 90)
            }

            // Bottom bar
            if isInApprovalQueue {
                // Override button for approval queue context
                VStack(spacing: 0) {
                    Rectangle().fill(Color.borderColor).frame(height: 1)
                    HStack {
                        Button(action: { overrideReason = ""; showOverrideSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.badge.shield.checkmark.fill").font(.system(size: 13, weight: .bold))
                                Text("Override").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.95, green: 0.55, blue: 0.15))
                            .cornerRadius(10)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color(UIColor.systemGroupedBackground))
                }
            } else if allowEdit && !isLocked {
                // Edit Receipt for regular user context
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
        .sheet(isPresented: $showOverrideSheet) {
            NavigationView {
                VStack(alignment: .leading, spacing: 20) {
                    // Item summary
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(live.merchant.isEmpty ? live.description : live.merchant)
                                .font(.system(size: 14, weight: .semibold))
                            Text(live.holderName.isEmpty ? "—" : live.holderName)
                                .font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(FormatUtils.formatGBP(live.amount))
                            .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                    .padding(14).background(Color(.systemGray6)).cornerRadius(10)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("REASON FOR OVERRIDE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                        TextField("e.g. Approver unavailable, deadline critical…", text: $overrideReason)
                            .font(.system(size: 13))
                            .padding(12)
                            .background(Color.bgSurface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    Spacer()

                    Button(action: {
                        guard !overrideReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        isOverriding = true
                        appState.overrideApprovalItem(live.id, reason: overrideReason) { success in
                            isOverriding = false
                            if success { showOverrideSheet = false; presentationMode.wrappedValue.dismiss() }
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isOverriding { ActivityIndicator(isAnimating: true) }
                            Text(isOverriding ? "Overriding…" : "Confirm Override")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding
                                    ? Color.gray.opacity(0.3) : Color(red: 0.95, green: 0.55, blue: 0.15))
                        .foregroundColor(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding
                                         ? .gray : .white)
                        .cornerRadius(12)
                    }
                    .disabled(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding)
                }
                .padding(20)
                .background(Color.bgBase.edgesIgnoringSafeArea(.all))
                .navigationBarTitle("Override Approval", displayMode: .inline)
                .navigationBarItems(leading: Button("Cancel") {
                    showOverrideSheet = false
                }.foregroundColor(.goldDark))
            }
        }
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

    private func approverRow(userId: String, tierNumber: Int, override: Bool) -> some View {
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
            if tierNumber > 0 {
                Text("Level \(tierNumber)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(red: 0.7, green: 0.55, blue: 0.0))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(red: 1.0, green: 0.85, blue: 0.2).opacity(0.18))
                    .cornerRadius(3)
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
                .background(Color.bgSurface).cornerRadius(10)
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
        .appActionSheet(title: "Cost Code", isPresented: $showCodeSheet, items:
            [.action("None") { costCode = "" }]
            + costCodeOptions.map { c in .action(c.1) { costCode = c.0 } }
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
    @State private var navigateToHistory = false

    // Prefer freshly fetched detail; fall back to the receipt passed in
    private var live: Receipt {
        appState.currentReceiptDetail?.id == receipt.id
            ? appState.currentReceiptDetail!
            : receipt
    }

    private var receiptDocumentURL: URL? {
        guard !live.filePath.isEmpty else { return nil }
        return URL(string: "\(CardExpenseRequest.baseURL)\(live.filePath)")
    }

    // MARK: - Derived helpers

    private var currentStep: Int {
        switch live.workflowStatus.lowercased() {
        case "pending_receipt":             return 0
        case "pending_code","pending_coding": return 1
        case "awaiting_approval":           return 2
        case "approved":                    return 3
        case "posted":                      return 4
        default:                            return 0
        }
    }

    private var expenseDate: String {
        let ts = live.transactionDate > 0 ? live.transactionDate : live.createdAt
        return ts > 0 ? FormatUtils.formatTimestamp(ts) : "—"
    }

    private var hasLinkedTxn: Bool { !live.linkedMerchant.isEmpty || live.linkedAmount != nil }
    private var uploaderUser: AppUser? { UsersData.byId[live.uploaderId] }

    // MARK: - Status badge

    private func statusBadge() -> some View {
        let teal   = Color(red: 0.0,  green: 0.6,  blue: 0.5)
        let navy   = Color(red: 0.05, green: 0.15, blue: 0.42)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        let s = live.workflowStatus.isEmpty ? live.matchStatus : live.workflowStatus
        let (label, fg, bg): (String, Color, Color) = {
            switch s.lowercased() {
            case "pending_coding", "pending_code", "pending code": return ("Pending Code", navy, navy.opacity(0.12))
            case "posted":               return ("Posted",            Color(red: 0.1, green: 0.6, blue: 0.3), Color.green.opacity(0.1))
            case "approved":             return ("Approved",          teal,   teal.opacity(0.12))
            case "awaiting_approval":    return ("Awaiting Approval", orange, orange.opacity(0.12))
            case "matched","suggested_match": return ("Matched",      teal,   teal.opacity(0.12))
            case "unmatched":            return ("No Match",          orange, orange.opacity(0.12))
            case "pending_receipt":      return ("Pending Receipt",   orange, orange.opacity(0.12))
            default:                     return ("Pending",           orange, orange.opacity(0.12))
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(bg).cornerRadius(5)
    }

    // MARK: - Step dot

    private func stepDot(index: Int, label: String) -> some View {
        let isDone   = index < currentStep
        let isActive = index == currentStep
        let dotColor: Color = isDone ? Color(red: 0.1, green: 0.6, blue: 0.3) : isActive ? .goldDark : Color.gray.opacity(0.3)
        let textColor: Color = isDone ? Color(red: 0.1, green: 0.6, blue: 0.3) : isActive ? .goldDark : Color.gray.opacity(0.5)
        return VStack(spacing: 5) {
            ZStack {
                Circle().fill(isDone ? Color(red: 0.1, green: 0.6, blue: 0.3) : isActive ? Color.goldDark : Color.gray.opacity(0.15))
                    .frame(width: 22, height: 22)
                if isDone {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                } else {
                    Circle().fill(isActive ? Color.white : dotColor).frame(width: 7, height: 7)
                }
            }
            Text(label)
                .font(.system(size: 9, weight: isActive ? .bold : .medium))
                .foregroundColor(textColor)
                .lineLimit(2).multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Detail row

    private func dRow(_ icon: String, _ label: String, _ value: String, valueColor: Color = .primary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 18)
            Text(label).font(.system(size: 13)).foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(valueColor).lineLimit(1)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: - Body

    var body: some View {
        let showActionBar = live.workflowStatus.lowercased() == "pending_receipt" && appState.currentUser?.isAccountant == true

        return ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            // Centered loader while fetching fresh detail
            if appState.isLoadingReceiptDetail {
                VStack {
                    Spacer()
                    LoaderView()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.bgBase.edgesIgnoringSafeArea(.all))
                .zIndex(1)
            }

            ScrollView {
                VStack(spacing: 12) {

                    // ── Hero card ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        // Top: merchant + urgent + status
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(live.displayMerchant.isEmpty ? "Receipt" : live.displayMerchant)
                                        .font(.system(size: 18, weight: .bold)).lineLimit(2)
                                    if live.isUrgent {
                                        Text("URGENT")
                                            .font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                                            .padding(.horizontal, 5).padding(.vertical, 3)
                                            .background(Color.red).cornerRadius(4)
                                    }
                                }
                                Text(expenseDate)
                                    .font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            Spacer(minLength: 8)
                            statusBadge()
                        }
                        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

                        // Amount
                        if live.displayAmount > 0 {
                            Text(FormatUtils.formatGBP(live.displayAmount))
                                .font(.system(size: 26, weight: .bold, design: .monospaced))
                                .foregroundColor(.goldDark)
                                .padding(.horizontal, 14).padding(.bottom, 10)
                        }

                        Divider().padding(.horizontal, 14)

                        // Uploader
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Color.gold.opacity(0.18)).frame(width: 32, height: 32)
                                Text((uploaderUser?.initials ?? String(live.uploaderName.prefix(2))).uppercased())
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(.goldDark)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(uploaderUser?.fullName ?? (live.uploaderName.isEmpty ? "—" : live.uploaderName))
                                    .font(.system(size: 13, weight: .semibold))
                                if !live.uploaderDepartment.isEmpty {
                                    Text(live.uploaderDepartment)
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            // Nominal code pill
                            if let code = live.nominalCode, !code.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill").font(.system(size: 9)).foregroundColor(.goldDark)
                                    Text(code.uppercased().replacingOccurrences(of: "_", with: "-"))
                                        .font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.gold.opacity(0.12)).cornerRadius(5)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)

                        Divider().padding(.horizontal, 14)

                        // Action buttons
                        HStack(spacing: 10) {
                            Button(action: { activeSheet = .document }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "doc.text.viewfinder").font(.system(size: 11))
                                    Text("View Receipt").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.goldDark)
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(Color.gold.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                            }.buttonStyle(BorderlessButtonStyle())

                            Button(action: { activeSheet = .edit }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "pencil").font(.system(size: 11))
                                    Text("Edit Details").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(Color.goldDark)
                                .cornerRadius(8)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                    }
                    .background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                    // ── Workflow progress ─────────────────────────
                    VStack(spacing: 0) {
                        Text("WORKFLOW").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 14)
                        HStack(alignment: .top, spacing: 0) {
                            stepDot(index: 0, label: "Submitted")
                            stepConnector(isDone: currentStep > 0)
                            stepDot(index: 1, label: "Coding")
                            stepConnector(isDone: currentStep > 1)
                            stepDot(index: 2, label: "Approval")
                            stepConnector(isDone: currentStep > 2)
                            stepDot(index: 3, label: "Approved")
                            stepConnector(isDone: currentStep > 3)
                            stepDot(index: 4, label: "Posted")
                        }
                        .padding(.horizontal, 10).padding(.bottom, 14)
                    }
                    .background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                    // ── Key details ───────────────────────────────
                    VStack(spacing: 0) {
                        Text("DETAILS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)

                        if live.displayAmount > 0 {
                            dRow("sterlingsign.circle", "Amount", FormatUtils.formatGBP(live.displayAmount), valueColor: .goldDark)
                            Divider().padding(.leading, 42)
                        }
                        dRow("calendar", "Date", expenseDate)
                        if let code = live.nominalCode, !code.isEmpty {
                            Divider().padding(.leading, 42)
                            dRow("tag", "Nominal Code", code.uppercased().replacingOccurrences(of: "_", with: "-"), valueColor: .goldDark)
                        }
                        Divider().padding(.leading, 42)
                        dRow("arrow.triangle.2.circlepath", "Match Status", live.matchStatus.replacingOccurrences(of: "_", with: " ").capitalized)
                        if !live.workflowStatus.isEmpty {
                            Divider().padding(.leading, 42)
                            dRow("checkmark.seal", "Workflow", live.workflowStatus.replacingOccurrences(of: "_", with: " ").capitalized)
                        }
                        Divider().padding(.leading, 42)
                        dRow("person.fill", "Uploaded by", (uploaderUser?.fullName ?? live.uploaderName).isEmpty ? "—" : (uploaderUser?.fullName ?? live.uploaderName))
                        Divider().padding(.leading, 42)
                        dRow("clock", "Created", live.createdAt > 0 ? FormatUtils.formatTimestamp(live.createdAt) : "—")
                        if !live.originalName.isEmpty {
                            Divider().padding(.leading, 42)
                            dRow("doc.fill", "File", live.originalName)
                        }
                    }
                    .background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                    // ── Linked transaction ────────────────────────
                    if hasLinkedTxn {
                        VStack(spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "link.circle.fill").font(.system(size: 13)).foregroundColor(.goldDark)
                                Text("LINKED TRANSACTION").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.8)
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                if !live.linkedMerchant.isEmpty {
                                    Text(live.linkedMerchant)
                                        .font(.system(size: 14, weight: .semibold)).lineLimit(2)
                                }
                                HStack(spacing: 10) {
                                    if let amt = live.linkedAmount {
                                        Text(FormatUtils.formatGBP(amt))
                                            .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                                    }
                                    if !live.linkedCardLast4.isEmpty {
                                        HStack(spacing: 3) {
                                            Text("····").font(.system(size: 11)).foregroundColor(.secondary)
                                            Text(live.linkedCardLast4).font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        }
                                    }
                                    if let ld = live.linkedDate, ld > 0 {
                                        Text(FormatUtils.formatTimestamp(ld))
                                            .font(.system(size: 11)).foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                        }
                        .background(Color.bgSurface).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
                    }

                    // ── Line items ────────────────────────────────
                    if !live.lineItems.isEmpty {
                        VStack(spacing: 0) {
                            Text("LINE ITEMS (\(live.lineItems.count))")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                            Divider()
                            ForEach(Array(live.lineItems.enumerated()), id: \.offset) { idx, li in
                                HStack(spacing: 8) {
                                    if let c = li.code, !c.isEmpty {
                                        Text(c.uppercased()).font(.system(size: 9, weight: .bold)).foregroundColor(.goldDark)
                                            .padding(.horizontal, 5).padding(.vertical, 2)
                                            .background(Color.gold.opacity(0.1)).cornerRadius(4)
                                    }
                                    Text(li.description ?? "—").font(.system(size: 12)).foregroundColor(.primary).lineLimit(1)
                                    Spacer()
                                    Text(FormatUtils.formatGBP(li.amountValue))
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                if idx < live.lineItems.count - 1 { Divider().padding(.leading, 14) }
                            }
                            Divider()
                            HStack {
                                Text("Total").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(FormatUtils.formatGBP(live.lineItems.reduce(0) { $0 + $1.amountValue }))
                                    .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                        }
                        .background(Color.bgSurface).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
                    }

                }
                .padding(.horizontal, 16).padding(.top, 14)
                .padding(.bottom, showActionBar ? 80 : 28)
                .opacity(appState.isLoadingReceiptDetail ? 0 : 1)
            }

            if showActionBar {
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
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.bgSurface)
                .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
            }
        }
        .background(
            NavigationLink(destination: ReceiptHistoryPage(history: live.history).environmentObject(appState),
                           isActive: $navigateToHistory) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .navigationBarTitle(Text("Receipt Detail"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)); Text("Back").font(.system(size: 16)) }.foregroundColor(.goldDark)
            },
            trailing: Button(action: { navigateToHistory = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 13))
                    Text("History").font(.system(size: 14))
                }.foregroundColor(.goldDark)
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
        .onAppear { appState.loadReceiptDetail(id: receipt.id) }
    }

    private func stepConnector(isDone: Bool) -> some View {
        Rectangle()
            .fill(isDone ? Color(red: 0.1, green: 0.6, blue: 0.3) : Color.gray.opacity(0.2))
            .frame(height: 2)
            .padding(.bottom, 18)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt History Page
// ═══════════════════════════════════════════════════════════════════

struct ReceiptHistoryPage: View {
    let history: [ReceiptHistoryEntry]
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            if history.isEmpty {
                VStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                    Text("No history available").font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, minHeight: 480)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(history.enumerated()), id: \.offset) { idx, entry in
                        HStack(alignment: .top, spacing: 12) {
                            // Timeline dot + line
                            VStack(spacing: 0) {
                                Circle().fill(Color.goldDark).frame(width: 10, height: 10).padding(.top, 3)
                                if idx < history.count - 1 {
                                    Rectangle().fill(Color.goldDark.opacity(0.2)).frame(width: 1).frame(maxHeight: .infinity)
                                }
                            }.frame(width: 10)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.action ?? "Action").font(.system(size: 13, weight: .semibold))
                                if let d = entry.details, !d.isEmpty {
                                    Text(d).font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                if let ts = entry.timestamp, ts > 0 {
                                    Text(FormatUtils.formatDateTime(ts))
                                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, idx == 0 ? 16 : 12)
                        .padding(.bottom, idx == history.count - 1 ? 16 : 0)
                    }
                }
                .background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
            }
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("History"), displayMode: .inline)
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
            .background(Color.bgSurface)
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
        .background(Color.bgSurface).cornerRadius(10)
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
        .background(Color.bgSurface).cornerRadius(10)
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
        .background(Color.bgSurface).cornerRadius(10)
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
                            .background(Color.bgSurface).cornerRadius(10)
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
        .appActionSheet(title: "Category", isPresented: $showCategorySheet, items:
            claimCategories.map { c in
                .action(c.1) {
                    if drafts.indices.contains(activeDraftIdx) { drafts[activeDraftIdx].category = c.0 }
                }
            }
        )
        .appActionSheet(title: "Budget Code", isPresented: $showCodeSheet, items:
            [.action("None") {
                if drafts.indices.contains(activeDraftIdx) { drafts[activeDraftIdx].budgetCode = "" }
            }] + costCodeOptions.map { c in
                .action(c.1) {
                    if drafts.indices.contains(activeDraftIdx) { drafts[activeDraftIdx].budgetCode = c.0 }
                }
            }
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
        .padding(12).background(Color.bgSurface).cornerRadius(10)
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

// MARK: - Multiline text input (iOS 13 compatible replacement for TextEditor)

struct MultilineTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = UIFont.systemFont(ofSize: 14)
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        tv.isScrollEnabled = false
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updatePlaceholder(tv)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if text.isEmpty && !tv.isFirstResponder {
            tv.text = placeholder
            tv.textColor = UIColor.placeholderText
        } else if tv.textColor == UIColor.placeholderText && !text.isEmpty {
            tv.text = text
            tv.textColor = UIColor.label
        } else if tv.textColor != UIColor.placeholderText {
            if tv.text != text { tv.text = text }
            tv.textColor = UIColor.label
        }
    }

    private func updatePlaceholder(_ tv: UITextView) {
        if text.isEmpty {
            tv.text = placeholder
            tv.textColor = UIColor.placeholderText
        } else {
            tv.text = text
            tv.textColor = UIColor.label
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MultilineTextView
        init(_ parent: MultilineTextView) { self.parent = parent }

        func textViewDidBeginEditing(_ tv: UITextView) {
            if tv.textColor == UIColor.placeholderText {
                tv.text = ""
                tv.textColor = UIColor.label
            }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            if tv.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                tv.text = parent.placeholder
                tv.textColor = UIColor.placeholderText
                parent.text = ""
            }
        }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
        }
    }
}
