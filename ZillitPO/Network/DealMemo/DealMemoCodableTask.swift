//
//  DealMemoCodableTask.swift
//  ZillitPO
//
//  Typed task wrappers for every DealMemoRequest endpoint.
//

import Foundation

enum DealMemoCodableTask {
    // MARK: - Overview / Deals
    case getOverview((Result<ZLGenericResponse<DealMemoOverviewResponse>?, Error>) -> Void)
    case listDeals([String: String], (Result<ZLGenericResponse<[DealMemo]>?, Error>) -> Void)
    case getMyDeal((Result<ZLGenericResponse<DealMemo>?, Error>) -> Void)
    case getDeal(String, (Result<ZLGenericResponse<DealMemo>?, Error>) -> Void)
    case getDealHistory(String, (Result<ZLGenericResponse<[DealMemoHistoryEntry]>?, Error>) -> Void)
    case getSchedule(String, (Result<ZLGenericResponse<DealMemo>?, Error>) -> Void)
    case getActiveForUser(String, (Result<ZLGenericResponse<DealMemo>?, Error>) -> Void)
    case createDeal([String: Any], (Result<Data?, Error>) -> Void)
    case updateDeal(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deleteDeal(String, (Result<Data?, Error>) -> Void)

    // Lifecycle
    case submitDeal(String, (Result<Data?, Error>) -> Void)
    case approveDeal(String, [String: Any], (Result<Data?, Error>) -> Void)
    case rejectDeal(String, [String: Any], (Result<Data?, Error>) -> Void)
    case activateDeal(String, (Result<Data?, Error>) -> Void)
    case completeDeal(String, (Result<Data?, Error>) -> Void)
    case cancelDeal(String, (Result<Data?, Error>) -> Void)

    // Metadata + approval queue
    case getMetadata((Result<ZLGenericResponse<DealMemoMetadata>?, Error>) -> Void)
    case listApprovalQueue((Result<DealMemoApprovalQueueResponse?, Error>) -> Void)

    // Templates
    case listTemplates((Result<ZLGenericResponse<[DealMemo]>?, Error>) -> Void)
    case getTemplate(String, (Result<ZLGenericResponse<DealMemo>?, Error>) -> Void)
    case createTemplate([String: Any], (Result<Data?, Error>) -> Void)
    case updateTemplate(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deleteTemplate(String, (Result<Data?, Error>) -> Void)
}

extension DealMemoCodableTask: FCCodableDataTask {
    var urlDataTask: URLSessionDataTask? {
        switch self {

        case .getOverview(let completion):
            guard let r = DealMemoRequest.getOverview.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .listDeals(let q, let completion):
            guard let r = DealMemoRequest.listDeals(q).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .getMyDeal(let completion):
            guard let r = DealMemoRequest.getMyDeal.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .getDeal(let id, let completion):
            guard let r = DealMemoRequest.getDeal(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .getDealHistory(let id, let completion):
            guard let r = DealMemoRequest.getDealHistory(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .getSchedule(let userId, let completion):
            guard let r = DealMemoRequest.getSchedule(userId).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .getActiveForUser(let userId, let completion):
            guard let r = DealMemoRequest.getActiveForUser(userId).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .createDeal(let body, let completion):
            guard let r = DealMemoRequest.createDeal(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .updateDeal(let id, let body, let completion):
            guard let r = DealMemoRequest.updateDeal(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .deleteDeal(let id, let completion):
            guard let r = DealMemoRequest.deleteDeal(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        // Lifecycle
        case .submitDeal(let id, let completion):
            guard let r = DealMemoRequest.submitDeal(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .approveDeal(let id, let body, let completion):
            guard let r = DealMemoRequest.approveDeal(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .rejectDeal(let id, let body, let completion):
            guard let r = DealMemoRequest.rejectDeal(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .activateDeal(let id, let completion):
            guard let r = DealMemoRequest.activateDeal(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .completeDeal(let id, let completion):
            guard let r = DealMemoRequest.completeDeal(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .cancelDeal(let id, let completion):
            guard let r = DealMemoRequest.cancelDeal(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        // Metadata + approval queue
        case .getMetadata(let completion):
            guard let r = DealMemoRequest.getMetadata.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .listApprovalQueue(let completion):
            // The server returns `{ data: { pending, approved, rejected }, totals }` —
            // not wrapped in the standard envelope — so decode `DealMemoApprovalQueueResponse`
            // directly via `dataResultTask`.
            guard let r = DealMemoRequest.listApprovalQueue.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r) { result in
                switch result {
                case .success(let data):
                    guard let d = data,
                          let decoded = try? JSONDecoder().decode(DealMemoApprovalQueueResponse.self, from: d) else {
                        completion(.success(nil)); return
                    }
                    completion(.success(decoded))
                case .failure(let e): completion(.failure(e))
                }
            }

        // Templates
        case .listTemplates(let completion):
            guard let r = DealMemoRequest.listTemplates.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .getTemplate(let id, let completion):
            guard let r = DealMemoRequest.getTemplate(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .createTemplate(let body, let completion):
            guard let r = DealMemoRequest.createTemplate(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .updateTemplate(let id, let body, let completion):
            guard let r = DealMemoRequest.updateTemplate(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .deleteTemplate(let id, let completion):
            guard let r = DealMemoRequest.deleteTemplate(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)
        }
    }
}
