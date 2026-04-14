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
    // Status values (mirrors backend FloatRequestService STATUS enum):
    //   AWAITING_APPROVAL → APPROVED (all tiers) | REJECTED | ACCT_OVERRIDE
    //   APPROVED / ACCT_OVERRIDE → READY_TO_COLLECT → COLLECTED
    //   COLLECTED / ACTIVE / SPENDING / SPENT / PENDING_RETURN → CLOSED | CANCELLED
    var statusDisplay: String {
        switch status.uppercased() {
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
        default: return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Short action-oriented guidance shown under or alongside the status badge.
    /// Aligned with backend workflow: Awaiting → Approved → Ready to Collect →
    /// Collected → Spending → Spent → Pending Return → Closed/Cancelled.
    var statusSubtitle: String {
        switch status.uppercased() {
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
    var category: String = ""
    var costCode: String = ""
    var codingDescription: String = ""
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
    var category: String?; var cost_code: String?; var coding_description: String?
    var rejection_reason: String?; var rejected_by: String?
    var escalation_reason: String?; var assigned_to: String?
    var posted_by: String?; var posted_at: String?
    var created_at: String?; var updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, batch_reference, user_id, department_id, expense_type, float_request_id
        case settlement_type, status, total_gross, total_net, total_vat, claim_count, notes
        case category, cost_code, coding_description
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
        category = try? c.decode(String.self, forKey: .category)
        cost_code = try? c.decode(String.self, forKey: .cost_code)
        coding_description = try? c.decode(String.self, forKey: .coding_description)
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
        cb.category = category ?? ""; cb.costCode = cost_code ?? ""; cb.codingDescription = coding_description ?? ""
        cb.department = dept?.displayName ?? ""
        cb.rejectionReason = rejection_reason; cb.rejectedBy = rejected_by
        cb.escalationReason = escalation_reason; cb.assignedTo = assigned_to
        cb.postedBy = posted_by; cb.postedAt = posted_at.flatMap { Int64($0) }
        cb.createdAt = Int64(created_at ?? "") ?? 0; cb.updatedAt = Int64(updated_at ?? "") ?? 0
        return cb
    }
}

// MARK: - Payment Routing Response

struct PaymentRoutingResponse: Decodable {
    var stats: PaymentRoutingStats = PaymentRoutingStats()
    var bacsBatches: [PaymentRoutingBatch] = []
    var payrollBatches: [PaymentRoutingBatch] = []

    enum CodingKeys: String, CodingKey {
        case stats
        case bacsBatches    = "bacs_batches"
        case payrollBatches = "payroll_batches"
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stats         = (try? c.decode(PaymentRoutingStats.self,   forKey: .stats))         ?? PaymentRoutingStats()
        bacsBatches   = (try? c.decode([PaymentRoutingBatch].self, forKey: .bacsBatches))   ?? []
        payrollBatches = (try? c.decode([PaymentRoutingBatch].self, forKey: .payrollBatches)) ?? []
    }
}

struct PaymentRoutingStats: Decodable {
    var bacsReady: Double = 0
    var bacsCount: Int    = 0
    var payrollTotal: Double = 0
    var payrollCount: Int    = 0

    enum CodingKeys: String, CodingKey {
        case bacsReady    = "bacs_ready"
        case bacsCount    = "bacs_count"
        case payrollTotal = "payroll_total"
        case payrollCount = "payroll_count"
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func dbl(_ k: CodingKeys) -> Double {
            if let d = try? c.decode(Double.self, forKey: k) { return d }
            if let s = try? c.decode(String.self, forKey: k), let d = Double(s) { return d }
            return 0
        }
        bacsReady    = dbl(.bacsReady)
        bacsCount    = (try? c.decode(Int.self, forKey: .bacsCount))    ?? 0
        payrollTotal = dbl(.payrollTotal)
        payrollCount = (try? c.decode(Int.self, forKey: .payrollCount)) ?? 0
    }
}

struct PaymentRoutingBatch: Identifiable, Decodable {
    var id: String = UUID().uuidString
    var userId: String = ""
    var batchReference: String = ""
    var totalGross: Double = 0
    var totalNet: Double = 0
    var totalVat: Double = 0
    var settlementType: String = ""
    var settlementDetails: RoutingSettlementDetails? = nil
    var status: String = ""
    var claimCount: Int = 0
    var postedAt: Int64? = nil

    enum CodingKeys: String, CodingKey {
        case id, status
        case userId            = "user_id"
        case batchReference    = "batch_reference"
        case totalGross        = "total_gross"
        case totalNet          = "total_net"
        case totalVat          = "total_vat"
        case settlementType    = "settlement_type"
        case settlementDetails = "settlement_details"
        case claimCount        = "claim_count"
        case postedAt          = "posted_at"
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func dbl(_ k: CodingKeys) -> Double {
            if let d = try? c.decode(Double.self, forKey: k) { return d }
            if let s = try? c.decode(String.self, forKey: k), let d = Double(s) { return d }
            return 0
        }
        id              = (try? c.decode(String.self, forKey: .id))             ?? UUID().uuidString
        userId          = (try? c.decode(String.self, forKey: .userId))         ?? ""
        batchReference  = (try? c.decode(String.self, forKey: .batchReference)) ?? ""
        totalGross      = dbl(.totalGross)
        totalNet        = dbl(.totalNet)
        totalVat        = dbl(.totalVat)
        settlementType  = (try? c.decode(String.self, forKey: .settlementType)) ?? ""
        settlementDetails = try? c.decode(RoutingSettlementDetails.self, forKey: .settlementDetails)
        status          = (try? c.decode(String.self, forKey: .status))         ?? ""
        claimCount      = (try? c.decode(Int.self,    forKey: .claimCount))     ?? 0
        if let i = try? c.decode(Int64.self, forKey: .postedAt)                 { postedAt = i }
        else if let s = try? c.decode(String.self, forKey: .postedAt),
                let i = Int64(s)                                                 { postedAt = i }
    }

    var holderName: String { UsersData.byId[userId]?.fullName ?? userId }
}

struct RoutingSettlementDetails: Decodable {
    var bankDetails: RoutingBankDetails? = nil
    var paymentMethod: String = ""

    enum CodingKeys: String, CodingKey {
        case bankDetails   = "bank_details"
        case paymentMethod = "payment_method"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bankDetails   = try? c.decode(RoutingBankDetails.self, forKey: .bankDetails)
        paymentMethod = (try? c.decode(String.self, forKey: .paymentMethod)) ?? ""
    }
}

struct RoutingBankDetails: Decodable {
    var sortCode: String = ""
    var accountName: String = ""
    var accountNumber: String = ""

    enum CodingKeys: String, CodingKey {
        case sortCode      = "sort_code"
        case accountName   = "account_name"
        case accountNumber = "account_number"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sortCode      = (try? c.decode(String.self, forKey: .sortCode))      ?? ""
        accountName   = (try? c.decode(String.self, forKey: .accountName))   ?? ""
        accountNumber = (try? c.decode(String.self, forKey: .accountNumber)) ?? ""
    }
}

// MARK: - Float Details (full breakdown from /float-requests/{id}/details)

struct FloatTopUpEntry: Decodable {
    var id: String = ""
    var amount: Double = 0
    var issuedAmount: Double = 0
    var status: String = ""
    var note: String = ""
    var createdAt: Int64 = 0

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
        id           = str("id") ?? ""
        amount       = dbl("amount") ?? 0
        issuedAmount = dbl("issued_amount", "issuedAmount") ?? amount
        status       = str("status") ?? ""
        note         = str("note") ?? ""
        if let s = str("created_at", "createdAt"), let v = Int64(s) { createdAt = v }
    }
}

struct FloatReturnEntry: Decodable {
    var id: String = ""
    var returnAmount: Double = 0
    var returnReason: String = ""
    var reasonNotes: String = ""
    var notes: String = ""
    var receivedDate: Int64 = 0
    var recordedAt: Int64 = 0
    var recordedBy: String = ""

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
        id           = str("id") ?? ""
        returnAmount = dbl("return_amount", "returnAmount") ?? 0
        returnReason = str("return_reason", "returnReason") ?? ""
        reasonNotes  = str("reason_notes", "reasonNotes") ?? ""
        notes        = str("notes") ?? ""
        if let s = str("received_date", "receivedDate"), let v = Int64(s) { receivedDate = v }
        if let s = str("recorded_at", "recordedAt"), let v = Int64(s) { recordedAt = v }
        recordedBy   = str("recorded_by", "recordedBy") ?? ""
    }
}

struct FloatTotals: Decodable {
    var issued: Double = 0
    var spent: Double = 0
    var toppedUp: Double = 0
    var finalBalance: Double = 0
    var returned: Double = 0
    var receiptsAmount: Double = 0
    var requested: Double = 0

    init() {}

    enum CodingKeys: String, CodingKey {
        case issued, spent, returned, requested
        case toppedUp = "topped_up"
        case finalBalance = "final_balance"
        case receiptsAmount = "receipts_amount"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func dbl(_ k: CodingKeys) -> Double {
            if let v = try? c.decode(Double.self, forKey: k) { return v }
            if let s = try? c.decode(String.self, forKey: k), let v = Double(s) { return v }
            return 0
        }
        issued = dbl(.issued); spent = dbl(.spent); toppedUp = dbl(.toppedUp)
        finalBalance = dbl(.finalBalance); returned = dbl(.returned)
        receiptsAmount = dbl(.receiptsAmount); requested = dbl(.requested)
    }
}

struct FloatDetailsResponse: Decodable {
    var float: FloatRequestRaw?
    var batches: [ClaimBatchRaw] = []
    var topups: [FloatTopUpEntry] = []
    var returns: [FloatReturnEntry] = []
    var totals: FloatTotals = FloatTotals()

    enum CodingKeys: String, CodingKey { case float, batches, topups, returns, totals }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        float   = try? c.decode(FloatRequestRaw.self, forKey: .float)
        batches = (try? c.decode([ClaimBatchRaw].self, forKey: .batches)) ?? []
        topups  = (try? c.decode([FloatTopUpEntry].self, forKey: .topups))  ?? []
        returns = (try? c.decode([FloatReturnEntry].self, forKey: .returns)) ?? []
        totals  = (try? c.decode(FloatTotals.self, forKey: .totals)) ?? FloatTotals()
    }
}
