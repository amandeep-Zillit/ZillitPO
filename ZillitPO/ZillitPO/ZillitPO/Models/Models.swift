import Foundation

// MARK: - Flexible Int decode helper (handles string/double/int from API)

func flexibleIntDecode<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> Int? {
    if let v = try? container.decode(Int.self, forKey: key) { return v }
    if let v = try? container.decode(Double.self, forKey: key) { return Int(v) }
    if let v = try? container.decode(String.self, forKey: key) { return Int(v) ?? Int(Double(v) ?? 0) }
    return nil
}

func flexibleDoubleDecode<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> Double? {
    if let v = try? container.decode(Double.self, forKey: key) { return v }
    if let v = try? container.decode(Int.self, forKey: key) { return Double(v) }
    if let v = try? container.decode(String.self, forKey: key) { return Double(v) }
    return nil
}

// ═══════════════════════════════════════════════════════════════════════════════
// Models — 1:1 with DB Migrations (001–010)
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - 001 approval_tier_configs

struct ApprovalTierConfig: Identifiable, Codable, Equatable {
    let id: String
    var projectId: String
    var module: String
    var scope: String            // "all" | "department"
    var departmentId: String?
    var tiers: [TierDef]
    var createdBy: String
    var updatedBy: String
    var createdAt: Int64
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, module, scope, tiers
        case projectId = "project_id"
        case departmentId = "department_id"
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        projectId = try c.decode(String.self, forKey: .projectId)
        module = try c.decode(String.self, forKey: .module)
        scope = try c.decode(String.self, forKey: .scope)
        departmentId = try? c.decode(String.self, forKey: .departmentId)
        tiers = (try? c.decode([TierDef].self, forKey: .tiers)) ?? []
        createdBy = (try? c.decode(String.self, forKey: .createdBy)) ?? ""
        updatedBy = (try? c.decode(String.self, forKey: .updatedBy)) ?? ""
        // API may return timestamps as String or Int64
        if let v = try? c.decode(Int64.self, forKey: .createdAt) { createdAt = v }
        else if let s = try? c.decode(String.self, forKey: .createdAt) { createdAt = Int64(s) ?? 0 }
        else { createdAt = 0 }
        if let v = try? c.decode(Int64.self, forKey: .updatedAt) { updatedAt = v }
        else if let s = try? c.decode(String.self, forKey: .updatedAt) { updatedAt = Int64(s) ?? 0 }
        else { updatedAt = 0 }
    }

    init(id: String, projectId: String, module: String, scope: String, departmentId: String?, tiers: [TierDef], createdBy: String, updatedBy: String, createdAt: Int64, updatedAt: Int64) {
        self.id = id; self.projectId = projectId; self.module = module; self.scope = scope
        self.departmentId = departmentId; self.tiers = tiers; self.createdBy = createdBy
        self.updatedBy = updatedBy; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

struct TierDef: Codable, Equatable {
    let order: Int
    let gate: TierGate?
    let rules: [TierRule]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        order = (try? c.decode(Int.self, forKey: .order)) ?? 0
        gate = try? c.decode(TierGate.self, forKey: .gate)
        rules = (try? c.decode([TierRule].self, forKey: .rules)) ?? []
    }

    init(order: Int, gate: TierGate?, rules: [TierRule]) {
        self.order = order; self.gate = gate; self.rules = rules
    }

    enum CodingKeys: String, CodingKey { case order, gate, rules }
}

struct TierGate: Codable, Equatable {
    let enabled: Bool
    let type: String
    let amountThreshold: Double?
    enum CodingKeys: String, CodingKey {
        case enabled, type
        case amountThreshold = "amount_threshold"
    }
}

struct TierRule: Codable, Equatable {
    let type: String             // "default" | "amount"
    let amountThreshold: Double?
    let userIds: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case amountThreshold = "amount_threshold"
        case userIds = "user_ids"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? c.decode(String.self, forKey: .type)) ?? "default"
        amountThreshold = try? c.decode(Double.self, forKey: .amountThreshold)
        userIds = (try? c.decode([String].self, forKey: .userIds)) ?? []
    }

    init(type: String, amountThreshold: Double?, userIds: [String]) {
        self.type = type; self.amountThreshold = amountThreshold; self.userIds = userIds
    }
}

// MARK: - 002 vendors

struct Vendor: Identifiable, Codable, Equatable {
    let id: String
    var projectId: String
    var userId: String
    var name: String
    var address: VendorAddress
    var email: String
    var phone: VendorPhone
    var contactPerson: String
    var vatNumber: String?
    var status: String
    var verifiedAt: Int?
    var verifiedBy: String?
    var addedBy: String?
    var updatedBy: String?
    var departmentId: String?
    var createdAt: Int?
    var updatedAt: Int?

    var verified: Bool {
        guard let v = verifiedAt else { return false }
        return v > 0
    }

    enum CodingKeys: String, CodingKey {
        case id, name, address, email, phone, status
        case projectId = "project_id"
        case userId = "user_id"
        case contactPerson = "contact_person"
        case vatNumber = "vat_number"
        case verifiedAt = "verified_at"
        case verifiedBy = "verified_by"
        case addedBy = "added_by"
        case updatedBy = "updated_by"
        case departmentId = "department_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String = UUID().uuidString, projectId: String = "", userId: String = "",
         name: String = "", address: VendorAddress = VendorAddress(), email: String = "",
         phone: VendorPhone = VendorPhone(), contactPerson: String = "",
         vatNumber: String? = nil, status: String = "PENDING",
         verifiedAt: Int? = nil, verifiedBy: String? = nil,
         addedBy: String? = nil, updatedBy: String? = nil, departmentId: String? = nil,
         createdAt: Int? = nil, updatedAt: Int? = nil) {
        self.id = id; self.projectId = projectId; self.userId = userId
        self.name = name; self.address = address; self.email = email; self.phone = phone
        self.contactPerson = contactPerson; self.vatNumber = vatNumber; self.status = status
        self.verifiedAt = verifiedAt; self.verifiedBy = verifiedBy; self.addedBy = addedBy
        self.updatedBy = updatedBy; self.departmentId = departmentId
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        projectId = (try? c.decode(String.self, forKey: .projectId)) ?? ""
        userId = (try? c.decode(String.self, forKey: .userId)) ?? ""
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        address = (try? c.decode(VendorAddress.self, forKey: .address)) ?? VendorAddress()
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
        phone = (try? c.decode(VendorPhone.self, forKey: .phone)) ?? VendorPhone()
        contactPerson = (try? c.decode(String.self, forKey: .contactPerson)) ?? ""
        vatNumber = try? c.decode(String.self, forKey: .vatNumber)
        status = (try? c.decode(String.self, forKey: .status)) ?? "PENDING"
        verifiedBy = try? c.decode(String.self, forKey: .verifiedBy)
        addedBy = try? c.decode(String.self, forKey: .addedBy)
        updatedBy = try? c.decode(String.self, forKey: .updatedBy)
        departmentId = try? c.decode(String.self, forKey: .departmentId)
        // Flexible Int fields
        verifiedAt = flexibleIntDecode(c, .verifiedAt)
        createdAt = flexibleIntDecode(c, .createdAt)
        updatedAt = flexibleIntDecode(c, .updatedAt)
    }
}

struct VendorPhone: Codable, Equatable {
    var countryCode: String
    var number: String
    enum CodingKeys: String, CodingKey { case countryCode = "country_code"; case number }
    init(countryCode: String = "", number: String = "") {
        self.countryCode = countryCode; self.number = number
    }
}

struct VendorAddress: Codable, Equatable {
    var line1: String?; var line2: String?; var city: String?
    var state: String?; var postalCode: String?; var country: String?
    enum CodingKeys: String, CodingKey {
        case line1, line2, city, state, country; case postalCode = "postal_code"
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

struct PurchaseOrder: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var projectId: String = ""
    var userId: String = ""
    var poNumber: String = ""
    var vendorId: String?
    var departmentId: String?
    var nominalCode: String?
    var description: String?
    var currency: String = "GBP"
    var effectiveDate: Int64?
    var notes: String?
    var netAmount: Double = 0
    var status: String = "DRAFT"
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
    var vatTreatment: String = "pending"
    var deliveryAddress: DeliveryAddress?
    var deliveryDate: Int64?
    var closedBy: String?
    var closedAt: Int64?
    var closureReason: String?
    var customFields: [CustomFieldSection] = []
    var vatAmount: Double?
    var grossTotal: Double?
    var approvals: [Approval] = []
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0

    // Display fields (resolved, not in DB)
    var vendor: String = ""
    var vendorAddress: String = ""
    var department: String = ""
    var lineItems: [LineItem] = []

    static func == (lhs: PurchaseOrder, rhs: PurchaseOrder) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt && lhs.status == rhs.status
        && lhs.netAmount == rhs.netAmount && lhs.vatTreatment == rhs.vatTreatment
        && lhs.lineItems.count == rhs.lineItems.count
    }
    var poStatus: POStatus { POStatus.fromAPI(status) }
    var totalAmount: Double {
        if netAmount > 0 { return netAmount }
        // Fallback: compute from line items if net_amount is 0 or missing
        let computed = lineItems.filter { $0.splitParentId == nil }.reduce(0.0) { $0 + ($1.quantity * $1.unitPrice) }
        return computed > 0 ? computed : netAmount
    }
}

struct DeliveryAddress: Codable, Equatable {
    var name: String?; var email: String?; var phoneCode: String?; var phone: String?
    var line1: String?; var line2: String?; var city: String?
    var state: String?; var postalCode: String?; var country: String?
    var formattedAddress: String {
        [line1, line2, city, state, postalCode].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct Approval: Codable, Equatable {
    var userId: String; var tierNumber: Int; var approvedAt: Int64
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"; case tierNumber = "tier_number"; case approvedAt = "approved_at"
    }
}

struct CustomFieldSection: Codable, Equatable {
    var section: String?; var fields: [CustomFieldValue]?
}

struct CustomFieldValue: Codable, Equatable {
    var name: String; var value: String
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
    var id: String = UUID().uuidString
    var projectId: String?; var userId: String?; var poId: String?
    var lineNumber: Int = 1
    var description: String = ""
    var quantity: Double = 1
    var unitPrice: Double = 0
    var total: Double = 0
    var account: String = ""
    var department: String = ""
    var expenditureType: String = "Purchase"
    var vatTreatment: String = "pending"
    var rentalStart: Int64?; var rentalEnd: Int64?
    var splitParentId: String?
    var customFields: [CustomFieldValue] = []
    var createdAt: Int64?; var updatedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, description, quantity, total, account, department
        case projectId = "project_id"; case userId = "user_id"; case poId = "po_id"
        case lineNumber = "line_number"; case unitPrice = "unit_price"
        case expenditureType = "expenditure_type"; case vatTreatment = "vat_treatment"
        case rentalStart = "rental_start"; case rentalEnd = "rental_end"
        case splitParentId = "split_parent_id"; case customFields = "custom_fields"
        case createdAt = "created_at"; case updatedAt = "updated_at"
    }

    init(id: String = UUID().uuidString, description: String = "", quantity: Double = 1,
         unitPrice: Double = 0, total: Double = 0, account: String = "",
         department: String = "", expenditureType: String = "Purchase", vatTreatment: String = "pending") {
        self.id = id; self.description = description; self.quantity = quantity
        self.unitPrice = unitPrice; self.total = total; self.account = account
        self.department = department; self.expenditureType = expenditureType
        self.vatTreatment = vatTreatment
    }
}

// MARK: - 005 po_templates

struct POTemplate: Identifiable, Codable {
    let id: String
    var templateNumber: String?; var templateName: String?
    var vendorId: String?; var departmentId: String?; var nominalCode: String?
    var description: String?; var currency: String?; var notes: String?
    var netAmount: Double?; var vatTreatment: String?
    var deliveryAddress: FlexibleDeliveryAddress?; var deliveryDate: Int?
    var customFields: FlexibleCustomFields?; var effectiveDate: Int?
    var createdAt: Int?; var updatedAt: Int?
    var lineItems: FlexibleLineItems?

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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        templateNumber = try? c.decode(String.self, forKey: .templateNumber)
        templateName = try? c.decode(String.self, forKey: .templateName)
        vendorId = try? c.decode(String.self, forKey: .vendorId)
        departmentId = try? c.decode(String.self, forKey: .departmentId)
        nominalCode = try? c.decode(String.self, forKey: .nominalCode)
        description = try? c.decode(String.self, forKey: .description)
        currency = try? c.decode(String.self, forKey: .currency)
        notes = try? c.decode(String.self, forKey: .notes)
        vatTreatment = try? c.decode(String.self, forKey: .vatTreatment)
        deliveryAddress = try? c.decode(FlexibleDeliveryAddress.self, forKey: .deliveryAddress)
        customFields = try? c.decode(FlexibleCustomFields.self, forKey: .customFields)
        lineItems = try? c.decode(FlexibleLineItems.self, forKey: .lineItems)
        // Flexible Int fields
        netAmount = flexibleDoubleDecode(c, .netAmount)
        deliveryDate = flexibleIntDecode(c, .deliveryDate)
        effectiveDate = flexibleIntDecode(c, .effectiveDate)
        createdAt = flexibleIntDecode(c, .createdAt)
        updatedAt = flexibleIntDecode(c, .updatedAt)
    }
}

// MARK: - 007 po_assignment_rules

struct POAssignmentRule: Identifiable, Codable, Equatable {
    let id: String
    var projectId: String; var userId: String; var name: String?
    var departments: [String]; var vendors: [String]; var nominalCodes: [String]
    var amountMin: Double?; var targetUserId: String; var priority: Int
    var isActive: Bool; var createdAt: Int64; var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, name, departments, vendors, priority
        case projectId = "project_id"; case userId = "user_id"
        case nominalCodes = "nominal_codes"; case amountMin = "amount_min"
        case targetUserId = "target_user_id"; case isActive = "is_active"
        case createdAt = "created_at"; case updatedAt = "updated_at"
    }
}

// MARK: - 009 po_settings_metadata

struct POSettingsMetadata: Identifiable, Codable, Equatable {
    let id: String
    var projectId: String; var descriptionFormat: String
    var autoSplitRentals: Bool; var defaultSplitType: String
    var requireEffectiveDate: Bool; var enforcePeriodClose: Bool
    var createdBy: String; var updatedBy: String
    var createdAt: Int64; var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"; case descriptionFormat = "description_format"
        case autoSplitRentals = "auto_split_rentals"; case defaultSplitType = "default_split_type"
        case requireEffectiveDate = "require_effective_date"; case enforcePeriodClose = "enforce_period_close"
        case createdBy = "created_by"; case updatedBy = "updated_by"
        case createdAt = "created_at"; case updatedAt = "updated_at"
    }
}

// MARK: - Form Template (dynamic form configuration from API)

struct FormTemplateResponse: Codable {
    let id: String
    var userId: String?
    var projectId: String?
    var module: String?
    var template: [FormSection]
    var createdBy: String?
    var updatedBy: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, module, template
        case userId = "user_id"
        case projectId = "project_id"
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try? c.decode(String.self, forKey: .userId)
        projectId = try? c.decode(String.self, forKey: .projectId)
        module = try? c.decode(String.self, forKey: .module)
        createdBy = try? c.decode(String.self, forKey: .createdBy)
        updatedBy = try? c.decode(String.self, forKey: .updatedBy)
        createdAt = try? c.decode(String.self, forKey: .createdAt)
        updatedAt = try? c.decode(String.self, forKey: .updatedAt)
        // Decode template: handle JSON array or JSON string
        if let sections = try? c.decode([FormSection].self, forKey: .template) {
            template = sections
        } else if let str = try? c.decode(String.self, forKey: .template),
                  let data = str.data(using: .utf8),
                  let sections = try? JSONDecoder().decode([FormSection].self, from: data) {
            template = sections
        } else {
            template = []
        }
    }
}

struct FormSection: Codable, Identifiable {
    var key: String
    var label: String
    var order: Int
    var fields: [FormField]
    var values: [String]?
    var systemDefault: Bool?

    var id: String { key }
    var isSystemDefault: Bool { systemDefault ?? true }
    var visibleFields: [FormField] {
        fields.filter { !$0.isHidden }.sorted { $0.order < $1.order }
    }

    enum CodingKeys: String, CodingKey {
        case key, label, order, fields, values
        case systemDefault = "system_default"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = (try? c.decode(String.self, forKey: .key)) ?? ""
        label = (try? c.decode(String.self, forKey: .label)) ?? ""
        order = flexibleIntDecode(c, .order) ?? 0
        values = try? c.decode([String].self, forKey: .values)
        systemDefault = try? c.decode(Bool.self, forKey: .systemDefault)
        // Decode fields flexibly — skip individual fields that fail
        if let rawFields = try? c.decode([SafeFormField].self, forKey: .fields) {
            fields = rawFields.compactMap { $0.field }
        } else {
            fields = []
        }
    }
}

// Wrapper to safely decode individual FormFields without failing the entire array
private struct SafeFormField: Decodable {
    let field: FormField?
    init(from decoder: Decoder) throws {
        field = try? FormField(from: decoder)
    }
}

struct FormField: Codable, Identifiable {
    var hide: Bool?
    var name: String
    var type: String
    var label: String?
    var order: Int
    var required: Bool?
    var selectionType: String?
    var systemDefault: Bool?

    var id: String { "\(order)_\(name)" }
    var isHidden: Bool { hide ?? false }
    var isRequired: Bool { required ?? false }
    var isSystemDefault: Bool { systemDefault ?? true }

    enum CodingKeys: String, CodingKey {
        case hide, name, type, label, order, required
        case selectionType = "selection_type"
        case systemDefault = "system_default"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        type = (try? c.decode(String.self, forKey: .type)) ?? "text"
        order = flexibleIntDecode(c, .order) ?? 0
        hide = try? c.decode(Bool.self, forKey: .hide)
        label = try? c.decode(String.self, forKey: .label)
        required = try? c.decode(Bool.self, forKey: .required)
        selectionType = try? c.decode(String.self, forKey: .selectionType)
        systemDefault = try? c.decode(Bool.self, forKey: .systemDefault)
    }
}

// MARK: - Invoices

struct Invoice: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var projectId: String = ""
    var userId: String = ""
    var invoiceNumber: String = ""
    var vendorId: String?
    var departmentId: String?
    var description: String?
    var currency: String = "GBP"
    var invoiceDate: Int64?
    var dueDate: Int64?
    var effectiveDate: Int64?
    var grossAmount: Double = 0
    var status: String = "draft"
    var approvalStatus: String = "pending"
    var payMethod: String?
    var costCentre: String?
    var assignedTo: String?
    var supplierName: String = ""
    var reference: String?
    var holdReason: String?
    var holdNote: String?
    var isOverdue: Bool = false
    var poId: String?
    var poNumber: String?
    var poIds: [String] = []
    var lineItems: [LineItem] = []
    var approvals: [Approval] = []
    var approvedBy: String?
    var approvedAt: Int64?
    var rejectedBy: String?
    var rejectedAt: Int64?
    var rejectionReason: String?
    var tags: [String] = []
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0

    // Display fields (resolved, not in DB)
    var department: String = ""

    static func == (lhs: Invoice, rhs: Invoice) -> Bool { lhs.id == rhs.id }
    var invoiceStatus: InvoiceStatus { InvoiceStatus.fromAPI(status) }
    var totalAmount: Double { grossAmount }
}

enum InvoiceStatus: String, CaseIterable {
    case draft = "draft", approval = "approval", approved = "approved"
    case rejected = "rejected", paid = "paid", onHold = "on_hold"
    case partiallyPaid = "partially_paid", voided = "voided"

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .approval: return "Pending Approval"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .paid: return "Paid"
        case .onHold: return "On Hold"
        case .partiallyPaid: return "Partially Paid"
        case .voided: return "Voided"
        }
    }
    static func fromAPI(_ raw: String) -> InvoiceStatus {
        InvoiceStatus(rawValue: raw.lowercased()) ?? .draft
    }
}

// MARK: - Payment Run

struct PaymentRunInvoice: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var invoiceNumber: String = ""
    var supplierName: String = ""
    var description: String = ""
    var dueDate: Int64?
    var amount: Double = 0
    var currency: String = "GBP"
}

struct PaymentRunApproval: Identifiable, Equatable {
    var id: String { "\(userId)-\(tierNumber)" }
    var userId: String
    var approvedAt: Int64
    var tierNumber: Int
}

struct PaymentRun: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var projectId: String = ""
    var name: String = ""
    var number: String = ""
    var payMethod: String = ""
    var approval: [PaymentRunApproval] = []
    var status: String = "pending"
    var totalAmount: Double = 0
    var createdBy: String = ""
    var createdAt: Int64 = 0
    var updatedAt: Int64 = 0
    var rejectedBy: String?
    var rejectedAt: Int64?
    var rejectionReason: String?
    var invoiceCount: Int = 0
    var computedTotal: Double = 0
    var invoices: [PaymentRunInvoice] = []

    static func == (lhs: PaymentRun, rhs: PaymentRun) -> Bool { lhs.id == rhs.id }
    var isPending: Bool { status.lowercased() == "pending" }
    var isApproved: Bool { status.lowercased() == "approved" }
    var isRejected: Bool { status.lowercased() == "rejected" }
    var approvedCount: Int { approval.count }
}

// MARK: - Non-DB models

typealias LegacyTierConfig = [String: [LegacyTierEntry]]
struct LegacyTierEntry { let userId: String; let departmentId: String?; let tierNumber: Int }

struct AppUser: Identifiable, Equatable {
    let id: String; let fullName: String; let firstName: String; let lastName: String
    let departmentId: String; let departmentName: String; let departmentIdentifier: String
    let designationId: String; let designationName: String; let designationIdentifier: String
    let status: String; let isAdmin: Bool; let isOwner: Bool; let email: String
    var displayDesignation: String { FormatUtils.formatLabel(designationName) }
    var displayDepartment: String { FormatUtils.formatLabel(departmentName) }
    var isAccountant: Bool { departmentIdentifier == "department_accounts" }
    var initials: String { fullName.split(separator: " ").map { String($0.prefix(1)) }.joined() }
}

struct Department: Identifiable, Equatable {
    let id: String; let projectId: String; let departmentName: String
    let identifier: String; let systemDefined: Bool
    var displayName: String { FormatUtils.formatLabel(departmentName) }
}

// Flexible JSON value
enum AnyCodableValue: Codable, Equatable {
    case string(String); case int(Int64); case double(Double); case bool(Bool); case null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int64.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        self = .null
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v); case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v); case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    var doubleValue: Double {
        switch self { case .string(let s): return Double(s) ?? 0; case .int(let i): return Double(i)
        case .double(let d): return d; default: return 0 }
    }
    var int64Value: Int64? {
        switch self { case .int(let i): return i; case .double(let d): return Int64(d)
        case .string(let s): return Int64(s); default: return nil }
    }
}
