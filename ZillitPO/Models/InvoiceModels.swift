//
//  InvoiceModels.swift
//  ZillitPO
//
//  Settings-related models for invoices (Team, Alerts, Run Auth, Assignment Rules).
//  Core Invoice, InvoiceStatus, and PaymentRun models live in Models.swift.
//

import Foundation

// MARK: - Invoice History Entry

struct InvoiceHistoryEntry: Codable, Identifiable {
    var id: String { "\(effectiveTimestamp ?? 0)-\(action ?? "")" }
    var action: String?
    var details: String?
    /// Server-sent `timestamp` (separate history endpoint shape).
    /// Consumers should prefer `effectiveTimestamp` for display so the
    /// inline `action_at` fallback is honoured.
    var timestamp: Int64?
    /// Inline-history timestamp (`action_at` key) — present when the
    /// entry is embedded on the invoice row instead of the dedicated
    /// history endpoint.
    var actionAt: Int64?
    /// Server-sent `user_id` (separate history endpoint shape).
    var userId: String?
    /// Inline-history user id (`action_by` key).
    var actionBy: String?
    var userName: String?

    /// Supports BOTH history shapes the backend returns:
    /// - Separate history endpoint: `{ action, details, timestamp, user_id, user_name }`
    /// - Inline on invoice rows:     `{ action, action_at, action_by }`
    enum CodingKeys: String, CodingKey {
        case action, details, timestamp
        case userId   = "user_id"
        case userName = "user_name"
        case actionAt = "action_at"
        case actionBy = "action_by"
    }

    /// Merged timestamp for display — the separate history endpoint
    /// populates `timestamp`; the inline shape populates `action_at`.
    var effectiveTimestamp: Int64? { timestamp ?? actionAt }

    /// Merged user id for display — prefers the canonical `user_id`,
    /// falls back to the inline `action_by`.
    var effectiveUserId: String? { userId ?? actionBy }
}

// MARK: - Invoice Query Thread (raised against an invoice)

/// The single query thread returned by
/// GET /api/v2/account-hub/queries/entity/invoice/{invoiceId}.
/// Response shape:
/// {
///   "id": "…",
///   "entity_type": "invoice",
///   "entity_id": "…",
///   "raised_by": "mock-sa",
///   "raised_at": "1776168245993",
///   "queries": [
///     { "query": "ok", "queried_at": 1776168245993, "queried_by": "mock-sa" }
///   ],
///   "created_at": "…", "updated_at": "…"
/// }
struct InvoiceQueryThread: Codable, Identifiable {
    var id: String?
    var entityType: String?
    var entityId: String?
    var raisedBy: String?
    var raisedAt: Int64?
    var createdAt: Int64?
    var updatedAt: Int64?
    var messages: [InvoiceQueryMessage]?

    enum CodingKeys: String, CodingKey {
        case id, messages = "queries"
        case entityType = "entity_type"
        case entityId   = "entity_id"
        case raisedBy   = "raised_by"
        case raisedAt   = "raised_at"
        case createdAt  = "created_at"
        case updatedAt  = "updated_at"
    }
}

/// One message inside an InvoiceQueryThread's `queries` array.
/// Each entry is shaped `{ query, queried_at, queried_by }`.
struct InvoiceQueryMessage: Codable, Identifiable {
    /// Composite id derived from user + timestamp — the backend doesn't
    /// send a per-message id.
    var id: String { "\(queriedBy ?? "unknown")-\(queriedAt ?? 0)" }
    var query: String?
    var queriedAt: Int64?
    var queriedBy: String?

    enum CodingKeys: String, CodingKey {
        case query
        case queriedAt = "queried_at"
        case queriedBy = "queried_by"
    }

}

// MARK: - Run Authorization Level

struct RunAuthLevel: Codable, Equatable {
    var tier: Int?
    var user: [String]?
}

// MARK: - Invoice Settings

struct InvoiceSettings: Codable {
    var id: String?
    var projectId: String?
    var alerts: [String]?
    var teamMembers: [InvoiceTeamMember]?
    var runAuthorization: [RunAuthLevel]?
    var assignmentRules: [InvoiceAssignmentRule]?
    var createdBy: String?
    var updatedBy: String?
    var createdAt: Int64?
    var updatedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case alerts
        case teamMembers = "team_members"
        case runAuthorization = "run_authorization"
        case assignmentRules = "assignment_rules"
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Team Member

struct InvoiceTeamMember: Codable, Equatable, Identifiable {
    var userId: String?
    /// Raw posting-limit string. Server sends "unlimited" (or null/empty)
    /// for no cap, or a numeric string like "500" for a per-posting cap.
    var postingLimit: String?
    var runAccess: Bool?
    var overrideAccess: Bool?

    var id: String { userId ?? "" }

    var isUnlimited: Bool {
        let trimmed = (postingLimit ?? "").trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.lowercased() == "unlimited"
    }

    var postingLimitValue: Double? {
        if isUnlimited { return nil }
        return Double(postingLimit ?? "")
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case postingLimit = "posting_limit"
        case runAccess = "run_access"
        case overrideAccess = "override_access"
    }

}

// MARK: - Invoice Assignment Rule

struct InvoiceAssignmentRule: Codable, Equatable, Identifiable {
    var id: String?
    var projectId: String?
    var userId: String?
    var name: String?
    var departments: [String]?
    var vendors: [String]?
    var nominalCodes: [String]?
    var amountMin: Double?
    var targetUserId: String?
    var priority: Int?
    var isActive: Bool?
    var module: String?
    var createdAt: Int64?
    var updatedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, name, departments, vendors, priority, module
        case projectId = "project_id"
        case userId = "user_id"
        case nominalCodes = "nominal_codes"
        case amountMin = "amount_min"
        case targetUserId = "target_user_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Payment Run Detail

struct PaymentRunDetail: Codable {
    var run: PaymentRun?
    var invoices: [Invoice]?

    init(run: PaymentRun? = nil, invoices: [Invoice]? = nil) {
        self.run = run; self.invoices = invoices
    }

    enum CodingKeys: String, CodingKey { case run, invoices }
}

// MARK: - Upload extraction result

struct InvoiceExtraction: Codable {
    var file: String?
    var uploadId: String?
    var invoiceNumber: String?
    var poNumber: String?
    var invoiceDate: String?
    var dueDate: String?
    var supplier: InvoiceExtractionSupplier?
    var lineItems: [InvoiceExtractionLineItem]?
    var net: Double?
    var vat: Double?
    var gross: Double?
    var vatRate: Double?
    var currency: String?
    var confidence: Int?
    var rawText: String?

    enum CodingKeys: String, CodingKey {
        case file, supplier, net, vat, gross, currency, confidence
        case uploadId = "upload_id"
        case invoiceNumber = "invoice_number"
        case poNumber = "po_number"
        case invoiceDate = "invoice_date"
        case dueDate = "due_date"
        case lineItems = "line_items"
        case vatRate = "vat_rate"
        case rawText = "raw_text"
    }

    var grossValue: Double { gross ?? 0 }
    var netValue: Double { net ?? 0 }
    var vatValue: Double { vat ?? 0 }

    struct InvoiceExtractionSupplier: Codable {
        var name: String?
        var address: String?
        var email: String?
        var phone: String?
        var vatNumber: String?

        enum CodingKeys: String, CodingKey {
            case name, address, email, phone
            case vatNumber = "vat_number"
        }
    }

    struct InvoiceExtractionLineItem: Codable {
        var description: String?
        var quantity: Double?
        var unitPrice: Double?
        var amount: Double?

        enum CodingKeys: String, CodingKey {
            case description, quantity, amount
            case unitPrice = "unit_price"
        }

        var quantityValue: Double { quantity ?? 0 }
        var unitPriceValue: Double { unitPrice ?? 0 }
        var amountValue: Double { amount ?? 0 }
    }
}
