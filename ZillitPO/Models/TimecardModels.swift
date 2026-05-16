//
//  TimecardModels.swift
//  ZillitPO
//
//  Shapes mirror `timecard-server/src/models/v2/*.js` + the response
//  envelopes from `client/src/api/timecard/*.js`. Fields stay optional
//  because the server projects sparsely depending on endpoint.
//

import Foundation

// MARK: - Status enum

enum TimecardStatus: String, Codable, CaseIterable {
    case draft
    case submitted               // submitted for approval
    case approved                // all tiers signed
    case rejected
    case queried                 // approver requested changes
    case paid

    var label: String {
        switch self {
        case .draft:     return "Draft"
        case .submitted: return "Submitted"
        case .approved:  return "Approved"
        case .rejected:  return "Rejected"
        case .queried:   return "Queried"
        case .paid:      return "Paid"
        }
    }

    var tokenColor: String {
        switch self {
        case .draft:               return "gray"
        case .submitted:           return "amber"
        case .approved:            return "green"
        case .rejected:            return "red"
        case .queried:             return "blue"
        case .paid:                return "green"
        }
    }
}

// MARK: - Day type (work / holiday / sick / weekly-rest / etc.)

enum TimecardDayType: String, Codable {
    case work
    case holiday
    case sick
    case bankHoliday = "bank_holiday"
    case weeklyRest  = "weekly_rest"
    case unpaidLeave = "unpaid_leave"
    case other
}

// MARK: - One day on a weekly timecard

struct TimecardDay: Codable, Equatable, Identifiable {
    /// Epoch ms — start-of-day in the user's TZ.
    var date: Int64?
    /// `work` / `holiday` / `sick` / `bank_holiday` / `weekly_rest` / `unpaid_leave` / `other`.
    var dayType: String?
    /// "HH:mm" — call-time start.
    var callTime: String?
    /// "HH:mm" — wrap-time end.
    var wrapTime: String?
    /// Meal-break duration in minutes (lunch + tea).
    var mealBreakMins: Int?
    /// Net hours worked (call→wrap minus meal break, after server math).
    var hoursWorked: Double?
    /// Driver/early-call/distant indicators baked in.
    var indicators: [String]?
    var notes: String?

    var id: String { "\(date ?? 0)-\(dayType ?? "")" }

    enum CodingKeys: String, CodingKey {
        case date, indicators, notes
        case dayType        = "day_type"
        case callTime       = "call_time"
        case wrapTime       = "wrap_time"
        case mealBreakMins  = "meal_break_mins"
        case hoursWorked    = "hours_worked"
    }
}

// MARK: - Approval entry

struct TimecardApproval: Codable, Equatable {
    var userId: String?
    var tierNumber: Int?
    var approvedAt: Int64?
    var signature: String?
    var comment: String?

    enum CodingKeys: String, CodingKey {
        case signature, comment
        case userId     = "user_id"
        case tierNumber = "tier_number"
        case approvedAt = "approved_at"
    }
}

// MARK: - Timecard (weekly)

struct Timecard: Codable, Identifiable, Equatable {
    var _id: String?
    var timecardNumber: String?
    var projectId: String?
    var userId: String?
    var departmentId: String?
    var designationId: String?

    /// Epoch ms of Monday 00:00 in the user's TZ.
    var weekStarting: Int64?
    var weekEnding: Int64?
    /// Display "Week N" — the older identifier; UI now prefers weekStarting.
    var weekNumber: Int?
    var timezone: String?

    var status: String?
    var days: [TimecardDay]?
    var approvals: [TimecardApproval]?

    /// Server-computed totals.
    var totalHours: Double?
    var basicHours: Double?
    var overtimeHours: Double?
    var holidayHours: Double?
    var grossPay: Double?
    var holidayPay: Double?
    var currency: String?

    var rejectionReason: String?
    var queryNote: String?
    var paidAt: Int64?
    var createdAt: Int64?
    var updatedAt: Int64?
    var submittedAt: Int64?
    var approvedAt: Int64?

    var id: String { _id ?? timecardNumber ?? UUID().uuidString }
    var tcStatus: TimecardStatus { TimecardStatus(rawValue: status ?? "") ?? .draft }

    enum CodingKeys: String, CodingKey {
        case _id, status, days, approvals, currency
        case timecardNumber  = "timecard_number"
        case projectId       = "project_id"
        case userId          = "user_id"
        case departmentId    = "department_id"
        case designationId   = "designation_id"
        case weekStarting    = "week_starting"
        case weekEnding      = "week_ending"
        case weekNumber      = "week_number"
        case timezone
        case totalHours      = "total_hours"
        case basicHours      = "basic_hours"
        case overtimeHours   = "overtime_hours"
        case holidayHours    = "holiday_hours"
        case grossPay        = "gross_pay"
        case holidayPay      = "holiday_pay"
        case rejectionReason = "rejection_reason"
        case queryNote       = "query_note"
        case paidAt          = "paid_at"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        case submittedAt     = "submitted_at"
        case approvedAt      = "approved_at"
    }
}

// MARK: - My-timecards summary row

struct TimecardSummary: Codable, Equatable, Identifiable {
    var _id: String?
    var timecardNumber: String?
    var weekStarting: Int64?
    var status: String?
    var daysWorked: Int?
    var totalHours: Double?
    var grossPay: Double?
    var currency: String?

    var id: String { _id ?? "\(weekStarting ?? 0)" }
    var tcStatus: TimecardStatus { TimecardStatus(rawValue: status ?? "") ?? .draft }

    enum CodingKeys: String, CodingKey {
        case _id, status, currency
        case timecardNumber = "timecard_number"
        case weekStarting   = "week_starting"
        case daysWorked     = "days_worked"
        case totalHours     = "total_hours"
        case grossPay       = "gross_pay"
    }
}

// MARK: - Metadata (gates the role-aware sub-cards on the landing)

struct TimecardMetadata: Codable, Equatable {
    var isAccountant: Bool?
    var isApprover: Bool?
    var isCompleter: Bool?
    var statusCounts: TimecardStatusCounts?
    var pendingApproval: Int?
    var approverDepartmentIds: [String]?
    var approvalTierConfigs: [ApprovalTierConfig]?

    enum CodingKeys: String, CodingKey {
        case isAccountant          = "is_accountant"
        case isApprover            = "is_approver"
        case isCompleter           = "is_completer"
        case statusCounts          = "status_counts"
        case pendingApproval       = "pending_approval"
        case approverDepartmentIds = "approver_department_ids"
        case approvalTierConfigs   = "approval_tier_configs"
    }
}

struct TimecardStatusCounts: Codable, Equatable {
    var draft: Int?
    var submitted: Int?
    var approved: Int?
    var rejected: Int?
    var queried: Int?
    var paid: Int?
}

// MARK: - Daily login record

struct DailyLogin: Codable, Equatable, Identifiable {
    var _id: String?
    var userId: String?
    /// Epoch ms — start of the day in the user's TZ.
    var date: Int64?
    var loginDetails: DailyLoginDetails?
    var logoutDetails: DailyLoginDetails?
    var dayType: String?
    var notes: String?
    var hoursWorked: Double?
    /// `pending` / `logged_in` / `logged_out` / `voided` — derived
    /// server-side from `loginDetails` / `logoutDetails`.
    var status: String?
    var createdAt: Int64?
    var updatedAt: Int64?

    var id: String { _id ?? "\(date ?? 0)" }

    enum CodingKeys: String, CodingKey {
        case _id, status, notes
        case userId        = "user_id"
        case date
        case loginDetails  = "login_details"
        case logoutDetails = "logout_details"
        case dayType       = "day_type"
        case hoursWorked   = "hours_worked"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }
}

struct DailyLoginDetails: Codable, Equatable {
    /// Epoch ms when the button was tapped.
    var timestamp: Int64?
    var location: String?
    var deviceId: String?
    var manual: Bool?

    enum CodingKeys: String, CodingKey {
        case timestamp, location, manual
        case deviceId = "device_id"
    }
}

// MARK: - History entry

struct TimecardHistoryEntry: Codable, Equatable, Identifiable {
    var action: String?
    var actionBy: String?
    var actionAt: Int64?
    var note: String?

    var id: String { "\(actionBy ?? "")-\(actionAt ?? 0)-\(action ?? "")" }

    enum CodingKeys: String, CodingKey {
        case action, note
        case actionBy = "action_by"
        case actionAt = "action_at"
    }
}
