//
//  CashExpenseRequest.swift
//  ZillitPO
//
//  Mirrors live's per-domain Request pattern — each case binds a local
//  `let endPoint = "\(ServerRequest.CASH_BASE_URL)..."` and returns
//  `FCURLRequest(urlPath:type:body:).requestObject`. Account-hub
//  cross-service calls (queries) compose against
//  `ServerRequest.ACC_HUB_BASE_URL` instead.
//

import Foundation

enum CashExpenseRequest {
    // Metadata (roles, settings)
    case fetchMetadata

    // Float Requests
    case fetchMyFloats
    case fetchAllFloats
    case fetchActiveFloats
    case fetchApprovalQueue
    case createFloatRequest([String: Any])
    case fetchFloatDetails(String)                // id → /float-requests/{id}/details
    case getFloat(String)                         // id → /float-requests/{id}
    case approveFloat(String, [String: Any])      // id, body → /float-requests/{id}/approve
    case rejectFloat(String, [String: Any])       // id, body → /float-requests/{id}/reject
    case recordFloatReturn(String, [String: Any]) // id, body → /float-requests/{id}/record-return
    case fetchFloatHistory(String)                // id → /float-requests/{id}/history

    // Claims
    case fetchMyClaims
    /// `GET /claims/my-batches[?float_request_id=<uuid>]`. The optional
    /// parameter is the web client's server-side filter — when supplied,
    /// the backend returns only batches submitted against that float.
    case fetchMyBatches(String?)
    case fetchAllClaims
    case fetchClaimHistory(String)                // batchId → /claims/{id}/history
    case fetchEntityQueries(String, String)       // entityType, entityId → /account-hub/queries/entity/{type}/{id}
    case fetchCodingQueue
    case fetchAuditQueue
    case fetchApprovalQueueClaims
    case fetchReconciliations
    case fetchClaimsByStatus(String)
    case createClaimBatch([String: Any])
    case getClaim(String)
    case saveClaims(String, [String: Any])        // batchId, body
    case saveAndSubmit(String, [String: Any])     // batchId, body (forward to accounts)
    case batchApproval(String, [String: Any])     // batchId, body → /claims/{id}/batch-approval
    case overrideBatch(String)                    // batchId → /claims/{id}/override

    // Overview
    case fetchPaymentRouting

    // Settings
    case fetchSettings
}

extension CashExpenseRequest: FCURLRequestProtocol {
    var urlRequest: URLRequest? {
        switch self {

        // MARK: Metadata
        case .fetchMetadata:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/metadata"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Float Requests
        case .fetchMyFloats:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/float-requests/my-floats"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchAllFloats:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/float-requests"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchActiveFloats:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/float-requests/active-floats"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchApprovalQueue:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/float-requests/approval-queue"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .createFloatRequest(let body):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/float-requests"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .fetchFloatDetails(let id):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/float-requests/\(id)/details"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getFloat(let id):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/float-requests/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .approveFloat(let id, let body):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/float-requests/\(id)/approve"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .rejectFloat(let id, let body):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/float-requests/\(id)/reject"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .recordFloatReturn(let id, let body):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/float-requests/\(id)/record-return"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .fetchFloatHistory(let id):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/float-requests/\(id)/history"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Claims
        case .fetchMyClaims:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/my-claims"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchMyBatches(let floatId):
            let base = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/my-batches"
            guard let id = floatId, !id.isEmpty else {
                return FCURLRequest(urlPath: base, type: .get).requestObject
            }
            let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
            let endPoint = "\(base)?float_request_id=\(encoded)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchAllClaims:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchCodingQueue:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/coding-queue"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchAuditQueue:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/audit-queue"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchApprovalQueueClaims:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/approval-queue"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchReconciliations:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/reconciliations"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchClaimsByStatus(let s):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims?status=\(s)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .createClaimBatch(let body):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .getClaim(let id):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .batchApproval(let id, let body):
            // Unified approve/reject endpoint.
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/\(id)/batch-approval"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .overrideBatch(let id):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/\(id)/override"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .fetchClaimHistory(let batchId):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/\(batchId)/history"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchEntityQueries(let entityType, let entityId):
            // Generic queries live on the AccountHub service, not the
            // cash-expenses one.
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/queries/entity/\(entityType)/\(entityId)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .saveClaims(let id, let body):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/\(id)/save-claims"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .saveAndSubmit(let id, let body):
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/\(id)/save-and-submit"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        // MARK: Overview
        case .fetchPaymentRouting:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/claims/overview/payment-routing"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Settings
        case .fetchSettings:
            let endPoint = "\(ServerRequest.CASH_BASE_URL)cash-expenses/settings"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject
        }
    }
}
