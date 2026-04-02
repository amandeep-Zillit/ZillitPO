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
