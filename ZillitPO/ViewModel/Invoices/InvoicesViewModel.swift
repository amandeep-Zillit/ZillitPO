//
//  InvoicesViewModel.swift
//  ZillitPO
//

import SwiftUI
import Combine

// MARK: - InvoicesViewModel
//
// Owns invoices, invoice settings, invoice upload, payment runs and
// the run-auth approval surface. Reads vendors from the shared
// `AccountHubViewModel` via the injected `hub` reference.

class InvoicesViewModel: ObservableObject {
    @Published var userId = Util.getLoginUserID()
    @Published var currentUser: LoginUserData?

    weak var hub: AccountHubViewModel?

    // Invoice list + history/queries
    @Published var invoices: [Invoice] = []
    @Published var invoiceHistory: [String: [InvoiceHistoryEntry]] = [:]
    @Published var invoiceHistoryLoading: Bool = false
    @Published var invoiceQueries: [String: InvoiceQueryThread] = [:]
    @Published var invoiceQueriesLoading: Bool = false
    @Published var invoiceTierConfigRows: [ApprovalTierConfig] = []

    // Loaders
    @Published var isLoadingInvoices = false
    @Published var isRefreshingInvoice = false

    // Alert state
    @Published var alertType: InvoicesViewModel.InvoiceAlert? = nil
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false

    // Tab / sheet state
    @Published var activeInvoiceTab: InvoiceTab = .all
    @Published var selectedInvoice: Invoice?
    @Published var showRejectInvoiceSheet = false
    @Published var rejectInvoiceTarget: Invoice?
    @Published var rejectInvoiceReason = ""
    @Published var deleteInvoiceTarget: Invoice?
    @Published var isInvoiceApprover = false

    // Invoice settings
    @Published var invoiceAlerts: [String] = []
    @Published var invoiceTeamMembers: [InvoiceTeamMember] = []
    @Published var invoiceAssignmentRules: [InvoiceAssignmentRule] = []
    @Published var invoiceRunAuth: [RunAuthLevel] = []

    // Upload state
    @Published var showUploadPreview = false
    @Published var uploadFileName: String = ""
    @Published var uploadFileData: Data?
    @Published var uploadFileMimeType: String = ""
    @Published var uploading = false
    @Published var uploadError: String?
    @Published var uploadExtraction: InvoiceExtraction?
    @Published var uploadId: String?
    @Published var uploadedDocument: DocumentModel?
    @Published var showTypeSelect = false
    @Published var invoiceType: String?
    @Published var uploadSubmitting = false
    @Published var uploadSubmitted = false

    // Payment Runs
    @Published var paymentRuns: [PaymentRun] = []
    @Published var isLoadingPaymentRuns: Bool = false
    @Published var showRejectPaymentRunSheet = false
    @Published var rejectPaymentRunTarget: PaymentRun?
    @Published var rejectPaymentRunReason = ""
    @Published var pendingRunsLoading = false
    @Published var selectedRunDetail: PaymentRunDetail?
    @Published var runDetailLoading = false
    @Published var approvingRunId: String?

    /// Optional PO tier configs — invoice approval may fall back to PO
    /// tiers when there's no invoice-specific row.
    weak var poVM: POViewModel?

    init() {
        currentUser = appUserDefault.getLoginUserData()
    }

    func bind(to hub: AccountHubViewModel, poVM: POViewModel? = nil) {
        self.hub = hub
        self.poVM = poVM
    }

    var vendors: [Vendor] { hub?.vendors ?? [] }
    var poTierConfigRows: [ApprovalTierConfig] { poVM?.tierConfigRows ?? [] }
}
