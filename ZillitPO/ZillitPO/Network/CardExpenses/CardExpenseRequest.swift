//
//  CardExpenseRequest.swift
//  ZillitPO
//

import Foundation

enum CardExpenseRequest {
    static let baseURL = "http://localhost:3005"

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
    case approveCardReq(String, [String: Any])         // id, body
    case rejectCardReq(String, [String: Any])          // id, body

    // MARK: - Approval Tiers
    case fetchCardApprovalTiers

    // MARK: - Overview
    case fetchOverview

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

        case .fetchMyReceipts(let userId):
            return buildLocal(.get, "/api/v2/card-expenses/receipts/my?userId=\(userId)")

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

        case .approveCardReq(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/cards/\(id)/approve", body: body)

        case .rejectCardReq(let id, let body):
            return buildLocal(.post, "/api/v2/card-expenses/cards/\(id)/reject", body: body)

        // MARK: Approval Tiers
        case .fetchCardApprovalTiers:
            let url = "http://localhost:3003/api/v2/account-hub/approval-tiers?module=card_processing"
            guard let u = URL(string: url) else { return nil }
            var req = URLRequest(url: u)
            req.httpMethod = "GET"
            req.timeoutInterval = 30
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
            req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
            return req

        // MARK: Overview
        case .fetchOverview:
            return buildLocal(.get, "/api/v2/card-expenses/overview")

        // MARK: Settings
        case .fetchSettings:
            return buildLocal(.get, "/api/v2/card-expenses/settings")

        case .updateSettings(let body):
            return buildLocal(.patch, "/api/v2/card-expenses/settings", body: body)
        }
    }
}
