//
//  InvoiceBadgeViewModel.swift
//  ZillitPO
//
//  Demo stub. Mirrors the live `InvoiceBadgeViewModel` API surface;
//  counts stay at 0 because the demo has no Firebase RTDB / Realm
//  notification pipeline.
//

import Foundation
import SwiftUI
import Combine

class InvoiceBadgeViewModel: ObservableObject {

    enum ToolUnit: String {
        case accountHub    = "account_hub_label"
        case purchaseOrder = "purchase_order_label"
    }

    enum InvoiceUnit: String {
        case invoice = "invoice_label"
    }

    enum InvoiceSection: String {
        case invoiceInbox         = "invoice_inbox"
        case invoiceMatching      = "invoice_matching"
        case invoiceApprovalQueue = "invoice_approval_queue"
        case invoiceEntry         = "invoice_entry"
        case paymentRuns          = "payment_runs"
        case creditNotes          = "credit_notes"
        case salesInvoices        = "sales_invoices"
        case myInvoices           = "my_invoices"
        case invoiceSettings      = "invoice_settings"
        case invoiceRegister      = "invoice_register"
    }

    enum InvoiceLevel2: String {
        case invoiceLabel = "invoice_label"
        case queryChat    = "query_chat"
    }

    enum InvoiceAction: String {
        case invoiceCreated          = "invoice_created"
        case duplicateDetected       = "duplicate_detected"
        case matchedToPo             = "matched_to_po"
        case awaitingApproval        = "awaiting_approval"
        case invoiceAwaitingApproval = "invoice_awaiting_approval"
        case approvalProgress        = "approval_progress"
        case postedToLedger          = "posted_to_ledger"
        case invoiceAssigned         = "invoice_assigned"
        case runAwaitingApproval     = "run_awaiting_approval"
        case runApprovalRevoked      = "run_approval_revoked"
        case salesOverdue            = "sales_overdue"
        case teamRightsUpdated       = "team_rights_updated"
        case chaseApprover           = "chase_approver"
        case queryChat               = "query_chat"
        case invoiceAcceptReject     = "invoice_accept_reject"
        case holdReleased            = "hold_released"
        case invoiceHoldReleased     = "invoice_hold_released"
        case invoicePostedPaid       = "invoice_posted_paid"
        case salesSentPaid           = "sales_sent_paid"
        case runLifecycle            = "run_lifecycle"
        case creditNoteLifecycle     = "credit_note_lifecycle"
        case creditNoteDispute       = "credit_note_dispute"
    }

    @Published var invoiceBadgesCount: Int = 0
    @Published var approvalQueueBadgesCount: Int = 0
    @Published var myInvoicesBadgeCount: Int = 0
    @Published var invoiceBadges: [LocalNotificationModel] = []

    func setupObserver() {}

    func badgeCount(forInvoiceId invoiceId: String) -> Int { 0 }

    func readInvoiceBadges(section: InvoiceSection, id: String) {
        guard !id.isEmpty else { return }
        let isAcct = FormatUtils.isAccountant(appUserDefault.getLoginUserData()?.departmentIdentifier ?? "")
        let toolAction: ToolType = isAcct ? .accountHub : .po
        FirebaseRTDB.shared.refInstance.readToolMessage(
            InvoiceUnit.invoice.rawValue,
            action: toolAction,
            level1: section.rawValue,
            level2: InvoiceLevel2.invoiceLabel.rawValue,
            level3: id
        )
    }
}
