//
//  PORequest.swift
//  ZillitPO
//

import Foundation

enum PORequest {
    // MARK: - Vendors
    case fetchVendors
    case createVendor([String: Any])
    case deleteVendor(String)

    // MARK: - Approval Tiers
    case fetchApprovalTiers

    // MARK: - Purchase Orders
    case fetchPurchaseOrders(String)               // full path with query params
    case fetchDrafts
    case createPO([String: Any])
    case updatePO(String, [String: Any])            // id, body
    case deletePO(String)
    case approvePO(String, [String: Any])           // id, body
    case rejectPO(String, [String: Any])            // id, body
    case generatePDF(String, [String: Any])         // id, body

    // MARK: - Templates
    case fetchTemplates
    case createTemplate([String: Any])
    case updateTemplate(String, [String: Any])      // id, body
    case deleteTemplate(String)

    // MARK: - Form Template
    case fetchFormTemplate

    // MARK: - Invoices
    case fetchInvoices(String)
}

extension PORequest: POURLRequestProtocol {
    var urlRequest: URLRequest? {
        switch self {

        // MARK: Vendors
        case .fetchVendors:
            let endPoint = "/api/v2/vendors?per_page=200"
            return APIClient.shared.buildRequest(.get, endPoint)

        case .createVendor(let body):
            let endPoint = "/api/v2/vendors"
            return APIClient.shared.buildRequest(.post, endPoint, body: body)

        case .deleteVendor(let id):
            let endPoint = "/api/v2/vendors/\(id)"
            return APIClient.shared.buildRequest(.delete, endPoint)

        // MARK: Approval Tiers
        case .fetchApprovalTiers:
            let endPoint = "/api/v2/account-hub/approval-tiers?module=purchase_orders"
            return APIClient.shared.buildRequest(.get, endPoint)

        // MARK: Purchase Orders
        case .fetchPurchaseOrders(let path):
            return APIClient.shared.buildRequest(.get, path)

        case .fetchDrafts:
            let endPoint = "/api/v2/purchase-orders?status=DRAFT"
            return APIClient.shared.buildRequest(.get, endPoint)

        case .createPO(let body):
            let endPoint = "/api/v2/purchase-orders"
            return APIClient.shared.buildRequest(.post, endPoint, body: body)

        case .updatePO(let id, let body):
            let endPoint = "/api/v2/purchase-orders/\(id)"
            return APIClient.shared.buildRequest(.patch, endPoint, body: body)

        case .deletePO(let id):
            let endPoint = "/api/v2/purchase-orders/\(id)"
            return APIClient.shared.buildRequest(.delete, endPoint)

        case .approvePO(let id, let body):
            let endPoint = "/api/v2/purchase-orders/\(id)/approve"
            return APIClient.shared.buildRequest(.post, endPoint, body: body)

        case .rejectPO(let id, let body):
            let endPoint = "/api/v2/purchase-orders/\(id)/reject"
            return APIClient.shared.buildRequest(.post, endPoint, body: body)

        case .generatePDF(let id, let body):
            let endPoint = "/api/v2/purchase-orders/\(id)/pdf"
            return APIClient.shared.buildRequest(.post, endPoint, body: body)

        // MARK: Templates
        case .fetchTemplates:
            let endPoint = "/api/v2/purchase-orders/templates"
            return APIClient.shared.buildRequest(.get, endPoint)

        case .createTemplate(let body):
            let endPoint = "/api/v2/purchase-orders/templates"
            return APIClient.shared.buildRequest(.post, endPoint, body: body)

        case .updateTemplate(let id, let body):
            let endPoint = "/api/v2/purchase-orders/templates/\(id)"
            return APIClient.shared.buildRequest(.patch, endPoint, body: body)

        case .deleteTemplate(let id):
            let endPoint = "/api/v2/purchase-orders/templates/\(id)"
            return APIClient.shared.buildRequest(.delete, endPoint)

        // MARK: Form Template
        case .fetchFormTemplate:
            let endPoint = "/api/v2/purchase-orders/form-templates?module=purchase_orders"
            return APIClient.shared.buildRequest(.get, endPoint)

        // MARK: Invoices
        case .fetchInvoices(let path):
            return APIClient.shared.buildRequest(.get, path)
        }
    }
}
