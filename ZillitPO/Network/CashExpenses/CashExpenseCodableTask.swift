//
//  CashExpenseCodableTask.swift
//  ZillitPO
//

import Foundation

enum CashExpenseCodableTask {
    case fetchMetadata((Result<APIResponse<CashExpenseMetadata>?, Error>) -> Void)
    case fetchMyFloats((Result<APIResponse<[FloatRequestRaw]>?, Error>) -> Void)
    case fetchAllFloats((Result<APIResponse<[FloatRequestRaw]>?, Error>) -> Void)
    case fetchActiveFloats((Result<APIResponse<[FloatRequestRaw]>?, Error>) -> Void)
    case fetchApprovalQueue((Result<APIResponse<[FloatRequestRaw]>?, Error>) -> Void)
    case fetchMyClaims((Result<APIResponse<[ClaimBatchRaw]>?, Error>) -> Void)
    case fetchMyBatches(String?, (Result<APIResponse<[ClaimBatchRaw]>?, Error>) -> Void)
    case fetchAllClaims((Result<APIResponse<[ClaimBatchRaw]>?, Error>) -> Void)
    case fetchCodingQueue((Result<APIResponse<[ClaimBatchRaw]>?, Error>) -> Void)
    case fetchAuditQueue((Result<APIResponse<[ClaimBatchRaw]>?, Error>) -> Void)
    case fetchApprovalQueueClaims((Result<APIResponse<[ClaimBatchRaw]>?, Error>) -> Void)
    case fetchPaymentRouting((Result<APIResponse<PaymentRoutingResponse>?, Error>) -> Void)
    case createFloatRequest([String: Any], (Result<Data?, Error>) -> Void)
    case fetchFloatDetails(String, (Result<APIResponse<FloatDetailsResponse>?, Error>) -> Void)
    case getFloat(String, (Result<APIResponse<FloatRequestRaw>?, Error>) -> Void)
    case approveFloat(String, [String: Any], (Result<Data?, Error>) -> Void)
    case rejectFloat(String, [String: Any], (Result<Data?, Error>) -> Void)
    case recordFloatReturn(String, [String: Any], (Result<Data?, Error>) -> Void)
    case fetchFloatHistory(String, (Result<APIResponse<[FloatHistoryEntry]>?, Error>) -> Void)
    case fetchClaimHistory(String, (Result<APIResponse<[FloatHistoryEntry]>?, Error>) -> Void)
    case fetchEntityQueries(String, String, (Result<APIResponse<InvoiceQueryThread>?, Error>) -> Void)
    case createClaimBatch([String: Any], (Result<Data?, Error>) -> Void)
    case saveClaims(String, [String: Any], (Result<Data?, Error>) -> Void)
    case saveAndSubmit(String, [String: Any], (Result<Data?, Error>) -> Void)
    case batchApproval(String, [String: Any], (Result<Data?, Error>) -> Void)
    case overrideBatch(String, (Result<Data?, Error>) -> Void)
}

extension CashExpenseCodableTask: PODataTaskProtocol {
    var urlDataTask: URLSessionDataTask? {
        switch self {
        case .fetchMetadata(let c):
            guard let r = CashExpenseRequest.fetchMetadata.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchMyFloats(let c):
            guard let r = CashExpenseRequest.fetchMyFloats.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchAllFloats(let c):
            guard let r = CashExpenseRequest.fetchAllFloats.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchActiveFloats(let c):
            guard let r = CashExpenseRequest.fetchActiveFloats.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchApprovalQueue(let c):
            guard let r = CashExpenseRequest.fetchApprovalQueue.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchMyClaims(let c):
            guard let r = CashExpenseRequest.fetchMyClaims.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchMyBatches(let floatId, let c):
            guard let r = CashExpenseRequest.fetchMyBatches(floatId).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchAllClaims(let c):
            guard let r = CashExpenseRequest.fetchAllClaims.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchCodingQueue(let c):
            guard let r = CashExpenseRequest.fetchCodingQueue.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchAuditQueue(let c):
            guard let r = CashExpenseRequest.fetchAuditQueue.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchApprovalQueueClaims(let c):
            guard let r = CashExpenseRequest.fetchApprovalQueueClaims.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchPaymentRouting(let c):
            guard let r = CashExpenseRequest.fetchPaymentRouting.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .createFloatRequest(let body, let c):
            guard let r = CashExpenseRequest.createFloatRequest(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: r, completion: c)
        case .fetchFloatDetails(let id, let c):
            guard let r = CashExpenseRequest.fetchFloatDetails(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .getFloat(let id, let c):
            guard let r = CashExpenseRequest.getFloat(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .approveFloat(let id, let body, let c):
            guard let r = CashExpenseRequest.approveFloat(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: r, completion: c)
        case .rejectFloat(let id, let body, let c):
            guard let r = CashExpenseRequest.rejectFloat(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: r, completion: c)
        case .recordFloatReturn(let id, let body, let c):
            guard let r = CashExpenseRequest.recordFloatReturn(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: r, completion: c)
        case .fetchFloatHistory(let id, let c):
            guard let r = CashExpenseRequest.fetchFloatHistory(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchClaimHistory(let id, let c):
            guard let r = CashExpenseRequest.fetchClaimHistory(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .fetchEntityQueries(let entityType, let entityId, let c):
            guard let r = CashExpenseRequest.fetchEntityQueries(entityType, entityId).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: r, completion: c)
        case .createClaimBatch(let body, let c):
            guard let r = CashExpenseRequest.createClaimBatch(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: r, completion: c)
        case .saveClaims(let id, let body, let c):
            guard let r = CashExpenseRequest.saveClaims(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: r, completion: c)
        case .saveAndSubmit(let id, let body, let c):
            guard let r = CashExpenseRequest.saveAndSubmit(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: r, completion: c)
        case .batchApproval(let id, let body, let c):
            guard let r = CashExpenseRequest.batchApproval(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: r, completion: c)
        case .overrideBatch(let id, let c):
            guard let r = CashExpenseRequest.overrideBatch(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: r, completion: c)
        }
    }
}
