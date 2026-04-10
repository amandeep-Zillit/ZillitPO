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
    var workflowStatus: String = ""   // API "status" — workflow state for display (pending_coding, posted…)

    // Inbox matching fields
    var matchScore: Double? = nil
    var isUrgent: Bool = false
    var duplicateScore: Double? = nil
    var personalScore: Double? = nil
    var duplicateDismissed: Bool = false
    var personalDismissed: Bool = false
    var linkedMerchant: String = ""
    var linkedAmount: Double? = nil
    var linkedDate: Int64? = nil
    var linkedCardLast4: String = ""
    var transactionDate: Int64 = 0

    static func == (lhs: Receipt, rhs: Receipt) -> Bool { lhs.id == rhs.id }

    var displayMerchant: String {
        if let m = merchantDetected, !m.isEmpty { return m }
        return originalName
    }
    var displayAmount: Double { Double(amountDetected ?? "") ?? 0 }

    var statusDisplay: String {
        // Prefer workflowStatus (API "status" field) for display; fall back to matchStatus
        let s = workflowStatus.isEmpty ? matchStatus : workflowStatus
        switch s.lowercased() {
        case "pending", "pending_receipt":  return "Pending"
        case "pending_coding", "pending_code", "pending code": return "Pending Code"
        case "coded":                       return "Coded"
        case "suggested_match":             return "Suggested Match"
        case "matched":                     return "Matched"
        case "unmatched":                   return "No Match"
        case "duplicate":                   return "Duplicate"
        case "personal":                    return "Personal"
        case "approved":                    return "Approved"
        case "posted":                      return "Posted"
        default:                            return s.replacingOccurrences(of: "_", with: " ").capitalized
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

struct ReceiptRaw: Decodable {
    var id: String = ""
    var project_id: String?
    var uploader_id: String?
    var uploader_name: String?
    var uploader_department: String?
    var original_name: String?
    var file_path: String?
    var file_type: String?
    var file_size_bytes: Int?
    var match_status: String?
    var workflow_status: String?
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

    // Inbox matching fields
    var match_score: Double?
    var is_urgent: Bool?
    var duplicate_score: Double?
    var personal_score: Double?
    var duplicate_dismissed: Bool?
    var personal_dismissed: Bool?
    var linked_merchant: String?
    var linked_amount: Double?
    var linked_date: String?
    var linked_card_last4: String?

    struct AnyKey: CodingKey {
        var stringValue: String; var intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)

        // str() handles both JSON strings AND JSON numbers — critical for timestamps (unix ms)
        // and amounts that the API may send as numbers instead of strings.
        func str(_ keys: String...) -> String? {
            for k in keys {
                guard let key = AnyKey(stringValue: k) else { continue }
                if let v = try? c.decode(String.self, forKey: key), !v.isEmpty { return v }
                // API may send numeric timestamps — convert to string so callers can Int64() it
                if let v = try? c.decode(Int64.self, forKey: key) { return String(v) }
                if let v = try? c.decode(Double.self, forKey: key) { return String(v) }
            }
            return nil
        }
        func dbl(_ keys: String...) -> Double? {
            for k in keys {
                guard let key = AnyKey(stringValue: k) else { continue }
                if let v = try? c.decode(Double.self, forKey: key) { return v }
                if let s = try? c.decode(String.self, forKey: key), let v = Double(s) { return v }
            }
            return nil
        }
        func int(_ keys: String...) -> Int? {
            for k in keys {
                guard let key = AnyKey(stringValue: k) else { continue }
                if let v = try? c.decode(Int.self, forKey: key) { return v }
                if let d = try? c.decode(Double.self, forKey: key) { return Int(d) }
                if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { return v }
            }
            return nil
        }
        func bool(_ keys: String...) -> Bool? {
            for k in keys {
                guard let key = AnyKey(stringValue: k) else { continue }
                if let v = try? c.decode(Bool.self, forKey: key) { return v }
                if let i = try? c.decode(Int.self, forKey: key) { return i != 0 }
            }
            return nil
        }

        id              = str("id") ?? ""
        project_id      = str("project_id", "projectId")
        uploader_id     = str("uploader_id", "uploaderId", "user_id", "userId")
        uploader_name   = str("uploader_name", "uploaderName", "card_holder_name", "holder_name", "cardHolderName")
        uploader_department = str("uploader_department", "uploaderDepartment", "department_name", "departmentName")
        original_name   = str("original_name", "originalName", "filename", "file_name", "name")
        file_path       = str("file_path", "filePath", "url", "document_url", "file_url", "documentUrl")
        file_type       = str("file_type", "fileType", "mime_type", "mimeType")
        file_size_bytes = int("file_size_bytes", "fileSizeBytes", "file_size")
        match_status    = str("match_status", "matchStatus")
        workflow_status = str("status", "workflow_status", "workflowStatus", "receipt_status")
        transaction_id  = str("transaction_id", "transactionId")
        merchant_detected = str("merchant_detected", "merchantDetected", "merchant", "description")
        // amount_detected: API may send as number (e.g. 45.5) — str() now handles that
        amount_detected = str("amount_detected", "amountDetected", "amount")
        date_detected   = str("date_detected", "dateDetected", "date")
        nominal_code    = str("nominal_code", "nominalCode")
        upload_type     = str("upload_type", "uploadType", "type")
        reassign_count  = int("reassign_count", "reassignCount")
        // line_items: try both snake_case and camelCase keys
        for k in ["line_items", "lineItems", "items"] {
            if let key = AnyKey(stringValue: k),
               let decoded = try? c.decode([ReceiptLineItem].self, forKey: key) {
                line_items = decoded; break
            }
        }
        // history: try common key variants
        for k in ["history", "audit_trail", "auditTrail", "audit_history", "auditHistory"] {
            if let key = AnyKey(stringValue: k),
               let decoded = try? c.decode([ReceiptHistoryEntry].self, forKey: key) {
                history = decoded; break
            }
        }
        // timestamps: str() now returns numeric values as strings too
        created_at      = str("created_at", "createdAt", "uploaded_at", "uploadedAt")
        updated_at      = str("updated_at", "updatedAt")

        // Inbox matching
        match_score         = dbl("match_score", "matchScore")
        is_urgent           = bool("is_urgent", "isUrgent", "urgent")
        duplicate_score     = dbl("duplicate_score", "duplicateScore")
        personal_score      = dbl("personal_score", "personalScore")
        duplicate_dismissed = bool("duplicate_dismissed", "duplicateDismissed")
        personal_dismissed  = bool("personal_dismissed", "personalDismissed")
        linked_merchant     = str("linked_merchant", "linkedMerchant", "transaction_merchant", "transactionMerchant")
        linked_amount       = dbl("linked_amount", "linkedAmount", "transaction_amount", "transactionAmount")
        linked_date         = str("linked_date", "linkedDate", "transaction_date", "transactionDate",
                                  "linked_transaction_date", "linkedTransactionDate")
        linked_card_last4   = str("linked_card_last4", "linkedCardLast4", "transaction_card_last4",
                                  "transactionCardLast4", "card_last_four", "cardLastFour", "last_four")
    }

    // Parse a timestamp string that may be unix-ms integer, unix-ms float, or ISO date.
    // Returns 0 when the string is nil/empty/unparseable.
    private func ts64(_ s: String?) -> Int64 {
        guard let s = s, !s.isEmpty else { return 0 }
        if let i = Int64(s) { return i }                   // "1710000000000"
        if let d = Double(s) { return Int64(d) }           // "1710000000000.0"
        return 0                                           // ISO strings → 0 (view falls back to createdAt)
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
        r.workflowStatus = workflow_status ?? ""
        r.transactionId = transaction_id
        r.merchantDetected = merchant_detected
        r.amountDetected = amount_detected
        r.dateDetected = date_detected
        r.nominalCode = nominal_code
        r.uploadType = upload_type
        r.reassignCount = reassign_count ?? 0
        r.lineItems = line_items ?? []
        r.history = history ?? []
        r.createdAt = ts64(created_at)
        r.updatedAt = ts64(updated_at)
        // Inbox matching
        r.matchScore = match_score
        r.isUrgent = is_urgent ?? false
        r.duplicateScore = duplicate_score
        r.personalScore = personal_score
        r.duplicateDismissed = duplicate_dismissed ?? false
        r.personalDismissed = personal_dismissed ?? false
        r.linkedMerchant = linked_merchant ?? ""
        r.linkedAmount = linked_amount
        let ldVal = ts64(linked_date); r.linkedDate = ldVal > 0 ? ldVal : nil
        r.linkedCardLast4 = linked_card_last4 ?? ""
        // transactionDate: OCR-detected date (unix-ms string); if absent view falls back to createdAt
        let td = ts64(date_detected); r.transactionDate = td > 0 ? td : ts64(linked_date)
        return r
    }
}

// MARK: - Card Expense Metadata (from /api/v2/card-expenses/overview)

struct CardExpenseMeta: Decodable {
    var cardRegister: Int = 0
    var receiptInbox: Int = 0
    var allTransactions: Int = 0
    var pendingCoding: Int = 0
    var approvalQueue: Int = 0
    var topUps: Int = 0
    var history: Int = 0
    var smartAlerts: Int = 0
    var isCoordinator: Bool = false
    var coordinatorDeptIds: [String] = []

    struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
        init?(intValue: Int) { self.intValue = intValue; stringValue = "\(intValue)" }
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        func intFor(_ keys: String...) -> Int {
            for k in keys {
                if let key = AnyKey(stringValue: k) {
                    if let i = try? c.decode(Int.self, forKey: key) { return i }
                    if let d = try? c.decode(Double.self, forKey: key) { return Int(d) }
                    if let s = try? c.decode(String.self, forKey: key), let i = Int(s) { return i }
                }
            }
            return 0
        }
        func boolFor(_ keys: String...) -> Bool {
            for k in keys {
                if let key = AnyKey(stringValue: k) {
                    if let b = try? c.decode(Bool.self, forKey: key) { return b }
                    if let i = try? c.decode(Int.self, forKey: key) { return i != 0 }
                }
            }
            return false
        }
        cardRegister    = intFor("card_register", "cardRegister", "cards", "card_count")
        receiptInbox    = intFor("receipt_inbox", "receiptInbox", "inbox", "inbox_count")
        allTransactions = intFor("all_transactions", "allTransactions", "transactions", "transaction_count")
        pendingCoding   = intFor("pending_coding", "pendingCoding", "pending_queue", "pendingQueue")
        approvalQueue   = intFor("approval_queue", "approvalQueue", "approvals", "approval_count")
        topUps          = intFor("top_ups", "topUps", "topup", "topup_count", "topups")
        history         = intFor("history", "historyCount", "history_count", "posted", "posted_count")
        smartAlerts     = intFor("smart_alerts", "smartAlerts", "alerts", "alert_count", "active_alerts")
        isCoordinator   = boolFor("is_coordinator", "isCoordinator", "coordinator")
        if let key = AnyKey(stringValue: "coordinator_department_ids") {
            coordinatorDeptIds = (try? c.decode([String].self, forKey: key)) ?? []
        }
    }
}

// MARK: - Smart Alert (from /api/v2/card-expenses/alerts)

struct SmartAlert: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var type: String = ""           // anomaly | duplicate_risk | velocity | merchant
    var title: String = ""
    var alertDescription: String = ""
    var priority: String = ""       // high | medium | low
    var status: String = ""         // active | resolved | dismissed
    var detectedAt: Int64 = 0
    var resolvedAt: Int64 = 0
    var bsControlCode: String = ""
    var cardLastFour: String = ""
    var holderId: String = ""
    var holderName: String = ""
    var holderRole: String = ""
    var department: String = ""
    var amount: Double = 0
    var transactionId: String = ""
    var merchantName: String = ""
    var savings: Double = 0

    static func == (lhs: SmartAlert, rhs: SmartAlert) -> Bool { lhs.id == rhs.id }

    // Extract card last four from title as fallback: "Card ••••7733 at..." → "7733"
    var effectiveCardLastFour: String {
        if !cardLastFour.isEmpty { return cardLastFour }
        for marker in ["••••", "****"] {
            if let r = title.range(of: marker) {
                let after = String(title[r.upperBound...])
                let digits = after.prefix(4)
                if digits.count == 4 && digits.allSatisfy({ $0.isNumber }) { return String(digits) }
            }
        }
        return ""
    }

    // Meta line: ••••7733 · Sophie Turner (Catering Manager)
    var holderDisplay: String {
        var parts: [String] = []
        let last4 = effectiveCardLastFour
        if !last4.isEmpty { parts.append("••••\(last4)") }
        var nameStr = holderName
        if !holderRole.isEmpty { nameStr += " (\(holderRole))" }
        if !nameStr.isEmpty { parts.append(nameStr) }
        return parts.joined(separator: " · ")
    }

    // Best label for the transaction preview card header
    var transactionLabel: String {
        if !merchantName.isEmpty { return merchantName }
        if !bsControlCode.isEmpty { return "BS: \(bsControlCode)" }
        return ""
    }

    // Fallback: extract first £X.XX from description/title if amount not decoded
    var effectiveAmount: Double {
        if amount > 0 { return amount }
        let text = alertDescription.isEmpty ? title : alertDescription
        // Find first "£" followed by digits
        if let r = text.range(of: "£") {
            let after = String(text[r.upperBound...])
            let numStr = String(after.prefix(while: { $0.isNumber || $0 == "." || $0 == "," }))
            let cleaned = numStr.replacingOccurrences(of: ",", with: "")
            if let v = Double(cleaned), v > 0 { return v }
        }
        return 0
    }

    var hasTransactionData: Bool {
        effectiveAmount > 0 || !effectiveCardLastFour.isEmpty || !transactionId.isEmpty ||
        !bsControlCode.isEmpty || !merchantName.isEmpty || !holderName.isEmpty
    }

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
        default:       return priority.isEmpty ? "" : priority.capitalized
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
    var id: String = ""
    var type: String?
    var title: String?
    var description: String?
    var message: String?
    var priority: String?
    var status: String?
    var detected_at: String?
    var resolved_at: String?
    var bs_control_code: String?
    var card_last_four: String?
    var holder_id: String?
    var holder_name: String?
    var holder_designation: String?
    var department_id: String?
    var department_name: String?
    var amount: Double?
    var transaction_id: String?
    var merchant_name: String?
    var savings: Double?
    var created_at: String?

    struct AnyKey: CodingKey {
        var stringValue: String; var intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    }

    private static func str(_ c: KeyedDecodingContainer<AnyKey>, _ keys: [String]) -> String? {
        for k in keys { if let key = AnyKey(stringValue: k), let v = try? c.decode(String.self, forKey: key), !v.isEmpty { return v } }
        return nil
    }
    private static func dbl(_ c: KeyedDecodingContainer<AnyKey>, _ keys: [String]) -> Double? {
        for k in keys {
            guard let key = AnyKey(stringValue: k) else { continue }
            if let v = try? c.decode(Double.self, forKey: key) { return v }
            if let s = try? c.decode(String.self, forKey: key), let v = Double(s) { return v }
        }
        return nil
    }
    private static func bsCode(_ c: KeyedDecodingContainer<AnyKey>, _ keys: [String]) -> String? {
        for k in keys {
            guard let key = AnyKey(stringValue: k) else { continue }
            if let s = try? c.decode(String.self, forKey: key), !s.isEmpty { return s }
            if let i = try? c.decode(Int.self, forKey: key) { return String(i) }
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)

        id              = Self.str(c, ["id"]) ?? ""
        type            = Self.str(c, ["type", "alert_type", "alertType"])
        title           = Self.str(c, ["title", "name", "subject"])
        description     = Self.str(c, ["description", "detail", "details", "body", "content"])
        message         = Self.str(c, ["message", "msg"])
        // API uses "severity" not "priority"
        priority        = Self.str(c, ["severity", "priority", "level"])
        status          = Self.str(c, ["status", "state"])
        // API uses "timestamp" not "detected_at"
        if let s = Self.str(c, ["timestamp", "detected_at", "detectedAt", "created_at", "createdAt"]) {
            detected_at = s
        } else if let n = Self.dbl(c, ["timestamp", "detected_at", "detectedAt", "created_at", "createdAt"]) {
            detected_at = String(Int64(n))
        }
        resolved_at     = Self.str(c, ["resolved_at", "resolvedAt"])
        created_at      = Self.str(c, ["created_at", "createdAt"])
        savings         = Self.dbl(c, ["savings", "saving"])

        // Root-level transaction fields (may be absent — filled from relatedTxns below)
        bs_control_code = Self.bsCode(c, ["bs_control_code", "bsControlCode", "bs_code", "bsCode", "control_code", "controlCode"])
        card_last_four  = Self.str(c, ["card_last_four", "cardLastFour", "card_last4", "cardLast4", "last_four", "lastFour", "last4"])
        holder_id       = Self.str(c, ["holder_id", "holderId", "user_id", "userId", "card_holder_id", "cardHolderId"])
        holder_name     = Self.str(c, ["holder_name", "holderName", "card_holder_name", "cardHolderName"])
        department_id   = Self.str(c, ["department_id", "departmentId"])
        department_name = Self.str(c, ["department_name", "departmentName", "department"])
        amount          = Self.dbl(c, ["amount", "transaction_amount", "transactionAmount", "spent_amount", "spentAmount"])
        transaction_id  = Self.str(c, ["transaction_id", "transactionId", "receipt_id", "receiptId"])
        merchant_name   = Self.str(c, ["merchant_name", "merchantName", "merchant", "vendor"])

        // ── relatedTxns: array of linked transactions ──
        // Try as array first, then as single object
        // ── relatedTxns[0] keys: ["amount", "holder", "merchant", "ref"] ──
        if let txKey = AnyKey(stringValue: "relatedTxns"),
           var arr = try? c.nestedUnkeyedContainer(forKey: txKey), !arr.isAtEnd,
           let tx = try? arr.nestedContainer(keyedBy: AnyKey.self) {

            // "amount" → transaction amount
            if amount == nil { amount = Self.dbl(tx, ["amount"]) }

            // "ref" → BS control code / transaction reference
            if bs_control_code == nil { bs_control_code = Self.bsCode(tx, ["ref", "bs_control_code", "bsControlCode", "control_code"]) }

            // "merchant" → merchant name (string or nested object with "name")
            if merchant_name == nil {
                if let mn = Self.str(tx, ["merchant"]) {
                    merchant_name = mn
                } else if let mKey = AnyKey(stringValue: "merchant"),
                          let mObj = try? tx.nestedContainer(keyedBy: AnyKey.self, forKey: mKey) {
                    merchant_name = Self.str(mObj, ["name", "merchant_name", "merchantName"])
                }
            }

            // "holder" → card holder (string or nested object)
            if let hKey = AnyKey(stringValue: "holder") {
                if let holderStr = try? tx.decode(String.self, forKey: hKey), !holderStr.isEmpty {
                    // holder is a plain string — try as user ID first, otherwise use as name
                    if UsersData.byId[holderStr] != nil {
                        if holder_id == nil { holder_id = holderStr }
                    } else {
                        if holder_name == nil { holder_name = holderStr }
                    }
                } else if let h = try? tx.nestedContainer(keyedBy: AnyKey.self, forKey: hKey) {
                    if holder_id == nil {
                        holder_id = Self.str(h, ["id", "holder_id", "holderId", "user_id", "userId"])
                    }
                    if holder_name == nil {
                        holder_name = Self.str(h, ["name", "full_name", "fullName", "holder_name", "holderName", "display_name", "displayName"])
                    }
                    if holder_designation == nil {
                        holder_designation = Self.str(h, ["designation", "role", "title", "job_title", "jobTitle",
                                                          "position", "designation_name", "designationName"])
                    }
                    if card_last_four == nil {
                        card_last_four = Self.str(h, ["card_last_four", "cardLastFour", "last_four", "lastFour", "last4", "card_last4"])
                    }
                    if department_id == nil   { department_id   = Self.str(h, ["department_id", "departmentId"]) }
                    if department_name == nil { department_name = Self.str(h, ["department_name", "departmentName", "department"]) }
                }
            }
        }
    }

    func toSmartAlert() -> SmartAlert {
        var a = SmartAlert()
        a.id = id
        a.type = type ?? ""
        a.title = title ?? ""
        a.alertDescription = description ?? message ?? ""
        a.priority = priority ?? ""
        a.status = status ?? "active"
        a.detectedAt = Int64(detected_at ?? created_at ?? "") ?? 0
        a.resolvedAt = Int64(resolved_at ?? "") ?? 0
        a.bsControlCode = bs_control_code ?? ""
        a.cardLastFour = card_last_four ?? ""
        let uid = holder_id ?? ""
        a.holderId = uid
        a.holderName = UsersData.byId[uid]?.fullName ?? holder_name ?? (uid.isEmpty ? "" : uid)
        a.holderRole = UsersData.byId[uid]?.displayDesignation
            ?? FormatUtils.formatLabel(holder_designation ?? "")
            .trimmingCharacters(in: .whitespaces)
        if let name = department_name, !name.isEmpty {
            a.department = name
        } else if let dept = DepartmentsData.all.first(where: { $0.id == (department_id ?? "") }) {
            a.department = dept.displayName
        } else if let h = UsersData.byId[uid] {
            a.department = h.displayDepartment
        }
        a.amount = amount ?? 0
        a.transactionId = transaction_id ?? ""
        a.merchantName = merchant_name ?? ""
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
    var bs_control_code: String?  // may arrive as Int or String
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

    enum CodingKeys: String, CodingKey {
        case id, project_id, entity_id, entity_type, receipt_id
        case holder_name, card_last_four, amount, method, status
        case created_at, updated_at, note
        case card_id, user_id, department_id, bs_control_code
        case receipt_merchant, receipt_amount
        case card_balance, card_limit, card_spent
        case float_balance, float_issued, float_spent, float_req_number, float_status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        project_id       = try? c.decode(String.self, forKey: .project_id)
        entity_id        = try? c.decode(String.self, forKey: .entity_id)
        entity_type      = try? c.decode(String.self, forKey: .entity_type)
        receipt_id       = try? c.decode(String.self, forKey: .receipt_id)
        holder_name      = try? c.decode(String.self, forKey: .holder_name)
        card_last_four   = try? c.decode(String.self, forKey: .card_last_four)
        amount           = try? c.decode(Double.self, forKey: .amount)
        method           = try? c.decode(String.self, forKey: .method)
        status           = try? c.decode(String.self, forKey: .status)
        created_at       = try? c.decode(String.self, forKey: .created_at)
        updated_at       = try? c.decode(String.self, forKey: .updated_at)
        note             = try? c.decode(String.self, forKey: .note)
        card_id          = try? c.decode(String.self, forKey: .card_id)
        user_id          = try? c.decode(String.self, forKey: .user_id)
        department_id    = try? c.decode(String.self, forKey: .department_id)
        // bs_control_code may arrive as a JSON number or string
        if let s = try? c.decode(String.self, forKey: .bs_control_code), !s.isEmpty {
            bs_control_code = s
        } else if let i = try? c.decode(Int.self, forKey: .bs_control_code) {
            bs_control_code = String(i)
        } else {
            bs_control_code = nil
        }
        receipt_merchant = try? c.decode(String.self, forKey: .receipt_merchant)
        receipt_amount   = try? c.decode(String.self, forKey: .receipt_amount)
        card_balance     = try? c.decode(Double.self, forKey: .card_balance)
        card_limit       = try? c.decode(Double.self, forKey: .card_limit)
        card_spent       = try? c.decode(Double.self, forKey: .card_spent)
        float_balance    = try? c.decode(Double.self, forKey: .float_balance)
        float_issued     = try? c.decode(Double.self, forKey: .float_issued)
        float_spent      = try? c.decode(Double.self, forKey: .float_spent)
        float_req_number = try? c.decode(String.self, forKey: .float_req_number)
        float_status     = try? c.decode(String.self, forKey: .float_status)
    }

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
    var isUrgent: Bool = false
    var episode: String = ""
    var codeDescription: String = ""
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0

    // Inbox matching fields
    var matchScore: Double? = nil
    var linkedMerchant: String = ""
    var linkedAmount: Double? = nil
    var linkedDate: Int64? = nil
    var linkedCardLast4: String = ""

    static func == (lhs: CardTransaction, rhs: CardTransaction) -> Bool { lhs.id == rhs.id }

    var statusDisplay: String {
        switch status.lowercased() {
        case "pending", "pending_receipt": return "Pending Receipt"
        case "pending_coding", "pending_code", "pending code": return "Pending Code"
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
    // Inbox linked transaction fields (separate from receipt's own fields)
    var match_score: Double?
    var transaction_merchant_raw: String?
    var transaction_card_last4_raw: String?
    var transaction_amount_raw: Double?
    var transaction_date_raw: String?
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
        // Inbox linked-transaction fields (distinct from the receipt's own merchant/date/card_last_four)
        match_score = dbl("match_score", "matchScore")
        transaction_merchant_raw = str("transaction_merchant", "transactionMerchant")
        transaction_card_last4_raw = str("transaction_card_last4", "transactionCardLast4")
        transaction_amount_raw = dbl("transaction_amount", "transactionAmount")
        transaction_date_raw = str("transaction_date", "transactionDate")
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
        t.isUrgent = is_urgent ?? false
        // Inbox linked transaction fields
        t.matchScore = match_score
        t.linkedMerchant = transaction_merchant_raw ?? ""
        t.linkedAmount = transaction_amount_raw
        t.linkedDate = Int64(transaction_date_raw ?? "")
        t.linkedCardLast4 = transaction_card_last4_raw ?? ""
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

struct CardRaw: Decodable {
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
        // bs_control_code arrives as either a JSON string or a JSON number
        if let s = try? c.decode(String.self, forKey: .bs_control_code), !s.isEmpty {
            bs_control_code = s
        } else if let i = try? c.decode(Int.self, forKey: .bs_control_code) {
            bs_control_code = String(i)
        } else {
            bs_control_code = nil
        }
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

struct CardApprovalRaw: Decodable {
    var user_id: String?
    var tier_number: Int?
    var approved_at: String?

    struct AnyKey: CodingKey {
        var stringValue: String; var intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        // user id — try both snake and camel
        for k in ["user_id", "userId", "approved_by", "approvedBy"] {
            if let key = AnyKey(stringValue: k), let v = try? c.decode(String.self, forKey: key), !v.isEmpty {
                user_id = v; break
            }
        }
        // tier number — try Int then String→Int
        for k in ["tier_number", "tierNumber", "tier", "level"] {
            if let key = AnyKey(stringValue: k) {
                if let v = try? c.decode(Int.self, forKey: key) { tier_number = v; break }
                if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { tier_number = v; break }
            }
        }
        // approved_at — try String then number
        for k in ["approved_at", "approvedAt", "approved_time", "timestamp"] {
            if let key = AnyKey(stringValue: k) {
                if let s = try? c.decode(String.self, forKey: key), !s.isEmpty { approved_at = s; break }
                if let n = try? c.decode(Double.self, forKey: key) { approved_at = String(Int64(n)); break }
            }
        }
    }
}

// MARK: - Pending Coding Item (from /api/v2/card-expenses/receipts/pending-coding)

struct PendingCodingItem: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var projectId: String = ""
    var userId: String = ""
    var status: String = ""             // pending_code, pending_receipt
    var transactionId: String? = nil
    var description: String = ""
    var amount: Double = 0
    var date: Int64 = 0
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0
    var nominalCode: String? = nil
    var history: [PendingCodingHistory] = []
    var departmentId: String? = nil
    var episode: String? = nil
    var codeDescription: String? = nil
    var matchStatus: String = ""
    var receiptAttachment: PendingCodingAttachment? = nil
    var processingFlags: [ProcessingFlag] = []
    var isUrgent: Bool = false
    var requestTopUp: Bool = false
    var taxAmount: Double? = nil
    var netAmount: Double? = nil
    var grossAmount: Double? = nil

    static func == (lhs: PendingCodingItem, rhs: PendingCodingItem) -> Bool { lhs.id == rhs.id }

    var userName: String { UsersData.byId[userId]?.fullName ?? userId }
    var userDepartment: String {
        if let deptId = departmentId, let dept = DepartmentsData.all.first(where: { $0.id == deptId }) {
            return dept.displayName
        }
        return UsersData.byId[userId]?.displayDepartment ?? ""
    }

    var statusDisplay: String {
        switch status.lowercased() {
        case "pending_code", "pending_coding", "pending code": return "Needs Coding"
        case "pending_receipt": return "Awaiting Receipt"
        case "coded":           return "Coded"
        case "posted":          return "Posted"
        default:                return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
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
}

struct PendingCodingAttachment: Codable, Equatable {
    var id: String?
    var name: String?
}

struct ProcessingFlag: Codable, Equatable {
    var flag: String?           // review, query, deduct
    var title: String?
    var ruleId: String?
    var description: String?
    var processType: String?    // senior_review, need_query, deduct_amount
    var thresholdType: String?  // min_amount, percentage
    var thresholdValue: Double?

    var flagColor: String {
        switch flag?.lowercased() {
        case "review": return "purple"
        case "query":  return "orange"
        case "deduct": return "red"
        default:       return "gray"
        }
    }
}

// MARK: - Pending Coding Item Raw (API)

struct PendingCodingItemRaw: Codable {
    var id: String
    var project_id: String?
    var user_id: String?
    var status: String?
    var transaction_id: String?
    var description: String?
    var amount: String?
    var date: String?
    var created_at: String?
    var updated_at: String?
    var nominal_code: String?
    var history: [PendingCodingHistoryRaw]?
    var department_id: String?
    var episode: String?
    var code_description: String?
    var match_status: String?
    var receipt_attachment: PendingCodingAttachmentRaw?
    var processing_flags: [ProcessingFlagRaw]?
    var is_urgent: Bool?
    var request_top_up: Bool?
    var tax_amount: AnyCodableValue?
    var net_amount: AnyCodableValue?
    var gross_amount: AnyCodableValue?

    func toPendingCodingItem() -> PendingCodingItem {
        var item = PendingCodingItem()
        item.id = id
        item.projectId = project_id ?? ""
        item.userId = user_id ?? ""
        item.status = status ?? ""
        item.transactionId = transaction_id
        item.description = description ?? ""
        item.amount = Double(amount ?? "") ?? 0
        item.date = Int64(date ?? "") ?? 0
        item.createdAt = Int64(created_at ?? "") ?? 0
        item.updatedAt = Int64(updated_at ?? "") ?? 0
        item.nominalCode = nominal_code
        item.history = (history ?? []).map { $0.toPendingCodingHistory() }
        item.departmentId = department_id
        item.episode = episode
        item.codeDescription = code_description
        item.matchStatus = match_status ?? ""
        item.receiptAttachment = receipt_attachment?.toAttachment()
        item.processingFlags = (processing_flags ?? []).map { $0.toProcessingFlag() }
        item.isUrgent = is_urgent ?? false
        item.requestTopUp = request_top_up ?? false
        item.taxAmount = tax_amount?.doubleValue
        item.netAmount = net_amount?.doubleValue
        item.grossAmount = gross_amount?.doubleValue
        return item
    }
}

struct PendingCodingHistoryRaw: Codable {
    var action: String?
    var action_at: Int64?
    var action_by: String?

    func toPendingCodingHistory() -> PendingCodingHistory {
        PendingCodingHistory(action: action, actionAt: action_at, actionBy: action_by)
    }
}

struct PendingCodingAttachmentRaw: Codable {
    var id: String?
    var name: String?

    func toAttachment() -> PendingCodingAttachment {
        PendingCodingAttachment(id: id, name: name)
    }
}

struct ProcessingFlagRaw: Codable {
    var flag: String?
    var title: String?
    var rule_id: String?
    var description: String?
    var process_type: String?
    var threshold_type: String?
    var threshold_value: AnyCodableValue?

    func toProcessingFlag() -> ProcessingFlag {
        ProcessingFlag(
            flag: flag, title: title, ruleId: rule_id, description: description,
            processType: process_type, thresholdType: threshold_type,
            thresholdValue: threshold_value?.doubleValue
        )
    }
}

// MARK: - Bank Accounts

struct BankAccountAdditionalDetail: Codable, Equatable {
    var field: String
    var value: String
}

struct ProductionBankAccount: Identifiable, Equatable {
    var id: String
    var name: String
    var accountNumber: String
    var accountHolderName: String
    var sortCode: String?
    var ibanNumber: String?
    var swiftCode: String?
    var nominalCode: String?
    var accPayableCode: String?
    var paymentPrefix: String?
    var entityType: String
    var additionalDetails: [BankAccountAdditionalDetail]
}

struct ProductionBankAccountRaw: Codable {
    var id: String?
    var name: String?
    var account_number: String?
    var account_holder_name: String?
    var sort_code: String?
    var iban_number: String?
    var swift_code: String?
    var nominal_code: String?
    var acc_payable_code: String?
    var payment_prefix: String?
    var entity_type: String?
    var additional_details: [BankAccountAdditionalDetail]?

    func toProductionBankAccount() -> ProductionBankAccount {
        ProductionBankAccount(
            id: id ?? UUID().uuidString,
            name: name ?? "",
            accountNumber: account_number ?? "",
            accountHolderName: account_holder_name ?? "",
            sortCode: sort_code,
            ibanNumber: iban_number,
            swiftCode: swift_code,
            nominalCode: nominal_code,
            accPayableCode: acc_payable_code,
            paymentPrefix: payment_prefix,
            entityType: entity_type ?? "production",
            additionalDetails: additional_details ?? []
        )
    }
}
