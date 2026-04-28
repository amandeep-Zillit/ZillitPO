//
//  CardExpenseModels.swift
//  ZillitPO
//

import Foundation

// MARK: - Receipt

struct Receipt: Identifiable, Codable, Equatable {
    var id: String?
    var projectId: String?
    var uploaderId: String?
    var uploaderName: String?
    var uploaderDepartment: String?
    var originalName: String?
    var filePath: String?
    var fileType: String?
    var fileSizeBytes: Int?
    var matchStatus: String?
    var workflowStatus: String?   // API "status" field
    var transactionId: String?
    var merchantDetected: String?
    var amountDetected: String?
    var dateDetected: String?
    var nominalCode: String?
    var uploadType: String?
    var reassignCount: Int?
    var lineItems: [ReceiptLineItem]?
    var history: [ReceiptHistoryEntry]?
    var createdAt: Int64?
    var updatedAt: Int64?
    // Inbox matching fields
    var matchScore: Double?
    var isUrgent: Bool?
    var duplicateScore: Double?
    var personalScore: Double?
    var duplicateDismissed: Bool?
    var personalDismissed: Bool?
    var linkedMerchant: String?
    var linkedAmount: Double?
    var linkedDate: Int64?
    var linkedCardLast4: String?

    static func == (lhs: Receipt, rhs: Receipt) -> Bool { lhs.id == rhs.id }

    var displayMerchant: String {
        if let m = merchantDetected, !m.isEmpty { return m }
        return originalName ?? ""
    }
    var displayAmount: Double { Double(amountDetected ?? "") ?? 0 }
    var transactionDate: Int64? {
        let td = Int64(dateDetected ?? "") ?? 0
        return td > 0 ? td : linkedDate
    }
    var statusDisplay: String {
        let ws = workflowStatus ?? ""; let ms = matchStatus ?? ""
        let s = ws.isEmpty ? ms : ws
        switch s.lowercased() {
        case "pending", "pending_receipt":                       return "Pending"
        case "pending_coding", "pending_code", "pending code":   return "Pending Code"
        case "coded":           return "Coded"
        case "suggested_match": return "Suggested Match"
        case "matched":         return "Matched"
        case "unmatched":       return "No Match"
        case "duplicate":       return "Duplicate"
        case "personal":        return "Personal"
        case "approved":        return "Approved"
        case "posted":          return "Posted"
        default: return s.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    var fileSizeDisplay: String {
        if (fileSizeBytes ?? 0) > 0 { return "\((fileSizeBytes ?? 0) / 1024) KB" }
        return ""
    }

    enum CodingKeys: String, CodingKey {
        case id
        case projectId          = "project_id"
        case uploaderId         = "uploader_id"
        case uploaderName       = "uploader_name"
        case uploaderDepartment = "uploader_department"
        case originalName       = "original_name"
        case filePath           = "file_path"
        case fileType           = "file_type"
        case fileSizeBytes      = "file_size_bytes"
        case matchStatus        = "match_status"
        case workflowStatus     = "status"
        case transactionId      = "transaction_id"
        case merchantDetected   = "merchant_detected"
        case amountDetected     = "amount_detected"
        case dateDetected       = "date_detected"
        case nominalCode        = "nominal_code"
        case uploadType         = "upload_type"
        case reassignCount      = "reassign_count"
        case lineItems          = "line_items"
        case history
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
        case matchScore         = "match_score"
        case isUrgent           = "is_urgent"
        case duplicateScore     = "duplicate_score"
        case personalScore      = "personal_score"
        case duplicateDismissed = "duplicate_dismissed"
        case personalDismissed  = "personal_dismissed"
        case linkedMerchant     = "linked_merchant"
        case linkedAmount       = "linked_amount"
        case linkedDate         = "linked_date"
        case linkedCardLast4    = "linked_card_last4"
    }
}

struct ReceiptLineItem: Codable, Equatable {
    var code: String?
    var amount: Double?
    var description: String?
    var amountValue: Double { amount ?? 0 }
}

struct ReceiptHistoryEntry: Codable, Equatable {
    var action: String?
    var details: String?
    var timestamp: Int64?
    static func == (lhs: ReceiptHistoryEntry, rhs: ReceiptHistoryEntry) -> Bool {
        lhs.action == rhs.action && lhs.timestamp == rhs.timestamp
    }
}

// MARK: - Card History Entry

struct CardHistoryEntry: Identifiable, Codable, Equatable {
    var id: String?
    var action: String?
    var details: String?
    var actionBy: String?
    var timestamp: Int64?
    var tierNumber: Int?
    var reason: String?
    var oldValue: String?
    var newValue: String?
    var field: String?

    static func == (lhs: CardHistoryEntry, rhs: CardHistoryEntry) -> Bool {
        lhs.id == rhs.id && lhs.timestamp == rhs.timestamp
    }

    var actionByName: String? {
        guard let by = actionBy, !by.isEmpty else { return nil }
        return UsersData.byId[by]?.fullName
    }

    enum CodingKeys: String, CodingKey {
        case action, details, reason, field
        case actionBy   = "action_by"
        case timestamp  = "action_at"
        case tierNumber = "tier_number"
        case oldValue   = "old_value"
        case newValue   = "new_value"
    }
}

// MARK: - Card Expense Metadata

struct CardExpenseMeta: Codable {
    var cardRegister: Int?
    var receiptInbox: Int?
    var allTransactions: Int?
    var pendingCoding: Int?
    var approvalQueue: Int?
    var topUps: Int?
    var history: Int?
    var smartAlerts: Int?
    var isCoordinator: Bool?
    var coordinatorDeptIds: [String]?
    var isApprover: Bool?
    var canOverride: Bool?
    var cardOverride: Bool?

    var canOverrideCards: Bool { (canOverride ?? false) && (cardOverride ?? false) }

    enum CodingKeys: String, CodingKey {
        case isCoordinator      = "is_coordinator"
        case coordinatorDeptIds = "coordinator_department_ids"
        case isApprover         = "is_approver"
        case canOverride        = "can_override"
        case cardOverride       = "card_override"
        case cardRegister       = "card_register"
        case receiptInbox       = "receipt_inbox"
        case allTransactions    = "all_transactions"
        case pendingCoding      = "pending_coding"
        case approvalQueue      = "approval_queue"
        case topUps             = "top_ups"
        case history
        case smartAlerts        = "smart_alerts"
    }
}

// MARK: - Smart Alert

struct SmartAlert: Identifiable, Codable, Equatable {
    var id: String?
    var type: String?
    var title: String?
    var alertDescription: String?
    var priority: String?
    var status: String?
    var detectedAt: Int64?
    var resolvedAt: Int64?
    var bsControlCode: String?
    var cardLastFour: String?
    var holderId: String?
    /// Raw `holder_name` column decoded off the API response.
    /// Callers should read `holderName` (computed) so the UsersData
    /// lookup takes precedence when the catalogue is loaded.
    var apiHolderName: String?
    /// Raw `designation` column decoded off the API response.
    /// Callers should read `holderRole` (computed).
    var apiDesignation: String?
    /// Raw `department_name` column decoded off the API response.
    /// Callers should read `department` (computed).
    var apiDepartmentName: String?
    /// Raw `department_id` column — fed into the DepartmentsData
    /// lookup by the `department` computed helper.
    var apiDepartmentId: String?
    var amount: Double?
    var transactionId: String?
    var merchantName: String?
    var savings: Double?
    var resolution: String?
    /// Related transactions array — pure decode, no decoder-side
    /// enrichment (callers compute fallbacks at the call site).
    var relatedTxns: [RelatedTxn]?

    static func == (lhs: SmartAlert, rhs: SmartAlert) -> Bool { lhs.id == rhs.id }

    /// Display name — prefers the UsersData lookup (so avatars/roles
    /// match the rest of the app), falls back to the API-sent
    /// `holder_name`, then the raw holder id.
    var holderName: String? {
        if let u = UsersData.byId[holderId ?? ""], let full = u.fullName, !full.isEmpty {
            return full
        }
        if let n = apiHolderName, !n.isEmpty { return n }
        if let h = holderId, !h.isEmpty { return h }
        return nil
    }

    /// Display designation — prefers the UsersData lookup, falls back
    /// to the API's `designation` column formatted through the standard
    /// label helper.
    var holderRole: String? {
        if let u = UsersData.byId[holderId ?? ""] {
            let d = u.displayDesignation
            if !d.isEmpty { return d }
        }
        let formatted = FormatUtils.formatLabel(apiDesignation ?? "").trimmingCharacters(in: .whitespaces)
        return formatted.isEmpty ? nil : formatted
    }

    /// Department display name — prefers the API's `department_name`,
    /// then DepartmentsData by `department_id`, then the holder's
    /// catalogue department.
    var department: String? {
        if let n = apiDepartmentName, !n.isEmpty { return n }
        if let d = DepartmentsData.all.first(where: { $0.id == (apiDepartmentId ?? "") }) {
            return d.displayName
        }
        if let h = holderId, !h.isEmpty { return UsersData.byId[h]?.displayDepartment }
        return nil
    }

    var effectiveCardLastFour: String {
        if let c = cardLastFour, !c.isEmpty { return c }
        let t = title ?? ""
        for marker in ["••••", "****"] {
            if let r = t.range(of: marker) {
                let after = String(t[r.upperBound...])
                let digits = after.prefix(4)
                if digits.count == 4 && digits.allSatisfy({ $0.isNumber }) { return String(digits) }
            }
        }
        return ""
    }
    var holderDisplay: String {
        var parts: [String] = []
        let last4 = effectiveCardLastFour
        if !last4.isEmpty { parts.append("••••\(last4)") }
        var nameStr = holderName ?? ""
        let role = holderRole ?? ""
        if !role.isEmpty { nameStr += " (\(role))" }
        if !nameStr.isEmpty { parts.append(nameStr) }
        return parts.joined(separator: " · ")
    }
    var transactionLabel: String {
        if let m = merchantName, !m.isEmpty { return m }
        if let b = bsControlCode, !b.isEmpty { return "BS: \(b)" }
        return ""
    }
    var effectiveAmount: Double {
        if (amount ?? 0) > 0 { return amount! }
        // Fall back to the first related transaction amount before
        // parsing the description — cheaper and more accurate when
        // the backend populated the array.
        if let tx = relatedTxns?.first, let a = tx.amount, a > 0 { return a }
        let text = (alertDescription ?? "").isEmpty ? (title ?? "") : (alertDescription ?? "")
        if let r = text.range(of: "£") {
            let after = String(text[r.upperBound...])
            let numStr = String(after.prefix(while: { $0.isNumber || $0 == "." || $0 == "," }))
            let cleaned = numStr.replacingOccurrences(of: ",", with: "")
            if let v = Double(cleaned), v > 0 { return v }
        }
        return 0
    }
    var hasTransactionData: Bool {
        effectiveAmount > 0 || !effectiveCardLastFour.isEmpty || !(transactionId ?? "").isEmpty ||
        !(bsControlCode ?? "").isEmpty || !(merchantName ?? "").isEmpty || !(holderName ?? "").isEmpty
    }
    var typeDisplay: String {
        switch (type ?? "").lowercased() {
        case "anomaly": return "Anomaly"
        case "duplicate_risk", "duplicate": return "Duplicate Risk"
        case "velocity": return "Velocity"
        case "merchant": return "Merchant"
        default: return (type ?? "").capitalized
        }
    }
    var priorityDisplay: String {
        switch (priority ?? "").lowercased() {
        case "high":   return "High Priority"
        case "medium": return "Medium Priority"
        case "low":    return "Low Priority"
        default: let p = priority ?? ""; return p.isEmpty ? "" : p.capitalized
        }
    }
    var statusDisplay: String {
        switch (status ?? "").lowercased() {
        case "active": return "Active"; case "resolved": return "Resolved"
        case "dismissed": return "Dismissed"
        default: return (status ?? "").capitalized
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, type, title, status, savings, amount, resolution, priority
        case alertDescription  = "description"
        case detectedAt        = "detected_at"
        case resolvedAt        = "resolved_at"
        case bsControlCode     = "bs_control_code"
        case cardLastFour      = "card_last_four"
        case holderId          = "holder_id"
        case apiHolderName     = "holder_name"
        case apiDesignation    = "designation"
        case apiDepartmentName = "department_name"
        case apiDepartmentId   = "department_id"
        case transactionId     = "transaction_id"
        case merchantName      = "merchant_name"
        case relatedTxns
    }
}

// MARK: - RelatedTxn

struct RelatedTxn: Codable, Equatable {
    var txnID: String?
    var amount: Double?
    var date: Int?
    /// Additional fields previously pulled from the first `related_txns`
    /// entry by the SmartAlert decoder as fallbacks for `amount`,
    /// `bsControlCode`, and `merchantName`. Callers can reach into
    /// `relatedTxns.first` directly when those flat columns are nil.
    var bsControlCode: String?
    var merchantName: String?
    enum CodingKeys: String, CodingKey {
        case txnID = "txn_id"; case amount, date
        case bsControlCode = "bs_control_code"
        case merchantName  = "merchant_name"
    }
}

// MARK: - Top-Up Item

struct TopUpItem: Identifiable, Codable, Equatable {
    var id: String?
    var entityType: String?
    var entityId: String?
    var receiptId: String?
    var cardId: String?
    var cardLastFour: String?
    var userId: String?
    /// Raw `holder_name` column decoded off the API response.
    /// Callers should read `holderName` (computed) so the UsersData
    /// lookup takes precedence when the catalogue is loaded.
    var apiHolderName: String?
    var departmentId: String?
    var amount: Double?
    var method: String?
    var status: String?
    var note: String?
    var receiptMerchant: String?
    var receiptAmount: Double?
    var cardBalance: Double?
    var cardLimit: Double?
    var cardSpent: Double?
    var bsControlCode: String?
    var floatBalance: Double?
    var floatIssued: Double?
    var floatSpent: Double?
    var floatReqNumber: String?
    var floatStatus: String?
    var uploadType: String?
    var createdAt: Int64?
    var updatedAt: Int64?

    static func == (lhs: TopUpItem, rhs: TopUpItem) -> Bool { lhs.id == rhs.id }

    /// Display holder name — prefers the UsersData catalogue, falls
    /// back to the API's `holder_name` column, then the raw user id.
    var holderName: String? {
        if let u = UsersData.byId[userId ?? ""], let full = u.fullName, !full.isEmpty {
            return full
        }
        if let n = apiHolderName, !n.isEmpty { return n }
        return userId
    }

    var isUrgent: Bool { (uploadType ?? "").lowercased() == "urgent" }

    var department: String? {
        DepartmentsData.all.first { $0.id == (departmentId ?? "") }?.displayName
    }

    var statusDisplay: String {
        switch (status ?? "").lowercased() {
        case "completed": return "Completed"; case "skipped": return "Skipped"
        case "partial": return "Partial"; case "pending": return "Pending"
        default: return (status ?? "").capitalized
        }
    }
    var methodDisplay: String {
        switch (method ?? "").lowercased() {
        case "top_up": return "Top-Up"; case "restore": return "Restore"
        case "expense": return "Expense"
        default: return (method ?? "").capitalized
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, amount, method, status, note
        case entityId        = "entity_id"
        case entityType      = "entity_type"
        case receiptId       = "receipt_id"
        case apiHolderName   = "holder_name"
        case cardLastFour    = "card_last_four"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        case cardId          = "card_id"
        case userId          = "user_id"
        case departmentId    = "department_id"
        case bsControlCode   = "bs_control_code"
        case receiptMerchant = "receipt_merchant"
        case receiptAmount   = "receipt_amount"
        case cardBalance     = "card_balance"
        case cardLimit       = "card_limit"
        case cardSpent       = "card_spent"
        case floatBalance    = "float_balance"
        case floatIssued     = "float_issued"
        case floatSpent      = "float_spent"
        case floatReqNumber  = "float_req_number"
        case floatStatus     = "float_status"
        case uploadType      = "upload_type"
    }
}

// MARK: - Card Transaction

struct CardTransaction: Identifiable, Codable, Equatable {
    var id: String?
    var projectId: String?
    var cardId: String?
    var holderId: String?
    var departmentId: String?
    /// Raw `holder_name` column decoded off the API response.
    /// Callers should read `holderName` (computed) so the UsersData
    /// lookup takes precedence when the catalogue is loaded.
    var apiHolderName: String?
    /// Raw `department_name` column — consumed by the `department`
    /// computed helper.
    var apiDepartmentName: String?
    var cardLastFour: String?
    var merchant: String?
    var description: String?
    var amount: Double?
    var currency: String?
    var transactionDate: Int64?
    var status: String?
    /// Full receipt-attachment block (the server ships `{ id, name }`).
    /// `hasReceipt` / `effectiveReceiptId` are computed from this and
    /// the flat `receipt_id` column.
    var receiptAttachment: CardReceiptAttachment?
    var receiptId: String?
    var linkedTransactionId: String?
    var matchStatus: String?
    var duplicateDismissed: Bool?
    var personalDismissed: Bool?
    var duplicateScore: Double?
    var personalScore: Double?
    var nominalCode: String?
    var notes: String?
    var taxAmount: Double?
    var netAmount: Double?
    var grossAmount: Double?
    var approvedBy: String?
    var approvedAt: Int64?
    var approvals: [CardApproval]?
    var isUrgent: Bool?
    var episode: String?
    var codeDescription: String?
    var createdAt: Int64?
    var updatedAt: Int64?
    var matchScore: Double?
    var linkedMerchant: String?
    var linkedAmount: Double?
    var linkedDate: Int64?
    var linkedCardLast4: String?

    static func == (lhs: CardTransaction, rhs: CardTransaction) -> Bool { lhs.id == rhs.id }

    /// Display holder name — prefers the UsersData catalogue, falls
    /// back to the API's `holder_name` column.
    var holderName: String? {
        if let u = UsersData.byId[holderId ?? ""], let full = u.fullName, !full.isEmpty {
            return full
        }
        return apiHolderName
    }

    /// Department display name — prefers the API's `department_name`,
    /// then DepartmentsData by `department_id`, then the holder's
    /// catalogue department.
    var department: String? {
        if let n = apiDepartmentName, !n.isEmpty { return n }
        if let d = DepartmentsData.all.first(where: { $0.id == (departmentId ?? "") }) {
            return d.displayName
        }
        return UsersData.byId[holderId ?? ""]?.displayDepartment
    }

    /// `true` when either the `receipt_attachment` block has a populated
    /// id or the flat `receipt_id` column is set.
    var hasReceipt: Bool {
        if let rid = receiptAttachment?.id, !rid.isEmpty { return true }
        if let rid = receiptId, !rid.isEmpty { return true }
        return false
    }

    /// Effective receipt id — prefers the nested attachment's id, falls
    /// back to the flat `receipt_id` column.
    var effectiveReceiptId: String? {
        if let rid = receiptAttachment?.id, !rid.isEmpty { return rid }
        return receiptId
    }

    var statusDisplay: String {
        switch (status ?? "").lowercased() {
        case "pending", "pending_receipt":              return "Pending Receipt"
        case "pending_coding", "pending_code":          return "Pending Code"
        case "awaiting_approval":                       return "Awaiting Approval"
        case "approved", "matched", "coded":            return "Approved"
        case "queried":                                 return "Queried"
        case "under_review":                            return "Under Review"
        case "escalated":                               return "Escalated"
        case "posted":                                  return "Posted"
        default: return (status ?? "").capitalized
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, status, approvals, description, amount, currency, episode, notes
        // The dev backend speaks camelCase for these five fields
        // (`merchant`, `cardLastFour`, `cardId`, `receiptId`, `userId`),
        // so we omit the snake_case mappings and let Swift use the
        // property name as the JSON key. `holderId` is mapped to the
        // server's `userId` since they refer to the same concept.
        case merchant
        case projectId          = "project_id"
        case cardId
        case holderId           = "userId"
        case cardLastFour
        case apiHolderName      = "holder_name"
        case departmentId       = "department_id"
        case apiDepartmentName  = "department_name"
        case transactionDate    = "date"
        case matchStatus        = "match_status"
        case duplicateDismissed = "duplicate_dismissed"
        case personalDismissed  = "personal_dismissed"
        case duplicateScore     = "duplicate_score"
        case personalScore      = "personal_score"
        case nominalCode        = "nominal_code"
        case taxAmount          = "tax_amount"
        case netAmount          = "net_amount"
        case grossAmount        = "gross_amount"
        case approvedBy         = "approved_by"
        case approvedAt         = "approved_at"
        case isUrgent           = "is_urgent"
        case codeDescription    = "code_description"
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
        case matchScore         = "match_score"
        case linkedMerchant     = "linked_merchant"
        case linkedAmount       = "linked_amount"
        case linkedDate         = "linked_date"
        case linkedCardLast4    = "linked_card_last4"
        case linkedTransactionId = "transaction_id"
        case receiptAttachment  = "receipt_attachment"
        case receiptId          // server uses camelCase
    }
}

struct CardReceiptAttachment: Codable, Equatable {
    var id: String?
    var name: String?
}

struct CardApproval: Codable, Equatable {
    var userId: String?
    var tierNumber: Int?
    var approvedAt: Int64?
    var isOverride: Bool?
    var reason: String?

    enum CodingKeys: String, CodingKey {
        case reason
        case userId     = "user_id"
        case tierNumber = "tier_number"
        case approvedAt = "approved_at"
        case isOverride = "override"
    }

}

// MARK: - Card (ExpenseCard)

struct BankAccount: Codable, Equatable {
    var id: String?
    var name: String?
    var accountNumber: String?
    var sortCode: String?
    enum CodingKeys: String, CodingKey {
        case id, name
        case accountNumber = "account_number"
        case sortCode      = "sort_code"
    }
}

struct ExpenseCard: Identifiable, Codable, Equatable {
    var id: String?
    var projectId: String?
    var holderId: String?
    var departmentId: String?
    var status: String?
    var lastFour: String?
    var cardIssuer: String?
    var monthlyLimit: Double?
    var currentBalance: Double?
    var proposedLimit: Double?
    var bsControlCode: String?
    var justification: String?
    var requestedBy: String?
    var requestedAt: Int64?
    var approvals: [Approval]?
    var approvedBy: String?
    var approvedAt: Int64?
    var rejectedBy: String?
    var rejectedAt: Int64?
    var rejectionReason: String?
    var digitalCardNumber: String?
    var physicalCardNumber: String?
    var bankAccount: BankAccount?
    var updatedBy: String?
    var updatedAt: Int64?

    static func == (lhs: ExpenseCard, rhs: ExpenseCard) -> Bool { lhs.id == rhs.id }

    // Computed from singletons (not in CodingKeys)
    var holderName: String?        { UsersData.byId[holderId ?? ""]?.fullName }
    var holderUser: AppUser?       { UsersData.byId[holderId ?? ""] }
    var holderFullName: String     { holderName ?? "" }
    var holderDesignation: String  { holderUser?.displayDesignation ?? "" }
    var department: String?        { DepartmentsData.all.first { $0.id == (departmentId ?? "") }?.displayName }
    var bankName: String           { bankAccount?.name ?? "" }

    var spentAmount: Double { max((monthlyLimit ?? 0) - (currentBalance ?? 0), 0) }
    var spendPercent: Double { (monthlyLimit ?? 0) > 0 ? spentAmount / (monthlyLimit ?? 0) : 0 }
    var isDigitalOnly: Bool {
        digitalCardNumber != nil && !digitalCardNumber!.isEmpty &&
        (physicalCardNumber == nil || physicalCardNumber!.isEmpty)
    }

    func statusDisplay(isAccountant: Bool) -> String {
        switch status ?? "" {
        case "active":    return isDigitalOnly ? "Digital Active" : "Active"
        case "requested": return "Requested"
        case "pending":   return "Pending Approval"
        case "approved", "override":
            return isAccountant ? (status == "override" ? "Override" : "Approved") : "In-Progress"
        case "rejected":  return "Rejected"
        case "suspended": return "Suspended"
        default: return (status ?? "").capitalized
        }
    }

    /// Effective four-digit display — falls back to the last four digits
    /// of the digital or physical card number when the server didn't ship
    /// a `last_four` column.
    var effectiveLastFour: String? {
        if let l = lastFour, !l.isEmpty { return l }
        let num = digitalCardNumber ?? physicalCardNumber
        guard let n = num else { return nil }
        let digits = n.filter { $0.isNumber }
        return digits.count >= 4 ? String(digits.suffix(4)) : nil
    }

    enum CodingKeys: String, CodingKey {
        case id, status, approvals, justification
        case projectId          = "project_id"
        case holderId           = "user_id"
        case departmentId       = "department_id"
        case lastFour           = "last_four"
        case cardIssuer         = "card_issuer"
        case monthlyLimit       = "monthly_limit"
        case currentBalance     = "current_balance"
        case proposedLimit      = "proposed_float"
        case bsControlCode      = "bs_control_code"
        case requestedBy        = "requested_by"
        case requestedAt        = "requested_at"
        case approvedBy         = "approved_by"
        case approvedAt         = "approved_at"
        case rejectedBy         = "rejected_by"
        case rejectedAt         = "rejected_at"
        case rejectionReason    = "rejection_reason"
        case digitalCardNumber  = "digital_card_number"
        case physicalCardNumber = "physical_card_number"
        case bankAccount        = "bank_account"
        case updatedBy          = "updated_by"
        case updatedAt          = "updated_at"
    }
}

// MARK: - Pending Coding Item

struct PendingCodingItem: Identifiable, Codable, Equatable {
    var id: String?
    var projectId: String?
    var userId: String?
    var status: String?
    var transactionId: String?
    var description: String?
    var amount: Double?
    var date: Int64?
    var createdAt: Int64?
    var updatedAt: Int64?
    var nominalCode: String?
    var history: [PendingCodingHistory]?
    var departmentId: String?
    var episode: String?
    var codeDescription: String?
    var matchStatus: String?
    var receiptAttachment: PendingCodingAttachment?
    var processingFlags: [ProcessingFlag]?
    var isUrgent: Bool?
    var requestTopUp: Bool?
    var taxAmount: Double?
    var netAmount: Double?
    var grossAmount: Double?

    static func == (lhs: PendingCodingItem, rhs: PendingCodingItem) -> Bool { lhs.id == rhs.id }

    var userName: String { UsersData.byId[userId ?? ""]?.fullName ?? "" }
    var userDepartment: String {
        guard let deptId = departmentId,
              let dept = DepartmentsData.all.first(where: { $0.id == deptId }) else { return "" }
        return dept.displayName
    }
    var statusDisplay: String {
        switch (status ?? "").lowercased() {
        case "pending_code", "pending_coding": return "Needs Coding"
        case "pending_receipt": return "Awaiting Receipt"
        case "coded":           return "Coded"
        case "posted":          return "Posted"
        default: return (status ?? "").replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, status, description, amount, date, episode
        case projectId         = "project_id"
        case userId            = "user_id"
        case transactionId     = "transaction_id"
        case createdAt         = "created_at"
        case updatedAt         = "updated_at"
        case nominalCode       = "nominal_code"
        case history
        case departmentId      = "department_id"
        case codeDescription   = "code_description"
        case matchStatus       = "match_status"
        case receiptAttachment = "receipt_attachment"
        case processingFlags   = "processing_flags"
        case isUrgent          = "is_urgent"
        case requestTopUp      = "request_top_up"
        case taxAmount         = "tax_amount"
        case netAmount         = "net_amount"
        case grossAmount       = "gross_amount"
    }
}

struct PendingCodingHistory: Codable, Equatable {
    var action: String?
    var actionAt: Int64?
    var actionBy: String?

    var actionByName: String {
        guard let id = actionBy, !id.isEmpty else { return "System" }
        return UsersData.byId[id]?.fullName ?? id
    }

    enum CodingKeys: String, CodingKey {
        case action
        case actionAt = "action_at"
        case actionBy = "action_by"
    }
}

struct PendingCodingAttachment: Codable, Equatable {
    var id: String?
    var name: String?
}

struct ProcessingFlag: Codable, Equatable {
    var flag: String?
    var title: String?
    var ruleId: String?
    var description: String?
    var processType: String?
    var thresholdType: String?
    var thresholdValue: Double?

    var flagColor: String {
        switch flag?.lowercased() {
        case "review": return "purple"; case "query": return "orange"
        case "deduct": return "red"; default: return "gray"
        }
    }

    enum CodingKeys: String, CodingKey {
        case flag, title, description
        case ruleId        = "rule_id"
        case processType   = "process_type"
        case thresholdType = "threshold_type"
        case thresholdValue = "threshold_value"
    }

}

// MARK: - Bank Accounts

struct BankAccountAdditionalDetail: Codable, Equatable {
    var field: String?
    var value: String?
}

struct ProductionBankAccount: Identifiable, Codable, Equatable {
    var id: String?
    var name: String?
    var accountNumber: String?
    var accountHolderName: String?
    var sortCode: String?
    var ibanNumber: String?
    var swiftCode: String?
    var nominalCode: String?
    var accPayableCode: String?
    var paymentPrefix: String?
    var entityType: String?
    var additionalDetails: [BankAccountAdditionalDetail]?

    enum CodingKeys: String, CodingKey {
        case id, name
        case accountNumber      = "account_number"
        case accountHolderName  = "account_holder_name"
        case sortCode           = "sort_code"
        case ibanNumber         = "iban_number"
        case swiftCode          = "swift_code"
        case nominalCode        = "nominal_code"
        case accPayableCode     = "acc_payable_code"
        case paymentPrefix      = "payment_prefix"
        case entityType         = "entity_type"
        case additionalDetails  = "additional_details"
    }

    init(id: String? = nil) { self.id = id }
}
