//
//  CashExpensesBadgeViewModel.swift
//  ZillitPO
//
//  Demo stub. Public surface matches live; observers are no-ops because
//  demo has no Firebase RTDB / Realm notification pipeline.
//

import Foundation
import SwiftUI
import Combine

class CashExpensesBadgeViewModel: ObservableObject {

    enum ToolUnit: String {
        case accountHub   = "account_hub_label"
        case cashExpenses = "cash_expenses_label"
    }

    enum CashUnit: String {
        case cashExpenses = "cash_expenses_label"
    }

    enum Section: String {
        case cashAuditQueue    = "cash_audit_queue"
        case cashApprovalQueue = "cash_approval_queue"
        case cashCodingQueue   = "cash_coding_queue"
        case cashOop           = "cash_oop"
        case cashPc            = "cash_pc"
        case cashHistory       = "cash_history"
        case cashSettings      = "cash_settings"
    }

    enum Action: String {
        case batchOverridden                 = "batch_overridden"
        case batchClaimCoded                 = "batch_claim_coded"
        case reconSignedOff                  = "recon_signed_off"
        case floatOverridden                 = "float_overridden"
        case settingsUpdated                 = "settings_updated"
        case batchPosted                     = "batch_posted"
        case batchApproved                   = "batch_approved"
        case topupScheduled                  = "topup_scheduled"
        case batchSubmittedForAudit          = "batch_submitted_for_audit"
        case batchApprovedRejected           = "batch_approved_rejected"
        case batchApprovedFinal              = "batch_approved_final"
        case batchSubmittedForSeniorReview   = "batch_submitted_for_senior_review"
        case batchEscalatedToSenior          = "batch_escalated_to_senior"
        case floatApprovedFinal              = "float_approved_final"
        case floatReadyToCollect             = "float_ready_to_collect"
        case floatReadyCollected             = "float_ready_collected"
        case floatClosed                     = "float_closed"
        case floatReturnRecorded             = "float_return_recorded"
        case floatApprovedRejected           = "float_approved_rejected"
        case topupNeeded                     = "topup_needed"
        case topupProcessed                  = "topup_processed"
        case reconSubmittedForReview         = "recon_submitted_for_review"
        case batchApproval                   = "batch_approval"
        case floatApproval                   = "float_approval"
        case batchSubmittedForCoord          = "batch_submitted_for_coord"
        case queryChat                       = "query_chat"
    }

    static let notificationOnlyActions: Set<String> = [
        Action.batchOverridden.rawValue,
        Action.batchClaimCoded.rawValue,
        Action.reconSignedOff.rawValue,
        Action.floatOverridden.rawValue,
        Action.settingsUpdated.rawValue,
        Action.batchApproved.rawValue,
        Action.topupScheduled.rawValue,
    ]

    @Published var totalBadgesCount: Int = 0
    @Published var cashAuditQueueCount: Int = 0
    @Published var cashApprovalQueueCount: Int = 0
    @Published var cashCodingQueueCount: Int = 0
    @Published var cashOopCount: Int = 0
    @Published var cashPcCount: Int = 0
    @Published var cashBadges: [LocalNotificationModel] = []

    func setupObserver() {}

    func badgeCount(forBatchId id: String) -> Int { 0 }
    func badgeCount(forFloatId id: String) -> Int { 0 }
    func badgeCount(forClaimId id: String) -> Int { 0 }

    func readBadges(level1: Section, action: Action?, entityId: String) {
        guard !entityId.isEmpty else { return }
        let isAcct = FormatUtils.isAccountant(appUserDefault.getLoginUserData()?.departmentIdentifier ?? "")
        let toolAction: ToolType = isAcct ? .accountHub : .cashExpenses
        FirebaseRTDB.shared.refInstance.readToolMessage(
            CashUnit.cashExpenses.rawValue,
            action: toolAction,
            level1: level1.rawValue,
            level2: action?.rawValue ?? "",
            level3: entityId
        )
    }
}
