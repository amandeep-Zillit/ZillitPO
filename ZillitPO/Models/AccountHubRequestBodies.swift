//
//  AccountHubRequestBodies.swift
//  ZillitPO
//
//  Typed Encodable request-body models for every mutating AccountHub
//  endpoint. The request-enum cases in PORequest / CardExpenseRequest /
//  CashExpenseRequest take these directly and encode them to JSON via
//  `JSONEncoder` — mirroring the pattern used by `ContractSignatureRequest`
//  in the live Zillit project.
//
//  Conventions:
//  • Snake_case API keys are declared via CodingKeys.
//  • Optional fields are omitted from the JSON when nil (default
//    JSONEncoder behaviour), matching the previous conditional-dict
//    construction in the ViewModels.
//  • Fields that must be sent as explicit `null` (e.g. `reason_notes`
//    on recordFloatReturn) use `NullableString` / `NullableDouble`
//    wrappers which encode nil → `null` rather than omitting the key.
//
//  Demo vs Live attachment flow:
//  • Live: file → S3 (via SwiftUIUtils.uploadAttachmentModel) → DocumentModel
//    is sent in JSON.
//  • Demo: file → multipart POST → server returns { file_name, path } →
//    same DocumentModel is sent in JSON. The struct shape is identical;
//    only `media/region/bucket` (live) vs `serverPath` (demo) differ.
//

import Foundation

// MARK: - Nullable wrappers

enum NullableString: Encodable {
    case value(String)
    case null

    init(_ s: String?) {
        if let s = s { self = .value(s) } else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .value(let s): try c.encode(s)
        case .null: try c.encodeNil()
        }
    }
}

enum NullableDouble: Encodable {
    case value(Double)
    case null

    init(_ v: Double?) { if let v = v { self = .value(v) } else { self = .null } }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .value(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

// MARK: - Shared approval / rejection / override

struct ApprovalActionRequest: Encodable {
    var tierNumber: Int
    var totalTiers: Int
    var userId: String?

    enum CodingKeys: String, CodingKey {
        case tierNumber = "tier_number"
        case totalTiers = "total_tiers"
        case userId     = "user_id"
    }
}

struct FloatOverrideApprovalRequest: Encodable {
    var override: Bool = true
    var userId: String?

    enum CodingKeys: String, CodingKey {
        case override
        case userId = "user_id"
    }
}

struct ReasonRequest: Encodable {
    var reason: String
    var userId: String?

    enum CodingKeys: String, CodingKey {
        case reason
        case userId = "user_id"
    }
}

struct RejectionReasonRequest: Encodable {
    var rejectionReason: String
    var userId: String?

    enum CodingKeys: String, CodingKey {
        case rejectionReason = "rejection_reason"
        case userId          = "user_id"
    }
}

// MARK: - Vendors

struct VendorPhoneBody: Encodable {
    var countryCode: String
    var number: String

    enum CodingKeys: String, CodingKey {
        case countryCode = "country_code"
        case number
    }
}

struct VendorAddressBody: Encodable {
    var line1: String
    var line2: String?
    var city: String
    var state: String?
    var postalCode: String
    var country: String

    enum CodingKeys: String, CodingKey {
        case line1, line2, city, state, country
        case postalCode = "postal_code"
    }
}

struct VendorBankAdditionalDetailBody: Codable {
    var title: String
    var description: String
}

struct VendorBankDetailsUpdateBody: Codable {
    var bankName: String?
    var accountHolderName: String?
    var accountNumber: String?
    var sortCode: String?
    var ibanCode: String?
    var swiftCode: String?
    var additionalInfo: [VendorBankAdditionalDetailBody]?

    enum CodingKeys: String, CodingKey {
        case bankName          = "bank_name"
        case accountHolderName = "account_holder_name"
        case accountNumber     = "account_number"
        case sortCode          = "sort_code"
        case ibanCode          = "iban_code"
        case swiftCode         = "swift_code"
        case additionalInfo    = "additional_info"
    }
}

struct VendorRequestBody: Encodable {
    var name: String
    var contactPerson: String
    var email: String
    var phone: VendorPhoneBody
    var address: VendorAddressBody
    var vatNumber: String?
    var departmentId: String?
    var companyType: String?
    var terms: String?
    var defaultCode: String?
    var vendorType: String?
    var compliance: String?
    var bankName: String?
    var accountHolderName: String?
    var accountNumber: String?
    var sortCode: String?
    var ibanCode: String?
    var swiftCode: String?
    var additionalInfo: [VendorBankAdditionalDetailBody]?

    enum CodingKeys: String, CodingKey {
        case name, email, terms, phone, address, compliance
        case contactPerson     = "contact_person"
        case vatNumber         = "vat_number"
        case departmentId      = "department_id"
        case companyType       = "company_type"
        case defaultCode       = "default_code"
        case vendorType        = "vendor_type"
        case bankName          = "bank_name"
        case accountHolderName = "account_holder_name"
        case accountNumber     = "account_number"
        case sortCode          = "sort_code"
        case ibanCode          = "iban_code"
        case swiftCode         = "swift_code"
        case additionalInfo    = "additional_info"
    }
}

// MARK: - Purchase Orders

struct PODeliveryAddressBody: Encodable {
    var name: String
    var email: String
    var phoneCode: String?
    var phone: String
    var line1: String
    var line2: String
    var city: String
    var state: String
    var postalCode: String
    var country: String

    enum CodingKeys: String, CodingKey {
        case name, email, phone, line1, line2, city, state, country
        case phoneCode  = "phone_code"
        case postalCode = "postal_code"
    }
}

struct POCustomFieldEntryBody: Encodable {
    var name: String
    var value: String
}

struct POCustomFieldSectionBody: Encodable {
    var section: String
    var fields: [POCustomFieldEntryBody]
}

struct POApprovalEntryBody: Encodable {
    var userId: String
    var tierNumber: Int
    var approvedAt: Int64

    enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case tierNumber = "tier_number"
        case approvedAt = "approved_at"
    }
}

struct POLineItemBody: Encodable {
    var id: String
    var description: String
    var quantity: Double
    var unitPrice: Double
    var total: Double
    var account: String
    var department: String
    var expenditureType: String
    var vatTreatment: String
    var taxType: String?
    var taxRate: Double?
    var tags: [String]?
    var customFields: [POCustomFieldEntryBody]?

    enum CodingKeys: String, CodingKey {
        case id, description, quantity, total, account, department, tags
        case unitPrice       = "unit_price"
        case expenditureType = "expenditure_type"
        case vatTreatment    = "vat_treatment"
        case taxType         = "tax_type"
        case taxRate         = "tax_rate"
        case customFields    = "custom_fields"
    }
}

struct POAttachmentBody: Encodable {
    var fileName: String?
    var media: String?
    var region: String?
    var bucket: String?
    var contentType: String?
    var contentSubType: String?

    enum CodingKeys: String, CodingKey {
        case media, region, bucket
        case fileName       = "name"
        case contentType    = "content_type"
        case contentSubType = "content_subtype"
    }
}

struct POCreateRequest: Encodable {
    var vendorId: String?
    var departmentId: String
    var nominalCode: String
    var description: String
    var currency: String
    var vatTreatment: String
    var notes: String
    var netAmount: Double
    var status: String
    var lineItems: [POLineItemBody]
    var approvals: [POApprovalEntryBody]?
    var effectiveDate: Int64?
    var deliveryDate: Int64?
    var deliveryAddress: PODeliveryAddressBody?
    var customFields: [POCustomFieldSectionBody]?
    var attachments: [POAttachmentBody]?

    enum CodingKeys: String, CodingKey {
        case description, currency, notes, status, approvals, attachments
        case vendorId        = "vendor_id"
        case departmentId    = "department_id"
        case nominalCode     = "nominal_code"
        case vatTreatment    = "vat_treatment"
        case netAmount       = "net_amount"
        case lineItems       = "line_items"
        case effectiveDate   = "effective_date"
        case deliveryDate    = "delivery_date"
        case deliveryAddress = "delivery_address"
        case customFields    = "custom_fields"
    }
}

// MARK: - PO post endpoint (/purchase-orders/{id}/post)

struct PostPODetailsBody: Encodable {
    var description: String
    var vendorId: String
    var departmentId: String
    var nominalCode: String
    var currency: String
    var notes: String
    var deliveryAddress: PODeliveryAddressBody?
    var deliveryDate: Int64?

    enum CodingKeys: String, CodingKey {
        case description, currency, notes
        case vendorId        = "vendor_id"
        case departmentId    = "department_id"
        case nominalCode     = "nominal_code"
        case deliveryAddress = "delivery_address"
        case deliveryDate    = "delivery_date"
    }
}

struct PostPORequest: Encodable {
    var vatTreatment: String
    var netTotal: Double
    var vatAmount: Double
    var grossTotal: Double
    var lineItems: [POLineItemBody]
    var poDetails: PostPODetailsBody
    var effectiveDate: Int64?
}

struct ClosePORequest: Encodable {
    var reason: String
    var effectiveDate: Int64?

    enum CodingKeys: String, CodingKey {
        case reason
        case effectiveDate = "effective_date"
    }
}

// MARK: - PO Bulk update

struct BulkUpdatePOsRequest: Encodable {
    var poIds: [String]
    var data: BulkUpdatePOsData

    enum CodingKeys: String, CodingKey {
        case poIds = "po_ids"
        case data
    }
}

struct BulkUpdatePOsData: Encodable {
    var assignedTo: String?
    var reassignmentReason: String?
    var effectiveDate: Int64?
    var status: String?
    var closureReason: String?

    enum CodingKeys: String, CodingKey {
        case assignedTo         = "assigned_to"
        case reassignmentReason = "reassignment_reason"
        case effectiveDate      = "effective_date"
        case status
        case closureReason      = "closure_reason"
    }
}

struct GeneratePDFRequest: Encodable {
    var vendor: String
    var vendorAddress: String
    var department: String
    var raisedByName: String
    var departmentMap: [String: String]

    enum CodingKeys: String, CodingKey {
        case vendor, department
        case vendorAddress = "vendorAddress"
        case raisedByName  = "raised_by_name"
        case departmentMap = "departmentMap"
    }
}

// MARK: - PO Templates

struct POTemplateRequest: Encodable {
    var templateName: String
    var vendorId: String?
    var departmentId: String
    var nominalCode: String
    var description: String
    var currency: String
    var vatTreatment: String
    var notes: String
    var netAmount: Double
    var lineItems: [POLineItemBody]
    var effectiveDate: Int64?
    var deliveryDate: Int64?
    var deliveryAddress: PODeliveryAddressBody?
    var customFields: [POCustomFieldSectionBody]?

    enum CodingKeys: String, CodingKey {
        case description, currency, notes
        case templateName    = "template_name"
        case vendorId        = "vendor_id"
        case departmentId    = "department_id"
        case nominalCode     = "nominal_code"
        case vatTreatment    = "vat_treatment"
        case netAmount       = "net_amount"
        case lineItems       = "line_items"
        case effectiveDate   = "effective_date"
        case deliveryDate    = "delivery_date"
        case deliveryAddress = "delivery_address"
        case customFields    = "custom_fields"
    }
}

// MARK: - Invoices

struct InvoiceSupplierBody: Encodable {
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

struct InvoiceLineItemBody: Encodable {
    var description: String?
    var quantity: Double?
    var unitPrice: Double?
    var amount: Double?

    enum CodingKeys: String, CodingKey {
        case description, quantity, amount
        case unitPrice = "unit_price"
    }
}

/// Body for `POST /invoices/upload`. Live uploads to S3 first and sends
/// the resulting `DocumentModel`; demo posts the file via multipart, gets
/// back a `DocumentModel` (populated with `serverPath` instead of S3
/// fields) and sends the same struct here.
struct InvoiceUploadRequest: Encodable {
    var attachment: DocumentModel
}

struct InvoiceCreateRequest: Encodable {
    var currency: String
    var departmentId: String?
    var description: String
    var grossAmount: Double
    var payMethod: String
    var attachments: [DocumentModel]?

    enum CodingKeys: String, CodingKey {
        case currency, description, attachments
        case departmentId = "department_id"
        case grossAmount  = "gross_amount"
        case payMethod    = "pay_method"
    }
}

struct HoldInvoiceRequest: Encodable {
    var holdReason: String
    var holdNote: String?

    enum CodingKeys: String, CodingKey {
        case holdReason = "hold_reason"
        case holdNote   = "hold_note"
    }
}

struct UpdateInvoiceSettingsRequest: Encodable {
    var alerts: [String]?
    var teamMembers: [InvoiceTeamMember]?
    var runAuthorization: [RunAuthLevel]?
    var assignmentRules: [InvoiceAssignmentRule]?

    enum CodingKeys: String, CodingKey {
        case alerts
        case teamMembers      = "team_members"
        case runAuthorization = "run_authorization"
        case assignmentRules  = "assignment_rules"
    }
}

// MARK: - Card expenses

/// Body for `POST /card-expenses/receipts/upload`. Live: S3 first, then
/// JSON with DocumentModel. Demo: multipart upload returns DocumentModel
/// (serverPath populated), then the same JSON-body call goes here.
struct CardReceiptCreateRequest: Encodable {
    var date: Int64?
    var amount: String?
    var description: String?
    var category: String?
    var costCode: String?
    var episode: String?
    var codedDescription: String?
    var isUrgent: Bool?
    var requestTopUp: Bool?
    var receiptAttachment: DocumentModel?

    enum CodingKeys: String, CodingKey {
        case date, amount, description, category, episode
        case costCode         = "cost_code"
        case codedDescription = "coded_description"
        case isUrgent         = "is_urgent"
        case requestTopUp     = "request_top_up"
        case receiptAttachment = "receipt_attachment"
    }
}

struct CardReceiptBatchRequest: Encodable {
    var receipts: [CardReceiptCreateRequest]
}

struct MatchReceiptRequest: Encodable {
    var transactionId: String
    var userId: String

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case userId        = "user_id"
    }
}

struct CodingLineItemBody: Encodable {
    var description: String
    var amount: Double
    var code: String
}

struct SubmitCodingRequest: Encodable {
    var nominalCode: String
    var lineItems: [CodingLineItemBody]

    enum CodingKeys: String, CodingKey {
        case nominalCode = "nominal_code"
        case lineItems   = "line_items"
    }
}

struct UpdateTransactionRequest: Encodable {
    var description: String
    var amount: String
    var nominalCode: String
    var codeDescription: String

    enum CodingKeys: String, CodingKey {
        case description, amount
        case nominalCode     = "nominal_code"
        case codeDescription = "code_description"
    }
}

struct CreateCardRequest: Encodable {
    var userID, departmentID: String?
    var proposedLimit: Int?

    enum CodingKeys: String, CodingKey {
        case userID       = "user_id"
        case departmentID = "department_id"
        case proposedLimit = "proposed_limit"
    }
}

struct UpdateCardRequest: Encodable {
    var cardLimit: Double
    var monthlyLimit: Double
    var proposedLimit: Double
    var userId: String
    var status: String
    var bsControlCode: String
    var justification: String
    var bankAccountId: String?

    enum CodingKeys: String, CodingKey {
        case status, justification
        case cardLimit      = "card_limit"
        case monthlyLimit   = "monthly_limit"
        case proposedLimit  = "proposed_limit"
        case userId         = "user_id"
        case bsControlCode  = "bs_control_code"
        case bankAccountId  = "bank_account_id"
    }
}

struct UserIdRequest: Encodable {
    var userId: String

    enum CodingKeys: String, CodingKey { case userId = "user_id" }
}

struct UserIdReasonRequest: Encodable {
    var userId: String
    var reason: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case reason
    }
}

struct UserIdNoteRequest: Encodable {
    var userId: String
    var note: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case note
    }
}

struct UserIdRejectionReasonRequest: Encodable {
    var userId: String
    var rejectionReason: String

    enum CodingKeys: String, CodingKey {
        case userId           = "user_id"
        case rejectionReason  = "rejection_reason"
    }
}

struct ActivateCardRequest: Encodable {
    var userId: String
    var cardType: String
    var lastFour: String?
    var fullCardNumber: String?
    var physicalCardNumber: String?
    var digitalCardNumber: String?
    var cardIssuer: String?

    enum CodingKeys: String, CodingKey {
        case userId             = "user_id"
        case cardType           = "card_type"
        case lastFour           = "last_four"
        case fullCardNumber     = "full_card_number"
        case physicalCardNumber = "physical_card_number"
        case digitalCardNumber  = "digital_card_number"
        case cardIssuer         = "card_issuer"
    }
}

struct PartialTopUpRequest: Encodable {
    var amount: Double?
    var note: String?
}

// MARK: - Cash expenses

struct FloatCustomFieldEntryBody: Encodable {
    var name: String
    var label: String
    var type: String
    var value: String
    var selectionType: String?

    enum CodingKeys: String, CodingKey {
        case name, label, type, value
        case selectionType = "selection_type"
    }
}

struct FloatCustomFieldSectionBody: Encodable {
    var section: String
    var fields: [FloatCustomFieldEntryBody]
}

struct CreateFloatRequest: Encodable {
    var collectionMethod, departmentID: String?
    var reqAmount, startDate: Int?
    var durationType: String?
    var collectDate, collectTime: Int?
    var purpose: String?

    enum CodingKeys: String, CodingKey {
        case collectionMethod = "collection_method"
        case departmentID     = "department_id"
        case reqAmount        = "req_amount"
        case startDate        = "start_date"
        case durationType     = "duration_type"
        case collectDate      = "collect_date"
        case collectTime      = "collect_time"
        case purpose
    }
}

struct RecordFloatReturnRequest: Encodable {
    var returnAmount: Double
    var receivedDate: Int64
    var returnReason: String
    var reasonNotes: NullableString
    var notes: NullableString

    enum CodingKeys: String, CodingKey {
        case returnAmount = "return_amount"
        case receivedDate = "received_date"
        case returnReason = "return_reason"
        case reasonNotes  = "reason_notes"
        case notes
    }
}

// MARK: - Claims

struct ClaimReceiptItemBody: Encodable {
    var description: String
    var amount: Double
    var category: String
    var date: String?
    var costCode: String?
    var episode: String?
    var codedDescription: String?

    enum CodingKeys: String, CodingKey {
        case description, amount, category, date, episode
        case costCode         = "cost_code"
        case codedDescription = "coded_description"
    }
}

struct ClaimBankAdditionalDetailBody: Encodable {
    var label: String
    var value: String
}

struct ClaimBankDetailsBody: Encodable {
    var accountName: String
    var sortCode: String
    var accountNumber: String
    var additionalDetails: [ClaimBankAdditionalDetailBody]?

    enum CodingKeys: String, CodingKey {
        case accountName       = "account_name"
        case sortCode          = "sort_code"
        case accountNumber     = "account_number"
        case additionalDetails = "additional_details"
    }
}

struct ClaimSettlementDetailsBody: Encodable {
    var paymentMethod: String?
    var bankDetails: ClaimBankDetailsBody?
    var followUp: NullableString
    var topUpAmount: Double?

    enum CodingKeys: String, CodingKey {
        case paymentMethod = "payment_method"
        case bankDetails   = "bank_details"
        case followUp      = "follow_up"
        case topUpAmount   = "top_up_amount"
    }
}

struct CreateClaimBatchRequest: Encodable {
    var expenseType: String
    var departmentId: String
    var floatRequestId: NullableString
    var settlementType: String
    var settlementDetails: ClaimSettlementDetailsBody
    var notes: String
    var category: String
    var costCode: String
    var codingDescription: String
    var claims: [ClaimReceiptItemBody]

    enum CodingKeys: String, CodingKey {
        case notes, category, claims
        case expenseType       = "expense_type"
        case departmentId      = "department_id"
        case floatRequestId    = "float_request_id"
        case settlementType    = "settlement_type"
        case settlementDetails = "settlement_details"
        case costCode          = "cost_code"
        case codingDescription = "coding_description"
    }
}

struct BatchApprovalRequest: Encodable {
    var action: String          // "approve" | "reject"
    var tierNumber: Int?
    var totalTiers: Int?
    var userId: String?
    var claimIds: [String]?
    var reason: String?

    enum CodingKeys: String, CodingKey {
        case action, reason
        case tierNumber = "tier_number"
        case totalTiers = "total_tiers"
        case userId     = "user_id"
        case claimIds   = "claim_ids"
    }
}

struct ClaimCodingRequest: Encodable {
    var nominalCode: String
    var vatTreatment: String
    var notes: String

    enum CodingKeys: String, CodingKey {
        case notes
        case nominalCode  = "nominal_code"
        case vatTreatment = "vat_treatment"
    }
}

// MARK: - Submit Claim Batch (API contract models)

struct Claim: Codable {
    var description, category: String?
    var grossAmount: Double?
    var receiptDate: Int?
    var costCode, episode, codedDescription: String?
    var attachment: DocumentModel?

    enum CodingKeys: String, CodingKey {
        case description, category, episode
        case attachment = "attachment"
        case grossAmount      = "gross_amount"
        case receiptDate      = "receipt_date"
        case costCode         = "cost_code"
        case codedDescription = "coded_description"
    }
}

struct SettlementDetails: Codable {
    var paymentMethod, followUp: String?

    enum CodingKeys: String, CodingKey {
        case paymentMethod = "payment_method"
        case followUp      = "follow_up"
    }
}

struct Welcome: Codable {
    var expenseType, departmentID, floatRequestID, settlementType: String?
    var settlementDetails: SettlementDetails?
    var notes: String?
    var claims: [Claim]?

    enum CodingKeys: String, CodingKey {
        case notes, claims
        case expenseType       = "expense_type"
        case departmentID      = "department_id"
        case floatRequestID    = "float_request_id"
        case settlementType    = "settlement_type"
        case settlementDetails = "settlement_details"
    }
}

// MARK: - Bank Accounts

struct HubBankAccountRequestBody: Encodable {
    var name: String?
    var accountType: String?
    var bankName: String?
    var accountNumber: String?
    var sortCode: String?
    var currency: String?
    var openingBalance: Double?
    var isDefault: Bool?
    var active: Bool?

    enum CodingKeys: String, CodingKey {
        case name, currency, active
        case accountType    = "account_type"
        case bankName       = "bank_name"
        case accountNumber  = "account_number"
        case sortCode       = "sort_code"
        case openingBalance = "opening_balance"
        case isDefault      = "is_default"
    }
}

struct AHBadgeReadModel: Codable {
    var section, unit, tool, level1, level2, level3, action, projectId : String?
    var readTime: Int?
    enum CodingKeys: String, CodingKey {
        case section = "section"
        case unit = "unit"
        case tool = "tool"
        case action = "action"
        case level1 = "level_1"
        case level2 = "level_2"
        case level3 = "level_3"
        case readTime = "read_time"
        case projectId = "project_id"
    }
}
