//
//  TimecardRequest.swift
//  ZillitPO
//
//  Weekly timecards + payroll + history endpoints. Mirrors
//  `client/src/api/timecard/timecards.js`. Daily-login endpoints live
//  in `DailyLoginRequest.swift` next door.
//

import Foundation

enum TimecardRequest {
    // MARK: - Metadata (role flags + status counts)
    case getMetadata

    // MARK: - Weekly timecards
    case list([String: String])                  // ?status=&week_starting=&page=&per_page=
    case mySummary([String: String])             // ?through_week=&…
    case listForApproval                         // GET /weekly/approval
    case listForPayrollProcessing(Int64)         // weekStarting → /payroll-processing/{ms}
    case getOne(String)
    case create([String: Any])
    case update(String, [String: Any])
    case remove(String)

    // Lifecycle
    case submit(String, [String: Any])           // id, body (optional save+submit)
    case approve(String, [String: Any])
    case reject(String, [String: Any])
    case approveBatch([String])                  // ids
    case rejectBatch([String], String)           // ids, reason
    case query(String, [String: Any])            // id, body (request changes)
    case markPaid(String)
    case getHistory(String)

    // Accrued holiday pay
    case accruedHolidayPay(throughWeek: Int64?)
}

extension TimecardRequest: FCURLRequestProtocol {
    var urlRequest: URLRequest? {
        switch self {

        case .getMetadata:
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/metadata"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: List + summaries
        case .list(let query):
            let qs = query.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let endPoint = qs.isEmpty
                ? "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly"
                : "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly?\(qs)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .mySummary(let query):
            let qs = query.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let endPoint = qs.isEmpty
                ? "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/my-summary"
                : "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/my-summary?\(qs)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .listForApproval:
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/approval"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .listForPayrollProcessing(let weekStarting):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/payroll-processing/\(weekStarting)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getOne(let id):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .create(let body):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .update(let id, let body):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .remove(let id):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject

        // MARK: Lifecycle
        case .submit(let id, let body):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/\(id)/submit"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .approve(let id, let body):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/\(id)/approve"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .reject(let id, let body):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/\(id)/reject"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .approveBatch(let ids):
            let body: [String: Any] = ["ids": ids]
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/batch/approve"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .rejectBatch(let ids, let reason):
            let body: [String: Any] = ["ids": ids, "reason": reason]
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/batch/reject"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .query(let id, let body):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/\(id)/query"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .markPaid(let id):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/\(id)/mark-paid"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .getHistory(let id):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/\(id)/history"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .accruedHolidayPay(let through):
            let base = "\(ServerRequest.TIMECARD_BASE_URL)timecards/weekly/holiday-pay/accrued"
            if let t = through {
                return FCURLRequest(urlPath: "\(base)?through_week=\(t)", type: .get).requestObject
            }
            return FCURLRequest(urlPath: base, type: .get).requestObject
        }
    }
}
