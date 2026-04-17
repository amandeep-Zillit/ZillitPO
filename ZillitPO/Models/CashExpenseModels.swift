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
struct FloatHistoryEntry: Decodable, Identifiable {
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        action   = try? c.decode(String.self, forKey: .action)
        actionBy = try? c.decode(String.self, forKey: .actionBy)
        note     = try? c.decode(String.self, forKey: .note)
        if let v = try? c.decode(Int64.self,  forKey: .actionAt)      { actionAt = v }
        else if let v = try? c.decode(Double.self, forKey: .actionAt) { actionAt = Int64(v) }
        else if let s = try? c.decode(String.self, forKey: .actionAt), let v = Int64(s) { actionAt = v }
        else { actionAt = nil }
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
    var requireSeniorSignOff: Bool?
    var viewDepartmentFloats: Bool?
    var codingRequired: Bool?

    enum CodingKeys: String, CodingKey {
        case isApprover = "is_approver"
        case approverDepartmentIds = "approver_department_ids"
        case isCoordinator = "is_coordinator"
        case coordinatorDepartmentIds = "coordinator_department_ids"
        case isTeamMember = "is_team_member"
        case isSenior = "is_senior"
        case canOverride = "can_override"
        case requireSeniorSignOff = "require_senior_sign_off"
        case viewDepartmentFloats = "view_department_floats"
        case codingRequired = "coding_required"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isApprover = try? c.decode(Bool.self, forKey: .isApprover)
        approverDepartmentIds = try? c.decode([String].self, forKey: .approverDepartmentIds)
        isCoordinator = try? c.decode(Bool.self, forKey: .isCoordinator)
        coordinatorDepartmentIds = try? c.decode([String].self, forKey: .coordinatorDepartmentIds)
        isTeamMember = try? c.decode(Bool.self, forKey: .isTeamMember)
        isSenior = try? c.decode(Bool.self, forKey: .isSenior)
        canOverride = try? c.decode(Bool.self, forKey: .canOverride)
        requireSeniorSignOff = try? c.decode(Bool.self, forKey: .requireSeniorSignOff)
        viewDepartmentFloats = try? c.decode(Bool.self, forKey: .viewDepartmentFloats)
        codingRequired = try? c.decode(Bool.self, forKey: .codingRequired)
    }
}

// MARK: - Float Request

struct FloatRequest: Identifiable, Equatable {
    var id: String = UUID().uuidString
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
    var department: String?
    var createdAt: Int64?
    var updatedAt: Int64?
    static func == (lhs: FloatRequest, rhs: FloatRequest) -> Bool { lhs.id == rhs.id }

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
    /// Aligned with backend workflow: Awaiting → Approved → Ready to Collect →
    /// Collected → Spending → Spent → Pending Return → Closed/Cancelled.
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
}

struct FloatRequestRaw: Codable {
    var id: String
    var userId: String?; var departmentId: String?
    var reqNumber: String?; var reqAmount: String?; var issuedFloat: String?
    var receiptsAmount: String?; var returnAmount: String?; var duration: String?
    /// Running "spent" total — backend column `spent`.
    var spent: String?
    /// Authoritative remaining balance — backend column `balance`.
    var balance: String?
    var costCode: String?; var startDate: String?; var purpose: String?
    var collectionMethod: String?; var status: String?
    var approvals: [CashApprovalRaw]?
    var rejectionReason: String?; var rejectedBy: String?
    var createdAt: String?; var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, duration, purpose, status, approvals, spent, balance
        case userId = "user_id"
        case departmentId = "department_id"
        case reqNumber = "req_number"
        case reqAmount = "req_amount"
        case issuedFloat = "issued_float"
        case receiptsAmount = "receipts_amount"
        case returnAmount = "return_amount"
        case costCode = "cost_code"
        case startDate = "start_date"
        case collectionMethod = "collection_method"
        case rejectionReason = "rejection_reason"
        case rejectedBy = "rejected_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try? c.decode(String.self, forKey: .userId)
        departmentId = try? c.decode(String.self, forKey: .departmentId)
        reqNumber = try? c.decode(String.self, forKey: .reqNumber)
        reqAmount = try? c.decode(String.self, forKey: .reqAmount)
        issuedFloat = try? c.decode(String.self, forKey: .issuedFloat)
        receiptsAmount = try? c.decode(String.self, forKey: .receiptsAmount)
        returnAmount = try? c.decode(String.self, forKey: .returnAmount)
        // Numeric Postgres columns can arrive as either String or Number in
        // JSON depending on driver / serializer. Accept both so we don't
        // silently lose the value and fall back to 0.
        if let s = try? c.decode(String.self, forKey: .spent) { spent = s }
        else if let d = try? c.decode(Double.self, forKey: .spent) { spent = String(d) }
        if let s = try? c.decode(String.self, forKey: .balance) { balance = s }
        else if let d = try? c.decode(Double.self, forKey: .balance) { balance = String(d) }
        duration = try? c.decode(String.self, forKey: .duration)
        costCode = try? c.decode(String.self, forKey: .costCode)
        startDate = try? c.decode(String.self, forKey: .startDate)
        purpose = try? c.decode(String.self, forKey: .purpose)
        collectionMethod = try? c.decode(String.self, forKey: .collectionMethod)
        status = try? c.decode(String.self, forKey: .status)
        approvals = try? c.decode([CashApprovalRaw].self, forKey: .approvals)
        rejectionReason = try? c.decode(String.self, forKey: .rejectionReason)
        rejectedBy = try? c.decode(String.self, forKey: .rejectedBy)
        createdAt = try? c.decode(String.self, forKey: .createdAt)
        updatedAt = try? c.decode(String.self, forKey: .updatedAt)
    }

    func toFloatRequest() -> FloatRequest {
        let dept = DepartmentsData.all.first { $0.id == (departmentId ?? "") }
        var f = FloatRequest()
        f.id = id; f.userId = userId ?? ""; f.departmentId = departmentId ?? ""
        f.reqNumber = reqNumber ?? ""; f.reqAmount = Double(reqAmount ?? "") ?? 0
        f.issuedFloat = Double(issuedFloat ?? "") ?? 0
        f.receiptsAmount = Double(receiptsAmount ?? "") ?? 0
        f.returnAmount = Double(returnAmount ?? "") ?? 0
        // Backend-authoritative running totals. Fall back to legacy
        // values when not present (older list endpoints) so we still
        // render something sensible.
        f.spent = Double(spent ?? "") ?? f.receiptsAmount
        // Keep `balance` nil when the server didn't send it, so the
        // `remaining` computed var falls back to the derivation.
        f.balance = (balance?.isEmpty == false) ? Double(balance!) : nil
        f.duration = duration ?? ""; f.costCode = costCode ?? ""
        f.startDate = Int64(startDate ?? ""); f.purpose = purpose ?? ""
        f.collectionMethod = collectionMethod ?? ""; f.status = status ?? ""
        f.approvals = (approvals ?? []).map {
            Approval(userId: $0.userId ?? "", tierNumber: $0.tierNumber ?? 0, approvedAt: Int64($0.approvedAt ?? 0))
        }
        f.rejectionReason = rejectionReason; f.rejectedBy = rejectedBy
        f.department = dept?.displayName ?? ""
        f.createdAt = Int64(createdAt ?? "") ?? 0; f.updatedAt = Int64(updatedAt ?? "") ?? 0
        return f
    }
}

struct CashApprovalRaw: Codable {
    var userId: String?
    var tierNumber: Int?
    var approvedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tierNumber = "tier_number"
        case approvedAt = "approved_at"
    }
}

// MARK: - Claim Batch

struct ClaimBatch: Identifiable, Equatable {
    var id: String = UUID().uuidString
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
    var department: String?
    var rejectionReason: String?
    var rejectedBy: String?
    var escalationReason: String?
    var assignedTo: String?
    var postedBy: String?
    var postedAt: Int64?
    var createdAt: Int64?
    var updatedAt: Int64?
    /// Extra follow-up action stored under `settlement_details.follow_up`
    /// — typically "top_up" (reimburse back into float) or "close" (close
    /// the float after this batch posts). Used by the detail view's
    /// "Follow-up" column.
    var followUp: String?
    /// Tier approvals accumulated on this batch. Populated by the detail
    /// fetch (`GET /claims/{id}`) and used by the Approval Progress panel
    /// to render one entry per approver (name + Level N badge).
    var approvals: [Approval] = []
    static func == (lhs: ClaimBatch, rhs: ClaimBatch) -> Bool { lhs.id == rhs.id }

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
}

struct ClaimBatchRaw: Codable {
    var id: String
    var batchId: String?
    var batchReference: String?; var userId: String?; var departmentId: String?
    var expenseType: String?; var floatRequestId: String?; var settlementType: String?
    var status: String?; var totalGross: String?; var totalNet: String?; var totalVat: String?
    var claimCount: Int?; var notes: String?
    var category: String?; var costCode: String?; var codingDescription: String?
    var rejectionReason: String?; var rejectedBy: String?
    var escalationReason: String?; var assignedTo: String?
    var postedBy: String?; var postedAt: String?
    var createdAt: String?; var updatedAt: String?

    /// `settlement_details` is a nested JSON object. We only need
    /// `follow_up` out of it, so decode into this tiny struct.
    struct SettlementDetails: Codable {
        var followUp: String?
        enum CodingKeys: String, CodingKey {
            case followUp = "follow_up"
        }
    }
    var settlementDetails: SettlementDetails?
    /// Present on `GET /claims/{id}` — array of `{ user_id, tier_number,
    /// approved_at }` entries, one per tier approval so far. List views
    /// don't receive this; only the detail fetch does.
    var approvals: [CashApprovalRaw]?

    enum CodingKeys: String, CodingKey {
        case id, status, notes, category, approvals
        case batchId = "batch_id"
        case batchReference = "batch_reference"
        case userId = "user_id"
        case departmentId = "department_id"
        case expenseType = "expense_type"
        case floatRequestId = "float_request_id"
        case settlementType = "settlement_type"
        case totalGross = "total_gross"
        case totalNet = "total_net"
        case totalVat = "total_vat"
        case claimCount = "claim_count"
        case costCode = "cost_code"
        case codingDescription = "coding_description"
        case rejectionReason = "rejection_reason"
        case rejectedBy = "rejected_by"
        case escalationReason = "escalation_reason"
        case assignedTo = "assigned_to"
        case postedBy = "posted_by"
        case postedAt = "posted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case settlementDetails = "settlement_details"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        batchId = try? c.decode(String.self, forKey: .batchId)
        batchReference = try? c.decode(String.self, forKey: .batchReference)
        userId = try? c.decode(String.self, forKey: .userId)
        departmentId = try? c.decode(String.self, forKey: .departmentId)
        expenseType = try? c.decode(String.self, forKey: .expenseType)
        floatRequestId = try? c.decode(String.self, forKey: .floatRequestId)
        settlementType = try? c.decode(String.self, forKey: .settlementType)
        status = try? c.decode(String.self, forKey: .status)
        totalGross = try? c.decode(String.self, forKey: .totalGross)
        totalNet = try? c.decode(String.self, forKey: .totalNet)
        totalVat = try? c.decode(String.self, forKey: .totalVat)
        claimCount = try? c.decode(Int.self, forKey: .claimCount)
        notes = try? c.decode(String.self, forKey: .notes)
        category = try? c.decode(String.self, forKey: .category)
        costCode = try? c.decode(String.self, forKey: .costCode)
        codingDescription = try? c.decode(String.self, forKey: .codingDescription)
        rejectionReason = try? c.decode(String.self, forKey: .rejectionReason)
        rejectedBy = try? c.decode(String.self, forKey: .rejectedBy)
        escalationReason = try? c.decode(String.self, forKey: .escalationReason)
        assignedTo = try? c.decode(String.self, forKey: .assignedTo)
        postedBy = try? c.decode(String.self, forKey: .postedBy)
        postedAt = try? c.decode(String.self, forKey: .postedAt)
        createdAt = try? c.decode(String.self, forKey: .createdAt)
        updatedAt = try? c.decode(String.self, forKey: .updatedAt)
        settlementDetails = try? c.decode(SettlementDetails.self, forKey: .settlementDetails)
        // `approvals` may arrive as a parsed array OR as a JSON string the
        // server forgot to parse. Try both, fall back to empty.
        if let direct = try? c.decode([CashApprovalRaw].self, forKey: .approvals) {
            approvals = direct
        } else if let str = try? c.decode(String.self, forKey: .approvals),
                  let data = str.data(using: .utf8),
                  let parsed = try? JSONDecoder().decode([CashApprovalRaw].self, from: data) {
            approvals = parsed
        }
    }

    func toClaimBatch() -> ClaimBatch {
        let dept = DepartmentsData.all.first { $0.id == (departmentId ?? "") }
        var cb = ClaimBatch()
        cb.id = id
        // `/claims/my-claims` returns claim-item rows with the parent `batch_id`
        // joined in — use that for batch-scoped calls. For `/claims` the
        // response already IS a batch, so `batch_id` is absent and we fall
        // back to `id`.
        cb.batchId = (batchId?.isEmpty == false ? batchId! : id)
        cb.batchReference = batchReference ?? ""
        cb.userId = userId ?? ""; cb.departmentId = departmentId ?? ""
        cb.expenseType = expenseType ?? ""; cb.floatRequestId = floatRequestId
        cb.settlementType = settlementType ?? ""; cb.status = status ?? ""
        cb.totalGross = Double(totalGross ?? "") ?? 0
        cb.totalNet = Double(totalNet ?? "") ?? 0
        cb.totalVat = Double(totalVat ?? "") ?? 0
        cb.claimCount = claimCount ?? 0; cb.notes = notes ?? ""
        cb.category = category ?? ""; cb.costCode = costCode ?? ""; cb.codingDescription = codingDescription ?? ""
        cb.department = dept?.displayName ?? ""
        cb.rejectionReason = rejectionReason; cb.rejectedBy = rejectedBy
        cb.escalationReason = escalationReason; cb.assignedTo = assignedTo
        cb.postedBy = postedBy; cb.postedAt = postedAt.flatMap { Int64($0) }
        cb.createdAt = Int64(createdAt ?? "") ?? 0; cb.updatedAt = Int64(updatedAt ?? "") ?? 0
        cb.followUp = settlementDetails?.followUp ?? ""
        cb.approvals = (approvals ?? []).map {
            Approval(userId: $0.userId ?? "",
                     tierNumber: $0.tierNumber ?? 0,
                     approvedAt: Int64($0.approvedAt ?? 0))
        }
        return cb
    }
}

// MARK: - Payment Routing Response

struct PaymentRoutingResponse: Decodable {
    var stats: PaymentRoutingStats?
    var bacsBatches: [PaymentRoutingBatch]?
    var payrollBatches: [PaymentRoutingBatch]?

    enum CodingKeys: String, CodingKey {
        case stats
        case bacsBatches    = "bacs_batches"
        case payrollBatches = "payroll_batches"
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stats          = try? c.decode(PaymentRoutingStats.self,   forKey: .stats)
        bacsBatches    = try? c.decode([PaymentRoutingBatch].self, forKey: .bacsBatches)
        payrollBatches = try? c.decode([PaymentRoutingBatch].self, forKey: .payrollBatches)
    }
}

struct PaymentRoutingStats: Decodable {
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

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func dbl(_ k: CodingKeys) -> Double? {
            if let d = try? c.decode(Double.self, forKey: k) { return d }
            if let s = try? c.decode(String.self, forKey: k), let d = Double(s) { return d }
            return nil
        }
        bacsReady    = dbl(.bacsReady)
        bacsCount    = try? c.decode(Int.self, forKey: .bacsCount)
        payrollTotal = dbl(.payrollTotal)
        payrollCount = try? c.decode(Int.self, forKey: .payrollCount)
    }
}

struct PaymentRoutingBatch: Identifiable, Decodable {
    var id: String = UUID().uuidString
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

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func dbl(_ k: CodingKeys) -> Double? {
            if let d = try? c.decode(Double.self, forKey: k) { return d }
            if let s = try? c.decode(String.self, forKey: k), let d = Double(s) { return d }
            return nil
        }
        id                  = (try? c.decode(String.self, forKey: .id))             ?? UUID().uuidString
        userId              = try? c.decode(String.self, forKey: .userId)
        batchReference      = try? c.decode(String.self, forKey: .batchReference)
        totalGross          = dbl(.totalGross)
        totalNet            = dbl(.totalNet)
        totalVat            = dbl(.totalVat)
        reimbursementAmount = dbl(.reimbursementAmount)
        settlementType      = try? c.decode(String.self, forKey: .settlementType)
        settlementDetails   = try? c.decode(RoutingSettlementDetails.self, forKey: .settlementDetails)
        status              = try? c.decode(String.self, forKey: .status)
        claimCount          = try? c.decode(Int.self,    forKey: .claimCount)
        if let i = try? c.decode(Int64.self, forKey: .postedAt)                 { postedAt = i }
        else if let s = try? c.decode(String.self, forKey: .postedAt),
                let i = Int64(s)                                                 { postedAt = i }
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

struct RoutingSettlementDetails: Decodable {
    var bankDetails: RoutingBankDetails?
    var paymentMethod: String?

    enum CodingKeys: String, CodingKey {
        case bankDetails   = "bank_details"
        case paymentMethod = "payment_method"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bankDetails   = try? c.decode(RoutingBankDetails.self, forKey: .bankDetails)
        paymentMethod = try? c.decode(String.self, forKey: .paymentMethod)
    }
}

struct RoutingBankDetails: Decodable {
    var sortCode: String?
    var accountName: String?
    var accountNumber: String?

    enum CodingKeys: String, CodingKey {
        case sortCode      = "sort_code"
        case accountName   = "account_name"
        case accountNumber = "account_number"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sortCode      = try? c.decode(String.self, forKey: .sortCode)
        accountName   = try? c.decode(String.self, forKey: .accountName)
        accountNumber = try? c.decode(String.self, forKey: .accountNumber)
    }
}

// MARK: - Float Details (full breakdown from /float-requests/{id}/details)

struct FloatTopUpEntry: Decodable {
    var id: String?
    var amount: Double?
    var issuedAmount: Double?
    var status: String?
    var note: String?
    var createdAt: Int64?

    struct Keys: CodingKey { let stringValue: String; var intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue } }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        func str(_ keys: String...) -> String? {
            for k in keys { guard let key = Keys(stringValue: k) else { continue }
                if let v = try? c.decode(String.self, forKey: key), !v.isEmpty { return v }
                if let v = try? c.decode(Int64.self, forKey: key) { return String(v) }
                if let v = try? c.decode(Double.self, forKey: key) { return String(v) }
            }
            return nil
        }
        func dbl(_ keys: String...) -> Double? {
            for k in keys { guard let key = Keys(stringValue: k) else { continue }
                if let v = try? c.decode(Double.self, forKey: key) { return v }
                if let s = try? c.decode(String.self, forKey: key), let v = Double(s) { return v } }
            return nil
        }
        id           = str("id")
        amount       = dbl("amount")
        issuedAmount = dbl("issued_amount", "issuedAmount") ?? amount
        status       = str("status")
        note         = str("note")
        if let s = str("created_at", "createdAt"), let v = Int64(s) { createdAt = v }
    }
}

struct FloatReturnEntry: Decodable {
    var id: String?
    var returnAmount: Double?
    var returnReason: String?
    var reasonNotes: String?
    var notes: String?
    var receivedDate: Int64?
    var recordedAt: Int64?
    var recordedBy: String?

    struct Keys: CodingKey { let stringValue: String; var intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue } }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        func str(_ keys: String...) -> String? {
            for k in keys { guard let key = Keys(stringValue: k) else { continue }
                if let v = try? c.decode(String.self, forKey: key), !v.isEmpty { return v }
                if let v = try? c.decode(Int64.self, forKey: key) { return String(v) }
                if let v = try? c.decode(Double.self, forKey: key) { return String(v) }
            }
            return nil
        }
        func dbl(_ keys: String...) -> Double? {
            for k in keys { guard let key = Keys(stringValue: k) else { continue }
                if let v = try? c.decode(Double.self, forKey: key) { return v }
                if let s = try? c.decode(String.self, forKey: key), let v = Double(s) { return v } }
            return nil
        }
        id           = str("id")
        returnAmount = dbl("return_amount", "returnAmount")
        returnReason = str("return_reason", "returnReason")
        reasonNotes  = str("reason_notes", "reasonNotes")
        notes        = str("notes")
        if let s = str("received_date", "receivedDate"), let v = Int64(s) { receivedDate = v }
        if let s = str("recorded_at", "recordedAt"), let v = Int64(s) { recordedAt = v }
        recordedBy   = str("recorded_by", "recordedBy")
    }
}

struct FloatTotals: Decodable {
    var issued: Double?
    var spent: Double?
    var toppedUp: Double?
    var finalBalance: Double?
    var returned: Double?
    var receiptsAmount: Double?
    var requested: Double?

    init() {}

    enum CodingKeys: String, CodingKey {
        case issued, spent, returned, requested
        case toppedUp = "topped_up"
        case finalBalance = "final_balance"
        case receiptsAmount = "receipts_amount"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func dbl(_ k: CodingKeys) -> Double? {
            if let v = try? c.decode(Double.self, forKey: k) { return v }
            if let s = try? c.decode(String.self, forKey: k), let v = Double(s) { return v }
            return nil
        }
        issued = dbl(.issued); spent = dbl(.spent); toppedUp = dbl(.toppedUp)
        finalBalance = dbl(.finalBalance); returned = dbl(.returned)
        receiptsAmount = dbl(.receiptsAmount); requested = dbl(.requested)
    }
}

struct FloatDetailsResponse: Decodable {
    var float: FloatRequestRaw?
    var batches: [ClaimBatchRaw]?
    var topups: [FloatTopUpEntry]?
    var returns: [FloatReturnEntry]?
    var totals: FloatTotals?

    enum CodingKeys: String, CodingKey { case float, batches, topups, returns, totals }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        float   = try? c.decode(FloatRequestRaw.self, forKey: .float)
        batches = try? c.decode([ClaimBatchRaw].self, forKey: .batches)
        topups  = try? c.decode([FloatTopUpEntry].self, forKey: .topups)
        returns = try? c.decode([FloatReturnEntry].self, forKey: .returns)
        totals  = try? c.decode(FloatTotals.self, forKey: .totals)
    }
}

// MARK: - Claim item (one receipt inside a batch)

/// A single claim row inside a batch. Populated from the `claims` array
/// returned by `GET /api/v2/cash-expenses/claims/{batchId}`.
struct ClaimItem: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var itemDescription: String = ""
    var category: String = ""
    var amount: Double = 0
    var date: Int64 = 0
    var receiptUrl: String?
    var nominalCode: String?
    var status: String = ""
    var notes: String = ""

    static func == (lhs: ClaimItem, rhs: ClaimItem) -> Bool { lhs.id == rhs.id }
}

struct ClaimItemRaw: Decodable {
    var id: String
    var itemDescription: String?
    var category: String?
    var amount: String?
    var date: String?
    var receiptUrl: String?
    var nominalCode: String?
    var status: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, category, amount, date, status, notes
        case itemDescription = "description"
        case receiptUrl      = "receipt_url"
        case nominalCode     = "nominal_code"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        itemDescription = try? c.decode(String.self, forKey: .itemDescription)
        category        = try? c.decode(String.self, forKey: .category)
        date            = try? c.decode(String.self, forKey: .date)
        status          = try? c.decode(String.self, forKey: .status)
        notes           = try? c.decode(String.self, forKey: .notes)
        receiptUrl      = try? c.decode(String.self, forKey: .receiptUrl)
        nominalCode     = try? c.decode(String.self, forKey: .nominalCode)
        // amount may arrive as Double or String depending on the endpoint.
        if let d = try? c.decode(Double.self, forKey: .amount) { amount = String(d) }
        else { amount = try? c.decode(String.self, forKey: .amount) }
    }

    func toClaimItem() -> ClaimItem {
        var item = ClaimItem()
        item.id = id
        item.itemDescription = itemDescription ?? ""
        item.category = category ?? ""
        item.amount = Double(amount ?? "") ?? 0
        item.date = Int64(date ?? "") ?? 0
        item.receiptUrl = receiptUrl
        item.nominalCode = nominalCode
        item.status = status ?? ""
        item.notes = notes ?? ""
        return item
    }
}

/// Response envelope for `GET /api/v2/cash-expenses/claims/{batchId}` —
/// the full batch record with its claims array embedded. Mirrors the
/// React reference's `getExpenseClaimBatch(batch.id)` response shape.
struct ClaimBatchDetailRaw: Decodable {
    var batch: ClaimBatchRaw
    var claims: [ClaimItemRaw]

    init(from decoder: Decoder) throws {
        // The server returns the batch record at the top level with a
        // `claims` array tacked on. Decode the batch normally, then pull
        // claims out of a secondary container.
        batch = try ClaimBatchRaw(from: decoder)
        if let nested = try? decoder.container(keyedBy: ClaimsKey.self) {
            claims = (try? nested.decode([ClaimItemRaw].self, forKey: .claims)) ?? []
        } else {
            claims = []
        }
    }

    private enum ClaimsKey: String, CodingKey { case claims }
}
