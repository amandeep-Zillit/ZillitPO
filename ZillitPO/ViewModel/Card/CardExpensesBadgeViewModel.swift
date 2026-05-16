//
//  CardExpensesBadgeViewModel.swift
//  ZillitPO
//
//  Demo stub. Public surface (class name, nested enums, @Published
//  counters, setupObserver/readBadges/badgeCount) matches the live file;
//  observers are no-ops because demo has no Firebase RTDB / Realm.
//

import Foundation
import SwiftUI
import Combine

class CardExpensesBadgeViewModel: ObservableObject {

    enum ToolUnit: String {
        case accountHub   = "account_hub_label"
        case cardExpenses = "card_expenses_label"
    }

    enum CardUnit: String {
        case cardExpenses = "card_expenses_label"
    }

    enum Section: String {
        case receiptInbox          = "receipt_inbox"
        case approvalQueue         = "approval_queue"
        case process               = "process_queue"
        case cardRegister          = "card_register"
        case smartAlerts           = "smart_alerts"
        case topupTodo             = "topup_todo"
        case allTransactions       = "all_transactions"
        case pendingCoding         = "pending_coding"
        case cardExpensesSettings  = "card_expenses_settings"
        case myCards               = "my_cards"
        case myTransactions        = "my_transactions"
        case codingQueue           = "coding_queue"
    }

    enum Action: String {
        case transactionCreated           = "transaction_created"
        case transactionLifecycle         = "transaction_lifecycle"
        case transactionsSubmittedToUsers = "transactions_submitted_to_users"
        case receiptCoded                 = "receipt_coded"
        case receiptPosted                = "receipt_posted"
        case settingsUpdated              = "settings_updated"
        case receiptCreated               = "receipt_created"
        case receiptApproved              = "receipt_approved"
        case receiptAcceptReject          = "receipt_accept_reject"
        case receiptApproval              = "receipt_approval"
        case receiptCodingPending         = "receipt_coding_pending"
        case cardRequested                = "card_requested"
        case cardAcceptReject             = "card_accept_reject"
        case cardActivated                = "card_activated"
        case cardSuspended                = "card_suspended"
        case cardApproval                 = "card_approval"
        case alertLifecycle               = "alert_lifecycle"
        case topupLifecycle               = "topup_lifecycle"
        case queryChat                    = "query_chat"
    }

    static let notificationOnlyActions: Set<String> = [
        Action.transactionCreated.rawValue,
        Action.transactionLifecycle.rawValue,
        Action.transactionsSubmittedToUsers.rawValue,
        Action.receiptCoded.rawValue,
        Action.receiptPosted.rawValue,
        Action.settingsUpdated.rawValue,
    ]

    @Published var totalBadgesCount: Int = 0
    @Published var receiptInboxCount: Int = 0
    @Published var approvalQueueCount: Int = 0
    @Published var processCount: Int = 0
    @Published var cardRegisterCount: Int = 0
    @Published var smartAlertsCount: Int = 0
    @Published var topupTodoCount: Int = 0
    @Published var myCardsCount: Int = 0
    @Published var myTransactionsCount: Int = 0
    @Published var codingQueueCount: Int = 0
    @Published var cardBadges: [LocalNotificationModel] = []

    func setupObserver() {}

    func badgeCount(forCardId id: String) -> Int { 0 }
    func badgeCount(forTransactionId id: String) -> Int { 0 }
    func badgeCount(forReceiptId id: String) -> Int { 0 }

    func readBadges(level1: Section, action: Action?, entityId: String) {
        guard !entityId.isEmpty else { return }
        let isAcct = FormatUtils.isAccountant(appUserDefault.getLoginUserData()?.departmentIdentifier ?? "")
        let toolAction: ToolType = isAcct ? .accountHub : .cardExpenses
        FirebaseRTDB.shared.refInstance.readToolMessage(
            CardUnit.cardExpenses.rawValue,
            action: toolAction,
            level1: level1.rawValue,
            level2: action?.rawValue ?? "",
            level3: entityId
        )
    }
}
