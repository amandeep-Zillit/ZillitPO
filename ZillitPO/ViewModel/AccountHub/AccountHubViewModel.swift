//
//  AccountHubViewModel.swift
//  ZillitPO
//

import SwiftUI
import Combine

// MARK: - AccountHubViewModel
//
// Session container + Vendors module. Other domain VMs (PO, Invoices,
// Card, Cash) hold a weak reference to this and read `vendors` from
// here so the directory loads once per session.

class AccountHubViewModel: ObservableObject {
    @Published var userId = Util.getLoginUserID()
    @Published var currentUser: LoginUserData?

    // Vendors directory — shared with PO / Invoice flows for enrichment.
    @Published var vendors: [Vendor] = []
    @Published var isLoadingVendors: Bool = false

    // Audit trail for vendors (name change / address edit / creation /
    // verification / etc.), keyed by vendor id.
    @Published var vendorHistory: [String: [InvoiceHistoryEntry]] = [:]
    @Published var vendorHistoryLoading: Bool = false

    @Published var deleteVendorId: String?

    // Bank Accounts
    @Published var bankAccounts: [HubBankAccount] = []
    @Published var isLoadingBankAccounts: Bool = false

    // Query threads — shared across all entity types (PO, Invoice, Card, Cash).
    // Keyed by entityId so each detail page reads its own thread.
    @Published var queryThreads: [String: InvoiceQueryThread] = [:]
    @Published var queryThreadLoading: Bool = false

    @Published var alertType: AccountHubViewModel.AHAlert? = nil
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false

    init() {
        currentUser = appUserDefault.getLoginUserData()
    }
}
