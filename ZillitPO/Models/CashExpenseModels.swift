//
//  CashExpenseModels.swift
//  ZillitPO
//

import Foundation

// MARK: - Float History Entry
/// A single entry returned by GET /float-requests/{id}/history.
/// Each row is `{ action, action_by, action_at, note? }` where `action`
/// is a human-readable label the backend pre-formats (e.g.
/// "Float: AWAITING_APPROVAL" or "Batch #RB-0008: POSTED"), `action_at`
/// is epoch ms, and `note` carries any optional reason/rejection text.
struct FloatHistoryEntry: Codable, Identifiable {
    var id: String { "\(action ?? "")-\(actionAt ?? 0)-\(actionBy ?? "")" }
    var action: String?
    var actionBy: String?
    var actionAt: Int64?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case action
        case actionBy = "action_by"
        case actionAt = "action_at"
        case note
    }
}

// MARK: - Metadata

struct CashExpenseMetadata: Codable {
    var isApprover: Bool?
    var approverDepartmentIds: [String]?
    var isCoordinator: Bool?
    var coordinatorDepartmentIds: [String]?
    var isTeamMember: Bool?
    var isSenior: Bool?
    var canOverride: Bool?
    /// Module-level override toggle (Card Expenses). Set server-side —
    /// the web reference gates the Override button on BOTH this and
    /// `canOverride`:
    ///   `canOverrideCard = metadata.can_override && metadata.card_override`
    /// Missing this flag previously meant iOS showed the Override
    /// button in scenarios where the web would hide it.
    var cardOverride: Bool?
    /// Per-user cap on the gross value a team member can post. `null`
    /// = unlimited. Server uses this to gate batch posting.
    var postingLimit: Double?
    /// Approval-override toggles mirroring the web settings. Both flags
    /// ride alongside `canOverride` — the server sends them on the
    /// user-roles / metadata endpoint and the web uses them to
    /// differentiate receipt-level vs float-level overrides.
    var overrideReceiptBatch: Bool?
    var overrideFloatReq: Bool?
    var requireSeniorSignOff: Bool?
    var viewDepartmentFloats: Bool?
    var codingRequired: Bool?

    /// Convenience — matches the web's `canOverrideCard` derivation.
    /// Callers should prefer this over checking `canOverride` alone so
    /// iOS honours the server-side module gate.
    var canOverrideCards: Bool {
        (canOverride ?? false) && (cardOverride ?? false)
    }

    enum CodingKeys: String, CodingKey {
        case isApprover = "is_approver"
        case approverDepartmentIds = "approver_department_ids"
        case isCoordinator = "is_coordinator"
        case coordinatorDepartmentIds = "coordinator_department_ids"
        case isTeamMember = "is_team_member"
        case isSenior = "is_senior"
        case canOverride = "can_override"
        case cardOverride = "card_override"
        case postingLimit = "posting_limit"
        case overrideReceiptBatch = "override_receipt_batch"
        case overrideFloatReq = "override_float_req"
        case requireSeniorSignOff = "require_senior_sign_off"
        case viewDepartmentFloats = "view_department_floats"
        case codingRequired = "coding_required"
    }

}

// MARK: - Float Request

struct FloatRequest: Identifiable, Codable, Equatable {
    var id: String?
    var userId: String?
    var departmentId: String?
    var reqNumber: String?
    var reqAmount: Double?
    var issuedFloat: Double?
    var receiptsAmount: Double?
    var returnAmount: Double?
    /// Backend-authoritative "spent" running total — incremented when a
    /// posted batch reduces the float. We keep this as its own property
    /// (instead of deriving from receiptsAmount) because the backend tracks
    /// it independently and it's the value shown in the SPENT column.
    var spent: Double?
    /// Backend-authoritative remaining balance — the single source of
    /// truth. Optional so we can distinguish "server didn't send it"
    /// from "server said £0.00". When present (including 0), `remaining`
    /// returns this directly.
    var balance: Double?
    var duration: String?
    var costCode: String?
    var startDate: Int64?
    var purpose: String?
    var collectionMethod: String?
    var status: String?
    var approvals: [Approval]?
    var rejectionReason: String?
    var rejectedBy: String?
    var createdAt: Int64?
    var updatedAt: Int64?

    static func == (lhs: FloatRequest, rhs: FloatRequest) -> Bool { lhs.id == rhs.id }

    /// Department display name — resolved from DepartmentsData singleton.
    var department: String? { DepartmentsData.all.first { $0.id == (departmentId ?? "") }?.displayName }

    /// Remaining balance. Prefer the backend-authoritative `balance`
    /// column — it already accounts for top-ups, posted batches, and
    /// returns. Only derive client-side when the backend didn't send
    /// a `balance` field (legacy responses).
    var remaining: Double {
        if let b = balance { return b }
        return max(0, (issuedFloat ?? 0) - (receiptsAmount ?? 0) - (returnAmount ?? 0))
    }

    /// Total cash spent from this float (receipts posted against it).
    /// Priority:
    ///   1. Backend `spent` column (authoritative running total),
    ///   2. `receipts_amount` from legacy responses,
    ///   3. Derived: issued − balance − returned (mathematically
    ///      equivalent since the backend maintains
    ///      balance = issued − spent − returned).
    /// This covers the case where `spent` is 0 because the list endpoint
    /// doesn't populate it, but `balance` and `issuedFloat` are live.
    var spentTotal: Double {
        if (spent ?? 0) > 0.005 { return spent! }
        if (receiptsAmount ?? 0) > 0.005 { return receiptsAmount! }
        if let b = balance {
            return max(0, (issuedFloat ?? 0) - b - (returnAmount ?? 0))
        }
        return 0
    }

    // Status values (mirrors backend FloatRequestService STATUS enum):
    //   AWAITING_APPROVAL → APPROVED (all tiers) | REJECTED | ACCT_OVERRIDE
    //   APPROVED / ACCT_OVERRIDE → READY_TO_COLLECT → COLLECTED
    //   COLLECTED / ACTIVE / SPENDING / SPENT / PENDING_RETURN → CLOSED | CANCELLED
    var statusDisplay: String {
        switch status?.uppercased() ?? "" {
        case "AWAITING_APPROVAL":   return "Awaiting Approval"
        case "APPROVED":            return "Approved"
        case "ACCT_OVERRIDE":       return "Override Approved"
        case "REJECTED":            return "Rejected"
        case "READY_TO_COLLECT":    return "Ready to Collect"
        case "COLLECTED":           return "Collected"
        case "ACTIVE":              return "Active"
        case "SPENDING":            return "Spending"
        case "SPENT":               return "Spent"
        case "PENDING_RETURN":      return "Pending Return"
        case "CANCELLED":           return "Cancelled"
        case "CLOSED":              return "Closed"
        default: return (status ?? "").replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Short action-oriented guidance shown under or alongside the status badge.
    var statusSubtitle: String {
        switch status?.uppercased() ?? "" {
        case "AWAITING_APPROVAL":   return "Float request submitted — awaiting approval"
        case "APPROVED":            return "Float approved — awaiting cash preparation"
        case "ACCT_OVERRIDE":       return "Override approved — awaiting cash preparation"
        case "REJECTED":            return "Float rejected — see notes"
        case "READY_TO_COLLECT":    return "Cash ready — collect from the accountant"
        case "COLLECTED":           return "Cash collected — ready to spend"
        case "ACTIVE":              return "Float active — submit receipts against this float"
        case "SPENDING":            return "Spending in progress — submit receipts as you go"
        case "SPENT":               return "All cash spent — submit final receipts to close"
        case "PENDING_RETURN":      return "Awaiting physical cash return to accountant"
        case "CANCELLED":           return "Float cancelled"
        case "CLOSED":              return "Float closed"
        default: return ""
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, duration, purpose, status, approvals, spent, balance
        case userId           = "user_id"
        case departmentId     = "department_id"
        case reqNumber        = "req_number"
        case reqAmount        = "req_amount"
        case issuedFloat      = "issued_float"
        case receiptsAmount   = "receipts_amount"
        case returnAmount     = "return_amount"
        case costCode         = "cost_code"
        case startDate        = "start_date"
        case collectionMethod = "collection_method"
        case rejectionReason  = "rejection_reason"
        case rejectedBy       = "rejected_by"
        case createdAt        = "created_at"
        case updatedAt        = "updated_at"
    }
}

// MARK: - Claim Batch

struct ClaimBatch: Identifiable, Codable, Equatable {
    var id: String?
    /// Parent batch id. When the list came from `/claims/my-claims` (which
    /// returns individual claim-item rows joined with their batch), `id`
    /// holds the claim-item id and `batchId` holds the true batch id —
    /// required by batch-scoped endpoints like `/claims/{id}/history`.
    /// For rows that came from `/claims` directly, `batchId` equals `id`.
    var batchId: String?
    var batchReference: String?
    var userId: String?
    var departmentId: String?
    var expenseType: String?
    var floatRequestId: String?
    var settlementType: String?
    var status: String?
    var totalGross: Double?
    var totalNet: Double?
    var totalVat: Double?
    var claimCount: Int?
    var notes: String?
    var category: String?
    var costCode: String?
    var codingDescription: String?
    var rejectionReason: String?
    var rejectedBy: String?
    var escalationReason: String?
    var assignedTo: String?
    var postedBy: String?
    var postedAt: Int64?
    var createdAt: Int64?
    var updatedAt: Int64?
    /// Raw settlement details object decoded from `settlement_details`.
    /// The only field we surface downstream is `follow_up`, exposed via
    /// the `followUp` computed helper.
    var settlementDetails: SettlementDetails?
    /// Extra follow-up action stored under `settlement_details.follow_up`
    /// — typically "top_up" (reimburse back into float) or "close" (close
    /// the float after this batch posts).
    var followUp: String? { settlementDetails?.followUp }
    /// Tier approvals accumulated on this batch. Populated by the detail
    /// fetch (`GET /claims/{id}`) — the list fetch may omit it entirely
    /// (decoded as `nil`), which the Approval Progress panel treats the
    /// same as an empty array.
    var approvals: [Approval]?

    /// Effective batch id — falls back to `id` when the server didn't
    /// send a separate `batch_id` (i.e. when the row already IS a batch,
    /// not a joined claim-item). Callers hitting batch-scoped endpoints
    /// should prefer this over `batchId`.
    var effectiveBatchId: String { (batchId?.isEmpty == false ? batchId : nil) ?? id ?? "" }

    static func == (lhs: ClaimBatch, rhs: ClaimBatch) -> Bool { lhs.id == rhs.id }

    /// Department display name — resolved from DepartmentsData singleton.
    var department: String? { DepartmentsData.all.first { $0.id == (departmentId ?? "") }?.displayName }

    var isPettyCash: Bool { (expenseType ?? "").lowercased() == "pc" }
    var isOutOfPocket: Bool { (expenseType ?? "").lowercased() == "oop" }
    var statusDisplay: String {
        switch (status ?? "").uppercased() {
        case "CODING": return "Coding"
        case "CODED": return "Coded"
        case "IN_AUDIT": return "In Audit"
        case "AWAITING_APPROVAL": return "Awaiting Approval"
        case "APPROVED": return "Approved"
        case "READY_TO_POST": return "Ready to Post"
        case "POSTED": return "Posted"
        case "REJECTED": return "Rejected"
        case "ESCALATED": return "Escalated"
        case "ACCT_OVERRIDE": return "Override"
        default: return (status ?? "").capitalized
        }
    }

    /// Nested struct for `settlement_details` — we only need `follow_up`.
    struct SettlementDetails: Codable, Equatable {
        var followUp: String?
        enum CodingKeys: String, CodingKey { case followUp = "follow_up" }
    }

    enum CodingKeys: String, CodingKey {
        case id, status, notes, category, approvals
        case batchId          = "batch_id"
        case batchReference   = "batch_reference"
        case userId           = "user_id"
        case departmentId     = "department_id"
        case expenseType      = "expense_type"
        case floatRequestId   = "float_request_id"
        case settlementType   = "settlement_type"
        case totalGross       = "total_gross"
        case totalNet         = "total_net"
        case totalVat         = "total_vat"
        case claimCount       = "claim_count"
        case costCode         = "cost_code"
        case codingDescription = "coding_description"
        case rejectionReason  = "rejection_reason"
        case rejectedBy       = "rejected_by"
        case escalationReason = "escalation_reason"
        case assignedTo       = "assigned_to"
        case postedBy         = "posted_by"
        case postedAt         = "posted_at"
        case createdAt        = "created_at"
        case updatedAt        = "updated_at"
        case settlementDetails = "settlement_details"
    }
}

// MARK: - Payment Routing Response

struct PaymentRoutingResponse: Codable {
    var stats: PaymentRoutingStats?
    var bacsBatches: [PaymentRoutingBatch]?
    var payrollBatches: [PaymentRoutingBatch]?

    enum CodingKeys: String, CodingKey {
        case stats
        case bacsBatches    = "bacs_batches"
        case payrollBatches = "payroll_batches"
    }
}

struct PaymentRoutingStats: Codable {
    var bacsReady: Double?
    var bacsCount: Int?
    var payrollTotal: Double?
    var payrollCount: Int?

    enum CodingKeys: String, CodingKey {
        case bacsReady    = "bacs_ready"
        case bacsCount    = "bacs_count"
        case payrollTotal = "payroll_total"
        case payrollCount = "payroll_count"
    }
}

struct PaymentRoutingBatch: Identifiable, Codable {
    var id: String?
    var userId: String?
    var batchReference: String?
    var totalGross: Double?
    var totalNet: Double?
    var totalVat: Double?
    /// Server-computed reimbursement amount (net of VAT recovered, etc).
    /// When present, prefer this over `totalGross` for display — mirrors the
    /// React reference's `b.reimbursement_amount ?? b.total_gross` fallback.
    var reimbursementAmount: Double?
    var settlementType: String?
    var settlementDetails: RoutingSettlementDetails?
    var status: String?
    var claimCount: Int?
    var postedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, status
        case userId              = "user_id"
        case batchReference      = "batch_reference"
        case totalGross          = "total_gross"
        case totalNet            = "total_net"
        case totalVat            = "total_vat"
        case reimbursementAmount = "reimbursement_amount"
        case settlementType      = "settlement_type"
        case settlementDetails   = "settlement_details"
        case claimCount          = "claim_count"
        case postedAt            = "posted_at"
    }

    var holderName: String { UsersData.byId[userId ?? ""]?.fullName ?? userId ?? "" }

    /// Matches React's `b.reimbursement_amount ?? b.total_gross ?? 0`.
    var displayAmount: Double { reimbursementAmount ?? totalGross ?? 0 }

    /// "••••1234" for the payee's bank account, or empty if the batch has no
    /// bank details (BACS rows include this; payroll rows don't).
    var bankLast4Display: String {
        guard let acct = settlementDetails?.bankDetails?.accountNumber, acct.count >= 4 else { return "" }
        return "••••\(acct.suffix(4))"
    }

    /// Initials used for the avatar circle on each row (e.g. "SA").
    var holderInitials: String {
        if let u = UsersData.byId[userId ?? ""] { return u.initials }
        let parts = holderName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "??" : letters.uppercased()
    }
}

struct RoutingSettlementDetails: Codable {
    var bankDetails: RoutingBankDetails?
    var paymentMethod: String?

    enum CodingKeys: String, CodingKey {
        case bankDetails   = "bank_details"
        case paymentMethod = "payment_method"
    }
}

struct RoutingBankDetails: Codable {
    var sortCode: String?
    var accountName: String?
    var accountNumber: String?

    enum CodingKeys: String, CodingKey {
        case sortCode      = "sort_code"
        case accountName   = "account_name"
        case accountNumber = "account_number"
    }
}

// MARK: - Float Details (full breakdown from /float-requests/{id}/details)

struct FloatTopUpEntry: Codable {
    var id: String?
    var amount: Double?
    /// Server-issued amount after accountant override. Callers that want
    /// a fallback to the requested `amount` when this column is null
    /// should use `entry.issuedAmount ?? entry.amount` at the call site.
    var issuedAmount: Double?
    var status: String?
    var note: String?
    var createdAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, amount, status, note
        case issuedAmount = "issued_amount"
        case createdAt    = "created_at"
    }
}

struct FloatReturnEntry: Codable {
    var id: String?
    var returnAmount: Double?
    var returnReason: String?
    var reasonNotes: String?
    var notes: String?
    var receivedDate: Int64?
    var recordedAt: Int64?
    var recordedBy: String?

    enum CodingKeys: String, CodingKey {
        case id, notes
        case returnAmount = "return_amount"
        case returnReason = "return_reason"
        case reasonNotes  = "reason_notes"
        case receivedDate = "received_date"
        case recordedAt   = "recorded_at"
        case recordedBy   = "recorded_by"
    }

}

struct FloatTotals: Codable {
    var issued: Double?
    var spent: Double?
    var toppedUp: Double?
    var finalBalance: Double?
    var returned: Double?
    var receiptsAmount: Double?
    var requested: Double?

    enum CodingKeys: String, CodingKey {
        case issued, spent, returned, requested
        case toppedUp       = "topped_up"
        case finalBalance   = "final_balance"
        case receiptsAmount = "receipts_amount"
    }
}

struct FloatDetailsResponse: Codable {
    var float: FloatRequest?
    var batches: [ClaimBatch]?
    var topups: [FloatTopUpEntry]?
    var returns: [FloatReturnEntry]?
    var totals: FloatTotals?

    enum CodingKeys: String, CodingKey { case float, batches, topups, returns, totals }

}

// MARK: - Claim Item (one receipt inside a batch)

/// A single claim row inside a batch. Populated from the `claims` array
/// returned by `GET /api/v2/cash-expenses/claims/{batchId}`.
struct ClaimItem: Identifiable, Codable, Equatable {
    var id: String?
    var itemDescription: String?
    var category: String?
    var amount: Double?
    var date: Int64?
    var receiptUrl: String?
    var nominalCode: String?
    var status: String?
    var notes: String?

    static func == (lhs: ClaimItem, rhs: ClaimItem) -> Bool { lhs.id == rhs.id }

    enum CodingKeys: String, CodingKey {
        case id, category, status, notes
        case itemDescription = "description"
        case amount          = "amount"
        case date            = "date"
        case receiptUrl      = "receipt_url"
        case nominalCode     = "nominal_code"
    }
}

