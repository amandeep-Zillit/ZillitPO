//
//  PORequest.swift
//  ZillitPO
//

import Foundation

enum PORequest {
    static let baseURL = "http://192.168.29.92:3001"
    
    // MARK: - Vendors
    case fetchVendors
    case createVendor([String: Any])
    case updateVendor(String, [String: Any])     // id, body → PATCH /vendors/{id}
    case deleteVendor(String)
    case fetchVendorHistory(String)              // id → GET /vendors/{id}/history

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
    case fetchPOHistory(String)                     // id → /purchase-orders/{id}/history
    case fetchPOQueries(String)                     // id → /account-hub/queries/entity/purchase_order/{id}
    // New endpoints (Apr 2026):
    case fetchApprovalQueue                         // GET  /purchase-orders/approval
    case fetchMyPOs                                 // GET  /purchase-orders/my
    case bulkUpdatePOs([String: Any])               // PATCH /purchase-orders/bulk
    case postPO(String, [String: Any])              // POST /purchase-orders/{id}/post
    case closePO(String, [String: Any])             // POST /purchase-orders/{id}/close

    // MARK: - Templates
    case fetchTemplates
    case createTemplate([String: Any])
    case updateTemplate(String, [String: Any])      // id, body
    case deleteTemplate(String)

    // MARK: - Form Template
    case fetchFormTemplate
    case fetchFloatFormTemplate

    // MARK: - Invoices
    case fetchInvoices(String)
    case createInvoice([String: Any])
    case updateInvoice(String, [String: Any])       // id, body (for status changes etc)
    case deleteInvoice(String)
    case approveInvoice(String, [String: Any])      // id, body
    case rejectInvoice(String, [String: Any])       // id, body
    case fetchInvoiceHistory(String)                // id
    case fetchInvoiceQueries(String)                // id — /queries/entity/invoice/{id}

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

        case .updateVendor(let id, let body):
            let endPoint = "/api/v2/vendors/\(id)"
            return APIClient.shared.buildRequest(.patch, endPoint, body: body)

        case .deleteVendor(let id):
            let endPoint = "/api/v2/vendors/\(id)"
            return APIClient.shared.buildRequest(.delete, endPoint)

        case .fetchVendorHistory(let id):
            // perPage=200 so the audit trail arrives in one call —
            // matches the invoice + PO history convention.
            return APIClient.shared.buildRequest(.get, "/api/v2/vendors/\(id)/history?perPage=200")

        // MARK: Approval Tiers
        case .fetchApprovalTiers:
            let endPoint = "/api/v2/account-hub/approval-tiers?module=purchase_orders"
            return APIClient.shared.buildRequest(.get, endPoint)

        // MARK: Purchase Orders
        //
        // PO + template endpoints route to the dedicated
        // `purchase-order-server` microservice (localhost:3001 in dev,
        // see `PORequest.baseURL`). Everything else — vendors, invoices,
        // account-hub queries / approval-tiers / form-templates —
        // continues to use `APIClient.shared.baseURL` (the hosted
        // gateway). `APIClient.buildRequest` treats any `path` starting
        // with "http" as an absolute URL and skips the shared-baseURL
        // prefix, so these lines keep the rest of the pipeline
        // (headers, JSON body, timeout) intact.
        case .fetchPurchaseOrders(let path):
            // Caller passes a path that already starts with
            // "/api/v2/purchase-orders?..." — prepend the PO server's
            // baseURL unless they handed us an absolute URL.
            let url = path.hasPrefix("http") ? path : "\(Self.baseURL)\(path)"
            return APIClient.shared.buildRequest(.get, url)

        case .fetchDrafts:
            return APIClient.shared.buildRequest(.get, "\(Self.baseURL)/api/v2/purchase-orders?status=DRAFT")

        case .createPO(let body):
            return APIClient.shared.buildRequest(.post, "\(Self.baseURL)/api/v2/purchase-orders", body: body)

        case .updatePO(let id, let body):
            return APIClient.shared.buildRequest(.patch, "\(Self.baseURL)/api/v2/purchase-orders/\(id)", body: body)

        case .deletePO(let id):
            return APIClient.shared.buildRequest(.delete, "\(Self.baseURL)/api/v2/purchase-orders/\(id)")

        case .approvePO(let id, let body):
            return APIClient.shared.buildRequest(.post, "\(Self.baseURL)/api/v2/purchase-orders/\(id)/approve", body: body)

        case .rejectPO(let id, let body):
            return APIClient.shared.buildRequest(.post, "\(Self.baseURL)/api/v2/purchase-orders/\(id)/reject", body: body)

        case .generatePDF(let id, let body):
            return APIClient.shared.buildRequest(.post, "\(Self.baseURL)/api/v2/purchase-orders/\(id)/pdf", body: body)

        case .fetchPOHistory(let id):
            // perPage=200 so the full audit trail is returned in one call —
            // matches the invoice history convention.
            return APIClient.shared.buildRequest(.get, "\(Self.baseURL)/api/v2/purchase-orders/\(id)/history?perPage=200")

        case .fetchPOQueries(let id):
            // Queries live on the account-hub service (generic entity
            // queries endpoint) — stays on the shared base URL.
            return APIClient.shared.buildRequest(.get, "/api/v2/account-hub/queries/entity/purchase_order/\(id)")

        case .fetchApprovalQueue:
            // POs where the current user is an approver (server-driven —
            // replaces the client-side approval-tier filtering).
            return APIClient.shared.buildRequest(.get, "\(Self.baseURL)/api/v2/purchase-orders/approval")

        case .fetchMyPOs:
            // POs raised by the current user (non-DRAFT).
            return APIClient.shared.buildRequest(.get, "\(Self.baseURL)/api/v2/purchase-orders/my")

        case .bulkUpdatePOs(let body):
            // Body: { po_ids: [String], data: { assigned_to? / reassignment_reason? /
            // effective_date? / status?=CLOSED / closure_reason? } }.
            return APIClient.shared.buildRequest(.patch, "\(Self.baseURL)/api/v2/purchase-orders/bulk", body: body)

        case .postPO(let id, let body):
            // Accountant-only transition APPROVED / ACCT_ENTERED → POSTED.
            // Body carries camelCase totals + snake_case poDetails (matches the
            // web client payload exactly).
            return APIClient.shared.buildRequest(.post, "\(Self.baseURL)/api/v2/purchase-orders/\(id)/post", body: body)

        case .closePO(let id, let body):
            // Accountant-only transition POSTED → CLOSED.
            // Body: { reason, effective_date }.
            return APIClient.shared.buildRequest(.post, "\(Self.baseURL)/api/v2/purchase-orders/\(id)/close", body: body)

        // MARK: Templates (served by the same PO microservice)
        case .fetchTemplates:
            return APIClient.shared.buildRequest(.get, "\(Self.baseURL)/api/v2/purchase-orders/templates")

        case .createTemplate(let body):
            return APIClient.shared.buildRequest(.post, "\(Self.baseURL)/api/v2/purchase-orders/templates", body: body)

        case .updateTemplate(let id, let body):
            return APIClient.shared.buildRequest(.patch, "\(Self.baseURL)/api/v2/purchase-orders/templates/\(id)", body: body)

        case .deleteTemplate(let id):
            return APIClient.shared.buildRequest(.delete, "\(Self.baseURL)/api/v2/purchase-orders/templates/\(id)")

        // MARK: Form Template
        case .fetchFormTemplate:
            let endPoint = "/api/v2/account-hub/form-templates?module=purchase_orders"
            return APIClient.shared.buildRequest(.get, endPoint)

        case .fetchFloatFormTemplate:
            let endPoint = "/api/v2/account-hub/form-templates?module=cash_expenses"
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
            // Include `perPage=200` so the backend returns the full history
            // in a single request — mirrors the invoice list call which
            // also passes `perPage=200` to avoid server-side pagination
            // truncating the audit trail.
            return APIClient.shared.buildRequest(.get, "/api/v2/invoices/\(id)/history?perPage=200")

        case .fetchInvoiceQueries(let id):
            // Queries raised against an invoice (notes / questions / audit
            // flags). Endpoint returns all queries for the entity.
            return APIClient.shared.buildRequest(.get, "/api/v2/account-hub/queries/entity/invoice/\(id)")

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
