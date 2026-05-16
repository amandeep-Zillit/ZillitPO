//
//  InvoicesRequest.swift
//  ZillitPO
//
//  Invoice + Invoice-settings + Payment-run endpoints for the
//  Invoices microservice. Mirrors the live file 1:1.
//

import Foundation

enum InvoicesRequest {

    // MARK: - Invoices
    case fetchInvoices(InvoiceTab, String?)
    case fetchInvoice(String)                        // id → GET /invoices/{id}
    case uploadInvoice(InvoiceUploadRequest)
    case createInvoice([String: Any])
    case createInvoiceData(Data)
    case updateInvoice(String, [String: Any])        // id, body
    case deleteInvoice(String)
    case approveInvoice(String, [String: Any])       // id, body
    case rejectInvoice(String, [String: Any])        // id, body
    case holdInvoice(String, [String: Any])          // id, { hold_reason, hold_note? }
    case releaseInvoiceHold(String)                  // id → POST /invoices/{id}/release
    case sendInvoiceToApproval(String)               // id → POST /invoices/{id}/send-to-approval
    case postInvoiceToLedger(String)                 // id → POST /invoices/{id}/post
    case fetchInvoiceHistory(String)                 // id → GET /invoices/{id}/history

    // MARK: - Invoice Settings
    case getInvoiceSettings                          // GET /invoices/settings
    case updateInvoiceSettings([String: Any])        // PATCH /invoices/settings

    // MARK: - Payment Runs
    case fetchPaymentRuns                            // GET /invoices/active-runs
    case getPaymentRun(String)                       // GET /invoices/active-runs/{id}
    case approvePaymentRun(String, [String: Any])    // POST /invoices/active-runs/{id}/approve
    case rejectPaymentRun(String, [String: Any])     // POST /invoices/active-runs/{id}/reject
}

extension InvoicesRequest: FCURLRequestProtocol {
    var urlRequest: URLRequest? {
        switch self {

        // MARK: Invoices
        case .fetchInvoices(let tab, let deptID):
            var path: String = ""
            switch tab {
            case .all:
                if !FormatUtils.isAccountant(appUserDefault.getLoginUserData()?.departmentIdentifier ?? "") {
                    path = "/approval"
                }
            case .department:
                if let deptID {
                    path = "?department_id=\(deptID)"
                }
            case .my:
                path = "/my"
            }
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices\(path)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchInvoice(let id):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .uploadInvoice(let body):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/upload"
            let data = try? JSONEncoder().encode(body)
            return FCURLRequest(urlPath: endPoint, type: .post, body: data).requestObject

        case .createInvoice(let body):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .createInvoiceData(let data):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices"
            return FCURLRequest(urlPath: endPoint, type: .post, body: data).requestObject

        case .updateInvoice(let id, let body):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .deleteInvoice(let id):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject

        case .approveInvoice(let id, let body):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/\(id)/approve"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .rejectInvoice(let id, let body):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/\(id)/reject"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .holdInvoice(let id, let body):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/\(id)/hold"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .releaseInvoiceHold(let id):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/\(id)/release"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .sendInvoiceToApproval(let id):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/\(id)/send-to-approval"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .postInvoiceToLedger(let id):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/\(id)/post"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .fetchInvoiceHistory(let id):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/\(id)/history?perPage=200"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Invoice Settings
        case .getInvoiceSettings:
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/settings"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .updateInvoiceSettings(let body):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/settings"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        // MARK: Payment Runs
        case .fetchPaymentRuns:
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/active-runs"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getPaymentRun(let id):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/active-runs/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .approvePaymentRun(let id, let body):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/active-runs/\(id)/approve"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .rejectPaymentRun(let id, let body):
            let endPoint = "\(ServerRequest.INVOICES_BASE_URL)invoices/active-runs/\(id)/reject"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject
        }
    }
}
