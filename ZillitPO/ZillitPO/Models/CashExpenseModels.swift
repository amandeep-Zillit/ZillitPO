//
//  CashExpenseModels.swift
//  ZillitPO
//

import Foundation

// MARK: - Metadata

struct CashExpenseMetadata: Codable {
    var is_approver: Bool?
    var approver_department_ids: [String]?
    var is_coordinator: Bool?
    var coordinator_department_ids: [String]?
    var is_team_member: Bool?
    var is_senior: Bool?
    var can_override: Bool?
    var require_senior_sign_off: Bool?
    var view_department_floats: Bool?
    var coding_required: Bool?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        is_approver = try? c.decode(Bool.self, forKey: .is_approver)
        approver_department_ids = try? c.decode([String].self, forKey: .approver_department_ids)
        is_coordinator = try? c.decode(Bool.self, forKey: .is_coordinator)
        coordinator_department_ids = try? c.decode([String].self, forKey: .coordinator_department_ids)
        is_team_member = try? c.decode(Bool.self, forKey: .is_team_member)
        is_senior = try? c.decode(Bool.self, forKey: .is_senior)
        can_override = try? c.decode(Bool.self, forKey: .can_override)
        require_senior_sign_off = try? c.decode(Bool.self, forKey: .require_senior_sign_off)
        view_department_floats = try? c.decode(Bool.self, forKey: .view_department_floats)
        coding_required = try? c.decode(Bool.self, forKey: .coding_required)
    }
    enum CodingKeys: String, CodingKey {
        case is_approver, approver_department_ids, is_coordinator, coordinator_department_ids
        case is_team_member, is_senior, can_override, require_senior_sign_off
        case view_department_floats, coding_required
    }
}

// MARK: - Float Request

struct FloatRequest: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var userId: String = ""
    var departmentId: String = ""
    var reqNumber: String = ""
    var reqAmount: Double = 0
    var issuedFloat: Double = 0
    var receiptsAmount: Double = 0
    var returnAmount: Double = 0
    var duration: String = ""
    var costCode: String = ""
    var startDate: Int64?
    var purpose: String = ""
    var collectionMethod: String = ""
    var status: String = "AWAITING_APPROVAL"
    var approvals: [Approval] = []
    var rejectionReason: String?
    var rejectedBy: String?
    var department: String = ""
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0
    static func == (lhs: FloatRequest, rhs: FloatRequest) -> Bool { lhs.id == rhs.id }

    var remaining: Double { issuedFloat - receiptsAmount - returnAmount }
    var statusDisplay: String {
        switch status.uppercased() {
        case "AWAITING_APPROVAL": return "Awaiting Approval"
        case "APPROVED": return "Approved"
        case "ACTIVE": return "Active"
        case "SPENDING": return "Spending"
        case "CLOSED": return "Closed"
        case "REJECTED": return "Rejected"
        default: return status.capitalized
        }
    }
}

struct FloatRequestRaw: Codable {
    var id: String
    var user_id: String?; var department_id: String?
    var req_number: String?; var req_amount: String?; var issued_float: String?
    var receipts_amount: String?; var return_amount: String?; var duration: String?
    var cost_code: String?; var start_date: String?; var purpose: String?
    var collection_method: String?; var status: String?
    var approvals: [CashApprovalRaw]?
    var rejection_reason: String?; var rejected_by: String?
    var created_at: String?; var updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, user_id, department_id, req_number, req_amount, issued_float
        case receipts_amount, return_amount, duration, cost_code, start_date
        case purpose, collection_method, status, approvals
        case rejection_reason, rejected_by, created_at, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        user_id = try? c.decode(String.self, forKey: .user_id)
        department_id = try? c.decode(String.self, forKey: .department_id)
        req_number = try? c.decode(String.self, forKey: .req_number)
        req_amount = try? c.decode(String.self, forKey: .req_amount)
        issued_float = try? c.decode(String.self, forKey: .issued_float)
        receipts_amount = try? c.decode(String.self, forKey: .receipts_amount)
        return_amount = try? c.decode(String.self, forKey: .return_amount)
        duration = try? c.decode(String.self, forKey: .duration)
        cost_code = try? c.decode(String.self, forKey: .cost_code)
        start_date = try? c.decode(String.self, forKey: .start_date)
        purpose = try? c.decode(String.self, forKey: .purpose)
        collection_method = try? c.decode(String.self, forKey: .collection_method)
        status = try? c.decode(String.self, forKey: .status)
        approvals = try? c.decode([CashApprovalRaw].self, forKey: .approvals)
        rejection_reason = try? c.decode(String.self, forKey: .rejection_reason)
        rejected_by = try? c.decode(String.self, forKey: .rejected_by)
        created_at = try? c.decode(String.self, forKey: .created_at)
        updated_at = try? c.decode(String.self, forKey: .updated_at)
    }

    func toFloatRequest() -> FloatRequest {
        let dept = DepartmentsData.all.first { $0.id == (department_id ?? "") }
        var f = FloatRequest()
        f.id = id; f.userId = user_id ?? ""; f.departmentId = department_id ?? ""
        f.reqNumber = req_number ?? ""; f.reqAmount = Double(req_amount ?? "") ?? 0
        f.issuedFloat = Double(issued_float ?? "") ?? 0
        f.receiptsAmount = Double(receipts_amount ?? "") ?? 0
        f.returnAmount = Double(return_amount ?? "") ?? 0
        f.duration = duration ?? ""; f.costCode = cost_code ?? ""
        f.startDate = Int64(start_date ?? ""); f.purpose = purpose ?? ""
        f.collectionMethod = collection_method ?? ""; f.status = status ?? ""
        f.approvals = (approvals ?? []).map {
            Approval(userId: $0.user_id ?? "", tierNumber: $0.tier_number ?? 0, approvedAt: Int64($0.approved_at ?? 0))
        }
        f.rejectionReason = rejection_reason; f.rejectedBy = rejected_by
        f.department = dept?.displayName ?? ""
        f.createdAt = Int64(created_at ?? "") ?? 0; f.updatedAt = Int64(updated_at ?? "") ?? 0
        return f
    }
}

struct CashApprovalRaw: Codable {
    var user_id: String?; var tier_number: Int?; var approved_at: Int64?
}

// MARK: - Claim Batch

struct ClaimBatch: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var batchReference: String = ""
    var userId: String = ""
    var departmentId: String = ""
    var expenseType: String = ""
    var floatRequestId: String?
    var settlementType: String = ""
    var status: String = ""
    var totalGross: Double = 0
    var totalNet: Double = 0
    var totalVat: Double = 0
    var claimCount: Int = 0
    var notes: String = ""
    var department: String = ""
    var rejectionReason: String?
    var rejectedBy: String?
    var escalationReason: String?
    var assignedTo: String?
    var postedBy: String?
    var postedAt: Int64?
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0
    static func == (lhs: ClaimBatch, rhs: ClaimBatch) -> Bool { lhs.id == rhs.id }

    var isPettyCash: Bool { expenseType.lowercased() == "pc" }
    var isOutOfPocket: Bool { expenseType.lowercased() == "oop" }
    var statusDisplay: String {
        switch status.uppercased() {
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
        default: return status.capitalized
        }
    }
}

struct ClaimBatchRaw: Codable {
    var id: String
    var batch_reference: String?; var user_id: String?; var department_id: String?
    var expense_type: String?; var float_request_id: String?; var settlement_type: String?
    var status: String?; var total_gross: String?; var total_net: String?; var total_vat: String?
    var claim_count: Int?; var notes: String?
    var rejection_reason: String?; var rejected_by: String?
    var escalation_reason: String?; var assigned_to: String?
    var posted_by: String?; var posted_at: String?
    var created_at: String?; var updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, batch_reference, user_id, department_id, expense_type, float_request_id
        case settlement_type, status, total_gross, total_net, total_vat, claim_count, notes
        case rejection_reason, rejected_by, escalation_reason, assigned_to
        case posted_by, posted_at, created_at, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        batch_reference = try? c.decode(String.self, forKey: .batch_reference)
        user_id = try? c.decode(String.self, forKey: .user_id)
        department_id = try? c.decode(String.self, forKey: .department_id)
        expense_type = try? c.decode(String.self, forKey: .expense_type)
        float_request_id = try? c.decode(String.self, forKey: .float_request_id)
        settlement_type = try? c.decode(String.self, forKey: .settlement_type)
        status = try? c.decode(String.self, forKey: .status)
        total_gross = try? c.decode(String.self, forKey: .total_gross)
        total_net = try? c.decode(String.self, forKey: .total_net)
        total_vat = try? c.decode(String.self, forKey: .total_vat)
        claim_count = try? c.decode(Int.self, forKey: .claim_count)
        notes = try? c.decode(String.self, forKey: .notes)
        rejection_reason = try? c.decode(String.self, forKey: .rejection_reason)
        rejected_by = try? c.decode(String.self, forKey: .rejected_by)
        escalation_reason = try? c.decode(String.self, forKey: .escalation_reason)
        assigned_to = try? c.decode(String.self, forKey: .assigned_to)
        posted_by = try? c.decode(String.self, forKey: .posted_by)
        posted_at = try? c.decode(String.self, forKey: .posted_at)
        created_at = try? c.decode(String.self, forKey: .created_at)
        updated_at = try? c.decode(String.self, forKey: .updated_at)
    }

    func toClaimBatch() -> ClaimBatch {
        let dept = DepartmentsData.all.first { $0.id == (department_id ?? "") }
        var cb = ClaimBatch()
        cb.id = id; cb.batchReference = batch_reference ?? ""
        cb.userId = user_id ?? ""; cb.departmentId = department_id ?? ""
        cb.expenseType = expense_type ?? ""; cb.floatRequestId = float_request_id
        cb.settlementType = settlement_type ?? ""; cb.status = status ?? ""
        cb.totalGross = Double(total_gross ?? "") ?? 0
        cb.totalNet = Double(total_net ?? "") ?? 0
        cb.totalVat = Double(total_vat ?? "") ?? 0
        cb.claimCount = claim_count ?? 0; cb.notes = notes ?? ""
        cb.department = dept?.displayName ?? ""
        cb.rejectionReason = rejection_reason; cb.rejectedBy = rejected_by
        cb.escalationReason = escalation_reason; cb.assignedTo = assigned_to
        cb.postedBy = posted_by; cb.postedAt = posted_at.flatMap { Int64($0) }
        cb.createdAt = Int64(created_at ?? "") ?? 0; cb.updatedAt = Int64(updated_at ?? "") ?? 0
        return cb
    }
}
