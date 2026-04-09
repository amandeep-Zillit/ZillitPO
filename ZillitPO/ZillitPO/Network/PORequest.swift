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
    case createInvoice([String: Any])
    case updateInvoice(String, [String: Any])       // id, body (for status changes etc)
    case deleteInvoice(String)
    case approveInvoice(String, [String: Any])      // id, body
    case rejectInvoice(String, [String: Any])       // id, body
    case fetchInvoiceHistory(String)                // id

    // MARK: - Invoice Approval Tiers
    case fetchInvoiceApprovalTiers

    // MARK: - Invoice Settings
    case getInvoiceSettings
    case updateInvoiceSettings([String: Any])

    // MARK: - Payment Runs
    case fetchPaymentRuns
    case getPaymentRun(String)                       // runId
    case approvePaymentRun(String, [String: Any])   // id, body
    case rejectPaymentRun(String, [String: Any])    // id, body
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
            let endPoint = "/api/v2/account-hub/form-templates?module=purchase_orders"
            return APIClient.shared.buildRequest(.get, endPoint)

        // MARK: Invoices
        case .fetchInvoices(let path):
            return APIClient.shared.buildRequest(.get, path)

        case .createInvoice(let body):
            return APIClient.shared.buildRequest(.post, "/api/v2/invoices", body: body)

        case .updateInvoice(let id, let body):
            return APIClient.shared.buildRequest(.patch, "/api/v2/invoices/\(id)", body: body)

        case .deleteInvoice(let id):
            return APIClient.shared.buildRequest(.delete, "/api/v2/invoices/\(id)")

        case .approveInvoice(let id, let body):
            let endPoint = "/api/v2/invoices/\(id)/approve"
            return APIClient.shared.buildRequest(.post, endPoint, body: body)

        case .rejectInvoice(let id, let body):
            let endPoint = "/api/v2/invoices/\(id)/reject"
            return APIClient.shared.buildRequest(.post, endPoint, body: body)

        case .fetchInvoiceHistory(let id):
            return APIClient.shared.buildRequest(.get, "/api/v2/invoices/\(id)/history")

        // MARK: Invoice Approval Tiers
        case .fetchInvoiceApprovalTiers:
            let endPoint = "/api/v2/account-hub/approval-tiers?module=invoices"
            return APIClient.shared.buildRequest(.get, endPoint)

        // MARK: Invoice Settings
        case .getInvoiceSettings:
            return APIClient.shared.buildRequest(.get, "/api/v2/invoices/settings")

        case .updateInvoiceSettings(let body):
            return APIClient.shared.buildRequest(.patch, "/api/v2/invoices/settings", body: body)

        // MARK: Payment Runs (Active Runs)
        case .fetchPaymentRuns:
            let endPoint = "/api/v2/invoices/active-runs"
            return APIClient.shared.buildRequest(.get, endPoint)

        case .getPaymentRun(let id):
            return APIClient.shared.buildRequest(.get, "/api/v2/invoices/active-runs/\(id)")

        case .approvePaymentRun(let id, let body):
            let endPoint = "/api/v2/invoices/active-runs/\(id)/approve"
            return APIClient.shared.buildRequest(.post, endPoint, body: body)

        case .rejectPaymentRun(let id, let body):
            let endPoint = "/api/v2/invoices/active-runs/\(id)/reject"
            return APIClient.shared.buildRequest(.post, endPoint, body: body)
        }
    }
}
