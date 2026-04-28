import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// Models — 1:1 with DB Migrations (001–010)
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - 001 approval_tier_configs

struct ApprovalTierConfig: Identifiable, Codable, Equatable {
    var id: String?
    var projectId: String?
    var module: String?
    var scope: String?            // "all" | "department"
    var departmentId: String?
    var tiers: [TierDef]?
    var createdBy: String?
    var updatedBy: String?
    var createdAt: Int64?
    var updatedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, module, scope, tiers
        case projectId = "project_id"
        case departmentId = "department_id"
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

}

struct TierDef: Codable, Equatable {
    var order: Int?
    var gate: TierGate?
    var rules: [TierRule]?

    enum CodingKeys: String, CodingKey { case order, gate, rules }
}

struct TierGate: Codable, Equatable {
    var enabled: Bool?
    var type: String?
    var amountThreshold: Double?
    enum CodingKeys: String, CodingKey {
        case enabled, type
        case amountThreshold = "amount_threshold"
    }
}

struct TierRule: Codable, Equatable {
    var type: String?             // "default" | "amount"
    var amountThreshold: Double?
    var userIds: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case amountThreshold = "amount_threshold"
        case userIds = "user_ids"
    }

    init(type: String?, amountThreshold: Double?, userIds: [String]?) {
        self.type = type; self.amountThreshold = amountThreshold; self.userIds = userIds
    }
}

// MARK: - 002 vendors

struct Vendor: Identifiable, Codable, Equatable {
    var id: String?
    var projectId: String?
    var userId: String?
    var name: String?
    var address: VendorAddress?
    var email: String?
    var phone: VendorPhone?
    var contactPerson: String?
    var vatNumber: String?
    var status: String?
    var verifiedAt: Int64?
    var verifiedBy: String?
    var addedBy: String?
    var updatedBy: String?
    var departmentId: String?
    var companyType: String?           // e.g. "Limited", "Sole Trader"
    var terms: String?                 // payment terms key (net_30, etc.)
    /// FK into `account_hub_bank_accounts`. Bank details live in a
    /// separate table since migration 002 — fetch by id when needed.
    var bankId: String?
    var vendorType: String?
    var defaultCode: String?
    var compliance: String?
    var compliances: [String]?
    /// Inline audit trail. Each entry: { action, action_by, action_at }.
    var history: [VendorHistoryEntry]?
    /// Legacy embedded bank block. No longer populated by the server
    /// (columns were dropped in migration 002); retained for the form
    /// pages that still read/write it until the bank-fetch flow lands.
    var bankDetails: VendorBankDetails?
    var createdAt: Int64?
    var updatedAt: Int64?

    var verified: Bool { (verifiedAt ?? 0) > 0 }

    enum CodingKeys: String, CodingKey {
        case id, name, address, email, phone, status, terms, compliance, compliances, history
        case projectId = "project_id"
        case userId = "user_id"
        case contactPerson = "contact_person"
        case vatNumber = "vat_number"
        case verifiedAt = "verified_at"
        case verifiedBy = "verified_by"
        case addedBy = "added_by"
        case updatedBy = "updated_by"
        case departmentId = "department_id"
        case companyType = "company_type"
        case bankId = "bank_id"
        case vendorType = "vendor_type"
        case defaultCode = "default_code"
        case bankDetails = "bank_details"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String? = nil, projectId: String? = nil, userId: String? = nil,
         name: String? = nil, address: VendorAddress? = nil, email: String? = nil,
         phone: VendorPhone? = nil, contactPerson: String? = nil,
         vatNumber: String? = nil, status: String? = nil,
         verifiedAt: Int64? = nil, verifiedBy: String? = nil,
         addedBy: String? = nil, updatedBy: String? = nil, departmentId: String? = nil,
         companyType: String? = nil, terms: String? = nil,
         bankId: String? = nil, vendorType: String? = nil,
         defaultCode: String? = nil, compliance: String? = nil,
         compliances: [String]? = nil, history: [VendorHistoryEntry]? = nil,
         bankDetails: VendorBankDetails? = nil,
         createdAt: Int64? = nil, updatedAt: Int64? = nil) {
        self.id = id; self.projectId = projectId; self.userId = userId
        self.name = name; self.address = address; self.email = email; self.phone = phone
        self.contactPerson = contactPerson; self.vatNumber = vatNumber; self.status = status
        self.verifiedAt = verifiedAt; self.verifiedBy = verifiedBy; self.addedBy = addedBy
        self.updatedBy = updatedBy; self.departmentId = departmentId
        self.companyType = companyType; self.terms = terms
        self.bankId = bankId; self.vendorType = vendorType
        self.defaultCode = defaultCode; self.compliance = compliance
        self.compliances = compliances; self.history = history
        self.bankDetails = bankDetails
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

/// One entry in a Vendor's inline `history` JSONB array —
/// `{ action, action_by, action_at }` (epoch-ms).
struct VendorHistoryEntry: Codable, Equatable, Identifiable {
    var id: String { "\(actionAt ?? 0)-\(action ?? "")" }
    var action: String?
    var actionBy: String?
    var actionAt: Int64?

    enum CodingKeys: String, CodingKey {
        case action
        case actionBy = "action_by"
        case actionAt = "action_at"
    }
}

// MARK: - Vendor bank details (web parity)

/// Bank-account block attached to a vendor record. Mirrors the web
/// `bank_details` object: six primary fields (bank name, account holder,
/// account number, sort code, IBAN, SWIFT) and an open-ended list of
/// key/value rows for additional identifiers (IFSC, routing #, etc.).
struct VendorBankDetails: Codable, Equatable {
    var bankName: String?
    var accountHolderName: String?
    var accountNumber: String?
    var sortCode: String?
    var ibanCode: String?
    var swiftCode: String?
    var additionalDetails: [VendorBankAdditionalDetail]?

    enum CodingKeys: String, CodingKey {
        case bankName = "bank_name"
        case accountHolderName = "account_holder_name"
        case accountNumber = "account_number"
        case sortCode = "sort_code"
        case ibanCode = "iban_code"
        case swiftCode = "swift_code"
        case additionalDetails = "additional_details"
    }

    init(bankName: String? = nil, accountHolderName: String? = nil,
         accountNumber: String? = nil, sortCode: String? = nil,
         ibanCode: String? = nil, swiftCode: String? = nil,
         additionalDetails: [VendorBankAdditionalDetail]? = nil) {
        self.bankName = bankName; self.accountHolderName = accountHolderName
        self.accountNumber = accountNumber; self.sortCode = sortCode
        self.ibanCode = ibanCode; self.swiftCode = swiftCode
        self.additionalDetails = additionalDetails
    }

    /// `true` when every primary field and the additional-details list
    /// are empty — lets callers skip the block when the user hasn't
    /// provided any banking info.
    var isEmpty: Bool {
        let primaries = [bankName, accountHolderName, accountNumber, sortCode, ibanCode, swiftCode]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return primaries.isEmpty && (additionalDetails ?? []).isEmpty
    }
}

/// One extra key/value row ("IFSC Code" → "INDB0001234") attached to a
/// vendor's bank details. Title/description naming matches the web
/// form's labels so the two UIs round-trip cleanly.
struct VendorBankAdditionalDetail: Codable, Equatable, Identifiable {
    var id: String?
    var title: String?
    var description: String?

    enum CodingKeys: String, CodingKey { case title, description }

    init(id: String? = nil, title: String? = nil, description: String? = nil) {
        self.id = id; self.title = title; self.description = description
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let t = title { try c.encode(t, forKey: .title) }
        if let d = description { try c.encode(d, forKey: .description) }
    }
}

struct VendorPhone: Codable, Equatable {
    var countryCode: String?
    var number: String?
    enum CodingKeys: String, CodingKey { case countryCode = "isd"; case number }
    init(countryCode: String? = nil, number: String? = nil) {
        self.countryCode = countryCode; self.number = number
    }
}

struct VendorAddress: Codable, Equatable {
    var line1: String?; var line2: String?; var city: String?
    var state: String?; var postalCode: String?; var country: String?
    enum CodingKeys: String, CodingKey {
        case line1, line2, city, state, country; case postalCode = "postcode"
    }
    init(line1: String? = nil, line2: String? = nil, city: String? = nil,
         state: String? = nil, postalCode: String? = nil, country: String? = nil) {
        self.line1 = line1; self.line2 = line2; self.city = city
        self.state = state; self.postalCode = postalCode; self.country = country
    }
    var formatted: String {
        [line1, line2, city, state, postalCode, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - 003 purchase_orders

struct PurchaseOrder: Identifiable, Codable, Equatable {
    var id: String?
    var projectId: String?
    var userId: String?
    var poNumber: String?
    var vendorId: String?
    var departmentId: String?
    var nominalCode: String?
    var description: String?
    var currency: String?
    var effectiveDate: Int64?
    var notes: String?
    var netAmount: Double?
    var status: String?
    var assignedTo: String?
    var raisedBy: String?
    var raisedAt: Int64?
    var approvedBy: String?
    var approvedAt: Int64?
    var postedBy: String?
    var postedAt: Int64?
    var rejectedBy: String?
    var rejectedAt: Int64?
    var rejectionReason: String?
    var reassignmentReason: String?
    var reassignedBy: String?
    var reassignedAt: Int64?
    var vatTreatment: String?
    var deliveryAddress: DeliveryAddress?
    var deliveryDate: Int64?
    var closedBy: String?
    var closedAt: Int64?
    var closureReason: String?
    var customFields: [CustomFieldSection]?
    var vatAmount: Double?
    var grossTotal: Double?
    var approvals: [Approval]?
    var lineItems: [LineItem]?
    var createdAt: Int64?
    var updatedAt: Int64?
    var updatedBy: String?

    // Display fields (resolved client-side via enrich(vendors:departments:))
    var vendor: String?
    var vendorAddress: String?
    var department: String?

    enum CodingKeys: String, CodingKey {
        case id, description, currency, notes, status, approvals
        case projectId          = "project_id"
        case userId             = "user_id"
        case poNumber           = "po_number"
        case vendorId           = "vendor_id"
        case departmentId       = "department_id"
        case nominalCode        = "nominal_code"
        case effectiveDate      = "effective_date"
        case netAmount          = "net_amount"
        case assignedTo         = "assigned_to"
        case raisedBy           = "raised_by"
        case raisedAt           = "raised_at"
        case approvedBy         = "approved_by"
        case approvedAt         = "approved_at"
        case postedBy           = "posted_by"
        case postedAt           = "posted_at"
        case rejectedBy         = "rejected_by"
        case rejectedAt         = "rejected_at"
        case rejectionReason    = "rejection_reason"
        case reassignmentReason = "reassignment_reason"
        case reassignedBy       = "reassigned_by"
        case reassignedAt       = "reassigned_at"
        case vatTreatment       = "vat_treatment"
        case deliveryAddress    = "delivery_address"
        case deliveryDate       = "delivery_date"
        case closedBy           = "closed_by"
        case closedAt           = "closed_at"
        case closureReason      = "closure_reason"
        case customFields       = "custom_fields"
        case vatAmount          = "vat_amount"
        case grossTotal         = "gross_total"
        case lineItems          = "line_items"
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
        case updatedBy          = "updated_by"
    }

    static func == (lhs: PurchaseOrder, rhs: PurchaseOrder) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt && lhs.status == rhs.status
        && lhs.netAmount == rhs.netAmount && lhs.vatTreatment == rhs.vatTreatment
        && (lhs.lineItems?.count ?? 0) == (rhs.lineItems?.count ?? 0)
    }
    var poStatus: POStatus { POStatus.fromAPI(status ?? "") }
    var totalAmount: Double {
        if (netAmount ?? 0) > 0 { return netAmount ?? 0 }
        let computed = (lineItems ?? []).filter { $0.splitParentId == nil }.reduce(0.0) { $0 + ((($1.quantity ?? 0) * ($1.unitPrice ?? 0))) }
        return computed > 0 ? computed : (netAmount ?? 0)
    }

    /// Resolve vendor/department display fields and backfill legacy
    /// defaults (currency = "GBP", status = "DRAFT", vat = "pending",
    /// line-item quantity = 1, expenditureType = "Purchase") so the UI
    /// sees populated values without scattering `?? "GBP"` everywhere.
    /// Replaces the old `PurchaseOrderRaw.toPO(vendors:departments:)`.
    mutating func enrich(vendors: [Vendor], departments: [Department]) {
        let v = vendors.first { $0.id == (vendorId ?? "") }
        let d = departments.first { $0.id == (departmentId ?? "") || $0.identifier == (departmentId ?? "") }
        vendor = v?.name ?? ""
        department = d?.displayName ?? ""
        vendorAddress = [v?.address?.line1, v?.address?.city, v?.address?.postalCode]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")

        if currency?.isEmpty ?? true { currency = "GBP" }
        if status?.isEmpty ?? true { status = "DRAFT" }
        if vatTreatment?.isEmpty ?? true { vatTreatment = "pending" }

        let poLevelVat = vatTreatment ?? "pending"
        lineItems = (lineItems ?? []).map { li in
            var li = li
            let cfVat = li.customFields?.first(where: { $0.name == "vat" })?.value
            if li.vatTreatment == nil { li.vatTreatment = cfVat ?? poLevelVat }
            li.customFields = (li.customFields ?? []).filter { $0.name != "vat" }
            if li.quantity == nil { li.quantity = 1 }
            if li.total == nil { li.total = 0 }
            if li.expenditureType?.isEmpty ?? true { li.expenditureType = "Purchase" }
            return li
        }

        let rawNet = netAmount ?? 0
        let computed = (lineItems ?? []).filter { $0.splitParentId == nil }.reduce(0.0) { $0 + (($1.quantity ?? 0) * ($1.unitPrice ?? 0)) }
        if rawNet <= 0, computed > 0 { netAmount = computed }
    }
}

struct DeliveryAddress: Codable, Equatable {
    var name: String?; var email: String?; var phoneCode: String?; var phone: String?
    var line1: String?; var line2: String?; var city: String?
    var state: String?; var postalCode: String?; var country: String?

    enum CodingKeys: String, CodingKey {
        case name, email, phone, line1, line2, city, state, country
        case phoneCode = "phone_code"
        case postalCode = "postal_code"
    }

    var formattedAddress: String {
        [line1, line2, city, state, postalCode].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct Approval: Codable, Equatable, Identifiable {
    var id: String { "\(userId ?? "")-\(tierNumber ?? 0)" }
    var userId: String?; var tierNumber: Int?; var approvedAt: Int64?
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"; case tierNumber = "tier_number"; case approvedAt = "approved_at"
    }
}

struct CustomFieldSection: Codable, Equatable {
    var section: String?; var fields: [CustomFieldValue]?
}

struct CustomFieldValue: Codable, Equatable {
    var name: String?; var value: String?
}

enum POStatus: String, CaseIterable {
    case draft = "DRAFT", pending = "PENDING", approved = "APPROVED"
    case acctEntered = "ACCT_ENTERED", posted = "POSTED"
    case rejected = "REJECTED", closed = "CLOSED"

    var displayName: String {
        switch self {
        case .draft: return "Draft"; case .pending: return "Pending"
        case .approved: return "Approved"; case .acctEntered: return "Acct Entered"
        case .posted: return "Posted"; case .rejected: return "Rejected"
        case .closed: return "Closed"
        }
    }
    static func fromAPI(_ raw: String) -> POStatus {
        POStatus(rawValue: raw.uppercased()) ?? .pending
    }
}

// MARK: - 004 purchase_order_line_items

struct LineItem: Identifiable, Codable, Equatable {
    var id: String?
    var projectId: String?; var userId: String?; var poId: String?
    var lineNumber: Int?
    var description: String?
    var quantity: Double?
    var unitPrice: Double?
    var total: Double?
    var account: String?
    var department: String?
    var expenditureType: String?
    var vatTreatment: String?
    var rentalStart: Int64?; var rentalEnd: Int64?
    var splitParentId: String?
    var customFields: [CustomFieldValue]?
    /// Tax-treatment enum (`pending`, `standard_20`, `exempt`,
    /// `zero_rated`, `reverse_charged`, `outside_scope`, `other`).
    /// Added Apr 2026 alongside the per-line gross-total flow. Older
    /// records use the legacy `vatTreatment` / `custom_fields[vat]`
    /// path and will round-trip cleanly — the server populates both.
    var taxType: String?
    /// Percentage (0-100). Drives per-line gross: `total * (1 + rate/100)`.
    var taxRate: Double?
    /// Free-form tag list. Used by the web app's tag-picker chip row.
    var tags: [String]?
    var createdAt: Int64?; var updatedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, description, quantity, total, account, department, tags
        case projectId = "project_id"; case userId = "user_id"; case poId = "po_id"
        case lineNumber = "line_number"; case unitPrice = "unit_price"
        case expenditureType = "expenditure_type"; case vatTreatment = "vat_treatment"
        case rentalStart = "rental_start"; case rentalEnd = "rental_end"
        case splitParentId = "split_parent_id"; case customFields = "custom_fields"
        case taxType = "tax_type"; case taxRate = "tax_rate"
        case createdAt = "created_at"; case updatedAt = "updated_at"
    }

    init(id: String? = nil, description: String? = nil, quantity: Double? = nil,
         unitPrice: Double? = nil, total: Double? = nil, account: String? = nil,
         department: String? = nil, expenditureType: String? = nil, vatTreatment: String? = nil,
         taxType: String? = nil, taxRate: Double? = nil, tags: [String]? = nil) {
        self.id = id; self.description = description; self.quantity = quantity
        self.unitPrice = unitPrice; self.total = total; self.account = account
        self.department = department; self.expenditureType = expenditureType
        self.vatTreatment = vatTreatment
        self.taxType = taxType; self.taxRate = taxRate; self.tags = tags
    }
}

// MARK: - 005 po_templates

struct POTemplate: Identifiable, Codable {
    var id: String?
    var templateNumber: String?; var templateName: String?
    var vendorId: String?; var departmentId: String?; var nominalCode: String?
    var description: String?; var currency: String?; var notes: String?
    var netAmount: Double?; var vatTreatment: String?
    var deliveryAddress: DeliveryAddress?; var deliveryDate: Int64?
    var customFields: [CustomFieldSection]?; var effectiveDate: Int64?
    var createdAt: Int64?; var updatedAt: Int64?
    var lineItems: [LineItem]?

    var displayName: String { templateName ?? "Untitled" }

    enum CodingKeys: String, CodingKey {
        case id, description, currency, notes
        case templateNumber = "template_number"; case templateName = "template_name"
        case vendorId = "vendor_id"; case departmentId = "department_id"
        case nominalCode = "nominal_code"; case netAmount = "net_amount"
        case vatTreatment = "vat_treatment"; case deliveryAddress = "delivery_address"
        case deliveryDate = "delivery_date"; case customFields = "custom_fields"
        case effectiveDate = "effective_date"; case lineItems = "line_items"
        case createdAt = "created_at"; case updatedAt = "updated_at"
    }

}

// MARK: - Form Template (dynamic form configuration from API)

struct FormTemplateResponse: Codable {
    var id: String?
    var userId: String?
    var projectId: String?
    var module: String?
    var template: [FormSection]?
    var createdBy: String?
    var updatedBy: String?
    var createdAt: Int64?
    var updatedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, module, template
        case userId = "user_id"
        case projectId = "project_id"
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FormSection: Codable, Identifiable {
    var key: String?
    var label: String?
    var order: Int?
    var fields: [FormField]?
    var values: [String]?
    var systemDefault: Bool?

    var id: String { key ?? "" }
    var isSystemDefault: Bool { systemDefault ?? true }
    var visibleFields: [FormField] {
        (fields ?? []).filter { !$0.isHidden }.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }

    enum CodingKeys: String, CodingKey {
        case key, label, order, fields, values
        case systemDefault = "system_default"
    }
}

struct FormField: Codable, Identifiable {
    var hide: Bool?
    var name: String?
    var type: String?
    var label: String?
    var order: Int?
    var required: Bool?
    var selectionType: String?
    var systemDefault: Bool?

    var id: String { "\(order ?? 0)_\(name ?? "")" }
    var isHidden: Bool { hide ?? false }
    var isRequired: Bool { required ?? false }
    var isSystemDefault: Bool { systemDefault ?? true }

    enum CodingKeys: String, CodingKey {
        case hide, name, type, label, order, required
        case selectionType = "selection_type"
        case systemDefault = "system_default"
    }

}

// MARK: - Invoices

/// Lightweight per-link summary used in the "Linked POs" section of the
/// invoice detail page. Built from the `linked_pos` array the backend
/// returns alongside each invoice row.
struct LinkedPOSummary: Identifiable, Codable, Equatable {
    var id: String { (poId?.isEmpty == false ? poId : poNumber) ?? "" }
    var poId: String?
    var poNumber: String?
    var poVendorId: String?
    var poVendorName: String?   // resolved client-side via vendor lookup
    var poGrossTotal: Double?
    var currency: String?

    enum CodingKeys: String, CodingKey {
        case poId         = "po_id"
        case poNumber     = "po_number"
        case poVendorId   = "po_vendor_id"
        case poVendorName = "po_vendor_name"
        case poGrossTotal = "po_gross_total"
        case currency
    }

    init(poId: String? = nil, poNumber: String? = nil, poVendorId: String? = nil,
         poVendorName: String? = nil, poGrossTotal: Double? = nil, currency: String? = nil) {
        self.poId = poId; self.poNumber = poNumber; self.poVendorId = poVendorId
        self.poVendorName = poVendorName; self.poGrossTotal = poGrossTotal; self.currency = currency
    }

}

/// One entry in an Invoice's `attachments` array. The server ships a
/// real JSON array here (no stringified fallbacks) — each element has
/// the upload id, canonical/stored filename, original path, size, and
/// MIME type.
struct InvoiceAttachment: Codable, Equatable {
    var path: String?
    var filename: String?
    var storedFilename: String?
    var uploadId: String?
    var size: Int?
    var mimeType: String?

    enum CodingKeys: String, CodingKey {
        case path, filename, size
        case storedFilename = "stored_filename"
        case uploadId       = "upload_id"
        case mimeType       = "mime_type"
    }
}

struct Invoice: Identifiable, Codable, Equatable {
    var id: String?
    var projectId: String?
    var userId: String?
    var invoiceNumber: String?
    var vendorId: String?
    var departmentId: String?
    var description: String?
    var currency: String?
    var invoiceDate: Int64?
    var dueDate: Int64?
    var effectiveDate: Int64?
    var grossAmount: Double?
    var status: String?
    var approvalStatus: String?
    var payMethod: String?
    var costCentre: String?
    var assignedTo: String?
    /// Canonical vendor name — decoded from the server's `vendor_name`
    /// column (the legacy `supplier_name` fallback was dropped in the
    /// Apr 2026 model refactor). ViewModels enrich this from the
    /// vendor catalogue once loaded.
    var supplierName: String?
    var reference: String?
    var holdReason: String?
    var holdNote: String?
    var isOverdue: Bool?
    var poId: String?
    var poNumber: String?
    var poIds: [String]?
    /// Richer per-link metadata when the backend sends `linked_pos`: each entry
    /// already has the PO number, the PO's vendor id, and the PO's gross total
    /// — so we can render the "Linked POs" section without hitting the PO list.
    var linkedPOs: [LinkedPOSummary]?
    var lineItems: [LineItem]?
    var approvals: [Approval]?
    var approvedBy: String?
    var approvedAt: Int64?
    var rejectedBy: String?
    var rejectedAt: Int64?
    var rejectionReason: String?
    var tags: [String]?
    var createdAt: Int64?
    var updatedAt: Int64?
    var updatedBy: String?
    var uploadId: String?
    var file: String?
    /// Raw attachments array the server ships alongside each invoice row.
    /// The `fileURL` / `effectiveUploadId` computed helpers fall back to
    /// the first attachment's stored filename / upload id when the flat
    /// columns aren't populated.
    var attachments: [InvoiceAttachment]?
    /// New fields populated by the invoices-server list/detail
    /// endpoints (Apr 2026 web parity):
    ///   • `ocrConfidence` — 0.0-1.0 confidence the OCR pass returned
    ///     for auto-extracted fields; displayed as a subtle signal on
    ///     the Inbox review flow.
    ///   • `nominalCode` — default coding applied via assignment rules.
    ///   • `activeRunId` — id of the currently-scheduled payment run
    ///     this invoice belongs to (empty when not on any run).
    ///   • `previousStatus` — snapshot taken before Hold so the
    ///     server can restore the correct state on Release.
    var ocrConfidence: Double?
    var nominalCode: String?
    var activeRunId: String?
    var previousStatus: String?
    /// Free-form tag list used for credit/tax-credit filtering in the
    /// invoice list. Server column is `tax_credit_tags` (text[]).
    var taxCreditTags: [String]?
    /// Attachments uploaded for the matching wire transfer (separate
    /// from the primary invoice `attachments` array).
    var wireAttachments: [InvoiceAttachment]?
    /// Days past the invoice's due date. Computed server-side.
    var daysOutstanding: Int?
    /// Inline history array returned by list/detail endpoints.
    /// Decoded but not stored long-term — the ViewModel mirrors it into
    /// `invoiceHistory[id]` at load time for immediate display.
    var history: [InvoiceHistoryEntry]?

    // Display fields (resolved, not in DB — populated by enrich(vendor:))
    var vendorAddress: String?
    var vendorEmail: String?
    var vendorPhone: String?
    var vendorContact: String?
    var vendorVatNumber: String?

    static func == (lhs: Invoice, rhs: Invoice) -> Bool { lhs.id == rhs.id }
    var invoiceStatus: InvoiceStatus { InvoiceStatus.fromAPI(status ?? "") }
    var totalAmount: Double { grossAmount ?? 0 }

    /// Department display name — resolved from the DepartmentsData
    /// singleton each time it's read. Moving this out of `init(from:)`
    /// decouples decode from the departments catalogue load order.
    var department: String? {
        DepartmentsData.all.first {
            $0.id == (departmentId ?? "") || $0.identifier == (departmentId ?? "")
        }?.displayName
    }

    /// Effective file reference for the invoice attachment viewer.
    /// Prefers the flat `file` column, then falls back to the first
    /// attachment's `stored_filename` / `filename` / last-path-component
    /// of `path`.
    var fileURL: String? {
        if let f = file, !f.isEmpty { return f }
        if let a = attachments?.first {
            if let s = a.storedFilename, !s.isEmpty { return s }
            if let n = a.filename, !n.isEmpty { return n }
            if let p = a.path, !p.isEmpty {
                return (p as NSString).lastPathComponent
            }
        }
        return nil
    }

    /// Effective upload id — prefers the flat `upload_id` column, then
    /// falls back to the first attachment's upload id.
    var effectiveUploadId: String? {
        if let u = uploadId, !u.isEmpty { return u }
        return attachments?.first?.uploadId
    }

    enum CodingKeys: String, CodingKey {
        case id, description, currency, status, tags, approvals, attachments, file, history
        case projectId       = "project_id"
        case userId          = "user_id"
        case invoiceNumber   = "invoice_number"
        case vendorId        = "vendor_id"
        case departmentId    = "department_id"
        case grossAmount     = "gross_amount"
        case approvalStatus  = "approval_status"
        case payMethod       = "pay_method"
        case costCentre      = "cost_centre"
        case assignedTo      = "assigned_to"
        case supplierName    = "vendor_name"
        case reference
        case holdReason      = "hold_reason"
        case holdNote        = "hold_note"
        case isOverdue       = "is_overdue"
        case approvedBy      = "approved_by"
        case approvedAt      = "approved_at"
        case poId            = "po_id"
        case poNumber        = "po_number"
        case poIds           = "po_ids"
        case lineItems       = "line_items"
        case linkedPOs       = "linked_pos"
        case rejectionReason = "rejection_reason"
        case rejectedBy      = "rejected_by"
        case rejectedAt      = "rejected_at"
        case invoiceDate     = "invoice_date"
        case dueDate         = "due_date"
        case effectiveDate   = "effective_date"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        case updatedBy       = "updated_by"
        case uploadId        = "upload_id"
        case ocrConfidence   = "ocr_confidence"
        case nominalCode     = "nominal_code"
        case activeRunId     = "active_run_id"
        case previousStatus  = "previous_status"
        case taxCreditTags   = "tax_credit_tags"
        case wireAttachments = "wire_attachments"
        case daysOutstanding = "days_outstanding"
    }

    /// Enrich vendor display fields from the vendor list.
    /// Call this after decode when the vendor catalogue is available.
    mutating func enrich(vendor: Vendor?) {
        guard let v = vendor else { return }
        supplierName    = v.name ?? supplierName
        vendorAddress   = v.address?.formatted ?? ""
        vendorEmail     = v.email ?? ""
        let cc  = v.phone?.countryCode ?? ""
        let num = v.phone?.number ?? ""
        let full = "\(cc) \(num)".trimmingCharacters(in: .whitespaces)
        vendorPhone     = full.isEmpty ? nil : full
        vendorContact   = v.contactPerson ?? ""
        vendorVatNumber = v.vatNumber
    }
}

enum InvoiceStatus: String, CaseIterable {
    case inbox = "inbox"
    case draft = "draft", approval = "approval", approved = "approved"
    case rejected = "rejected", paid = "paid", onHold = "on_hold"
    case partiallyPaid = "partially_paid", voided = "voided"
    case override_ = "override"
    // Accountant-only workflow stages (web parity — EntryPage.jsx):
    //   • under_review — accountant is reviewing an approved invoice
    //     before marking it ready to pay
    //   • ready_to_pay — cleared for payment run scheduling
    case underReview = "under_review"
    case readyToPay  = "ready_to_pay"

    /// Display names mirror the web's `INVOICE_STATUS_MAP` so every
    /// surface in the app (list badges, detail header, quick filter
    /// text, delete/confirm prompts) shows the same wording the
    /// accountant sees on the browser.
    var displayName: String {
        switch self {
        case .inbox: return "Inbox"
        case .draft: return "Draft"
        case .approval: return "Approval"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .paid: return "Paid"
        case .onHold: return "On Hold"
        case .partiallyPaid: return "Partially Paid"
        case .voided: return "Cancelled"
        case .override_: return "Override"
        case .underReview: return "Under Review"
        case .readyToPay: return "Ready to Pay"
        }
    }
    static func fromAPI(_ raw: String) -> InvoiceStatus {
        if raw.lowercased() == "override" { return .override_ }
        return InvoiceStatus(rawValue: raw.lowercased()) ?? .draft
    }
}

// MARK: - Payment Run

struct PaymentRunInvoice: Identifiable, Codable, Equatable {
    var id: String?
    var invoiceNumber: String?
    var supplierName: String?
    var description: String?
    var dueDate: Int64?
    var amount: Double?
    var currency: String?

    enum CodingKeys: String, CodingKey {
        case id, description, currency
        case invoiceNumber = "invoice_number"
        case supplierName  = "supplier_name"
        case dueDate       = "due_date"
        case amount        = "gross_amount"
    }

    init(id: String? = nil, invoiceNumber: String? = nil, supplierName: String? = nil,
         description: String? = nil, dueDate: Int64? = nil, amount: Double? = nil, currency: String? = nil) {
        self.id = id; self.invoiceNumber = invoiceNumber; self.supplierName = supplierName
        self.description = description; self.dueDate = dueDate; self.amount = amount; self.currency = currency
    }
}

struct PaymentRunApproval: Identifiable, Codable, Equatable {
    var id: String { "\(userId ?? "")-\(tierNumber ?? 0)" }
    var userId: String?
    var approvedAt: Int64?
    var tierNumber: Int?

    enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case approvedAt = "approved_at"
        case tierNumber = "tier_number"
    }

    init(userId: String? = nil, approvedAt: Int64? = nil, tierNumber: Int? = nil) {
        self.userId = userId; self.approvedAt = approvedAt; self.tierNumber = tierNumber
    }
}

struct PaymentRun: Identifiable, Codable, Equatable {
    var id: String?
    var projectId: String?
    var name: String?
    var number: String?
    var payMethod: String?
    var approval: [PaymentRunApproval]?
    var status: String?
    var totalAmount: Double?
    var createdBy: String?
    var createdAt: Int64?
    var updatedAt: Int64?
    var rejectedBy: String?
    var rejectedAt: Int64?
    var rejectionReason: String?
    var invoiceCount: Int?
    var computedTotal: Double?
    var invoices: [PaymentRunInvoice]?

    static func == (lhs: PaymentRun, rhs: PaymentRun) -> Bool { lhs.id == rhs.id }
    var isPending: Bool { (status ?? "").lowercased() == "pending" }
    var isApproved: Bool { (status ?? "").lowercased() == "approved" }
    var isRejected: Bool { (status ?? "").lowercased() == "rejected" }
    var approvedCount: Int { approval?.count ?? 0 }

    enum CodingKeys: String, CodingKey {
        case id, name, number, status, approval, invoices
        case projectId       = "project_id"
        case payMethod       = "pay_method"
        case totalAmount     = "total_amount"
        case createdBy       = "created_by"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        case rejectedBy      = "rejected_by"
        case rejectedAt      = "rejected_at"
        case rejectionReason = "rejection_reason"
        case invoiceCount    = "invoice_count"
        case computedTotal   = "computed_total"
    }
}

// MARK: - Non-DB models

typealias LegacyTierConfig = [String: [LegacyTierEntry]]
struct LegacyTierEntry { var userId: String?; var departmentId: String?; var tierNumber: Int? }

struct AppUser: Identifiable, Equatable {
    var id: String?; var fullName: String?; var firstName: String?; var lastName: String?
    var departmentId: String?; var departmentName: String?; var departmentIdentifier: String?
    var designationId: String?; var designationName: String?; var designationIdentifier: String?
    var status: String?; var isAdmin: Bool?; var isOwner: Bool?; var email: String?
    var displayDesignation: String { FormatUtils.formatLabel(designationName ?? "") }
    var displayDepartment: String { FormatUtils.formatLabel(departmentName ?? "") }
    var isAccountant: Bool { departmentIdentifier == "department_accounts" }
    var initials: String { (fullName ?? "").split(separator: " ").map { String($0.prefix(1)) }.joined() }
}

struct Department: Identifiable, Equatable {
    var id: String?; var projectId: String?; var departmentName: String?
    var identifier: String?; var systemDefined: Bool?
    var displayName: String { FormatUtils.formatLabel(departmentName ?? "") }
}

