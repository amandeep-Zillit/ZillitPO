//
//  DealMemoModels.swift
//  ZillitPO
//
//  Shapes mirror `deal-memo-server/src/models/v2/*.js` + the response
//  envelopes from `client/src/api/deal-memo/deal-memo.js`. Fields are
//  optional everywhere because the server projects sparsely depending
//  on endpoint (overview returns a slim row; getDeal returns the full
//  document).
//

import Foundation

// MARK: - Status enum

enum DealMemoStatus: String, Codable, CaseIterable {
    case draft
    case awaitingApproval = "awaiting_approval"
    case approved
    case rejected
    case active
    case completed
    case cancelled

    var label: String {
        switch self {
        case .draft:             return "Draft"
        case .awaitingApproval:  return "Awaiting Approval"
        case .approved:          return "Approved"
        case .rejected:          return "Rejected"
        case .active:            return "Active"
        case .completed:         return "Completed"
        case .cancelled:         return "Cancelled"
        }
    }

    /// Mirrors the React `STATUS_META` colour token map.
    var tokenColor: String {
        switch self {
        case .draft:             return "gray"
        case .awaitingApproval:  return "amber"
        case .approved, .active: return "green"
        case .completed:         return "blue"
        case .rejected, .cancelled: return "red"
        }
    }
}

// MARK: - Crew details

struct DealMemoCrewDetails: Codable, Equatable {
    var crewName: String?
    var customDesignation: String?
    var designationIdentifier: String?
    var email: String?
    var phone: String?

    enum CodingKeys: String, CodingKey {
        case email, phone
        case crewName              = "crew_name"
        case customDesignation     = "custom_designation"
        case designationIdentifier = "designation_identifier"
    }
}

// MARK: - Rates (subset — full Step5Rates shape ports in a follow-up turn)

struct DealMemoRateRow: Codable, Equatable {
    var rate: Double?
    var currency: String?
}

struct DealMemoRates: Codable, Equatable {
    var contractCurrency: String?
    var daily: DealMemoRateRow?
    var weekly: DealMemoRateRow?
    var hourly: DealMemoRateRow?

    enum CodingKeys: String, CodingKey {
        case daily, weekly, hourly
        case contractCurrency = "contract_currency"
    }
}

// MARK: - Approval entry

struct DealMemoApproval: Codable, Equatable {
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

// MARK: - Deal memo (top-level)

struct DealMemo: Codable, Identifiable, Equatable {
    /// Mongo `_id`. Use `id` (the Identifiable computed below) at call sites.
    var _id: String?
    var dealReference: String?
    var projectId: String?
    var userId: String?
    var departmentId: String?
    var designationId: String?
    var status: String?
    var crewDetails: DealMemoCrewDetails?
    var rates: DealMemoRates?
    var approvals: [DealMemoApproval]?
    var rejectionReason: String?
    var createdAt: Int64?
    var updatedAt: Int64?
    var submittedAt: Int64?
    var approvedAt: Int64?
    var activatedAt: Int64?
    var completedAt: Int64?
    var cancelledAt: Int64?

    var id: String { _id ?? dealReference ?? UUID().uuidString }
    var poStatus: DealMemoStatus { DealMemoStatus(rawValue: status ?? "") ?? .draft }

    enum CodingKeys: String, CodingKey {
        case _id, status, rates, approvals
        case dealReference   = "deal_reference"
        case projectId       = "project_id"
        case userId          = "user_id"
        case departmentId    = "department_id"
        case designationId   = "designation_id"
        case crewDetails     = "crew_details"
        case rejectionReason = "rejection_reason"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        case submittedAt     = "submitted_at"
        case approvedAt      = "approved_at"
        case activatedAt     = "activated_at"
        case completedAt     = "completed_at"
        case cancelledAt     = "cancelled_at"
    }
}

// MARK: - Overview response

struct DealMemoOverviewStats: Codable, Equatable {
    var total: Int?
    var draft: Int?
    var awaitingApproval: Int?
    var approved: Int?
    var active: Int?
    var rejected: Int?
    var completed: Int?
    var cancelled: Int?
    var totalValue: Double?

    enum CodingKeys: String, CodingKey {
        case total, draft, approved, active, rejected, completed, cancelled
        case awaitingApproval = "awaiting_approval"
        case totalValue       = "total_value"
    }
}

struct DealMemoDeptBreakdown: Codable, Equatable, Identifiable {
    var department: String?
    var count: Int?
    var id: String { department ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey { case department, count }
}

struct DealMemoOverviewResponse: Codable, Equatable {
    var stats: DealMemoOverviewStats?
    var recent: [DealMemo]?
    var departmentBreakdown: [DealMemoDeptBreakdown]?

    enum CodingKeys: String, CodingKey {
        case stats, recent
        case departmentBreakdown = "department_breakdown"
    }
}

// MARK: - Approval queue response

struct DealMemoApprovalBuckets: Codable, Equatable {
    var pending: [DealMemo]?
    var approved: [DealMemo]?
    var rejected: [DealMemo]?
}

struct DealMemoApprovalTotals: Codable, Equatable {
    var pending: Int?
    var approved: Int?
    var rejected: Int?
}

struct DealMemoApprovalQueueResponse: Codable, Equatable {
    var data: DealMemoApprovalBuckets?
    var totals: DealMemoApprovalTotals?
}

// MARK: - Metadata response (gates approval-queue tab)

struct DealMemoMetadata: Codable, Equatable {
    var isApprover: Bool?
    var approverDepartmentIds: [String]?
    var approvalTierConfigs: [ApprovalTierConfig]?

    enum CodingKeys: String, CodingKey {
        case isApprover            = "is_approver"
        case approverDepartmentIds = "approver_department_ids"
        case approvalTierConfigs   = "approval_tier_configs"
    }
}

// MARK: - History entry

struct DealMemoHistoryEntry: Codable, Equatable, Identifiable {
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
