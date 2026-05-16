//
//  AccountHubCodableTask.swift
//  ZillitPO
//
//  Typed task wrappers for every AccountHubRequest endpoint.
//

import Foundation

enum AccountHubCodableTask {

    case fetchApprovalTiers(String, (Result<ZLGenericResponse<[ApprovalTierConfig]>?, Error>) -> Void)

    // MARK: - Vendors (typed bodies)
    case createVendor(VendorRequestBody, (Result<Data?, Error>) -> Void)
    case updateVendor(String, VendorRequestBody, (Result<Data?, Error>) -> Void)

    // MARK: - Queries (PO-specific, kept for LegacyPOViewModel compatibility)
    case fetchPOQueries(String, (Result<ZLGenericResponse<InvoiceQueryThread>?, Error>) -> Void)
    case sendPOQuery(String, [String: Any], (Result<ZLGenericResponse<InvoiceQueryThread>?, Error>) -> Void)
    case addPOQuery(String, [String: Any], (Result<ZLGenericResponse<InvoiceQueryThread>?, Error>) -> Void)

    // MARK: - Queries (generic — used by AccountHubViewModel)
    case fetchEntityQueries(String, String, (Result<ZLGenericResponse<InvoiceQueryThread>?, Error>) -> Void)
    case sendEntityQuery(InvoiceQueryThread, (Result<ZLGenericResponse<InvoiceQueryThread>?, Error>) -> Void)
    case addEntityQuery(String, InvoiceQueryMessage, (Result<ZLGenericResponse<InvoiceQueryThread>?, Error>) -> Void)

    // MARK: - Bank Accounts
    case fetchBankAccounts(type: String?, active: Bool?, (Result<ZLGenericResponse<[HubBankAccount]>?, Error>) -> Void)
    case fetchBankAccount(String, (Result<ZLGenericResponse<HubBankAccount>?, Error>) -> Void)
    case createBankAccount(HubBankAccountRequestBody, (Result<Data?, Error>) -> Void)
    case updateBankAccount(String, HubBankAccountRequestBody, (Result<Data?, Error>) -> Void)
    case deleteBankAccount(String, (Result<Data?, Error>) -> Void)

    case fetchFormTemplate(String, (Result<ZLGenericResponse<FormTemplateResponse>?, Error>) -> Void)
}

extension AccountHubCodableTask: FCCodableDataTask {
    var urlDataTask: URLSessionDataTask? {
        switch self {

        case .fetchApprovalTiers(let module, let completion):
            guard let urlRequest = AccountHubRequest.fetchApprovalTiers(module).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .createVendor(let body, let completion):
            guard let urlRequest = AccountHubRequest.createVendor(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .updateVendor(let id, let body, let completion):
            guard let urlRequest = AccountHubRequest.updateVendor(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .fetchPOQueries(let id, let completion):
            guard let urlRequest = AccountHubRequest.fetchQueries("purchase_order", id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .sendPOQuery(_, let body, let completion):
            guard let urlRequest = AccountHubRequest.sendQuery(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .addPOQuery(let threadId, let body, let completion):
            guard let urlRequest = AccountHubRequest.addQuery(threadId, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .fetchEntityQueries(let entityType, let entityId, let completion):
            guard let urlRequest = AccountHubRequest.fetchQueries(entityType, entityId).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .sendEntityQuery(let body, let completion):
            guard let urlRequest = AccountHubRequest.sendEntityQuery(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .addEntityQuery(let threadId, let body, let completion):
            guard let urlRequest = AccountHubRequest.addEntityQuery(threadId, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .fetchBankAccounts(let type, let active, let completion):
            guard let urlRequest = AccountHubRequest.fetchBankAccounts(type: type, active: active).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .fetchBankAccount(let id, let completion):
            guard let urlRequest = AccountHubRequest.fetchBankAccount(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .createBankAccount(let body, let completion):
            guard let urlRequest = AccountHubRequest.createBankAccount(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .updateBankAccount(let id, let body, let completion):
            guard let urlRequest = AccountHubRequest.updateBankAccount(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .deleteBankAccount(let id, let completion):
            guard let urlRequest = AccountHubRequest.deleteBankAccount(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .fetchFormTemplate(let module, let completion):
            guard let urlRequest = AccountHubRequest.fetchFormTemplate(module).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)
        }
    }
}
