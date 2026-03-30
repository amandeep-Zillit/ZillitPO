//
//  InvoiceModels.swift
//  ZillitPO
//
//  Settings-related models for invoices (Team, Alerts, Run Auth, Assignment Rules).
//  Core Invoice, InvoiceStatus, and PaymentRun models live in Models.swift.
//

import Foundation

// MARK: - Run Authorization Level

struct RunAuthLevel: Codable, Equatable {
    var tier: Int
    var user: [String]
}

// MARK: - Invoice Settings

struct InvoiceSettingsRaw: Codable {
    var id: String?
    var projectId: String?
    var alerts: [String]
    var teamMembers: [InvoiceTeamMember]
    var runAuthorization: [RunAuthLevel]
    var assignmentRules: [InvoiceAssignmentRule]
    var createdBy: String?
    var updatedBy: String?
    var createdAt: String?
    var updatedAt: String?

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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decode(String.self, forKey: .id)
        projectId = try? c.decode(String.self, forKey: .projectId)
        createdBy = try? c.decode(String.self, forKey: .createdBy)
        updatedBy = try? c.decode(String.self, forKey: .updatedBy)
        createdAt = try? c.decode(String.self, forKey: .createdAt)
        updatedAt = try? c.decode(String.self, forKey: .updatedAt)

        // alerts: array or JSON string
        if let arr = try? c.decode([String].self, forKey: .alerts) {
            alerts = arr
        } else if let s = try? c.decode(String.self, forKey: .alerts),
                  let d = s.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: d) {
            alerts = arr
        } else { alerts = [] }

        // team_members: array or JSON string
        if let arr = try? c.decode([InvoiceTeamMember].self, forKey: .teamMembers) {
            teamMembers = arr
        } else if let s = try? c.decode(String.self, forKey: .teamMembers),
                  let d = s.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([InvoiceTeamMember].self, from: d) {
            teamMembers = arr
        } else { teamMembers = [] }

        // run_authorization: array or JSON string
        if let arr = try? c.decode([RunAuthLevel].self, forKey: .runAuthorization) {
            runAuthorization = arr
        } else if let s = try? c.decode(String.self, forKey: .runAuthorization),
                  let d = s.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([RunAuthLevel].self, from: d) {
            runAuthorization = arr
        } else { runAuthorization = [] }

        // assignment_rules: array or JSON string
        if let arr = try? c.decode([InvoiceAssignmentRule].self, forKey: .assignmentRules) {
            assignmentRules = arr
        } else if let s = try? c.decode(String.self, forKey: .assignmentRules),
                  let d = s.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([InvoiceAssignmentRule].self, from: d) {
            assignmentRules = arr
        } else { assignmentRules = [] }
    }
}

// MARK: - Team Member

struct InvoiceTeamMember: Codable, Equatable, Identifiable {
    var userId: String
    var postingLimit: AnyCodableValue?
    var runAccess: Bool
    var overrideAccess: Bool

    var id: String { userId }

    var isUnlimited: Bool {
        guard let limit = postingLimit else { return true }
        switch limit {
        case .null: return true
        case .string(let s): return s == "unlimited" || s.isEmpty
        default: return false
        }
    }

    var postingLimitValue: Double? {
        if isUnlimited { return nil }
        return postingLimit?.doubleValue
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case postingLimit = "posting_limit"
        case runAccess = "run_access"
        case overrideAccess = "override_access"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = (try? c.decode(String.self, forKey: .userId)) ?? ""
        postingLimit = try? c.decode(AnyCodableValue.self, forKey: .postingLimit)
        runAccess = (try? c.decode(Bool.self, forKey: .runAccess)) ?? false
        overrideAccess = (try? c.decode(Bool.self, forKey: .overrideAccess)) ?? false
    }
}

// MARK: - Invoice Assignment Rule

struct InvoiceAssignmentRule: Codable, Equatable, Identifiable {
    var id: String
    var projectId: String?
    var userId: String?
    var name: String?
    var departments: [String]
    var vendors: [String]
    var nominalCodes: [String]
    var amountMin: Double?
    var targetUserId: String
    var priority: Int
    var isActive: Bool
    var module: String?
    var createdAt: String?
    var updatedAt: String?

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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        projectId = try? c.decode(String.self, forKey: .projectId)
        userId = try? c.decode(String.self, forKey: .userId)
        name = try? c.decode(String.self, forKey: .name)
        targetUserId = (try? c.decode(String.self, forKey: .targetUserId)) ?? ""
        priority = (try? c.decode(Int.self, forKey: .priority)) ?? 0
        isActive = (try? c.decode(Bool.self, forKey: .isActive)) ?? true
        module = try? c.decode(String.self, forKey: .module)
        createdAt = try? c.decode(String.self, forKey: .createdAt)
        updatedAt = try? c.decode(String.self, forKey: .updatedAt)
        amountMin = try? c.decode(Double.self, forKey: .amountMin)

        // departments: array or JSON string
        if let arr = try? c.decode([String].self, forKey: .departments) {
            departments = arr
        } else if let s = try? c.decode(String.self, forKey: .departments),
                  let d = s.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: d) {
            departments = arr
        } else { departments = [] }

        // vendors: array or JSON string
        if let arr = try? c.decode([String].self, forKey: .vendors) {
            vendors = arr
        } else if let s = try? c.decode(String.self, forKey: .vendors),
                  let d = s.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: d) {
            vendors = arr
        } else { vendors = [] }

        // nominal_codes: array or JSON string
        if let arr = try? c.decode([String].self, forKey: .nominalCodes) {
            nominalCodes = arr
        } else if let s = try? c.decode(String.self, forKey: .nominalCodes),
                  let d = s.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: d) {
            nominalCodes = arr
        } else { nominalCodes = [] }
    }
}

// MARK: - Payment Run Detail (parsed result for UI)

struct PaymentRunDetail {
    var run: PaymentRun
    var invoices: [Invoice]
}

// MARK: - Payment Run Detail Raw (for getPaymentRun API response)

struct PaymentRunDetailRaw: Codable {
    var run: PaymentRunRaw?
    var invoices: [InvoiceRaw]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        run = try? c.decode(PaymentRunRaw.self, forKey: .run)
        invoices = try? c.decode([InvoiceRaw].self, forKey: .invoices)
    }

    enum CodingKeys: String, CodingKey { case run, invoices }
}

// MARK: - Upload extraction result

struct InvoiceExtraction: Codable {
    var file: String?
    var upload_id: String?
    var invoice_number: String?
    var po_number: String?
    var invoice_date: String?
    var due_date: String?
    var supplier: InvoiceExtractionSupplier?
    var line_items: [InvoiceExtractionLineItem]?
    var net: AnyCodableValue?
    var vat: AnyCodableValue?
    var gross: AnyCodableValue?
    var vat_rate: AnyCodableValue?
    var currency: String?
    var confidence: Int?
    var raw_text: String?

    var grossValue: Double {
        gross?.doubleValue ?? 0
    }

    var netValue: Double {
        net?.doubleValue ?? 0
    }

    var vatValue: Double {
        vat?.doubleValue ?? 0
    }

    struct InvoiceExtractionSupplier: Codable {
        var name: String?
        var address: String?
        var email: String?
        var phone: String?
        var vat_number: String?
    }

    struct InvoiceExtractionLineItem: Codable {
        var description: String?
        var quantity: AnyCodableValue?
        var unit_price: AnyCodableValue?
        var amount: AnyCodableValue?

        var quantityValue: Double { quantity?.doubleValue ?? 0 }
        var unitPriceValue: Double { unit_price?.doubleValue ?? 0 }
        var amountValue: Double { amount?.doubleValue ?? 0 }
    }
}
