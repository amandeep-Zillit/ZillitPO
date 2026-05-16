//
//  DealMemoRequest.swift
//  ZillitPO
//
//  Mirrors `client/src/api/deal-memo/deal-memo.js`. Endpoints under
//  `/api/v2/deal-memo/...` served by `deal-memo-server`. URL composition
//  follows live's per-case `let endPoint = "..."` pattern — every case
//  inlines `ServerRequest.DEAL_MEMO_BASE_URL` so this file copy-pastes
//  into live alongside the other domain Request files.
//

import Foundation

enum DealMemoRequest {
    // MARK: - Overview / Deals
    case getOverview
    case listDeals([String: String])              // query → ?key=val&...
    case getMyDeal
    case getDeal(String)                          // id
    case getDealHistory(String)
    case getSchedule(String)                      // userId
    case getActiveForUser(String)                 // userId
    case createDeal([String: Any])
    case updateDeal(String, [String: Any])        // id, body
    case deleteDeal(String)

    // Lifecycle transitions
    case submitDeal(String)
    case approveDeal(String, [String: Any])       // id, { signature, comment }
    case rejectDeal(String, [String: Any])        // id, { reason }
    case activateDeal(String)
    case completeDeal(String)
    case cancelDeal(String)

    // Metadata + approval queue
    case getMetadata
    case listApprovalQueue

    // PDF (raw binary — not JSON)
    case generatePDF(String, [String: Any])

    // Templates
    case listTemplates
    case getTemplate(String)
    case createTemplate([String: Any])
    case updateTemplate(String, [String: Any])
    case deleteTemplate(String)
}

extension DealMemoRequest: FCURLRequestProtocol {
    var urlRequest: URLRequest? {
        switch self {

        // MARK: Overview
        case .getOverview:
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/overview"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Deals
        case .listDeals(let query):
            let qs = query.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let endPoint = qs.isEmpty
                ? "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals"
                : "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals?\(qs)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getMyDeal:
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deal"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getDeal(let id):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getDealHistory(let id):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/\(id)/history"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getSchedule(let userId):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/schedule/\(userId)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getActiveForUser(let userId):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/active/\(userId)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .createDeal(let body):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .updateDeal(let id, let body):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .deleteDeal(let id):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject

        // MARK: Lifecycle
        case .submitDeal(let id):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/\(id)/submit"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .approveDeal(let id, let body):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/\(id)/approve"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .rejectDeal(let id, let body):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/\(id)/reject"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .activateDeal(let id):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/\(id)/activate"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .completeDeal(let id):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/\(id)/complete"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .cancelDeal(let id):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/\(id)/cancel"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        // MARK: Metadata / approval queue
        case .getMetadata:
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/metadata"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .listApprovalQueue:
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/approval"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: PDF
        case .generatePDF(let id, let body):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/deals/\(id)/pdf"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        // MARK: Templates
        case .listTemplates:
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/templates"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getTemplate(let id):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/templates/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .createTemplate(let body):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/templates"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .updateTemplate(let id, let body):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/templates/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .deleteTemplate(let id):
            let endPoint = "\(ServerRequest.DEAL_MEMO_BASE_URL)deal-memo/templates/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject
        }
    }
}
