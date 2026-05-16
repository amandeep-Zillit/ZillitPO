//
//  DealMemoViewModel.swift
//  ZillitPO
//
//  Owns deal-memo state — overview snapshot, deals list, my deal,
//  approval queue, metadata (drives the approver-only tab gating).
//  Reads `AccountHubViewModel.vendors` only indirectly (deal memos
//  reference users/departments, not vendors) so it can stand alone,
//  but binds to the hub for currentUser parity.
//

import SwiftUI
import Combine

class DealMemoViewModel: ObservableObject {
    @Published var userId = Util.getLoginUserID()
    @Published var currentUser: LoginUserData?

    weak var hub: AccountHubViewModel?

    // Overview (DMOverviewPage)
    @Published var overview: DealMemoOverviewResponse?
    @Published var isLoadingOverview = false
    @Published var overviewError: String?

    // Deals list (DMDealsPage)
    @Published var deals: [DealMemo] = []
    @Published var isLoadingDeals = false

    // My deal (DMMyDealPage)
    @Published var myDeal: DealMemo?
    @Published var isLoadingMyDeal = false

    // Approval queue (DMApprovalQueuePage)
    @Published var approvalQueue: DealMemoApprovalBuckets?
    @Published var approvalTotals: DealMemoApprovalTotals?
    @Published var isLoadingApprovalQueue = false

    // Metadata (gates approval-queue tab)
    @Published var metadata: DealMemoMetadata?
    @Published var isLoadingMetadata = false

    // Deal detail (DMDealPreviewPage)
    @Published var currentDeal: DealMemo?
    @Published var currentDealHistory: [DealMemoHistoryEntry] = []
    @Published var isLoadingDealDetail = false

    // Templates
    @Published var templates: [DealMemo] = []

    // UI state
    @Published var activeTab: DealMemoTab = .overview
    @Published var searchText = ""
    @Published var statusFilter: DealMemoStatus? = nil

    // Reject sheet state — used by RejectDealMemoModal port
    @Published var showRejectSheet = false
    @Published var rejectTarget: DealMemo?
    @Published var rejectReason = ""

    @Published var alertType: DealMemoViewModel.DMAlert? = nil
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false

    init() {
        currentUser = appUserDefault.getLoginUserData()
    }

    func bind(to hub: AccountHubViewModel) {
        self.hub = hub
    }

    var isAccountant: Bool {
        FormatUtils.isAccountant(currentUser?.departmentIdentifier ?? "")
    }
    var isApprover: Bool { metadata?.isApprover ?? false }
    var defaultTab: DealMemoTab { isAccountant ? .overview : .myDeal }
}
