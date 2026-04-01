//
//  POViewModel+enums.swift
//  ZillitPO
//

import Foundation

enum DeptTab: String, CaseIterable, Identifiable {
    case all = "All POs", my = "My POs", department = "My Dept"
    case vendors = "Vendors"
    var id: String { rawValue }
}

enum QuickFilter: String, CaseIterable {
    case all = "All", pending = "Pending", approved = "Approved", rejected = "Rejected"
}

enum SortKey: String, CaseIterable {
    case dateDesc = "Date ↓", amountDesc = "Amount ↓", vendorAsc = "Vendor A-Z"
}

struct POFormData {
    var vendorId = ""; var departmentId = ""; var nominalCode = ""; var description = ""
    var currency = "GBP"; var vatTreatment = "pending"; var effectiveDate: Date?; var deliveryDate: Date?
    var notes = ""; var lineItems: [LineItem] = [LineItem()]; var existingDraftId: String?
    var deliveryAddress: DeliveryAddress?
    var customFieldValues: [String: String] = [:]
    var lineItemCustomValues: [String: [String: String]] = [:]
    var termsOfEngagement: [String] = []
    var netAmount: Double { lineItems.filter { $0.splitParentId == nil }.reduce(0) { $0 + $1.total } }
}
