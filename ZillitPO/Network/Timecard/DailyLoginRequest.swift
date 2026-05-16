//
//  DailyLoginRequest.swift
//  ZillitPO
//
//  Daily login / logout endpoints. Mirrors
//  `client/src/api/timecard/dailyLogin.js`.
//

import Foundation

enum DailyLoginRequest {
    case list([String: String])           // ?date_from=&date_to=
    case getForDate(Int64)                // dateMs
    case login(Int64, [String: Any])      // dateMs, body
    case logout(Int64, [String: Any])     // dateMs, body
    case update(Int64, [String: Any])     // dateMs, body
    case batchUpdate([String: Any])       // { user_id, timezone, days }
    case getHistory(Int64)
    case voidDay(Int64)
}

extension DailyLoginRequest: FCURLRequestProtocol {
    var urlRequest: URLRequest? {
        switch self {

        case .list(let query):
            let qs = query.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let endPoint = qs.isEmpty
                ? "\(ServerRequest.TIMECARD_BASE_URL)timecards/daily-login"
                : "\(ServerRequest.TIMECARD_BASE_URL)timecards/daily-login?\(qs)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .getForDate(let ms):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/daily-login/\(ms)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .login(let ms, let body):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/daily-login/\(ms)/login"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .logout(let ms, let body):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/daily-login/\(ms)/logout"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .update(let ms, let body):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/daily-login/\(ms)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .batchUpdate(let body):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/daily-login/batch"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .getHistory(let ms):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/daily-login/\(ms)/history"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .voidDay(let ms):
            let endPoint = "\(ServerRequest.TIMECARD_BASE_URL)timecards/daily-login/\(ms)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject
        }
    }
}
