//
//  CardViewModel.swift
//  ZillitPO
//

import SwiftUI
import Combine

// MARK: - CardViewModel
//
// Owns card expenses state — receipts, transactions, cards, top-ups,
// smart alerts, approvals, bank accounts. Pre-fetches metadata at
// init so the hub tile counts are available immediately.

class CardViewModel: ObservableObject {
    @Published var userId = Util.getLoginUserID()
    @Published var currentUser: LoginUserData?

    weak var hub: AccountHubViewModel?

    // Receipts
    @Published var receipts: [Receipt] = []
    @Published var inboxReceipts: [Receipt] = []
    @Published var currentReceiptDetail: Receipt? = nil
    @Published var isLoadingReceiptDetail = false

    // Metadata + transactions
    @Published var cardExpenseMeta: CardExpenseMeta = CardExpenseMeta()
    @Published var cardTransactions: [CardTransaction] = []
    @Published var cardReceipts: [CardTransaction] = []
    @Published var pendingCodingItems: [PendingCodingItem] = []
    @Published var cardApprovalQueueItems: [CardTransaction] = []
    @Published var myCardReceipts: [CardTransaction] = []
    @Published var topUpQueue: [TopUpItem] = []
    @Published var cashTopUpQueue: [TopUpItem] = []
    @Published var isLoadingCashTopUps: Bool = false
    @Published var smartAlerts: [SmartAlert] = []
    @Published var cardHistory: [CardTransaction] = []
    @Published var userCards: [ExpenseCard] = []
    @Published var allCards: [ExpenseCard] = []
    @Published var bankAccounts: [ProductionBankAccount] = []
    @Published var cardTierConfigRows: [ApprovalTierConfig] = []
    @Published var isCardApprover = false

    // Receipt query thread cache (keyed by receipt id)
    @Published var receiptQueries: [String: InvoiceQueryThread] = [:]
    @Published var receiptQueriesLoading: Bool = false

    // Loaders — start as `true` so the loader is visible on first render.
    @Published var isLoadingReceipts       = true
    @Published var isLoadingInboxReceipts  = true
    @Published var isLoadingCardTxns       = true
    @Published var isLoadingCards          = true
    @Published var isLoadingSmartAlerts    = true
    @Published var isLoadingTopUps         = true
    @Published var isLoadingPendingCoding  = true
    @Published var isLoadingCardApprovals  = true
    @Published var isLoadingCardHistory    = true

    init() {
        currentUser = appUserDefault.getLoginUserData()
    }

    func bind(to hub: AccountHubViewModel) {
        self.hub = hub
    }
}
