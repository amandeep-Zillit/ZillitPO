//
//  CashViewModel.swift
//  ZillitPO
//

import SwiftUI
import Combine

// MARK: - CashViewModel
//
// Owns cash expenses state — float requests, claim batches, payment
// routing. Pre-fetches metadata at init so coordinator tabs appear
// immediately on navigation.

class CashViewModel: ObservableObject {
    @Published var userId = Util.getLoginUserID()
    @Published var currentUser: LoginUserData?

    weak var hub: AccountHubViewModel?

    // Float form template (was previously alongside the PO form template)
    @Published var floatFormTemplate: FormTemplateResponse?

    @Published var cashMeta: CashExpenseMetadata?
    @Published var myFloats: [FloatRequest] = []
    @Published var allFloats: [FloatRequest] = []
    @Published var activeFloats: [FloatRequest] = []
    @Published var approvalQueueFloats: [FloatRequest] = []
    @Published var myClaims: [ClaimBatch] = []
    @Published var myBatches: [ClaimBatch] = []
    @Published var allClaims: [ClaimBatch] = []
    @Published var codingQueue: [ClaimBatch] = []
    @Published var auditQueue: [ClaimBatch] = []
    @Published var approvalQueueClaims: [ClaimBatch] = []
    @Published var paymentRouting: PaymentRoutingResponse = PaymentRoutingResponse()
    @Published var isLoadingPaymentRouting: Bool = false

    // Claim batch detail
    @Published var currentClaimBatchDetail: ClaimBatch? = nil
    @Published var isLoadingClaimBatchDetail = false

    // Claim history + queries (keyed by batch id)
    @Published var claimHistory: [String: [FloatHistoryEntry]] = [:]
    @Published var claimHistoryLoading: Bool = false
    @Published var claimQueries: [String: InvoiceQueryThread] = [:]
    @Published var claimQueriesLoading: Bool = false

    // Loaders — start as `true` so loaders are visible on first render.
    @Published var isLoadingMyFloats       = true
    @Published var isLoadingAllFloats      = true
    @Published var isLoadingActiveFloats   = true
    @Published var isLoadingApprovalFloats = true
    @Published var isLoadingMyClaims       = true
    @Published var isLoadingMyBatches      = true
    @Published var isLoadingAllClaims      = true
    @Published var isLoadingCodingQueue    = true
    @Published var isLoadingAuditQueue     = true
    @Published var isLoadingApprovalClaims = true

    init() {
        currentUser = appUserDefault.getLoginUserData()
    }

    func bind(to hub: AccountHubViewModel) {
        self.hub = hub
    }
}
