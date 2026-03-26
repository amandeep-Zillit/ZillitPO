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
    @Published var formTemplate: FormTemplateResponse?

    @Published var isLoading = false
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

    init() { currentUser = UsersData.byId[userId]; configureAPI() }

    func switchUser(_ id: String) {
        userId = id; currentUser = UsersData.byId[id]; configureAPI(); loadAllData()
    }

    func configureAPI() {
        let c = APIClient.shared; c.projectId = projectId; c.userId = userId
        c.isAccountant = currentUser?.isAccountant ?? false
    }
}
