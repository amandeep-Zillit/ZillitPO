//
//  POViewModel.swift
//  ZillitPO
//

import SwiftUI
import Combine

// MARK: - POViewModel (iOS 13 compatible — uses POCodableTask pattern)

class POViewModel: ObservableObject {
    @Published var projectId = ProjectData.projectId
    @Published var userId = "mock-u-cat2" // Sophie Turner
    @Published var currentUser: AppUser?

    @Published var purchaseOrders: [PurchaseOrder] = []
    @Published var vendors: [Vendor] = []
    @Published var templates: [POTemplate] = []
    @Published var drafts: [PurchaseOrder] = []
    @Published var tierConfigRows: [ApprovalTierConfig] = []
    @Published var invoices: [Invoice] = []
    @Published var invoiceHistory: [String: [InvoiceHistoryEntry]] = [:]
    @Published var invoiceHistoryLoading: Bool = false
    /// Single query thread raised against each invoice, keyed by invoice id.
    @Published var invoiceQueries: [String: InvoiceQueryThread] = [:]
    @Published var invoiceQueriesLoading: Bool = false
    @Published var invoiceTierConfigRows: [ApprovalTierConfig] = []
    @Published var formTemplate: FormTemplateResponse?
    @Published var floatFormTemplate: FormTemplateResponse?

    @Published var isLoading = false
    /// Per-module loader flags (the global `isLoading` only covers the
    /// initial `loadAllData` sweep). Tile-scoped loaders check these so
    /// that tapping an individual module triggers a visible spinner.
    @Published var isLoadingInvoices = false
    @Published var activeTab: DeptTab = .all
    @Published var showCreatePO = false
    @Published var editingPO: PurchaseOrder?
    @Published var selectedPO: PurchaseOrder?
    @Published var formSubmitting = false
    @Published var searchText = ""
    @Published var activeFilter: QuickFilter = .all
    @Published var sortKey: SortKey = .dateDesc
    @Published var showRejectSheet = false
    @Published var rejectTarget: PurchaseOrder?
    @Published var rejectReason = ""
    @Published var deleteTarget: PurchaseOrder?
    @Published var deleteTemplateId: String?
    @Published var deleteDraftId: String?
    @Published var deleteVendorId: String?
    @Published var resumeDraft: PurchaseOrder?
    @Published var editingTemplate: POTemplate?
    @Published var prefilledVendorId: String?
    @Published var popToRoot = false

    // Invoice-specific state
    @Published var selectedInvoice: Invoice?
    @Published var showRejectInvoiceSheet = false
    @Published var rejectInvoiceTarget: Invoice?
    @Published var rejectInvoiceReason = ""
    @Published var deleteInvoiceTarget: Invoice?
    @Published var isInvoiceApprover = false

    // Invoice settings state
    @Published var invoiceAlerts: [String] = []
    @Published var invoiceTeamMembers: [InvoiceTeamMember] = []
    @Published var invoiceAssignmentRules: [InvoiceAssignmentRule] = []
    @Published var invoiceRunAuth: [RunAuthLevel] = []

    // Invoice upload state
    @Published var showUploadPreview = false
    @Published var uploadFileName: String = ""
    @Published var uploadFileData: Data?
    @Published var uploadFileMimeType: String = ""
    @Published var uploading = false
    @Published var uploadError: String?
    @Published var uploadExtraction: InvoiceExtraction?
    @Published var uploadId: String?
    @Published var showTypeSelect = false
    @Published var invoiceType: String?
    @Published var uploadSubmitting = false
    @Published var uploadSubmitted = false

    // Card Expenses / Receipts state
    @Published var receipts: [Receipt] = []
    @Published var inboxReceipts: [Receipt] = []
    @Published var currentReceiptDetail: Receipt? = nil
    @Published var isLoadingReceiptDetail = false
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

    // Card Expenses loading flags
    // Start as `true` so the loader is visible on first render (before onAppear fires)
    @Published var isLoadingReceipts       = true
    @Published var isLoadingInboxReceipts  = true
    @Published var isLoadingCardTxns       = true
    @Published var isLoadingCards          = true
    @Published var isLoadingSmartAlerts    = true
    @Published var isLoadingTopUps         = true
    @Published var isLoadingPendingCoding  = true
    @Published var isLoadingCardApprovals  = true
    @Published var isLoadingCardHistory    = true

    // Cash & Expenses state
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
    @Published var signOffQueue: [ClaimBatch] = []
    @Published var paymentRouting: PaymentRoutingResponse = PaymentRoutingResponse()

    // Cash Expenses loading flags
    // Start as `true` so the loader is visible on first render (before onAppear fires)
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
    @Published var isLoadingSignOffQueue   = true

    // Payment Run state
    @Published var paymentRuns: [PaymentRun] = []
    @Published var showRejectPaymentRunSheet = false
    @Published var rejectPaymentRunTarget: PaymentRun?
    @Published var rejectPaymentRunReason = ""
    @Published var pendingRunsLoading = false
    @Published var selectedRunDetail: PaymentRunDetail?
    @Published var runDetailLoading = false
    @Published var approvingRunId: String?

    init() {
        currentUser = UsersData.byId[userId]
        configureAPI()
        // Pre-fetch metadata so coordinator tabs appear immediately on navigation
        loadCardExpenseMeta()
        loadCashExpenseMetadata()
    }

    func switchUser(_ id: String) {
        userId = id
        currentUser = UsersData.byId[id]
        configureAPI()
        // Clear any cached reference data so new-user views refetch cleanly
        vendors = []
        tierConfigRows = []
        invoiceTierConfigRows = []
        purchaseOrders = []
        invoices = []
        paymentRuns = []
        cardTransactions = []
        cardReceipts = []
        inboxReceipts = []
        pendingCodingItems = []
        cardApprovalQueueItems = []
        myCardReceipts = []
        userCards = []
        topUpQueue = []
        smartAlerts = []
        cardHistory = []
        cardExpenseMeta = CardExpenseMeta()
        cashMeta = nil
        myFloats = []
        myClaims = []
        allClaims = []
        activeFloats = []
        // Reset loading flags to true so pages show loaders on next navigation
        isLoadingReceipts = true; isLoadingInboxReceipts = true; isLoadingCardTxns = true; isLoadingCards = true
        isLoadingSmartAlerts = true; isLoadingTopUps = true; isLoadingPendingCoding = true
        isLoadingCardApprovals = true; isLoadingCardHistory = true
        isLoadingMyFloats = true; isLoadingAllFloats = true; isLoadingActiveFloats = true
        isLoadingApprovalFloats = true; isLoadingMyClaims = true; isLoadingMyBatches = true
        isLoadingAllClaims = true; isLoadingCodingQueue = true; isLoadingAuditQueue = true
        isLoadingApprovalClaims = true; isLoadingSignOffQueue = true
        // Re-fetch metadata for new user so coordinator tabs appear immediately
        loadCardExpenseMeta()
        loadCashExpenseMetadata()
    }

    func configureAPI() {
        let c = APIClient.shared; c.projectId = projectId; c.userId = userId
        c.isAccountant = currentUser?.isAccountant ?? false
    }
}
