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
    var projectId: String?
    var uploaderId: String?
    var uploaderName: String?
    var uploaderDepartment: String?
    var originalName: String?
    var filePath: String?
    var fileType: String?
    var fileSizeBytes: Int?
    var matchStatus: String?
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
    var workflowStatus: String?   // API "status" — workflow state for display (pending_coding, posted…)

    // Inbox matching fields
    var matchScore: Double? = nil
    var isUrgent: Bool?
    var duplicateScore: Double? = nil
    var personalScore: Double? = nil
    var duplicateDismissed: Bool?
    var personalDismissed: Bool?
    var linkedMerchant: String?
    var linkedAmount: Double? = nil
    var linkedDate: Int64? = nil
    var linkedCardLast4: String?
    var transactionDate: Int64?

    static func == (lhs: Receipt, rhs: Receipt) -> Bool { lhs.id == rhs.id }

    var displayMerchant: String {
        if let m = merchantDetected, !m.isEmpty { return m }
        return originalName ?? ""
    }
    var displayAmount: Double { Double(amountDetected ?? "") ?? 0 }

    var statusDisplay: String {
        // Prefer workflowStatus (API "status" field) for display; fall back to matchStatus
        let ws = workflowStatus ?? ""
        let ms = matchStatus ?? ""
        let s = ws.isEmpty ? ms : ws
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
        if (fileSizeBytes ?? 0) > 0 { return "\((fileSizeBytes ?? 0) / 1024) KB" }
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

// MARK: - Card History Entry (full detail)

struct CardHistoryEntry: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var action: String?
    var details: String?
    var actionBy: String?       // user id
    var actionByName: String?   // resolved name (from UsersData)
    var timestamp: Int64?
    var tierNumber: Int? = nil
    var reason: String?
    var oldValue: String?
    var newValue: String?
    var field: String?

    static func == (lhs: CardHistoryEntry, rhs: CardHistoryEntry) -> Bool {
        lhs.id == rhs.id && lhs.timestamp == rhs.timestamp
    }
}

struct CardHistoryEntryRaw: Decodable {
    var action: String?
    var details: String?
    var actionBy: String?
    var actionAt: Int64?
    var timestamp: Int64?
    var tierNumber: Int?
    var reason: String?
    var oldValue: String?
    var newValue: String?
    var field: String?

    struct AnyKey: CodingKey {
        var stringValue: String; var intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        func str(_ keys: String...) -> String? {
            for k in keys {
                guard let key = AnyKey(stringValue: k) else { continue }
                if let v = try? c.decode(String.self, forKey: key), !v.isEmpty { return v }
                if let v = try? c.decode(Int64.self, forKey: key) { return String(v) }
                if let v = try? c.decode(Double.self, forKey: key) { return String(v) }
            }
            return nil
        }
        func int64(_ keys: String...) -> Int64? {
            for k in keys {
                guard let key = AnyKey(stringValue: k) else { continue }
                if let v = try? c.decode(Int64.self, forKey: key) { return v }
                if let d = try? c.decode(Double.self, forKey: key) { return Int64(d) }
                if let s = try? c.decode(String.self, forKey: key), let v = Int64(s) { return v }
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

        action      = str("action")
        details     = str("details", "description")
        actionBy   = str("action_by", "actionBy", "user_id", "userId", "by")
        actionAt   = int64("action_at", "actionAt", "timestamp")
        timestamp   = int64("timestamp", "action_at")
        tierNumber = int("tier_number", "tierNumber", "tier")
        reason      = str("reason")
        oldValue   = str("old_value", "oldValue", "from")
        newValue   = str("new_value", "newValue", "to")
        field       = str("field", "key")
    }

    func toEntry() -> CardHistoryEntry {
        var e = CardHistoryEntry()
        e.action = action
        e.details = details
        e.actionBy = actionBy
        e.timestamp = actionAt ?? timestamp
        e.tierNumber = tierNumber
        e.reason = reason
        e.oldValue = oldValue
        e.newValue = newValue
        e.field = field
        // Resolve user name
        if let by = actionBy, !by.isEmpty {
            e.actionByName = UsersData.byId[by]?.fullName ?? by
        }
        return e
    }
}

// MARK: - Receipt Raw (API response)

struct ReceiptRaw: Decodable {
    var id: String = ""
    var projectId: String?
    var uploaderId: String?
    var uploaderName: String?
    var uploaderDepartment: String?
    var originalName: String?
    var filePath: String?
    var fileType: String?
    var fileSizeBytes: Int?
    var matchStatus: String?
    var workflowStatus: String?
    var transactionId: String?
    var merchantDetected: String?
    var amountDetected: String?
    var dateDetected: String?
    var nominalCode: String?
    var uploadType: String?
    var reassignCount: Int?
    var lineItems: [ReceiptLineItem]?
    var history: [ReceiptHistoryEntry]?
    var createdAt: String?
    var updatedAt: String?

    // Inbox matching fields
    var matchScore: Double?
    var isUrgent: Bool?
    var duplicateScore: Double?
    var personalScore: Double?
    var duplicateDismissed: Bool?
    var personalDismissed: Bool?
    var linkedMerchant: String?
    var linkedAmount: Double?
    var linkedDate: String?
    var linkedCardLast4: String?

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
        projectId      = str("project_id", "projectId")
        uploaderId     = str("uploader_id", "uploaderId", "user_id", "userId")
        uploaderName   = str("uploader_name", "uploaderName", "card_holder_name", "holder_name", "cardHolderName")
        uploaderDepartment = str("uploader_department", "uploaderDepartment", "department_name", "departmentName")
        originalName   = str("original_name", "originalName", "filename", "file_name", "name")
        filePath       = str("file_path", "filePath", "url", "document_url", "file_url", "documentUrl")
        fileType       = str("file_type", "fileType", "mime_type", "mimeType")
        fileSizeBytes = int("file_size_bytes", "fileSizeBytes", "file_size")
        matchStatus    = str("match_status", "matchStatus")
        workflowStatus = str("status", "workflow_status", "workflowStatus", "receipt_status")
        transactionId  = str("transaction_id", "transactionId")
        merchantDetected = str("merchant_detected", "merchantDetected", "merchant", "description")
        // amountDetected: API may send as number (e.g. 45.5) — str() now handles that
        amountDetected = str("amount_detected", "amountDetected", "amount")
        dateDetected   = str("date_detected", "dateDetected", "date")
        nominalCode    = str("nominal_code", "nominalCode")
        uploadType     = str("upload_type", "uploadType", "type")
        reassignCount  = int("reassign_count", "reassignCount")
        // lineItems: try both snake_case and camelCase keys
        for k in ["line_items", "lineItems", "items"] {
            if let key = AnyKey(stringValue: k),
               let decoded = try? c.decode([ReceiptLineItem].self, forKey: key) {
                lineItems = decoded; break
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
        createdAt      = str("created_at", "createdAt", "uploaded_at", "uploadedAt")
        updatedAt      = str("updated_at", "updatedAt")

        // Inbox matching
        matchScore         = dbl("match_score", "matchScore")
        isUrgent           = bool("is_urgent", "isUrgent", "urgent")
        duplicateScore     = dbl("duplicate_score", "duplicateScore")
        personalScore      = dbl("personal_score", "personalScore")
        duplicateDismissed = bool("duplicate_dismissed", "duplicateDismissed")
        personalDismissed  = bool("personal_dismissed", "personalDismissed")
        linkedMerchant     = str("linked_merchant", "linkedMerchant", "transaction_merchant", "transactionMerchant")
        linkedAmount       = dbl("linked_amount", "linkedAmount", "transaction_amount", "transactionAmount")
        linkedDate         = str("linked_date", "linkedDate", "transaction_date", "transactionDate",
                                  "linked_transaction_date", "linkedTransactionDate")
        linkedCardLast4   = str("linked_card_last4", "linkedCardLast4", "transaction_card_last4",
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
        r.projectId = projectId
        r.uploaderId = uploaderId
        r.uploaderName = uploaderName
        r.uploaderDepartment = uploaderDepartment
        r.originalName = originalName
        r.filePath = filePath
        r.fileType = fileType
        r.fileSizeBytes = fileSizeBytes
        r.matchStatus = matchStatus ?? "pending"
        r.workflowStatus = workflowStatus
        r.transactionId = transactionId
        r.merchantDetected = merchantDetected
        r.amountDetected = amountDetected
        r.dateDetected = dateDetected
        r.nominalCode = nominalCode
        r.uploadType = uploadType
        r.reassignCount = reassignCount
        r.lineItems = lineItems
        r.history = history
        r.createdAt = ts64(createdAt)
        r.updatedAt = ts64(updatedAt)
        // Inbox matching
        r.matchScore = matchScore
        r.isUrgent = isUrgent
        r.duplicateScore = duplicateScore
        r.personalScore = personalScore
        r.duplicateDismissed = duplicateDismissed
        r.personalDismissed = personalDismissed
        r.linkedMerchant = linkedMerchant
        r.linkedAmount = linkedAmount
        let ldVal = ts64(linkedDate); r.linkedDate = ldVal > 0 ? ldVal : nil
        r.linkedCardLast4 = linkedCardLast4
        // transactionDate: OCR-detected date (unix-ms string); if absent view falls back to createdAt
        let td = ts64(dateDetected); r.transactionDate = td > 0 ? td : ts64(linkedDate)
        return r
    }
}

// MARK: - Card Expense Metadata (from /api/v2/card-expenses/overview)

struct CardExpenseMeta: Decodable {
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

    struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
        init?(intValue: Int) { self.intValue = intValue; stringValue = "\(intValue)" }
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        func intFor(_ keys: String...) -> Int? {
            for k in keys {
                if let key = AnyKey(stringValue: k) {
                    if let i = try? c.decode(Int.self, forKey: key) { return i }
                    if let d = try? c.decode(Double.self, forKey: key) { return Int(d) }
                    if let s = try? c.decode(String.self, forKey: key), let i = Int(s) { return i }
                }
            }
            return nil
        }
        func boolFor(_ keys: String...) -> Bool? {
            for k in keys {
                if let key = AnyKey(stringValue: k) {
                    if let b = try? c.decode(Bool.self, forKey: key) { return b }
                    if let i = try? c.decode(Int.self, forKey: key) { return i != 0 }
                }
            }
            return nil
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
            coordinatorDeptIds = (try? c.decode([String].self, forKey: key))
        }
    }
}

// MARK: - Smart Alert (from /api/v2/card-expenses/alerts)

struct SmartAlert: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var type: String?           // anomaly | duplicate_risk | velocity | merchant
    var title: String?
    var alertDescription: String?
    var priority: String?       // high | medium | low
    var status: String?         // active | resolved | dismissed
    var detectedAt: Int64?
    var resolvedAt: Int64?
    var bsControlCode: String?
    var cardLastFour: String?
    var holderId: String?
    var holderName: String?
    var holderRole: String?
    var department: String?
    var amount: Double?
    var transactionId: String?
    var merchantName: String?
    var savings: Double?
    var resolution: String?

    static func == (lhs: SmartAlert, rhs: SmartAlert) -> Bool { lhs.id == rhs.id }

    // Extract card last four from title as fallback: "Card ••••7733 at..." → "7733"
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

    // Meta line: ••••7733 · Sophie Turner (Catering Manager)
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

    // Best label for the transaction preview card header
    var transactionLabel: String {
        if let m = merchantName, !m.isEmpty { return m }
        if let b = bsControlCode, !b.isEmpty { return "BS: \(b)" }
        return ""
    }

    // Fallback: extract first £X.XX from description/title if amount not decoded
    var effectiveAmount: Double {
        if (amount ?? 0) > 0 { return amount! }
        let text = (alertDescription ?? "").isEmpty ? (title ?? "") : (alertDescription ?? "")
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
        effectiveAmount > 0 || !effectiveCardLastFour.isEmpty || !(transactionId ?? "").isEmpty ||
        !(bsControlCode ?? "").isEmpty || !(merchantName ?? "").isEmpty || !(holderName ?? "").isEmpty
    }

    var typeDisplay: String {
        switch (type ?? "").lowercased() {
        case "anomaly":        return "Anomaly"
        case "duplicate_risk", "duplicate": return "Duplicate Risk"
        case "velocity":       return "Velocity"
        case "merchant":       return "Merchant"
        default:               return (type ?? "").capitalized
        }
    }

    var priorityDisplay: String {
        let p = priority ?? ""
        switch p.lowercased() {
        case "high":   return "High Priority"
        case "medium": return "Medium Priority"
        case "low":    return "Low Priority"
        default:       return p.isEmpty ? "" : p.capitalized
        }
    }

    var statusDisplay: String {
        switch (status ?? "").lowercased() {
        case "active":    return "Active"
        case "resolved":  return "Resolved"
        case "dismissed": return "Dismissed"
        default:          return (status ?? "").capitalized
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
    var detectedAt: String?
    var resolvedAt: String?
    var bsControlCode: String?
    var cardLastFour: String?
    var holderId: String?
    var holderName: String?
    var holderDesignation: String?
    var departmentId: String?
    var departmentName: String?
    var amount: Double?
    var transactionId: String?
    var merchantName: String?
    var savings: Double?
    var resolution: String?
    var createdAt: String?

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
        // API uses "timestamp" not "detectedAt"
        if let s = Self.str(c, ["timestamp", "detected_at", "detectedAt", "created_at", "createdAt"]) {
            detectedAt = s
        } else if let n = Self.dbl(c, ["timestamp", "detected_at", "detectedAt", "created_at", "createdAt"]) {
            detectedAt = String(Int64(n))
        }
        resolvedAt     = Self.str(c, ["resolved_at", "resolvedAt"])
        createdAt      = Self.str(c, ["created_at", "createdAt"])
        savings         = Self.dbl(c, ["savings", "saving"])

        // Root-level transaction fields (may be absent — filled from relatedTxns below)
        bsControlCode = Self.bsCode(c, ["bs_control_code", "bsControlCode", "bs_code", "bsCode", "control_code", "controlCode"])
        cardLastFour  = Self.str(c, ["card_last_four", "cardLastFour", "card_last4", "cardLast4", "last_four", "lastFour", "last4"])
        holderId       = Self.str(c, ["holder_id", "holderId", "user_id", "userId", "card_holder_id", "cardHolderId"])
        holderName     = Self.str(c, ["holder_name", "holderName", "card_holder_name", "cardHolderName"])
        departmentId   = Self.str(c, ["department_id", "departmentId"])
        departmentName = Self.str(c, ["department_name", "departmentName", "department"])
        amount          = Self.dbl(c, ["amount", "transaction_amount", "transactionAmount", "spent_amount", "spentAmount"])
        transactionId  = Self.str(c, ["transaction_id", "transactionId", "receipt_id", "receiptId"])
        merchantName   = Self.str(c, ["merchant_name", "merchantName", "merchant", "vendor"])
        resolution      = Self.str(c, ["resolution", "resolution_note", "resolutionNote", "resolve_note", "resolveNote"])

        // ── relatedTxns: array of linked transactions ──
        // Try as array first, then as single object
        // ── relatedTxns[0] keys: ["amount", "holder", "merchant", "ref"] ──
        if let txKey = AnyKey(stringValue: "relatedTxns"),
           var arr = try? c.nestedUnkeyedContainer(forKey: txKey), !arr.isAtEnd,
           let tx = try? arr.nestedContainer(keyedBy: AnyKey.self) {

            // "amount" → transaction amount
            if amount == nil { amount = Self.dbl(tx, ["amount"]) }

            // "ref" → BS control code / transaction reference
            if bsControlCode == nil { bsControlCode = Self.bsCode(tx, ["ref", "bs_control_code", "bsControlCode", "control_code"]) }

            // "merchant" → merchant name (string or nested object with "name")
            if merchantName == nil {
                if let mn = Self.str(tx, ["merchant"]) {
                    merchantName = mn
                } else if let mKey = AnyKey(stringValue: "merchant"),
                          let mObj = try? tx.nestedContainer(keyedBy: AnyKey.self, forKey: mKey) {
                    merchantName = Self.str(mObj, ["name", "merchant_name", "merchantName"])
                }
            }

            // "holder" → card holder (string or nested object)
            if let hKey = AnyKey(stringValue: "holder") {
                if let holderStr = try? tx.decode(String.self, forKey: hKey), !holderStr.isEmpty {
                    // holder is a plain string — try as user ID first, otherwise use as name
                    if UsersData.byId[holderStr] != nil {
                        if holderId == nil { holderId = holderStr }
                    } else {
                        if holderName == nil { holderName = holderStr }
                    }
                } else if let h = try? tx.nestedContainer(keyedBy: AnyKey.self, forKey: hKey) {
                    if holderId == nil {
                        holderId = Self.str(h, ["id", "holder_id", "holderId", "user_id", "userId"])
                    }
                    if holderName == nil {
                        holderName = Self.str(h, ["name", "full_name", "fullName", "holder_name", "holderName", "display_name", "displayName"])
                    }
                    if holderDesignation == nil {
                        holderDesignation = Self.str(h, ["designation", "role", "title", "job_title", "jobTitle",
                                                          "position", "designation_name", "designationName"])
                    }
                    if cardLastFour == nil {
                        cardLastFour = Self.str(h, ["card_last_four", "cardLastFour", "last_four", "lastFour", "last4", "card_last4"])
                    }
                    if departmentId == nil   { departmentId   = Self.str(h, ["department_id", "departmentId"]) }
                    if departmentName == nil { departmentName = Self.str(h, ["department_name", "departmentName", "department"]) }
                }
            }
        }
    }

    func toSmartAlert() -> SmartAlert {
        var a = SmartAlert()
        a.id = id
        a.type = type
        a.title = title
        a.alertDescription = description ?? message
        a.priority = priority
        a.status = status ?? "active"
        a.detectedAt = Int64(detectedAt ?? createdAt ?? "") ?? 0
        a.resolvedAt = Int64(resolvedAt ?? "") ?? 0
        a.bsControlCode = bsControlCode
        a.cardLastFour = cardLastFour
        let uid = holderId ?? ""
        a.holderId = uid
        a.holderName = UsersData.byId[uid]?.fullName ?? holderName ?? (uid.isEmpty ? nil : uid)
        a.holderRole = UsersData.byId[uid]?.displayDesignation
            ?? FormatUtils.formatLabel(holderDesignation ?? "")
            .trimmingCharacters(in: .whitespaces)
        if let name = departmentName, !name.isEmpty {
            a.department = name
        } else if let dept = DepartmentsData.all.first(where: { $0.id == (departmentId ?? "") }) {
            a.department = dept.displayName
        } else if let h = UsersData.byId[uid] {
            a.department = h.displayDepartment
        }
        a.amount = amount
        a.transactionId = transactionId
        a.merchantName = merchantName
        a.savings = savings
        a.resolution = resolution
        return a
    }
}

// MARK: - Top-Up Item (from /api/v2/card-expenses/topups)

struct TopUpItem: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var entityType: String?        // "card" or "cash"
    var entityId: String?
    var receiptId: String?
    var cardId: String?
    var cardLastFour: String?
    var userId: String?
    var holderName: String?
    var departmentId: String?
    var department: String?
    var amount: Double?
    var method: String?             // top_up, restore, expense
    var status: String?             // skipped, completed, partial, pending
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
    var uploadType: String?         // "urgent" marks the parent receipt as urgent
    var createdAt: Int64?
    var updatedAt: Int64?

    var isUrgent: Bool { (uploadType ?? "").lowercased() == "urgent" }

    static func == (lhs: TopUpItem, rhs: TopUpItem) -> Bool { lhs.id == rhs.id }

    var statusDisplay: String {
        switch (status ?? "").lowercased() {
        case "completed": return "Completed"
        case "skipped":   return "Skipped"
        case "partial":   return "Partial"
        case "pending":   return "Pending"
        default:          return (status ?? "").capitalized
        }
    }

    var methodDisplay: String {
        switch (method ?? "").lowercased() {
        case "top_up":  return "Top-Up"
        case "restore": return "Restore"
        case "expense": return "Expense"
        default:        return (method ?? "").capitalized
        }
    }
}

struct TopUpItemRaw: Decodable {
    var id: String
    var projectId: String?
    var entityId: String?
    var entityType: String?
    var receiptId: String?
    var holderName: String?
    var cardLastFour: String?
    var amount: Double?
    var method: String?
    var status: String?
    var createdAt: String?
    var updatedAt: String?
    var note: String?
    var cardId: String?
    var userId: String?
    var departmentId: String?
    var bsControlCode: String?  // may arrive as Int or String
    var receiptMerchant: String?
    var receiptAmount: String?
    var cardBalance: Double?
    var cardLimit: Double?
    var cardSpent: Double?
    var floatBalance: Double?
    var floatIssued: Double?
    var floatSpent: Double?
    var floatReqNumber: String?
    var floatStatus: String?
    var uploadType: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, method, status, note
        case projectId = "project_id"
        case entityId = "entity_id"
        case entityType = "entity_type"
        case receiptId = "receipt_id"
        case holderName = "holder_name"
        case cardLastFour = "card_last_four"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case cardId = "card_id"
        case userId = "user_id"
        case departmentId = "department_id"
        case bsControlCode = "bs_control_code"
        case receiptMerchant = "receipt_merchant"
        case receiptAmount = "receipt_amount"
        case cardBalance = "card_balance"
        case cardLimit = "card_limit"
        case cardSpent = "card_spent"
        case floatBalance = "float_balance"
        case floatIssued = "float_issued"
        case floatSpent = "float_spent"
        case floatReqNumber = "float_req_number"
        case floatStatus = "float_status"
        case uploadType = "upload_type"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        projectId        = try? c.decode(String.self, forKey: .projectId)
        entityId         = try? c.decode(String.self, forKey: .entityId)
        entityType       = try? c.decode(String.self, forKey: .entityType)
        receiptId        = try? c.decode(String.self, forKey: .receiptId)
        holderName       = try? c.decode(String.self, forKey: .holderName)
        cardLastFour     = try? c.decode(String.self, forKey: .cardLastFour)
        amount           = try? c.decode(Double.self, forKey: .amount)
        method           = try? c.decode(String.self, forKey: .method)
        status           = try? c.decode(String.self, forKey: .status)
        createdAt        = try? c.decode(String.self, forKey: .createdAt)
        updatedAt        = try? c.decode(String.self, forKey: .updatedAt)
        note             = try? c.decode(String.self, forKey: .note)
        cardId           = try? c.decode(String.self, forKey: .cardId)
        userId           = try? c.decode(String.self, forKey: .userId)
        departmentId     = try? c.decode(String.self, forKey: .departmentId)
        // bsControlCode may arrive as a JSON number or string
        if let s = try? c.decode(String.self, forKey: .bsControlCode), !s.isEmpty {
            bsControlCode = s
        } else if let i = try? c.decode(Int.self, forKey: .bsControlCode) {
            bsControlCode = String(i)
        } else {
            bsControlCode = nil
        }
        receiptMerchant  = try? c.decode(String.self, forKey: .receiptMerchant)
        receiptAmount    = try? c.decode(String.self, forKey: .receiptAmount)
        cardBalance      = try? c.decode(Double.self, forKey: .cardBalance)
        cardLimit        = try? c.decode(Double.self, forKey: .cardLimit)
        cardSpent        = try? c.decode(Double.self, forKey: .cardSpent)
        floatBalance     = try? c.decode(Double.self, forKey: .floatBalance)
        floatIssued      = try? c.decode(Double.self, forKey: .floatIssued)
        floatSpent       = try? c.decode(Double.self, forKey: .floatSpent)
        floatReqNumber   = try? c.decode(String.self, forKey: .floatReqNumber)
        floatStatus      = try? c.decode(String.self, forKey: .floatStatus)
        uploadType       = try? c.decode(String.self, forKey: .uploadType)
    }

    func toTopUpItem() -> TopUpItem {
        var t = TopUpItem()
        t.id = id
        t.entityType = entityType
        t.entityId = entityId
        t.receiptId = receiptId
        t.cardId = cardId
        t.cardLastFour = cardLastFour
        t.userId = userId
        let resolvedName = UsersData.byId[userId ?? ""]?.fullName
            ?? holderName
            ?? userId
        t.holderName = resolvedName
        t.departmentId = departmentId
        if let dept = DepartmentsData.all.first(where: { $0.id == (departmentId ?? "") }) {
            t.department = dept.displayName
        }
        t.amount = amount
        t.method = method
        t.status = status
        t.note = note
        t.receiptMerchant = receiptMerchant
        t.receiptAmount = Double(receiptAmount ?? "") ?? 0
        t.cardBalance = cardBalance
        t.cardLimit = cardLimit
        t.cardSpent = cardSpent
        t.bsControlCode = bsControlCode
        t.floatBalance = floatBalance
        t.floatIssued = floatIssued
        t.floatSpent = floatSpent
        t.floatReqNumber = floatReqNumber
        t.floatStatus = floatStatus
        t.uploadType = uploadType
        t.createdAt = Int64(createdAt ?? "") ?? 0
        t.updatedAt = Int64(updatedAt ?? "") ?? 0
        return t
    }
}

// MARK: - Card Transaction (Domain model)

struct CardTransaction: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var projectId: String?
    var cardId: String?
    var holderId: String?
    var holderName: String?
    var department: String?
    var cardLastFour: String?
    var merchant: String?
    var description: String?
    var amount: Double?
    var currency: String?
    var transactionDate: Int64?
    var status: String?            // pending, pending_receipt, pending_code, awaiting_approval, approved, queried, under_review, escalated, posted
    var hasReceipt: Bool?
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

    // Inbox matching fields
    var matchScore: Double? = nil
    var linkedMerchant: String?
    var linkedAmount: Double? = nil
    var linkedDate: Int64? = nil
    var linkedCardLast4: String?

    static func == (lhs: CardTransaction, rhs: CardTransaction) -> Bool { lhs.id == rhs.id }

    var statusDisplay: String {
        switch (status ?? "").lowercased() {
        case "pending", "pending_receipt": return "Pending Receipt"
        case "pending_coding", "pending_code", "pending code": return "Pending Code"
        case "awaiting_approval": return "Awaiting Approval"
        case "approved", "matched", "coded": return "Approved"
        case "queried": return "Queried"
        case "under_review": return "Under Review"
        case "escalated": return "Escalated"
        case "posted": return "Posted"
        default: return (status ?? "").capitalized
        }
    }
}

struct CardReceiptAttachmentRaw: Codable {
    var id: String?
    var name: String?
}

struct CardApproval: Equatable {
    var userId: String?
    var tierNumber: Int?
    var approvedAt: Int64?
    var override: Bool?
    var reason: String?
}

struct CardTxApprovalRaw: Codable {
    var userId: String?
    var tierNumber: Int?
    var approvedAt: Double?
    var isOverride: Bool?
    var reason: String?

    enum CodingKeys: String, CodingKey {
        case reason
        case userId = "user_id"
        case tierNumber = "tier_number"
        case approvedAt = "approved_at"
        case isOverride = "override"
    }
}

struct CardTransactionRaw: Decodable {
    var id: String
    var projectId: String?
    var userId: String?
    var holderId: String?
    var holderName: String?
    var cardHolderName: String?
    var departmentId: String?
    var departmentName: String?
    var cardId: String?
    var cardLastFour: String?
    var lastFour: String?
    var transactionId: String?
    var description: String?
    var merchant: String?
    var merchantName: String?
    var amount: String?
    var date: String?
    var status: String?
    var nominalCode: String?
    var codeDescription: String?
    var episode: String?
    var receiptAttachment: CardReceiptAttachmentRaw?
    var matchStatus: String?
    var duplicateDismissed: Bool?
    var personalDismissed: Bool?
    var duplicateScore: Double?
    var personalScore: Double?
    var taxAmount: Double?
    var netAmount: Double?
    var grossAmount: Double?
    var isUrgent: Bool?
    var requestTopUp: Bool?
    // Inbox linked transaction fields (separate from receipt's own fields)
    var matchScore: Double?
    var transactionMerchantRaw: String?
    var transactionCardLast4Raw: String?
    var transactionAmountRaw: Double?
    var transactionDateRaw: String?
    var approvedBy: String?
    var approvedAt: String?
    var approvals: [CardTxApprovalRaw]?
    var createdAt: String?
    var updatedAt: String?

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
        projectId = str("project_id", "projectId")
        userId = str("user_id", "userId")
        holderId = str("holder_id", "holderId")
        holderName = str("holder_name", "holderName")
        cardHolderName = str("card_holder_name", "cardHolderName")
        departmentId = str("department_id", "departmentId")
        departmentName = str("department_name", "departmentName")
        cardId = str("card_id", "cardId")
        cardLastFour = str("card_last_four", "cardLastFour", "lastFour", "last_four", "transaction_card_last4", "transactionCardLast4")
        lastFour = nil
        transactionId = str("transaction_id", "transactionId")
        description = str("description")
        merchant = str("merchant", "transaction_merchant", "transactionMerchant")
        merchantName = str("merchant_name", "merchantName")
        if let d = dbl("amount") { amount = String(d) } else { amount = nil }
        date = str("date") ?? str("transaction_date", "transactionDate")
        status = str("status")
        nominalCode = str("nominal_code", "nominalCode")
        codeDescription = str("code_description", "codeDescription")
        episode = str("episode")
        // Receipt attachment may be an object OR a top-level receiptId
        if let key = AnyKey(stringValue: "receipt_attachment"),
           let att = try? c.decode(CardReceiptAttachmentRaw.self, forKey: key) {
            receiptAttachment = att
        } else if let key = AnyKey(stringValue: "receiptAttachment"),
                  let att = try? c.decode(CardReceiptAttachmentRaw.self, forKey: key) {
            receiptAttachment = att
        } else if let rid = str("receipt_id", "receiptId") {
            var att = CardReceiptAttachmentRaw(); att.id = rid
            receiptAttachment = att
        } else {
            receiptAttachment = nil
        }
        matchStatus = str("match_status", "matchStatus")
        duplicateDismissed = bool("duplicate_dismissed", "duplicateDismissed")
        personalDismissed = bool("personal_dismissed", "personalDismissed")
        duplicateScore = dbl("duplicate_score", "duplicateScore")
        personalScore = dbl("personal_score", "personalScore")
        taxAmount = dbl("tax_amount", "taxAmount")
        netAmount = dbl("net_amount", "netAmount")
        grossAmount = dbl("gross_amount", "grossAmount")
        isUrgent = bool("is_urgent", "isUrgent")
        requestTopUp = bool("request_top_up", "requestTopUp")
        // Inbox linked-transaction fields (distinct from the receipt's own merchant/date/cardLastFour)
        matchScore = dbl("match_score", "matchScore")
        transactionMerchantRaw = str("transaction_merchant", "transactionMerchant")
        transactionCardLast4Raw = str("transaction_card_last4", "transactionCardLast4")
        transactionAmountRaw = dbl("transaction_amount", "transactionAmount")
        transactionDateRaw = str("transaction_date", "transactionDate")
        approvedBy = str("approved_by", "approvedBy")
        approvedAt = str("approved_at", "approvedAt")
        if let key = AnyKey(stringValue: "approvals"),
           let arr = try? c.decode([CardTxApprovalRaw].self, forKey: key) {
            approvals = arr
        } else { approvals = nil }
        createdAt = str("created_at", "createdAt")
        updatedAt = str("updated_at", "updatedAt")
    }

    func toCardTransaction() -> CardTransaction {
        var t = CardTransaction()
        t.id = id
        t.projectId = projectId
        let uid = holderId ?? userId ?? ""
        t.holderId = uid
        t.holderName = UsersData.byId[uid]?.fullName
            ?? holderName
            ?? cardHolderName
        if let name = departmentName, !name.isEmpty {
            t.department = name
        } else if let dept = DepartmentsData.all.first(where: { $0.id == (departmentId ?? "") }) {
            t.department = dept.displayName
        } else if let h = UsersData.byId[uid] {
            t.department = h.displayDepartment
        }
        t.cardLastFour = cardLastFour ?? lastFour
        t.cardId = cardId
        let m = merchant ?? merchantName ?? description ?? ""
        t.merchant = m
        t.description = description ?? m
        t.amount = Double(amount ?? "") ?? 0
        t.currency = "GBP"
        t.transactionDate = Int64(date ?? "") ?? 0
        t.status = status ?? "pending_receipt"
        t.hasReceipt = receiptAttachment != nil
        t.receiptId = receiptAttachment?.id
        t.linkedTransactionId = transactionId
        t.matchStatus = matchStatus
        t.duplicateDismissed = duplicateDismissed
        t.personalDismissed = personalDismissed
        t.duplicateScore = duplicateScore
        t.personalScore = personalScore
        t.nominalCode = nominalCode
        t.notes = codeDescription
        t.codeDescription = codeDescription
        t.episode = episode
        t.taxAmount = taxAmount
        t.netAmount = netAmount
        t.grossAmount = grossAmount
        t.approvedBy = approvedBy
        t.approvedAt = Int64(approvedAt ?? "") ?? 0
        t.isUrgent = isUrgent
        // Inbox linked transaction fields
        t.matchScore = matchScore
        t.linkedMerchant = transactionMerchantRaw
        t.linkedAmount = transactionAmountRaw
        t.linkedDate = Int64(transactionDateRaw ?? "")
        t.linkedCardLast4 = transactionCardLast4Raw
        t.approvals = (approvals ?? []).map { raw in
            var a = CardApproval()
            a.userId = raw.userId
            a.tierNumber = raw.tierNumber
            a.approvedAt = Int64(raw.approvedAt ?? 0)
            a.override = raw.isOverride
            a.reason = raw.reason
            return a
        }
        t.createdAt = Int64(createdAt ?? "") ?? 0
        t.updatedAt = Int64(updatedAt ?? "") ?? 0
        return t
    }
}

// MARK: - Card (Domain model)

struct BankAccount: Codable, Equatable {
    var id: String?
    var name: String?
    var accountNumber: String?
    var sortCode: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case accountNumber = "account_number"
        case sortCode = "sort_code"
    }
}

struct ExpenseCard: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var projectId: String?
    var holderId: String?
    var holderName: String?
    var department: String?
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
    var createdAt: Int64?
    var updatedAt: Int64?

    static func == (lhs: ExpenseCard, rhs: ExpenseCard) -> Bool { lhs.id == rhs.id }

    var spentAmount: Double { max((monthlyLimit ?? 0) - (currentBalance ?? 0), 0) }
    var spendPercent: Double { (monthlyLimit ?? 0) > 0 ? spentAmount / (monthlyLimit ?? 0) : 0 }
    var bankName: String { bankAccount?.name ?? "" }
    var holderUser: AppUser? { UsersData.byId[holderId ?? ""] }
    var holderFullName: String { holderUser?.fullName ?? holderName ?? "" }
    var holderDesignation: String { holderUser?.displayDesignation ?? "" }
    var isDigitalOnly: Bool { digitalCardNumber != nil && !digitalCardNumber!.isEmpty && (physicalCardNumber == nil || physicalCardNumber!.isEmpty) }

    func statusDisplay(isAccountant: Bool) -> String {
        switch status ?? "" {
        case "active": return isDigitalOnly ? "Digital Active" : "Active"
        case "requested": return "Requested"
        case "pending": return "Pending Approval"
        case "approved", "override": return isAccountant ? (status == "override" ? "Override" : "Approved") : "In-Progress"
        case "rejected": return "Rejected"
        case "suspended": return "Suspended"
        default: return (status ?? "").capitalized
        }
    }
}

// MARK: - Card Raw (API response)

struct CardRaw: Decodable {
    var id: String
    var projectId: String?
    var userId: String?
    var departmentId: String?
    var status: String?
    var lastFour: String?
    var cardIssuer: String?
    var monthlyLimit: Double?
    var currentBalance: Double?
    var proposedFloat: Double?
    var bsControlCode: String?
    var justification: String?
    var requestedBy: String?
    var requestedAt: String?
    var approvals: [CardApprovalRaw]?
    var approvedBy: String?
    var approvedAt: String?
    var rejectedBy: String?
    var rejectedAt: String?
    var rejectionReason: String?
    var digitalCardNumber: String?
    var physicalCardNumber: String?
    var bankAccount: BankAccount?
    var updatedBy: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, approvals
        case projectId = "project_id"
        case userId = "user_id"
        case departmentId = "department_id"
        case lastFour = "last_four"
        case cardIssuer = "card_issuer"
        case monthlyLimit = "monthly_limit"
        case currentBalance = "current_balance"
        case proposedFloat = "proposed_float"
        case bsControlCode = "bs_control_code"
        case justification
        case requestedBy = "requested_by"
        case requestedAt = "requested_at"
        case approvedBy = "approved_by"
        case approvedAt = "approved_at"
        case rejectedBy = "rejected_by"
        case rejectedAt = "rejected_at"
        case rejectionReason = "rejection_reason"
        case digitalCardNumber = "digital_card_number"
        case physicalCardNumber = "physical_card_number"
        case bankAccount = "bank_account"
        case updatedBy = "updated_by"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        projectId = try? c.decode(String.self, forKey: .projectId)
        userId = try? c.decode(String.self, forKey: .userId)
        departmentId = try? c.decode(String.self, forKey: .departmentId)
        status = try? c.decode(String.self, forKey: .status)
        lastFour = try? c.decode(String.self, forKey: .lastFour)
        cardIssuer = try? c.decode(String.self, forKey: .cardIssuer)
        // bsControlCode arrives as either a JSON string or a JSON number
        if let s = try? c.decode(String.self, forKey: .bsControlCode), !s.isEmpty {
            bsControlCode = s
        } else if let i = try? c.decode(Int.self, forKey: .bsControlCode) {
            bsControlCode = String(i)
        } else {
            bsControlCode = nil
        }
        justification = try? c.decode(String.self, forKey: .justification)
        requestedBy = try? c.decode(String.self, forKey: .requestedBy)
        requestedAt = try? c.decode(String.self, forKey: .requestedAt)
        approvedBy = try? c.decode(String.self, forKey: .approvedBy)
        approvedAt = try? c.decode(String.self, forKey: .approvedAt)
        rejectedBy = try? c.decode(String.self, forKey: .rejectedBy)
        rejectedAt = try? c.decode(String.self, forKey: .rejectedAt)
        rejectionReason = try? c.decode(String.self, forKey: .rejectionReason)
        digitalCardNumber = try? c.decode(String.self, forKey: .digitalCardNumber)
        physicalCardNumber = try? c.decode(String.self, forKey: .physicalCardNumber)
        updatedBy = try? c.decode(String.self, forKey: .updatedBy)
        updatedAt = try? c.decode(String.self, forKey: .updatedAt)
        bankAccount = try? c.decode(BankAccount.self, forKey: .bankAccount)
        approvals = try? c.decode([CardApprovalRaw].self, forKey: .approvals)
        monthlyLimit = flexibleDoubleDecode(c, .monthlyLimit)
        currentBalance = flexibleDoubleDecode(c, .currentBalance)
        proposedFloat = flexibleDoubleDecode(c, .proposedFloat)
    }

    func toCard() -> ExpenseCard {
        let dept = DepartmentsData.all.first { $0.id == (departmentId ?? "") }
        var card = ExpenseCard()
        card.id = id
        card.holderId = userId
        card.holderName = UsersData.byId[userId ?? ""]?.fullName
        card.department = dept?.displayName
        card.departmentId = departmentId
        card.status = status ?? "requested"
        card.lastFour = lastFour
        card.cardIssuer = cardIssuer
        card.monthlyLimit = monthlyLimit
        card.currentBalance = currentBalance
        card.proposedLimit = proposedFloat
        card.bsControlCode = bsControlCode
        card.justification = justification
        card.requestedBy = requestedBy
        card.requestedAt = Int64(requestedAt ?? "") ?? 0
        card.approvedBy = approvedBy
        card.approvedAt = approvedAt.flatMap { Int64($0) }
        card.rejectedBy = rejectedBy
        card.rejectedAt = rejectedAt.flatMap { Int64($0) }
        card.rejectionReason = rejectionReason
        card.digitalCardNumber = digitalCardNumber
        card.physicalCardNumber = physicalCardNumber
        card.bankAccount = bankAccount
        card.approvals = (approvals ?? []).map {
            Approval(userId: $0.userId ?? "", tierNumber: $0.tierNumber ?? 0, approvedAt: Int64($0.approvedAt ?? "") ?? 0)
        }
        card.updatedAt = Int64(updatedAt ?? "") ?? 0
        return card
    }
}

struct CardApprovalRaw: Decodable {
    var userId: String?
    var tierNumber: Int?
    var approvedAt: String?

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
                userId = v; break
            }
        }
        // tier number — try Int then String→Int
        for k in ["tier_number", "tierNumber", "tier", "level"] {
            if let key = AnyKey(stringValue: k) {
                if let v = try? c.decode(Int.self, forKey: key) { tierNumber = v; break }
                if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { tierNumber = v; break }
            }
        }
        // approvedAt — try String then number
        for k in ["approved_at", "approvedAt", "approved_time", "timestamp"] {
            if let key = AnyKey(stringValue: k) {
                if let s = try? c.decode(String.self, forKey: key), !s.isEmpty { approvedAt = s; break }
                if let n = try? c.decode(Double.self, forKey: key) { approvedAt = String(Int64(n)); break }
            }
        }
    }
}

// MARK: - Pending Coding Item (from /api/v2/card-expenses/receipts/pending-coding)

struct PendingCodingItem: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var projectId: String?
    var userId: String?
    var status: String?             // pending_code, pending_receipt
    var transactionId: String? = nil
    var description: String?
    var amount: Double?
    var date: Int64?
    var createdAt: Int64?
    var updatedAt: Int64?
    var nominalCode: String? = nil
    var history: [PendingCodingHistory]?
    var departmentId: String? = nil
    var episode: String? = nil
    var codeDescription: String? = nil
    var matchStatus: String?
    var receiptAttachment: PendingCodingAttachment? = nil
    var processingFlags: [ProcessingFlag]?
    var isUrgent: Bool?
    var requestTopUp: Bool?
    var taxAmount: Double? = nil
    var netAmount: Double? = nil
    var grossAmount: Double? = nil

    static func == (lhs: PendingCodingItem, rhs: PendingCodingItem) -> Bool { lhs.id == rhs.id }

    var userName: String { UsersData.byId[userId ?? ""]?.fullName ?? (userId ?? "") }
    var userDepartment: String {
        if let deptId = departmentId, let dept = DepartmentsData.all.first(where: { $0.id == deptId }) {
            return dept.displayName
        }
        return UsersData.byId[userId ?? ""]?.displayDepartment ?? ""
    }

    var statusDisplay: String {
        switch (status ?? "").lowercased() {
        case "pending_code", "pending_coding", "pending code": return "Needs Coding"
        case "pending_receipt": return "Awaiting Receipt"
        case "coded":           return "Coded"
        case "posted":          return "Posted"
        default:                return (status ?? "").replacingOccurrences(of: "_", with: " ").capitalized
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
    var projectId: String?
    var userId: String?
    var status: String?
    var transactionId: String?
    var description: String?
    var amount: String?
    var date: String?
    var createdAt: String?
    var updatedAt: String?
    var nominalCode: String?
    var history: [PendingCodingHistoryRaw]?
    var departmentId: String?
    var episode: String?
    var codeDescription: String?
    var matchStatus: String?
    var receiptAttachment: PendingCodingAttachmentRaw?
    var processingFlags: [ProcessingFlagRaw]?
    var isUrgent: Bool?
    var requestTopUp: Bool?
    var taxAmount: AnyCodableValue?
    var netAmount: AnyCodableValue?
    var grossAmount: AnyCodableValue?

    enum CodingKeys: String, CodingKey {
        case id, status, description, amount, date, episode
        case projectId = "project_id"
        case userId = "user_id"
        case transactionId = "transaction_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case nominalCode = "nominal_code"
        case history
        case departmentId = "department_id"
        case codeDescription = "code_description"
        case matchStatus = "match_status"
        case receiptAttachment = "receipt_attachment"
        case processingFlags = "processing_flags"
        case isUrgent = "is_urgent"
        case requestTopUp = "request_top_up"
        case taxAmount = "tax_amount"
        case netAmount = "net_amount"
        case grossAmount = "gross_amount"
    }

    func toPendingCodingItem() -> PendingCodingItem {
        var item = PendingCodingItem()
        item.id = id
        item.projectId = projectId
        item.userId = userId
        item.status = status
        item.transactionId = transactionId
        item.description = description
        item.amount = Double(amount ?? "") ?? 0
        item.date = Int64(date ?? "") ?? 0
        item.createdAt = Int64(createdAt ?? "") ?? 0
        item.updatedAt = Int64(updatedAt ?? "") ?? 0
        item.nominalCode = nominalCode
        item.history = (history ?? []).map { $0.toPendingCodingHistory() }
        item.departmentId = departmentId
        item.episode = episode
        item.codeDescription = codeDescription
        item.matchStatus = matchStatus
        item.receiptAttachment = receiptAttachment?.toAttachment()
        item.processingFlags = (processingFlags ?? []).map { $0.toProcessingFlag() }
        item.isUrgent = isUrgent
        item.requestTopUp = requestTopUp
        item.taxAmount = taxAmount?.doubleValue
        item.netAmount = netAmount?.doubleValue
        item.grossAmount = grossAmount?.doubleValue
        return item
    }
}

struct PendingCodingHistoryRaw: Codable {
    var action: String?
    var actionAt: Int64?
    var actionBy: String?

    enum CodingKeys: String, CodingKey {
        case action
        case actionAt = "action_at"
        case actionBy = "action_by"
    }

    func toPendingCodingHistory() -> PendingCodingHistory {
        PendingCodingHistory(action: action, actionAt: actionAt, actionBy: actionBy)
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
    var ruleId: String?
    var description: String?
    var processType: String?
    var thresholdType: String?
    var thresholdValue: AnyCodableValue?

    enum CodingKeys: String, CodingKey {
        case flag, title, description
        case ruleId = "rule_id"
        case processType = "process_type"
        case thresholdType = "threshold_type"
        case thresholdValue = "threshold_value"
    }

    func toProcessingFlag() -> ProcessingFlag {
        ProcessingFlag(
            flag: flag, title: title, ruleId: ruleId, description: description,
            processType: processType, thresholdType: thresholdType,
            thresholdValue: thresholdValue?.doubleValue
        )
    }
}

// MARK: - Bank Accounts

struct BankAccountAdditionalDetail: Codable, Equatable {
    var field: String?
    var value: String?
}

struct ProductionBankAccount: Identifiable, Equatable {
    var id: String
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
}

struct ProductionBankAccountRaw: Codable {
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
        case accountNumber = "account_number"
        case accountHolderName = "account_holder_name"
        case sortCode = "sort_code"
        case ibanNumber = "iban_number"
        case swiftCode = "swift_code"
        case nominalCode = "nominal_code"
        case accPayableCode = "acc_payable_code"
        case paymentPrefix = "payment_prefix"
        case entityType = "entity_type"
        case additionalDetails = "additional_details"
    }

    func toProductionBankAccount() -> ProductionBankAccount {
        ProductionBankAccount(
            id: id ?? UUID().uuidString,
            name: name,
            accountNumber: accountNumber,
            accountHolderName: accountHolderName,
            sortCode: sortCode,
            ibanNumber: ibanNumber,
            swiftCode: swiftCode,
            nominalCode: nominalCode,
            accPayableCode: accPayableCode,
            paymentPrefix: paymentPrefix,
            entityType: entityType,
            additionalDetails: additionalDetails
        )
    }
}
