//
//  CardExpenseModels.swift
//  ZillitPO
//
//  Models for Card Expenses — Receipts from /api/v2/card-expenses/receipts
//

import Foundation

// MARK: - Receipt (Domain model)

struct Receipt: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var projectId: String = ""
    var uploaderId: String = ""
    var uploaderName: String = ""
    var uploaderDepartment: String = ""
    var originalName: String = ""
    var filePath: String = ""
    var fileType: String = ""
    var fileSizeBytes: Int = 0
    var matchStatus: String = "pending"
    var transactionId: String?
    var merchantDetected: String?
    var amountDetected: String?
    var dateDetected: String?
    var nominalCode: String?
    var uploadType: String?
    var reassignCount: Int = 0
    var lineItems: [ReceiptLineItem] = []
    var history: [ReceiptHistoryEntry] = []
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0

    static func == (lhs: Receipt, rhs: Receipt) -> Bool { lhs.id == rhs.id }

    var displayMerchant: String { merchantDetected ?? originalName }
    var displayAmount: Double { Double(amountDetected ?? "") ?? 0 }

    var statusDisplay: String {
        switch matchStatus {
        case "pending": return "Pending"
        case "pending_coding": return "Needs Coding"
        case "coded": return "Coded"
        case "matched": return "Matched"
        case "unmatched": return "No Match"
        case "duplicate": return "Duplicate"
        case "personal": return "Personal"
        case "posted": return "Posted"
        default: return matchStatus.capitalized
        }
    }

    var fileSizeDisplay: String {
        if fileSizeBytes > 0 { return "\(fileSizeBytes / 1024) KB" }
        return ""
    }
}

struct ReceiptLineItem: Codable, Equatable {
    var code: String?
    var amount: AnyCodableValue?
    var description: String?

    var amountValue: Double { amount?.doubleValue ?? 0 }
}

struct ReceiptHistoryEntry: Codable, Equatable {
    var action: String?
    var details: String?
    var timestamp: Int64?

    static func == (lhs: ReceiptHistoryEntry, rhs: ReceiptHistoryEntry) -> Bool {
        lhs.action == rhs.action && lhs.timestamp == rhs.timestamp
    }
}

// MARK: - Receipt Raw (API response)

struct ReceiptRaw: Codable {
    var id: String
    var project_id: String?
    var uploader_id: String?
    var uploader_name: String?
    var uploader_department: String?
    var original_name: String?
    var file_path: String?
    var file_type: String?
    var file_size_bytes: Int?
    var match_status: String?
    var transaction_id: String?
    var merchant_detected: String?
    var amount_detected: String?
    var date_detected: String?
    var nominal_code: String?
    var upload_type: String?
    var reassign_count: Int?
    var line_items: [ReceiptLineItem]?
    var history: [ReceiptHistoryEntry]?
    var created_at: String?
    var updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, project_id, uploader_id, uploader_name, uploader_department
        case original_name, file_path, file_type, file_size_bytes
        case match_status, transaction_id, merchant_detected, amount_detected, date_detected
        case nominal_code, upload_type, reassign_count, line_items, history
        case created_at, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        project_id = try? c.decode(String.self, forKey: .project_id)
        uploader_id = try? c.decode(String.self, forKey: .uploader_id)
        uploader_name = try? c.decode(String.self, forKey: .uploader_name)
        uploader_department = try? c.decode(String.self, forKey: .uploader_department)
        original_name = try? c.decode(String.self, forKey: .original_name)
        file_path = try? c.decode(String.self, forKey: .file_path)
        file_type = try? c.decode(String.self, forKey: .file_type)
        file_size_bytes = try? c.decode(Int.self, forKey: .file_size_bytes)
        match_status = try? c.decode(String.self, forKey: .match_status)
        transaction_id = try? c.decode(String.self, forKey: .transaction_id)
        merchant_detected = try? c.decode(String.self, forKey: .merchant_detected)
        amount_detected = try? c.decode(String.self, forKey: .amount_detected)
        date_detected = try? c.decode(String.self, forKey: .date_detected)
        nominal_code = try? c.decode(String.self, forKey: .nominal_code)
        upload_type = try? c.decode(String.self, forKey: .upload_type)
        reassign_count = try? c.decode(Int.self, forKey: .reassign_count)
        line_items = try? c.decode([ReceiptLineItem].self, forKey: .line_items)
        history = try? c.decode([ReceiptHistoryEntry].self, forKey: .history)
        created_at = try? c.decode(String.self, forKey: .created_at)
        updated_at = try? c.decode(String.self, forKey: .updated_at)
    }

    func toReceipt() -> Receipt {
        var r = Receipt()
        r.id = id
        r.projectId = project_id ?? ""
        r.uploaderId = uploader_id ?? ""
        r.uploaderName = uploader_name ?? ""
        r.uploaderDepartment = uploader_department ?? ""
        r.originalName = original_name ?? ""
        r.filePath = file_path ?? ""
        r.fileType = file_type ?? ""
        r.fileSizeBytes = file_size_bytes ?? 0
        r.matchStatus = match_status ?? "pending"
        r.transactionId = transaction_id
        r.merchantDetected = merchant_detected
        r.amountDetected = amount_detected
        r.dateDetected = date_detected
        r.nominalCode = nominal_code
        r.uploadType = upload_type
        r.reassignCount = reassign_count ?? 0
        r.lineItems = line_items ?? []
        r.history = history ?? []
        r.createdAt = Int64(created_at ?? "") ?? 0
        r.updatedAt = Int64(updated_at ?? "") ?? 0
        return r
    }
}

// MARK: - Smart Alert (from /api/v2/card-expenses/alerts)

struct SmartAlert: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var type: String = ""           // anomaly | duplicate_risk | velocity | merchant
    var title: String = ""
    var description: String = ""
    var priority: String = ""       // high | medium | low
    var status: String = ""         // active | resolved | dismissed
    var detectedAt: Int64 = 0
    var resolvedAt: Int64 = 0
    var bsControlCode: String = ""
    var cardLastFour: String = ""
    var holderId: String = ""
    var holderName: String = ""
    var department: String = ""
    var amount: Double = 0
    var transactionId: String = ""
    var savings: Double = 0

    static func == (lhs: SmartAlert, rhs: SmartAlert) -> Bool { lhs.id == rhs.id }

    var typeDisplay: String {
        switch type.lowercased() {
        case "anomaly":        return "Anomaly"
        case "duplicate_risk", "duplicate": return "Duplicate Risk"
        case "velocity":       return "Velocity"
        case "merchant":       return "Merchant"
        default:               return type.capitalized
        }
    }

    var priorityDisplay: String {
        switch priority.lowercased() {
        case "high":   return "High Priority"
        case "medium": return "Medium Priority"
        case "low":    return "Low Priority"
        default:       return priority.capitalized
        }
    }

    var statusDisplay: String {
        switch status.lowercased() {
        case "active":    return "Active"
        case "resolved":  return "Resolved"
        case "dismissed": return "Dismissed"
        default:          return status.capitalized
        }
    }
}

struct SmartAlertRaw: Decodable {
    var id: String
    var type: String?
    var title: String?
    var description: String?
    var priority: String?
    var status: String?
    var detected_at: String?
    var resolved_at: String?
    var bs_control_code: String?
    var card_last_four: String?
    var card_last4: String?
    var holder_id: String?
    var user_id: String?
    var holder_name: String?
    var department_id: String?
    var department_name: String?
    var amount: Double?
    var transaction_id: String?
    var savings: Double?
    var created_at: String?

    func toSmartAlert() -> SmartAlert {
        var a = SmartAlert()
        a.id = id
        a.type = type ?? ""
        a.title = title ?? ""
        a.description = description ?? ""
        a.priority = priority ?? ""
        a.status = status ?? "active"
        a.detectedAt = Int64(detected_at ?? created_at ?? "") ?? 0
        a.resolvedAt = Int64(resolved_at ?? "") ?? 0
        a.bsControlCode = bs_control_code ?? ""
        a.cardLastFour = card_last_four ?? card_last4 ?? ""
        let uid = holder_id ?? user_id ?? ""
        a.holderId = uid
        a.holderName = UsersData.byId[uid]?.fullName ?? holder_name ?? uid
        if let name = department_name, !name.isEmpty {
            a.department = name
        } else if let dept = DepartmentsData.all.first(where: { $0.id == (department_id ?? "") }) {
            a.department = dept.displayName
        } else if let h = UsersData.byId[uid] {
            a.department = h.displayDepartment
        }
        a.amount = amount ?? 0
        a.transactionId = transaction_id ?? ""
        a.savings = savings ?? 0
        return a
    }
}

// MARK: - Top-Up Item (from /api/v2/card-expenses/topups)

struct TopUpItem: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var entityType: String = ""        // "card" or "cash"
    var entityId: String = ""
    var receiptId: String?
    var cardId: String = ""
    var cardLastFour: String = ""
    var userId: String = ""
    var holderName: String = ""
    var departmentId: String = ""
    var department: String = ""
    var amount: Double = 0
    var method: String = ""             // top_up, restore, expense
    var status: String = ""             // skipped, completed, partial, pending
    var note: String = ""
    var receiptMerchant: String = ""
    var receiptAmount: Double = 0
    var cardBalance: Double = 0
    var cardLimit: Double = 0
    var cardSpent: Double = 0
    var bsControlCode: String = ""
    var floatBalance: Double = 0
    var floatIssued: Double = 0
    var floatSpent: Double = 0
    var floatReqNumber: String = ""
    var floatStatus: String = ""
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0

    static func == (lhs: TopUpItem, rhs: TopUpItem) -> Bool { lhs.id == rhs.id }

    var statusDisplay: String {
        switch status.lowercased() {
        case "completed": return "Completed"
        case "skipped":   return "Skipped"
        case "partial":   return "Partial"
        case "pending":   return "Pending"
        default:          return status.capitalized
        }
    }

    var methodDisplay: String {
        switch method.lowercased() {
        case "top_up":  return "Top-Up"
        case "restore": return "Restore"
        case "expense": return "Expense"
        default:        return method.capitalized
        }
    }
}

struct TopUpItemRaw: Decodable {
    var id: String
    var project_id: String?
    var entity_id: String?
    var entity_type: String?
    var receipt_id: String?
    var holder_name: String?
    var card_last_four: String?
    var amount: Double?
    var method: String?
    var status: String?
    var created_at: String?
    var updated_at: String?
    var note: String?
    var card_id: String?
    var user_id: String?
    var department_id: String?
    var bs_control_code: String?
    var receipt_merchant: String?
    var receipt_amount: String?
    var card_balance: Double?
    var card_limit: Double?
    var card_spent: Double?
    var float_balance: Double?
    var float_issued: Double?
    var float_spent: Double?
    var float_req_number: String?
    var float_status: String?

    func toTopUpItem() -> TopUpItem {
        var t = TopUpItem()
        t.id = id
        t.entityType = entity_type ?? ""
        t.entityId = entity_id ?? ""
        t.receiptId = receipt_id
        t.cardId = card_id ?? ""
        t.cardLastFour = card_last_four ?? ""
        t.userId = user_id ?? ""
        let resolvedName = UsersData.byId[user_id ?? ""]?.fullName
            ?? holder_name
            ?? user_id
            ?? ""
        t.holderName = resolvedName
        t.departmentId = department_id ?? ""
        if let dept = DepartmentsData.all.first(where: { $0.id == (department_id ?? "") }) {
            t.department = dept.displayName
        }
        t.amount = amount ?? 0
        t.method = method ?? ""
        t.status = status ?? ""
        t.note = note ?? ""
        t.receiptMerchant = receipt_merchant ?? ""
        t.receiptAmount = Double(receipt_amount ?? "") ?? 0
        t.cardBalance = card_balance ?? 0
        t.cardLimit = card_limit ?? 0
        t.cardSpent = card_spent ?? 0
        t.bsControlCode = bs_control_code ?? ""
        t.floatBalance = float_balance ?? 0
        t.floatIssued = float_issued ?? 0
        t.floatSpent = float_spent ?? 0
        t.floatReqNumber = float_req_number ?? ""
        t.floatStatus = float_status ?? ""
        t.createdAt = Int64(created_at ?? "") ?? 0
        t.updatedAt = Int64(updated_at ?? "") ?? 0
        return t
    }
}

// MARK: - Card Transaction (Domain model)

struct CardTransaction: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var projectId: String = ""
    var cardId: String = ""
    var holderId: String = ""
    var holderName: String = ""
    var department: String = ""
    var cardLastFour: String = ""
    var merchant: String = ""
    var description: String = ""
    var amount: Double = 0
    var currency: String = "GBP"
    var transactionDate: Int64 = 0
    var status: String = "pending"            // pending, pending_receipt, pending_code, awaiting_approval, approved, queried, under_review, escalated, posted
    var hasReceipt: Bool = false
    var receiptId: String?
    var linkedTransactionId: String = ""
    var matchStatus: String = ""
    var duplicateDismissed: Bool = false
    var personalDismissed: Bool = false
    var duplicateScore: Double?
    var personalScore: Double?
    var nominalCode: String = ""
    var notes: String = ""
    var taxAmount: Double = 0
    var netAmount: Double = 0
    var grossAmount: Double = 0
    var approvedBy: String = ""
    var approvedAt: Int64 = 0
    var approvals: [CardApproval] = []
    var episode: String = ""
    var codeDescription: String = ""
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0

    static func == (lhs: CardTransaction, rhs: CardTransaction) -> Bool { lhs.id == rhs.id }

    var statusDisplay: String {
        switch status.lowercased() {
        case "pending", "pending_receipt": return "Pending Receipt"
        case "pending_coding", "pending_code": return "Pending Code"
        case "awaiting_approval": return "Awaiting Approval"
        case "approved", "matched", "coded": return "Approved"
        case "queried": return "Queried"
        case "under_review": return "Under Review"
        case "escalated": return "Escalated"
        case "posted": return "Posted"
        default: return status.capitalized
        }
    }
}

struct CardReceiptAttachmentRaw: Codable {
    var id: String?
    var name: String?
}

struct CardApproval: Equatable {
    var userId: String = ""
    var tierNumber: Int = 0
    var approvedAt: Int64 = 0
    var override: Bool = false
    var reason: String = ""
}

struct CardTxApprovalRaw: Codable {
    var user_id: String?
    var tier_number: Int?
    var approved_at: Double?
    var isOverride: Bool?
    var reason: String?

    enum CodingKeys: String, CodingKey {
        case user_id, tier_number, approved_at, reason
        case isOverride = "override"
    }
}

struct CardTransactionRaw: Decodable {
    var id: String
    var project_id: String?
    var user_id: String?
    var holder_id: String?
    var holder_name: String?
    var card_holder_name: String?
    var department_id: String?
    var department_name: String?
    var card_id: String?
    var card_last_four: String?
    var last_four: String?
    var transaction_id: String?
    var description: String?
    var merchant: String?
    var merchant_name: String?
    var amount: String?
    var date: String?
    var status: String?
    var nominal_code: String?
    var code_description: String?
    var episode: String?
    var receipt_attachment: CardReceiptAttachmentRaw?
    var match_status: String?
    var duplicate_dismissed: Bool?
    var personal_dismissed: Bool?
    var duplicate_score: Double?
    var personal_score: Double?
    var tax_amount: Double?
    var net_amount: Double?
    var gross_amount: Double?
    var is_urgent: Bool?
    var request_top_up: Bool?
    var approved_by: String?
    var approved_at: String?
    var approvals: [CardTxApprovalRaw]?
    var created_at: String?
    var updated_at: String?

    struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
        init?(intValue: Int) { self.intValue = intValue; stringValue = "\(intValue)" }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        func str(_ keys: String...) -> String? {
            for k in keys {
                if let key = AnyKey(stringValue: k), let v = try? c.decode(String.self, forKey: key), !v.isEmpty { return v }
            }
            return nil
        }
        func dbl(_ keys: String...) -> Double? {
            for k in keys {
                if let key = AnyKey(stringValue: k) {
                    if let d = try? c.decode(Double.self, forKey: key) { return d }
                    if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return d }
                }
            }
            return nil
        }
        func bool(_ keys: String...) -> Bool? {
            for k in keys {
                if let key = AnyKey(stringValue: k), let b = try? c.decode(Bool.self, forKey: key) { return b }
            }
            return nil
        }

        id = str("id") ?? UUID().uuidString
        project_id = str("project_id", "projectId")
        user_id = str("user_id", "userId")
        holder_id = str("holder_id", "holderId")
        holder_name = str("holder_name", "holderName")
        card_holder_name = str("card_holder_name", "cardHolderName")
        department_id = str("department_id", "departmentId")
        department_name = str("department_name", "departmentName")
        card_id = str("card_id", "cardId")
        card_last_four = str("card_last_four", "cardLastFour", "lastFour", "last_four", "transaction_card_last4", "transactionCardLast4")
        last_four = nil
        transaction_id = str("transaction_id", "transactionId")
        description = str("description")
        merchant = str("merchant", "transaction_merchant", "transactionMerchant")
        merchant_name = str("merchant_name", "merchantName")
        if let d = dbl("amount") { amount = String(d) } else { amount = nil }
        date = str("date") ?? str("transaction_date", "transactionDate")
        status = str("status")
        nominal_code = str("nominal_code", "nominalCode")
        code_description = str("code_description", "codeDescription")
        episode = str("episode")
        // Receipt attachment may be an object OR a top-level receiptId
        if let key = AnyKey(stringValue: "receipt_attachment"),
           let att = try? c.decode(CardReceiptAttachmentRaw.self, forKey: key) {
            receipt_attachment = att
        } else if let key = AnyKey(stringValue: "receiptAttachment"),
                  let att = try? c.decode(CardReceiptAttachmentRaw.self, forKey: key) {
            receipt_attachment = att
        } else if let rid = str("receipt_id", "receiptId") {
            var att = CardReceiptAttachmentRaw(); att.id = rid
            receipt_attachment = att
        } else {
            receipt_attachment = nil
        }
        match_status = str("match_status", "matchStatus")
        duplicate_dismissed = bool("duplicate_dismissed", "duplicateDismissed")
        personal_dismissed = bool("personal_dismissed", "personalDismissed")
        duplicate_score = dbl("duplicate_score", "duplicateScore")
        personal_score = dbl("personal_score", "personalScore")
        tax_amount = dbl("tax_amount", "taxAmount")
        net_amount = dbl("net_amount", "netAmount")
        gross_amount = dbl("gross_amount", "grossAmount")
        is_urgent = bool("is_urgent", "isUrgent")
        request_top_up = bool("request_top_up", "requestTopUp")
        approved_by = str("approved_by", "approvedBy")
        approved_at = str("approved_at", "approvedAt")
        if let key = AnyKey(stringValue: "approvals"),
           let arr = try? c.decode([CardTxApprovalRaw].self, forKey: key) {
            approvals = arr
        } else { approvals = nil }
        created_at = str("created_at", "createdAt")
        updated_at = str("updated_at", "updatedAt")
    }

    func toCardTransaction() -> CardTransaction {
        var t = CardTransaction()
        t.id = id
        t.projectId = project_id ?? ""
        let uid = holder_id ?? user_id ?? ""
        t.holderId = uid
        t.holderName = UsersData.byId[uid]?.fullName
            ?? holder_name
            ?? card_holder_name
            ?? ""
        if let name = department_name, !name.isEmpty {
            t.department = name
        } else if let dept = DepartmentsData.all.first(where: { $0.id == (department_id ?? "") }) {
            t.department = dept.displayName
        } else if let h = UsersData.byId[uid] {
            t.department = h.displayDepartment
        }
        t.cardLastFour = card_last_four ?? last_four ?? ""
        t.cardId = card_id ?? ""
        let m = merchant ?? merchant_name ?? description ?? ""
        t.merchant = m
        t.description = description ?? m
        t.amount = Double(amount ?? "") ?? 0
        t.currency = "GBP"
        t.transactionDate = Int64(date ?? "") ?? 0
        t.status = status ?? "pending_receipt"
        t.hasReceipt = receipt_attachment != nil
        t.receiptId = receipt_attachment?.id
        t.linkedTransactionId = transaction_id ?? ""
        t.matchStatus = match_status ?? ""
        t.duplicateDismissed = duplicate_dismissed ?? false
        t.personalDismissed = personal_dismissed ?? false
        t.duplicateScore = duplicate_score
        t.personalScore = personal_score
        t.nominalCode = nominal_code ?? ""
        t.notes = code_description ?? ""
        t.codeDescription = code_description ?? ""
        t.episode = episode ?? ""
        t.taxAmount = tax_amount ?? 0
        t.netAmount = net_amount ?? 0
        t.grossAmount = gross_amount ?? 0
        t.approvedBy = approved_by ?? ""
        t.approvedAt = Int64(approved_at ?? "") ?? 0
        t.approvals = (approvals ?? []).map { raw in
            var a = CardApproval()
            a.userId = raw.user_id ?? ""
            a.tierNumber = raw.tier_number ?? 0
            a.approvedAt = Int64(raw.approved_at ?? 0)
            a.override = raw.isOverride ?? false
            a.reason = raw.reason ?? ""
            return a
        }
        t.createdAt = Int64(created_at ?? "") ?? 0
        t.updatedAt = Int64(updated_at ?? "") ?? 0
        return t
    }
}

// MARK: - Card (Domain model)

struct BankAccount: Codable, Equatable {
    var id: String?
    var name: String?
    var account_number: String?
    var sort_code: String?
}

struct ExpenseCard: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var projectId: String = ""
    var holderId: String = ""
    var holderName: String = ""
    var department: String = ""
    var departmentId: String = ""
    var status: String = "requested"
    var lastFour: String = ""
    var cardIssuer: String = ""
    var monthlyLimit: Double = 0
    var currentBalance: Double = 0
    var proposedLimit: Double = 0
    var bsControlCode: String = ""
    var justification: String = ""
    var requestedBy: String = ""
    var requestedAt: Int64 = 0
    var approvals: [Approval] = []
    var approvedBy: String?
    var approvedAt: Int64?
    var rejectedBy: String?
    var rejectedAt: Int64?
    var rejectionReason: String?
    var digitalCardNumber: String?
    var physicalCardNumber: String?
    var bankAccount: BankAccount?
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0

    static func == (lhs: ExpenseCard, rhs: ExpenseCard) -> Bool { lhs.id == rhs.id }

    var spentAmount: Double { max(monthlyLimit - currentBalance, 0) }
    var spendPercent: Double { monthlyLimit > 0 ? spentAmount / monthlyLimit : 0 }
    var bankName: String { bankAccount?.name ?? "" }
    var holderUser: AppUser? { UsersData.byId[holderId] }
    var holderFullName: String { holderUser?.fullName ?? holderName }
    var holderDesignation: String { holderUser?.displayDesignation ?? "" }
    var isDigitalOnly: Bool { digitalCardNumber != nil && !digitalCardNumber!.isEmpty && (physicalCardNumber == nil || physicalCardNumber!.isEmpty) }

    func statusDisplay(isAccountant: Bool) -> String {
        switch status {
        case "active": return isDigitalOnly ? "Digital Active" : "Active"
        case "requested": return "Requested"
        case "pending": return "Pending Approval"
        case "approved", "override": return isAccountant ? (status == "override" ? "Override" : "Approved") : "In-Progress"
        case "rejected": return "Rejected"
        case "suspended": return "Suspended"
        default: return status.capitalized
        }
    }
}

// MARK: - Card Raw (API response)

struct CardRaw: Codable {
    var id: String
    var project_id: String?
    var user_id: String?
    var department_id: String?
    var status: String?
    var last_four: String?
    var card_issuer: String?
    var monthly_limit: Double?
    var current_balance: Double?
    var proposed_float: Double?
    var bs_control_code: String?
    var justification: String?
    var requested_by: String?
    var requested_at: String?
    var approvals: [CardApprovalRaw]?
    var approved_by: String?
    var approved_at: String?
    var rejected_by: String?
    var rejected_at: String?
    var rejection_reason: String?
    var digital_card_number: String?
    var physical_card_number: String?
    var bank_account: BankAccount?
    var updated_by: String?
    var updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, project_id, user_id, department_id
        case status, last_four, card_issuer, monthly_limit, current_balance, proposed_float
        case bs_control_code, justification, requested_by, requested_at
        case approvals, approved_by, approved_at
        case rejected_by, rejected_at, rejection_reason
        case digital_card_number, physical_card_number, bank_account
        case updated_by, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        project_id = try? c.decode(String.self, forKey: .project_id)
        user_id = try? c.decode(String.self, forKey: .user_id)
        department_id = try? c.decode(String.self, forKey: .department_id)
        status = try? c.decode(String.self, forKey: .status)
        last_four = try? c.decode(String.self, forKey: .last_four)
        card_issuer = try? c.decode(String.self, forKey: .card_issuer)
        bs_control_code = try? c.decode(String.self, forKey: .bs_control_code)
        justification = try? c.decode(String.self, forKey: .justification)
        requested_by = try? c.decode(String.self, forKey: .requested_by)
        requested_at = try? c.decode(String.self, forKey: .requested_at)
        approved_by = try? c.decode(String.self, forKey: .approved_by)
        approved_at = try? c.decode(String.self, forKey: .approved_at)
        rejected_by = try? c.decode(String.self, forKey: .rejected_by)
        rejected_at = try? c.decode(String.self, forKey: .rejected_at)
        rejection_reason = try? c.decode(String.self, forKey: .rejection_reason)
        digital_card_number = try? c.decode(String.self, forKey: .digital_card_number)
        physical_card_number = try? c.decode(String.self, forKey: .physical_card_number)
        updated_by = try? c.decode(String.self, forKey: .updated_by)
        updated_at = try? c.decode(String.self, forKey: .updated_at)
        bank_account = try? c.decode(BankAccount.self, forKey: .bank_account)
        approvals = try? c.decode([CardApprovalRaw].self, forKey: .approvals)
        monthly_limit = flexibleDoubleDecode(c, .monthly_limit)
        current_balance = flexibleDoubleDecode(c, .current_balance)
        proposed_float = flexibleDoubleDecode(c, .proposed_float)
    }

    func toCard() -> ExpenseCard {
        let dept = DepartmentsData.all.first { $0.id == (department_id ?? "") }
        var card = ExpenseCard()
        card.id = id
        card.holderId = user_id ?? ""
        card.holderName = UsersData.byId[user_id ?? ""]?.fullName ?? ""
        card.department = dept?.displayName ?? ""
        card.departmentId = department_id ?? ""
        card.status = status ?? "requested"
        card.lastFour = last_four ?? ""
        card.cardIssuer = card_issuer ?? ""
        card.monthlyLimit = monthly_limit ?? 0
        card.currentBalance = current_balance ?? 0
        card.proposedLimit = proposed_float ?? 0
        card.bsControlCode = bs_control_code ?? ""
        card.justification = justification ?? ""
        card.requestedBy = requested_by ?? ""
        card.requestedAt = Int64(requested_at ?? "") ?? 0
        card.approvedBy = approved_by
        card.approvedAt = approved_at.flatMap { Int64($0) }
        card.rejectedBy = rejected_by
        card.rejectedAt = rejected_at.flatMap { Int64($0) }
        card.rejectionReason = rejection_reason
        card.digitalCardNumber = digital_card_number
        card.physicalCardNumber = physical_card_number
        card.bankAccount = bank_account
        card.approvals = (approvals ?? []).map {
            Approval(userId: $0.user_id ?? "", tierNumber: $0.tier_number ?? 0, approvedAt: Int64($0.approved_at ?? "") ?? 0)
        }
        card.updatedAt = Int64(updated_at ?? "") ?? 0
        return card
    }
}

struct CardApprovalRaw: Codable {
    var user_id: String?
    var tier_number: Int?
    var approved_at: String?
}
