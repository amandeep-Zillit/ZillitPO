//
//  POViewModel.swift
//  ZillitPO
//

import SwiftUI
import Combine
import Foundation

// MARK: - POViewModel
//
// Owns Purchase Orders state — list, drafts, templates, approval
// tier configs, PO history + queries, form state. Reads vendors
// from `hub.vendors` (AccountHubViewModel) for enrichment.

class POViewModel: ObservableObject {
    @Published var userId = Util.getLoginUserID()
    @Published var currentUser: LoginUserData?

    // Cross-VM session/vendors source. Set by the root view after init.
    weak var hub: AccountHubViewModel?
    private var cancellables = Set<AnyCancellable>()

    // PO core state
    @Published var purchaseOrders: [PurchaseOrder] = []
    @Published var templates: [POTemplate] = []
    @Published var drafts: [PurchaseOrder] = []
    @Published var tierConfigRows: [ApprovalTierConfig] = []
    @Published var formTemplate: FormTemplateResponse?

    // PO history + queries (keyed by PO id)
    @Published var poHistory: [String: [InvoiceHistoryEntry]] = [:]
    @Published var poHistoryLoading: Bool = false
    @Published var poQueries: [String: InvoiceQueryThread] = [:]
    @Published var poQueriesLoading: Bool = false

    // Loaders
    @Published var isLoading = false
    @Published var isRefreshingPO = false
    @Published var isLoadingDrafts = false
    @Published var isLoadingTemplates = false

    // Tab + filter UI
    @Published var activeTab: DeptTab = .all
    @Published var activeFilter: QuickFilter = .all
    @Published var sortKey: SortKey = .dateDesc
    @Published var searchText = ""

    // Form / sheet state
    @Published var showCreatePO = false
    @Published var editingPO: PurchaseOrder?
    @Published var selectedPO: PurchaseOrder?
    @Published var formSubmitting = false
    @Published var formSaving = false
    @Published var showRejectSheet = false
    @Published var rejectTarget: PurchaseOrder?
    @Published var rejectReason = ""
    @Published var deleteTarget: PurchaseOrder?
    @Published var deleteTemplateId: String?
    @Published var deleteDraftId: String?
    @Published var resumeDraft: PurchaseOrder?
    @Published var fetchingDraftId: String?
    @Published var editingTemplate: POTemplate?
    @Published var prefilledVendorId: String?
    @Published var popToRoot = false

    @Published var alertType: POViewModel.POAlert? = nil
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false

    @Published var successToast: String? = nil

    func showToast(_ message: String) {
        successToast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.successToast == message { self?.successToast = nil }
        }
    }

    init() {
        currentUser = appUserDefault.getLoginUserData()
    }

    /// Bind to the AccountHubViewModel so PO loaders can read vendors
    /// and so PO display fields are re-hydrated whenever the vendor
    /// directory finishes loading. Call once from the root view.
    func bind(to hub: AccountHubViewModel) {
        self.hub = hub
        hub.$vendors
            .dropFirst()
            .sink { [weak self] _ in self?.hydrateVendorDisplayFields() }
            .store(in: &cancellables)
    }

    /// Vendors snapshot from the hub (or empty when unbound).
    var vendors: [Vendor] { hub?.vendors ?? [] }

    /// Patches the `vendor` (name) and `vendorAddress` display fields
    /// on every cached PO and draft using the current `vendors` list.
    func hydrateVendorDisplayFields() {
        guard !vendors.isEmpty else { return }
        let byId: [String: Vendor] = Dictionary(uniqueKeysWithValues: vendors.map { ($0.id, $0) })
        func patch(_ list: [PurchaseOrder]) -> [PurchaseOrder] {
            list.map { po -> PurchaseOrder in
                guard (po.vendor ?? "").isEmpty,
                      let vid = po.vendorId, !vid.isEmpty,
                      let v = byId[vid] else { return po }
                var updated = po
                updated.vendor = v.name ?? ""
                updated.vendorAddress = [v.address?.line1, v.address?.city, v.address?.postalCode]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                return updated
            }
        }
        purchaseOrders = patch(purchaseOrders)
        drafts = patch(drafts)
    }
}
