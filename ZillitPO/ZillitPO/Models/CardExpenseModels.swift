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

// MARK: - Card (Domain model)

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
    var approvals: [Approval] = []
    var rejectedBy: String?
    var rejectionReason: String?
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0

    static func == (lhs: ExpenseCard, rhs: ExpenseCard) -> Bool { lhs.id == rhs.id }

    var spentAmount: Double { max(monthlyLimit - currentBalance, 0) }
    var spendPercent: Double { monthlyLimit > 0 ? spentAmount / monthlyLimit : 0 }

    var statusDisplay: String {
        switch status {
        case "active": return "Active"
        case "requested": return "Requested"
        case "pending": return "Pending"
        case "rejected": return "Rejected"
        case "in_transit": return "In Transit"
        case "digital_active": return "Digital Active"
        case "inactive": return "Inactive"
        case "suspended": return "Suspended"
        default: return status.capitalized
        }
    }

    var issuerDisplay: String {
        switch cardIssuer.lowercased() {
        case "barclays": return "Barclays"
        case "equals": return "Equals"
        case "revolut": return "Revolut"
        default: return cardIssuer.isEmpty ? "—" : cardIssuer
        }
    }
}

// MARK: - Card Raw (API response)

struct CardRaw: Codable {
    var id: String
    var project_id: String?
    var holder_id: String?
    var holder_name: String?
    var department: String?
    var department_id: String?
    var status: String?
    var last_four: String?
    var card_issuer: String?
    var monthly_limit: Double?
    var current_balance: Double?
    var proposed_limit: Double?
    var approvals: [CardApprovalRaw]?
    var rejected_by: String?
    var rejection_reason: String?
    var created_at: String?
    var updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, project_id, holder_id, holder_name, department, department_id
        case status, last_four, card_issuer, monthly_limit, current_balance, proposed_limit
        case approvals, rejected_by, rejection_reason, created_at, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        project_id = try? c.decode(String.self, forKey: .project_id)
        holder_id = try? c.decode(String.self, forKey: .holder_id)
        holder_name = try? c.decode(String.self, forKey: .holder_name)
        department = try? c.decode(String.self, forKey: .department)
        department_id = try? c.decode(String.self, forKey: .department_id)
        status = try? c.decode(String.self, forKey: .status)
        last_four = try? c.decode(String.self, forKey: .last_four)
        card_issuer = try? c.decode(String.self, forKey: .card_issuer)
        rejected_by = try? c.decode(String.self, forKey: .rejected_by)
        rejection_reason = try? c.decode(String.self, forKey: .rejection_reason)
        approvals = try? c.decode([CardApprovalRaw].self, forKey: .approvals)
        monthly_limit = flexibleDoubleDecode(c, .monthly_limit)
        current_balance = flexibleDoubleDecode(c, .current_balance)
        proposed_limit = flexibleDoubleDecode(c, .proposed_limit)
        created_at = try? c.decode(String.self, forKey: .created_at)
        updated_at = try? c.decode(String.self, forKey: .updated_at)
    }

    func toCard() -> ExpenseCard {
        var card = ExpenseCard()
        card.id = id
        card.projectId = project_id ?? ""
        card.holderId = holder_id ?? ""
        card.holderName = holder_name ?? ""
        card.department = department ?? ""
        card.departmentId = department_id ?? ""
        card.status = status ?? "requested"
        card.lastFour = last_four ?? ""
        card.cardIssuer = card_issuer ?? ""
        card.monthlyLimit = monthly_limit ?? 0
        card.currentBalance = current_balance ?? 0
        card.proposedLimit = proposed_limit ?? 0
        card.approvals = (approvals ?? []).map {
            Approval(userId: $0.user_id ?? "", tierNumber: $0.tier_number ?? 0, approvedAt: Int64($0.approved_at ?? "") ?? 0)
        }
        card.rejectedBy = rejected_by
        card.rejectionReason = rejection_reason
        card.createdAt = Int64(created_at ?? "") ?? 0
        card.updatedAt = Int64(updated_at ?? "") ?? 0
        return card
    }
}

struct CardApprovalRaw: Codable {
    var user_id: String?
    var tier_number: Int?
    var approved_at: String?
}
