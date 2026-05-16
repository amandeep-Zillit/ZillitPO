//
//  TimecardCodableTask.swift
//  ZillitPO
//
//  Typed task wrappers for `TimecardRequest` and `DailyLoginRequest`.
//

import Foundation

enum TimecardCodableTask {
    // Metadata
    case getMetadata((Result<ZLGenericResponse<TimecardMetadata>?, Error>) -> Void)

    // Weekly timecards
    case list([String: String], (Result<ZLGenericResponse<[Timecard]>?, Error>) -> Void)
    case mySummary([String: String], (Result<ZLGenericResponse<[TimecardSummary]>?, Error>) -> Void)
    case listForApproval((Result<ZLGenericResponse<[Timecard]>?, Error>) -> Void)
    case listForPayrollProcessing(Int64, (Result<ZLGenericResponse<[Timecard]>?, Error>) -> Void)
    case getOne(String, (Result<ZLGenericResponse<Timecard>?, Error>) -> Void)
    case create([String: Any], (Result<Data?, Error>) -> Void)
    case update(String, [String: Any], (Result<Data?, Error>) -> Void)
    case remove(String, (Result<Data?, Error>) -> Void)

    // Lifecycle
    case submit(String, [String: Any], (Result<Data?, Error>) -> Void)
    case approve(String, [String: Any], (Result<Data?, Error>) -> Void)
    case reject(String, [String: Any], (Result<Data?, Error>) -> Void)
    case approveBatch([String], (Result<Data?, Error>) -> Void)
    case rejectBatch([String], String, (Result<Data?, Error>) -> Void)
    case query(String, [String: Any], (Result<Data?, Error>) -> Void)
    case markPaid(String, (Result<Data?, Error>) -> Void)
    case getHistory(String, (Result<ZLGenericResponse<[TimecardHistoryEntry]>?, Error>) -> Void)
}

extension TimecardCodableTask: FCCodableDataTask {
    var urlDataTask: URLSessionDataTask? {
        switch self {

        case .getMetadata(let completion):
            guard let r = TimecardRequest.getMetadata.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .list(let q, let completion):
            guard let r = TimecardRequest.list(q).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .mySummary(let q, let completion):
            guard let r = TimecardRequest.mySummary(q).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .listForApproval(let completion):
            guard let r = TimecardRequest.listForApproval.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .listForPayrollProcessing(let week, let completion):
            guard let r = TimecardRequest.listForPayrollProcessing(week).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .getOne(let id, let completion):
            guard let r = TimecardRequest.getOne(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .create(let body, let completion):
            guard let r = TimecardRequest.create(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .update(let id, let body, let completion):
            guard let r = TimecardRequest.update(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .remove(let id, let completion):
            guard let r = TimecardRequest.remove(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .submit(let id, let body, let completion):
            guard let r = TimecardRequest.submit(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .approve(let id, let body, let completion):
            guard let r = TimecardRequest.approve(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .reject(let id, let body, let completion):
            guard let r = TimecardRequest.reject(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .approveBatch(let ids, let completion):
            guard let r = TimecardRequest.approveBatch(ids).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .rejectBatch(let ids, let reason, let completion):
            guard let r = TimecardRequest.rejectBatch(ids, reason).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .query(let id, let body, let completion):
            guard let r = TimecardRequest.query(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .markPaid(let id, let completion):
            guard let r = TimecardRequest.markPaid(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .getHistory(let id, let completion):
            guard let r = TimecardRequest.getHistory(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)
        }
    }
}

// MARK: - Daily Login

enum DailyLoginCodableTask {
    case list([String: String], (Result<ZLGenericResponse<[DailyLogin]>?, Error>) -> Void)
    case getForDate(Int64, (Result<ZLGenericResponse<DailyLogin>?, Error>) -> Void)
    case login(Int64, [String: Any], (Result<Data?, Error>) -> Void)
    case logout(Int64, [String: Any], (Result<Data?, Error>) -> Void)
    case update(Int64, [String: Any], (Result<Data?, Error>) -> Void)
    case batchUpdate([String: Any], (Result<Data?, Error>) -> Void)
    case getHistory(Int64, (Result<ZLGenericResponse<[TimecardHistoryEntry]>?, Error>) -> Void)
    case voidDay(Int64, (Result<Data?, Error>) -> Void)
}

extension DailyLoginCodableTask: FCCodableDataTask {
    var urlDataTask: URLSessionDataTask? {
        switch self {
        case .list(let q, let completion):
            guard let r = DailyLoginRequest.list(q).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .getForDate(let ms, let completion):
            guard let r = DailyLoginRequest.getForDate(ms).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .login(let ms, let body, let completion):
            guard let r = DailyLoginRequest.login(ms, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .logout(let ms, let body, let completion):
            guard let r = DailyLoginRequest.logout(ms, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .update(let ms, let body, let completion):
            guard let r = DailyLoginRequest.update(ms, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .batchUpdate(let body, let completion):
            guard let r = DailyLoginRequest.batchUpdate(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)

        case .getHistory(let ms, let completion):
            guard let r = DailyLoginRequest.getHistory(ms).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: r, completion: completion)

        case .voidDay(let ms, let completion):
            guard let r = DailyLoginRequest.voidDay(ms).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: r, completion: completion)
        }
    }
}
