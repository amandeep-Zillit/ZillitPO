//
//  POViewModel+funcs.swift
//  ZillitPO
//
//  Pure computed helpers / non-network functions for the PO module.
//

import Foundation

extension POViewModel {

    // MARK: - Filtered POs

    var filteredPOs: [PurchaseOrder] {
        var list = purchaseOrders
        switch activeFilter {
        case .all: break
        case .pending:  list = list.filter { $0.poStatus == .pending }
        case .approved: list = list.filter { $0.poStatus == .approved }
        case .rejected: list = list.filter { $0.poStatus == .rejected }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                ($0.poNumber ?? "").lowercased().contains(q)
                    || ($0.vendor ?? "").lowercased().contains(q)
                    || ($0.description ?? "").lowercased().contains(q)
            }
        }
        switch sortKey {
        case .dateDesc:   list.sort { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }
        case .amountDesc: list.sort { $0.totalAmount > $1.totalAmount }
        case .vendorAsc:  list.sort { ($0.vendor ?? "") < ($1.vendor ?? "") }
        }
        return list
    }

    var pendingCount: Int { filteredPOs.filter { $0.poStatus == .pending }.count }
    var approvedCount: Int { filteredPOs.filter { $0.poStatus == .approved || $0.poStatus == .acctEntered }.count }
    var totalValue: Double {
        filteredPOs.reduce(0.0) { total, po in
            if (po.lineItems ?? []).isEmpty {
                return total + VATHelpers.calcVat(po.totalAmount, treatment: po.vatTreatment ?? "").gross
            }
            return total + (po.lineItems ?? []).reduce(0.0) {
                $0 + VATHelpers.calcVat(($1.quantity ?? 0) * ($1.unitPrice ?? 0), treatment: $1.vatTreatment ?? "").gross
            }
        }
    }

    func canAccessPO(_ po: PurchaseOrder) -> Bool {
        guard let user = currentUser,
              FormatUtils.isAccountant(user.departmentIdentifier ?? "") else { return true }
        if FormatUtils.isFullAccessAccountant(user.designationName ?? "") { return true }
        // Reuse legacy visibility logic — same algorithm.
        if po.userId == user.id || (po.departmentId ?? "") == (user.departmentId ?? "") { return true }
        if (po.approvals ?? []).contains(where: { $0.userId == user.id }) { return true }
        if let c = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: po.departmentId, amount: po.totalAmount) {
            return ApprovalHelpers.getVisibility(po: po, config: c, userId: user.id ?? "").visible
        }
        return false
    }

    func prepareAlert(type: POViewModel.POAlert, title: String, message: String) {
        self.alertType = type
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }
}
