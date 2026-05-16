//
//  CardExpenseRequest.swift
//  ZillitPO
//
//  Mirrors live's `Controller/AccountHub/Network/CardExpenses/CardExpenseRequest.swift`
//  pattern — each case binds a local `let endPoint = "\(ServerRequest.CARD_BASE_URL)..."`
//  and returns `FCURLRequest(urlPath:type:body:).requestObject`. Account-hub
//  cross-service calls (queries, bank accounts) compose against
//  `ServerRequest.ACC_HUB_BASE_URL` instead.
//

import Foundation

enum CardExpenseRequest {

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
    case fetchCards(String)                            // query params
    case getCard(String)                               // id
    case createCard([String: Any])
    case updateCardReq(String, [String: Any])          // id, body → PATCH /cards/{id}
    case deleteCardReq(String)                         // id → DELETE /cards/{id}
    case fetchCardHistoryById(String)                  // id → GET /cards/{id}/history
    case fetchReceiptHistory(String)                   // receiptId → GET /receipts/{id}/history

    // MARK: - Queries (account-hub generic queries endpoint)
    case fetchEntityQueries(String, String)            // entityType, entityId → GET /account-hub/queries/entity/{type}/{id}
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

    // MARK: - Bank Accounts (lives on AccountHub service)
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

extension CardExpenseRequest: FCURLRequestProtocol {
    var urlRequest: URLRequest? {
        switch self {

        // MARK: Receipts
        case .fetchAllReceipts:
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchMyReceipts:
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/my"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .confirmReceipt(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/\(id)/confirm"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .confirmAllReceipts:
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/confirm-all"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .matchReceipt(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/\(id)/match"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .unmatchReceipt(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/\(id)/unmatch"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .deleteReceipt(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject

        case .flagReceiptPersonal(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/\(id)/flag-personal"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .submitCoding(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/\(id)/submit-coding"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .uploadReceipt(let fileData, let fileName, let mimeType):
            // Multipart form upload — FCURLRequest doesn't model multipart,
            // so we build the request manually but compose the URL from
            // `ServerRequest.CARD_BASE_URL` to keep the host source-of-truth.
            let urlString = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/upload"
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
            let path = params.isEmpty ? "card-expenses/transactions" : "card-expenses/transactions?\(params)"
            let endPoint = "\(ServerRequest.CARD_BASE_URL)\(path)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getTransaction(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/transactions/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .updateTransaction(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/transactions/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .submitTransaction(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/transactions/\(id)/submit"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .postTransaction(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/transactions/\(id)/post"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        // MARK: Cards
        case .fetchCards(let params):
            let path = params.isEmpty ? "card-expenses/cards" : "card-expenses/cards?\(params)"
            let endPoint = "\(ServerRequest.CARD_BASE_URL)\(path)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getCard(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/cards/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .createCard(let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/cards"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .updateCardReq(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/cards/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .deleteCardReq(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/cards/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject

        case .fetchCardHistoryById(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/cards/\(id)/history"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchReceiptHistory(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/\(id)/history"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchEntityQueries(let entityType, let entityId):
            // Account-hub queries live on the AccountHub service, not the
            // card-expenses one. Compose against ACC_HUB_BASE_URL.
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/queries/entity/\(entityType)/\(entityId)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .suspendCardReq(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/cards/\(id)/suspend"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .reactivateCardReq(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/cards/\(id)/reactivate"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .activateCardReq(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/cards/\(id)/activate"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .approveCardReq(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/cards/\(id)/approve"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .rejectCardReq(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/cards/\(id)/reject"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .overrideCardReq(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/cards/\(id)/override"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        // MARK: Metadata
        case .fetchMetadata:
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/metadata"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Accountant Hub queues
        case .fetchTopUps:
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/topups"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchSmartAlerts:
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/alerts"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchCardHistory:
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/posted-history"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchPendingCoding:
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/pending-coding"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchApprovalQueue:
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/approvals"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .overrideApproval(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/approvals/\(id)/override"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .getReceipt(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchReceiptDetail(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/receipts/\(id)/detail"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Bank Accounts (AccountHub service)
        case .fetchBankAccounts:
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/bank-accounts?entity_type=production"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Top-Up Actions
        case .markTopUp(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/topups/\(id)/complete"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .skipTopUp(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/topups/\(id)/skip"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: [:]).requestObject

        case .partialTopUp(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/topups/\(id)/partial"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        // MARK: Smart Alert Actions
        case .resolveAlert(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/alerts/\(id)/resolve"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .dismissAlert(let id):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/alerts/\(id)/dismiss"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .investigateAlert(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/alerts/\(id)/investigate"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .revertAlert(let id, let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/alerts/\(id)/revert"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        // MARK: Settings
        case .fetchSettings:
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/settings"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .updateSettings(let body):
            let endPoint = "\(ServerRequest.CARD_BASE_URL)card-expenses/settings"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject
        }
    }
}
