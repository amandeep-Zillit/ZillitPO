//
//  CardExpenseCodableTask.swift
//  ZillitPO
//

import Foundation

enum CardExpenseCodableTask {
    // Receipts
    case fetchAllReceipts((Result<APIResponse<[ReceiptRaw]>?, Error>) -> Void)
    case fetchMyReceipts(String, (Result<APIResponse<[ReceiptRaw]>?, Error>) -> Void)
    case confirmReceipt(String, (Result<Data?, Error>) -> Void)
    case deleteReceipt(String, (Result<Data?, Error>) -> Void)
    case flagReceiptPersonal(String, (Result<Data?, Error>) -> Void)
    case submitCoding(String, [String: Any], (Result<Data?, Error>) -> Void)

    // Cards
    case fetchCards(String, (Result<APIResponse<[CardRaw]>?, Error>) -> Void)
    case fetchAllCards((Result<APIResponse<[CardRaw]>?, Error>) -> Void)
    case createCard([String: Any], (Result<Data?, Error>) -> Void)
    case approveCard(String, [String: Any], (Result<Data?, Error>) -> Void)
    case rejectCard(String, [String: Any], (Result<Data?, Error>) -> Void)

    // Approval Tiers
    case fetchCardApprovalTiers((Result<APIResponse<[ApprovalTierConfig]>?, Error>) -> Void)
}

extension CardExpenseCodableTask: PODataTaskProtocol {
    var urlDataTask: URLSessionDataTask? {
        switch self {

        // Receipts
        case .fetchAllReceipts(let completion):
            guard let req = CardExpenseRequest.fetchAllReceipts.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: req, completion: completion)

        case .fetchMyReceipts(let userId, let completion):
            guard let req = CardExpenseRequest.fetchMyReceipts(userId).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: req, completion: completion)

        case .confirmReceipt(let id, let completion):
            guard let req = CardExpenseRequest.confirmReceipt(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .deleteReceipt(let id, let completion):
            guard let req = CardExpenseRequest.deleteReceipt(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .flagReceiptPersonal(let id, let completion):
            guard let req = CardExpenseRequest.flagReceiptPersonal(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .submitCoding(let id, let body, let completion):
            guard let req = CardExpenseRequest.submitCoding(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        // Cards
        case .fetchCards(let params, let completion):
            guard let req = CardExpenseRequest.fetchCards(params).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: req, completion: completion)

        case .fetchAllCards(let completion):
            guard let req = CardExpenseRequest.fetchCards("").urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: req, completion: completion)

        case .createCard(let body, let completion):
            guard let req = CardExpenseRequest.createCard(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .approveCard(let id, let body, let completion):
            guard let req = CardExpenseRequest.approveCardReq(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .rejectCard(let id, let body, let completion):
            guard let req = CardExpenseRequest.rejectCardReq(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        // Approval Tiers
        case .fetchCardApprovalTiers(let completion):
            guard let req = CardExpenseRequest.fetchCardApprovalTiers.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: req, completion: completion)
        }
    }
}
