//
//  CardExpenseRequest.swift
//  ZillitPO
//

import Foundation

enum CardExpenseRequest {
    static let baseURL = "https://accounthub-dev.zillit.com"
    /// Account-hub service runs on a separate local port. The `/queries`
    /// endpoint lives there, not on the card-expenses server.
    static let accountHubBaseURL = "https://accounthub-dev.zillit.com"

    // MARK: - Receipts
    case fetchAllReceipts
    case fetchMyReceipts(String)                      // userId
    case confirmReceipt(String)                       // id
    case confirmAllReceipts
    case matchReceipt(String, [String: Any])          // id, body
    case unmatchReceipt(String)                       // id
    case deleteReceipt(String)                        // id
    case flagReceiptPersonal(String)                  // id
    case submitCoding(String, [String: Any])           // id, body
    case uploadReceipt(Data, String, String)           // fileData, fileName, mimeType

    // MARK: - Transactions
    case fetchTransactions(String)                     // query params
    case getTransaction(String)                        // id
    case updateTransaction(String, [String: Any])      // id, body
    case submitTransaction(String, [String: Any])      // id, body
    case postTransaction(String)                       // id

    // MARK: - Cards
    case fetchCards(String)                             // query params
    case getCard(String)                               // id
    case createCard([String: Any])
    case updateCardReq(String, [String: Any])          // id, body → PATCH /cards/{id}
    case deleteCardReq(String)                         // id → DELETE /cards/{id}
    case fetchCardHistoryById(String)                  // id → GET /cards/{id}/history
    case fetchReceiptHistory(String)                   // receiptId → GET /receipts/{id}/history

    // MARK: - Queries (account-hub generic queries endpoint)
    case fetchEntityQueries(String, String)            // entityType, entityId → GET /api/v2/account-hub/queries/entity/{type}/{id}
    case suspendCardReq(String, [String: Any])         // id, body → POST /cards/{id}/suspend
    case reactivateCardReq(String, [String: Any])      // id, body → POST /cards/{id}/reactivate
    case activateCardReq(String, [String: Any])        // id, body → POST /cards/{id}/activate
    case approveCardReq(String, [String: Any])         // id, body
    case rejectCardReq(String, [String: Any])          // id, body
    case overrideCardReq(String, [String: Any])        // id, body

    // MARK: - Metadata (hub counts + role)
    case fetchMetadata

    // MARK: - Accountant Hub queues
    case fetchTopUps
    case fetchSmartAlerts
    case fetchCardHistory
    case fetchPendingCoding
    case fetchApprovalQueue
    case overrideApproval(String, [String: Any])           // id, body
    case getReceipt(String)                                // id
    case fetchReceiptDetail(String)                        // id → /receipts/{id}/detail

    // MARK: - Approval Tiers (card expenses)
    case fetchCardApprovalTiers

    // MARK: - Bank Accounts
    case fetchBankAccounts

    // MARK: - Top-Up Actions
    case markTopUp(String, [String: Any])              // id, body → PATCH /topups/{id}/complete
    case skipTopUp(String)                             // id       → PATCH /topups/{id}/skip
    case partialTopUp(String, [String: Any])           // id, body → PATCH /topups/{id}/partial

    // MARK: - Smart Alert Actions
    case resolveAlert(String, [String: Any])           // id, body → POST /alerts/{id}/resolve
    case dismissAlert(String)                          // id       → POST /alerts/{id}/dismiss
    case investigateAlert(String, [String: Any])       // id, body → POST /alerts/{id}/investigate
    case revertAlert(String, [String: Any])            // id, body → POST /alerts/{id}/revert

    // MARK: - Settings
    case fetchSettings
    case updateSettings([String: Any])
}

extension CardExpenseRequest: POURLRequestProtocol {
    private func buildLocal(_ method: HTTPMethodType, _ path: String, body: Any? = nil) -> URLRequest? {
        let urlString = "\(CardExpenseRequest.baseURL)\(path)"
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
        req.setValue(String(APIClient.shared.isAccountant), forHTTPHeaderField: "x-is-accountant")
        if let body = body, let data = try? JSONSerialization.data(withJSONObject: body) {
            req.httpBody = data
        }
        return req
    }

    var urlRequest: URLRequest? {
        switch self {

        // MARK: Receipts
        case .fetchAllReceipts:
            return buildLocal(.get, "/api/v2/card-expenses/receipts")

case .fetchMyReceipts:
            return buildLocal(.get, "/api/v2/card-expenses/receipts/my")

        case .confirmReceipt(let id):
            return buildLocal(.post, "/api/v2/card-expenses/receipts/\(id)/confirm")

        case .confirmAllReceipts:
            return buildLocal(.post, "/api/v2/card-expenses/receipts/confirm-all")

        case .matchReceipt(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/receipts/\(id)/match", body: body)

        case .unmatchReceipt(let id):
            return buildLocal(.post, "/api/v2/card-expenses/receipts/\(id)/unmatch")

        case .deleteReceipt(let id):
            return buildLocal(.delete, "/api/v2/card-expenses/receipts/\(id)")

        case .flagReceiptPersonal(let id):
            return buildLocal(.post, "/api/v2/card-expenses/receipts/\(id)/flag-personal")

        case .submitCoding(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/receipts/\(id)/submit-coding", body: body)

        case .uploadReceipt(let fileData, let fileName, let mimeType):
            let urlString = "\(CardExpenseRequest.baseURL)/api/v2/card-expenses/receipts/upload"
            guard let url = URL(string: urlString) else { return nil }
            let boundary = "Boundary-\(UUID().uuidString)"
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 60
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
            req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(APIClient.shared.userId)\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            req.httpBody = body
            return req

        // MARK: Transactions
        case .fetchTransactions(let params):
            let path = params.isEmpty ? "/api/v2/card-expenses/transactions" : "/api/v2/card-expenses/transactions?\(params)"
            return buildLocal(.get, path)

        case .getTransaction(let id):
            return buildLocal(.get, "/api/v2/card-expenses/transactions/\(id)")

        case .updateTransaction(let id, let body):
            return buildLocal(.patch, "/api/v2/card-expenses/transactions/\(id)", body: body)

        case .submitTransaction(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/transactions/\(id)/submit", body: body)

        case .postTransaction(let id):
            return buildLocal(.post, "/api/v2/card-expenses/transactions/\(id)/post")

        // MARK: Cards
        case .fetchCards(let params):
            let path = params.isEmpty ? "/api/v2/card-expenses/cards" : "/api/v2/card-expenses/cards?\(params)"
            return buildLocal(.get, path)

        case .getCard(let id):
            return buildLocal(.get, "/api/v2/card-expenses/cards/\(id)")

        case .createCard(let body):
            return buildLocal(.post, "/api/v2/card-expenses/cards", body: body)

        case .updateCardReq(let id, let body):
            return buildLocal(.patch, "/api/v2/card-expenses/cards/\(id)", body: body)

        case .deleteCardReq(let id):
            return buildLocal(.delete, "/api/v2/card-expenses/cards/\(id)")

        case .fetchCardHistoryById(let id):
            return buildLocal(.get, "/api/v2/card-expenses/cards/\(id)/history")

        case .fetchReceiptHistory(let id):
            return buildLocal(.get, "/api/v2/card-expenses/receipts/\(id)/history")

        case .fetchEntityQueries(let entityType, let entityId):
            // Account-hub queries live on a separate local service (port 3003),
            // not the card-expenses server (3005). Build the request manually so
            // the host is correct but the standard card-expenses headers apply.
            let path = "/api/v2/account-hub/queries/entity/\(entityType)/\(entityId)"
            guard let url = URL(string: "\(CardExpenseRequest.accountHubBaseURL)\(path)") else { return nil }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.timeoutInterval = 30
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
            req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
            req.setValue(String(APIClient.shared.isAccountant), forHTTPHeaderField: "x-is-accountant")
            return req

        case .suspendCardReq(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/cards/\(id)/suspend", body: body)

        case .reactivateCardReq(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/cards/\(id)/reactivate", body: body)

        case .activateCardReq(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/cards/\(id)/activate", body: body)

        case .approveCardReq(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/cards/\(id)/approve", body: body)

        case .rejectCardReq(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/cards/\(id)/reject", body: body)

        case .overrideCardReq(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/cards/\(id)/override", body: body)

        // MARK: Metadata
        case .fetchMetadata:
            return buildLocal(.get, "/api/v2/card-expenses/metadata")

        // MARK: Accountant Hub queues
        case .fetchTopUps:
            return buildLocal(.get, "/api/v2/card-expenses/topups")
        case .fetchSmartAlerts:
            return buildLocal(.get, "/api/v2/card-expenses/alerts")
        case .fetchCardHistory:
            return buildLocal(.get, "/api/v2/card-expenses/receipts/posted-history")

        case .fetchPendingCoding:
            return buildLocal(.get, "/api/v2/card-expenses/receipts/pending-coding")

        case .fetchApprovalQueue:
            return buildLocal(.get, "/api/v2/card-expenses/approvals")

        case .overrideApproval(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/approvals/\(id)/override", body: body)

        case .getReceipt(let id):
            return buildLocal(.get, "/api/v2/card-expenses/receipts/\(id)")

        case .fetchReceiptDetail(let id):
            return buildLocal(.get, "/api/v2/card-expenses/receipts/\(id)/detail")

        // MARK: Approval Tiers (card expenses)
        case .fetchCardApprovalTiers:
            let path = "/api/v2/account-hub/approval-tiers?module=card_expenses"
            guard let u = URL(string: "\(CardExpenseRequest.accountHubBaseURL)\(path)") else { return nil }
            var req = URLRequest(url: u)
            req.httpMethod = "GET"
            req.timeoutInterval = 30
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
            req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
            req.setValue(String(APIClient.shared.isAccountant), forHTTPHeaderField: "x-is-accountant")
            return req

        // MARK: Bank Accounts
        case .fetchBankAccounts:
            // Account-hub service runs on its own port (3003) separate from
            // the card-expenses server. Use the shared `accountHubBaseURL`
            // constant so every account-hub request hits the same host — if
            // the machine's LAN IP changes, only that one constant needs
            // updating. (Previously this URL was hardcoded to a stale IP.)
            let path = "/api/v2/account-hub/bank-accounts?entity_type=production"
            guard let u = URL(string: "\(CardExpenseRequest.accountHubBaseURL)\(path)") else { return nil }
            var req = URLRequest(url: u)
            req.httpMethod = "GET"
            req.timeoutInterval = 30
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
            req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
            req.setValue(String(APIClient.shared.isAccountant), forHTTPHeaderField: "x-is-accountant")
            return req

        // MARK: Top-Up Actions
        case .markTopUp(let id, let body):
            return buildLocal(.patch, "/api/v2/card-expenses/topups/\(id)/complete", body: body)

        case .skipTopUp(let id):
            return buildLocal(.patch, "/api/v2/card-expenses/topups/\(id)/skip")

        case .partialTopUp(let id, let body):
            return buildLocal(.patch, "/api/v2/card-expenses/topups/\(id)/partial", body: body)

        // MARK: Smart Alert Actions
        case .resolveAlert(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/alerts/\(id)/resolve", body: body)

        case .dismissAlert(let id):
            return buildLocal(.post, "/api/v2/card-expenses/alerts/\(id)/dismiss")

        case .investigateAlert(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/alerts/\(id)/investigate", body: body)

        case .revertAlert(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/alerts/\(id)/revert", body: body)

        // MARK: Settings
        case .fetchSettings:
            return buildLocal(.get, "/api/v2/card-expenses/settings")

        case .updateSettings(let body):
            return buildLocal(.patch, "/api/v2/card-expenses/settings", body: body)
        }
    }
}
