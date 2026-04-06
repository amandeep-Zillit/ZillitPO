//
//  CashExpenseRequest.swift
//  ZillitPO
//

import Foundation

enum CashExpenseRequest {
    static let baseURL = "http://localhost:3006"

    // Metadata (roles, settings)
    case fetchMetadata
    // Float Requests
    case fetchMyFloats
    case fetchAllFloats
    case fetchActiveFloats
    case fetchApprovalQueue
    case createFloatRequest([String: Any])
    // Claims
    case fetchMyClaims
    case fetchMyBatches
    case fetchAllClaims
    case fetchCodingQueue
    case fetchAuditQueue
    case fetchApprovalQueueClaims
    case fetchSignOffQueue
    case fetchReconciliations
    case fetchClaimsByStatus(String)
    case createClaimBatch([String: Any])
    case getClaim(String)
    case saveClaims(String, [String: Any])       // batchId, body
    case saveAndSubmit(String, [String: Any])     // batchId, body (forward to accounts)
    // Settings
    case fetchSettings
}

extension CashExpenseRequest: POURLRequestProtocol {
    private func buildLocal(_ method: HTTPMethodType, _ path: String, body: Any? = nil) -> URLRequest? {
        let urlString = "\(CashExpenseRequest.baseURL)\(path)"
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
        req.setValue(String(APIClient.shared.isAccountant), forHTTPHeaderField: "x-is-accountant")
        if let body = body, let data = try? JSONSerialization.data(withJSONObject: body) { req.httpBody = data }
        return req
    }

    var urlRequest: URLRequest? {
        switch self {
        case .fetchMetadata:         return buildLocal(.get, "/api/v2/cash-expenses/metadata")
        case .fetchMyFloats:         return buildLocal(.get, "/api/v2/cash-expenses/float-requests/my-floats")
        case .fetchAllFloats:        return buildLocal(.get, "/api/v2/cash-expenses/float-requests")
        case .fetchActiveFloats:     return buildLocal(.get, "/api/v2/cash-expenses/float-requests/active-floats")
        case .fetchApprovalQueue:    return buildLocal(.get, "/api/v2/cash-expenses/float-requests/approval-queue")
        case .createFloatRequest(let body):
            return buildLocal(.post, "/api/v2/cash-expenses/float-requests", body: body)
        case .fetchMyClaims:         return buildLocal(.get, "/api/v2/cash-expenses/claims/my-claims")
        case .fetchMyBatches:        return buildLocal(.get, "/api/v2/cash-expenses/claims/my-batches")
        case .fetchAllClaims:        return buildLocal(.get, "/api/v2/cash-expenses/claims")
        case .fetchCodingQueue:      return buildLocal(.get, "/api/v2/cash-expenses/claims/coding-queue")
        case .fetchAuditQueue:       return buildLocal(.get, "/api/v2/cash-expenses/claims/audit-queue")
        case .fetchApprovalQueueClaims: return buildLocal(.get, "/api/v2/cash-expenses/claims/approval-queue")
        case .fetchSignOffQueue:     return buildLocal(.get, "/api/v2/cash-expenses/claims/sign-off-queue")
        case .fetchReconciliations:  return buildLocal(.get, "/api/v2/cash-expenses/reconciliations")
        case .fetchClaimsByStatus(let s): return buildLocal(.get, "/api/v2/cash-expenses/claims?status=\(s)")
        case .createClaimBatch(let body): return buildLocal(.post, "/api/v2/cash-expenses/claims", body: body)
        case .getClaim(let id):      return buildLocal(.get, "/api/v2/cash-expenses/claims/\(id)")
        case .saveClaims(let id, let body): return buildLocal(.post, "/api/v2/cash-expenses/claims/\(id)/save-claims", body: body)
        case .saveAndSubmit(let id, let body): return buildLocal(.post, "/api/v2/cash-expenses/claims/\(id)/save-and-submit", body: body)
        case .fetchSettings:         return buildLocal(.get, "/api/v2/cash-expenses/settings")
        }
    }
}
