//
//  AccountHubRequest.swift
//  ZillitPO
//
//  Vendors (typed bodies), generic entity-query thread endpoints,
//  approval-tier configs, form-templates and bank-accounts —
//  everything that lives under the AccountHub microservice in live.
//

import Foundation

enum AccountHubRequest {

    // MARK: - Vendors (typed bodies — used by AccountHubViewModel)
    case createVendor(VendorRequestBody)
    case updateVendor(String, VendorRequestBody)              // id, body → PATCH /vendors/{id}
    case deleteVendor(String)
    case verifyVendor(String)                                 // id → POST /vendors/{id}/verify
    case fetchVendorHistory(String)                           // id → GET /vendors/{id}/history

    // MARK: - Approval Tiers
    case fetchApprovalTiers(String)                           // module → GET /account-hub/approval-tiers?module=

    // MARK: - Form Templates
    case fetchFormTemplate(String)                            // module → GET /account-hub/form-templates?module=

    // MARK: - Queries (generic entity-thread endpoints)
    case fetchQueries(String, String)                         // entityType, id → GET /account-hub/queries/entity/{type}/{id}
    case sendQuery([String: Any])                             // POST /account-hub/queries (legacy [String:Any])
    case addQuery(String, [String: Any])                      // threadId, body → POST /account-hub/queries/{id}/add (legacy)
    case sendEntityQuery(InvoiceQueryThread)                  // POST /account-hub/queries (Codable)
    case addEntityQuery(String, InvoiceQueryMessage)          // threadId, body → POST /account-hub/queries/{id}/add (Codable)

    // MARK: - Bank Accounts
    case fetchBankAccounts(type: String?, active: Bool?)      // GET /bank-accounts?type=&active=
    case fetchBankAccount(String)                              // GET /bank-accounts/:id
    case createBankAccount(HubBankAccountRequestBody)          // POST /bank-accounts
    case updateBankAccount(String, HubBankAccountRequestBody)  // PATCH /bank-accounts/:id
    case deleteBankAccount(String)                             // DELETE /bank-accounts/:id
}

extension AccountHubRequest: FCURLRequestProtocol {
    var urlRequest: URLRequest? {
        switch self {

        // MARK: Vendors
        case .createVendor(let body):
            guard let data = try? JSONEncoder().encode(body) else { return nil }
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors"
            return FCURLRequest(urlPath: endPoint, type: .post, body: data).requestObject

        case .updateVendor(let id, let body):
            guard let data = try? JSONEncoder().encode(body) else { return nil }
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: data).requestObject

        case .deleteVendor(let id):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject

        case .verifyVendor(let id):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors/\(id)/verify"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .fetchVendorHistory(let id):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors/\(id)/history?perPage=200"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Approval Tiers
        case .fetchApprovalTiers(let module):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/approval-tiers?module=\(module)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Form Templates
        case .fetchFormTemplate(let module):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/form-templates?module=\(module)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Queries
        case .fetchQueries(let module, let id):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/queries/entity/\(module)/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .sendQuery(let body):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/queries"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .addQuery(let threadId, let body):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/queries/\(threadId)/add"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .sendEntityQuery(let body):
            guard let data = try? JSONEncoder().encode(body) else { return nil }
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/queries"
            return FCURLRequest(urlPath: endPoint, type: .post, body: data).requestObject

        case .addEntityQuery(let threadId, let body):
            guard let data = try? JSONEncoder().encode(body) else { return nil }
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/queries/\(threadId)/add"
            return FCURLRequest(urlPath: endPoint, type: .post, body: data).requestObject

        // MARK: Bank Accounts
        case .fetchBankAccounts(let type, let active):
            var parts: [String] = []
            if let t = type, !t.isEmpty { parts.append("type=\(t)") }
            if let a = active { parts.append("active=\(a)") }
            let query = parts.isEmpty ? "" : "?\(parts.joined(separator: "&"))"
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/bank-accounts\(query)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchBankAccount(let id):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/bank-accounts/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .createBankAccount(let body):
            guard let data = try? JSONEncoder().encode(body) else { return nil }
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/bank-accounts"
            return FCURLRequest(urlPath: endPoint, type: .post, body: data).requestObject

        case .updateBankAccount(let id, let body):
            guard let data = try? JSONEncoder().encode(body) else { return nil }
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/bank-accounts/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: data).requestObject

        case .deleteBankAccount(let id):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/bank-accounts/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject
        }
    }
}
