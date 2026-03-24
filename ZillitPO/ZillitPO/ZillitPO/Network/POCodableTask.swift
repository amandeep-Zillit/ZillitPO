//
//  POCodableTask.swift
//  ZillitPO
//

import Foundation

enum POCodableTask {
    // MARK: - Vendors (typed responses)
    case fetchVendors((Result<APIResponse<[Vendor]>?, Error>) -> Void)
    case createVendor([String: Any], (Result<Data?, Error>) -> Void)
    case deleteVendor(String, (Result<Data?, Error>) -> Void)

    // MARK: - Approval Tiers (typed response)
    case fetchApprovalTiers((Result<APIResponse<[ApprovalTierConfig]>?, Error>) -> Void)

    // MARK: - Purchase Orders (typed responses)
    case fetchPurchaseOrders(String, (Result<APIResponse<[PurchaseOrderRaw]>?, Error>) -> Void)
    case fetchDrafts((Result<APIResponse<[PurchaseOrderRaw]>?, Error>) -> Void)
    case createPO([String: Any], (Result<Data?, Error>) -> Void)
    case updatePO(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deletePO(String, (Result<Data?, Error>) -> Void)
    case approvePO(String, [String: Any], (Result<Data?, Error>) -> Void)
    case rejectPO(String, [String: Any], (Result<Data?, Error>) -> Void)
    case generatePDF(String, [String: Any], (Result<Data?, Error>) -> Void)

    // MARK: - Templates (typed responses)
    case fetchTemplates((Result<APIResponse<[POTemplate]>?, Error>) -> Void)
    case createTemplate([String: Any], (Result<Data?, Error>) -> Void)
    case updateTemplate(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deleteTemplate(String, (Result<Data?, Error>) -> Void)

    // MARK: - Form Template (typed response)
    case fetchFormTemplate((Result<APIResponse<FormTemplateResponse>?, Error>) -> Void)
}

extension POCodableTask: PODataTaskProtocol {
    var urlDataTask: URLSessionDataTask? {
        switch self {

        // MARK: Vendors
        case .fetchVendors(let completion):
            guard let urlRequest = PORequest.fetchVendors.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .createVendor(let body, let completion):
            guard let urlRequest = PORequest.createVendor(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .deleteVendor(let id, let completion):
            guard let urlRequest = PORequest.deleteVendor(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Approval Tiers
        case .fetchApprovalTiers(let completion):
            guard let urlRequest = PORequest.fetchApprovalTiers.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Purchase Orders
        case .fetchPurchaseOrders(let path, let completion):
            guard let urlRequest = PORequest.fetchPurchaseOrders(path).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .fetchDrafts(let completion):
            guard let urlRequest = PORequest.fetchDrafts.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .createPO(let body, let completion):
            guard let urlRequest = PORequest.createPO(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .updatePO(let id, let body, let completion):
            guard let urlRequest = PORequest.updatePO(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .deletePO(let id, let completion):
            guard let urlRequest = PORequest.deletePO(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .approvePO(let id, let body, let completion):
            guard let urlRequest = PORequest.approvePO(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .rejectPO(let id, let body, let completion):
            guard let urlRequest = PORequest.rejectPO(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .generatePDF(let id, let body, let completion):
            guard let urlRequest = PORequest.generatePDF(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Templates
        case .fetchTemplates(let completion):
            guard let urlRequest = PORequest.fetchTemplates.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .createTemplate(let body, let completion):
            guard let urlRequest = PORequest.createTemplate(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .updateTemplate(let id, let body, let completion):
            guard let urlRequest = PORequest.updateTemplate(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .deleteTemplate(let id, let completion):
            guard let urlRequest = PORequest.deleteTemplate(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Form Template
        case .fetchFormTemplate(let completion):
            guard let urlRequest = PORequest.fetchFormTemplate.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)
        }
    }
}
