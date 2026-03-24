//
//  POViewModel+funcs.swift
//  ZillitPO
//

import Foundation

extension POViewModel {

    // MARK: - Filtered POs

    var filteredPOs: [PurchaseOrder] {
        guard let user = currentUser else { return [] }
        var list = purchaseOrders
        switch activeTab {
        case .all: list = list.filter { isVisible($0) }
        case .my: list = list.filter { $0.userId == user.id }
        case .department: list = list.filter { ($0.departmentId ?? "") == user.departmentId && $0.userId != user.id }
        default: return []
        }
        switch activeFilter {
        case .all: break
        case .pending: list = list.filter { $0.poStatus == .pending }
        case .approved: list = list.filter { $0.poStatus == .approved || $0.poStatus == .acctEntered }
        case .rejected: list = list.filter { $0.poStatus == .rejected }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter { $0.poNumber.lowercased().contains(q) || $0.vendor.lowercased().contains(q) || ($0.description ?? "").lowercased().contains(q) }
        }
        switch sortKey {
        case .dateDesc: list.sort { $0.createdAt > $1.createdAt }
        case .amountDesc: list.sort { $0.totalAmount > $1.totalAmount }
        case .vendorAsc: list.sort { $0.vendor < $1.vendor }
        }
        return list
    }

    func isVisible(_ po: PurchaseOrder) -> Bool {
        guard let u = currentUser else { return false }
        if po.userId == u.id || (po.departmentId ?? "") == u.departmentId { return true }
        if po.approvals.contains(where: { $0.userId == u.id }) { return true }
        if let c = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: po.departmentId, amount: po.totalAmount) {
            return ApprovalHelpers.getVisibility(po: po, config: c, userId: u.id).visible
        }
        return false
    }

    var tabCounts: [DeptTab: Int] {
        guard let u = currentUser else { return [:] }
        return [.all: purchaseOrders.filter { isVisible($0) }.count,
                .my: purchaseOrders.filter { $0.userId == u.id }.count,
                .department: purchaseOrders.filter { ($0.departmentId ?? "") == u.departmentId && $0.userId != u.id }.count]
    }

    var pendingCount: Int { filteredPOs.filter { $0.poStatus == .pending }.count }
    var approvedCount: Int { filteredPOs.filter { $0.poStatus == .approved || $0.poStatus == .acctEntered }.count }
    var totalValue: Double { filteredPOs.reduce(0) { $0 + VATHelpers.calcVat($1.totalAmount, treatment: $1.vatTreatment).gross } }

    // MARK: - Template Body Builder

    func buildTemplateBody(_ fd: POFormData, templateName: String) -> [String: Any] {
        guard let u = currentUser else { return [:] }
        let dept: String = {
            if let d = DepartmentsData.all.first(where: { $0.identifier == fd.departmentId }) { return d.id }
            if !u.departmentId.isEmpty { return u.departmentId }
            return fd.departmentId
        }()
        let name = templateName.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : templateName.trimmingCharacters(in: .whitespaces)

        let lineItemPayloads: [[String: Any]] = fd.lineItems.map { li in
            let deptId = DepartmentsData.all.first(where: { $0.identifier == li.department })?.id ?? li.department
            var item: [String: Any] = [
                "id": li.id, "description": li.description,
                "quantity": li.quantity, "unit_price": li.unitPrice, "total": li.total,
                "account": li.account, "department": deptId,
                "expenditure_type": li.expenditureType
            ]
            if let customVals = fd.lineItemCustomValues[li.id] {
                var cfArr: [[String: String]] = []
                for (k, v) in customVals where !v.isEmpty { cfArr.append(["name": k, "value": v]) }
                if !cfArr.isEmpty { item["custom_fields"] = cfArr }
            }
            return item
        }

        var body: [String: Any] = [
            "template_name": name,
            "department_id": dept, "nominal_code": fd.nominalCode,
            "description": fd.description, "currency": fd.currency,
            "vat_treatment": fd.vatTreatment,
            "notes": fd.notes, "net_amount": fd.netAmount,
            "line_items": lineItemPayloads
        ]
        if !fd.vendorId.isEmpty { body["vendor_id"] = fd.vendorId }

        if let d = fd.effectiveDate { body["effective_date"] = Int64(d.timeIntervalSince1970 * 1000) }
        if let d = fd.deliveryDate { body["delivery_date"] = Int64(d.timeIntervalSince1970 * 1000) }

        if let da = fd.deliveryAddress {
            body["delivery_address"] = [
                "name": da.name ?? "", "email": da.email ?? "",
                "phone_code": da.phoneCode ?? "", "phone": da.phone ?? "",
                "line1": da.line1 ?? "", "line2": da.line2 ?? "",
                "city": da.city ?? "", "state": da.state ?? "",
                "postal_code": da.postalCode ?? "", "country": da.country ?? ""
            ] as [String: Any]
        }

        if !fd.customFieldValues.isEmpty {
            var cfSections: [String: [[String: String]]] = [:]
            for (k, v) in fd.customFieldValues where !v.isEmpty {
                let parts = k.split(separator: "_", maxSplits: 1)
                let sec = parts.count > 1 ? String(parts[0]) : "custom"
                let fieldName = parts.count > 1 ? String(parts[1]) : k
                cfSections[sec, default: []].append(["name": fieldName, "value": v])
            }
            body["custom_fields"] = cfSections.map { ["section": $0.key, "fields": $0.value] as [String: Any] }
        }

        return body
    }
}
