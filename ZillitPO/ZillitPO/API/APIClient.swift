import Foundation
import Combine

// MARK: - API Client (iOS 13 compatible — no async/await)

class APIClient {
    static let shared = APIClient()
    var baseURL = "https://accounthub-dev.zillit.com"
    var projectId = ""
    var userId = ""
    var isAccountant = false

    private let session = URLSession.shared

    private func headers() -> [String: String] {
        ["Content-Type": "application/json", "x-project-id": projectId,
         "x-user-id": userId, "x-is-accountant": String(isAccountant)]
    }

    func request(_ method: String, _ path: String, body: Any? = nil) -> AnyPublisher<Data, Error> {
        let urlString = path.hasPrefix("http") ? path : "\(baseURL)\(path)"
        guard let url = URL(string: urlString) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 30
        for (k, v) in headers() { req.setValue(v, forHTTPHeaderField: k) }
        if let body = body, let data = try? JSONSerialization.data(withJSONObject: body) {
            req.httpBody = data
        }

        print("[\(method)] \(urlString)")

        return session.dataTaskPublisher(for: req)
            .tryMap { output -> Data in
                guard let http = output.response as? HTTPURLResponse else { throw APIError.invalidResponse }
                if http.statusCode == 204 { return Data() }
                guard (200...299).contains(http.statusCode) else {
                    let msg = String(data: output.data, encoding: .utf8) ?? ""
                    print("  ❌ \(http.statusCode): \(msg.prefix(200))")
                    throw APIError.serverError(http.statusCode, msg)
                }
                print("  ✅ \(http.statusCode) (\(output.data.count) bytes)")
                return output.data
            }
            .eraseToAnyPublisher()
    }

    func get(_ p: String) -> AnyPublisher<Data, Error> { request("GET", p) }
    func post(_ p: String, body: Any? = nil) -> AnyPublisher<Data, Error> { request("POST", p, body: body) }
    func patch(_ p: String, body: Any? = nil) -> AnyPublisher<Data, Error> { request("PATCH", p, body: body) }
    func del(_ p: String) -> AnyPublisher<Data, Error> { request("DELETE", p) }
}

enum APIError: LocalizedError {
    case invalidURL, invalidResponse, serverError(Int, String), decodingError(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .serverError(let c, let m): return "Error \(c): \(m)"
        case .decodingError(let m): return "Decode: \(m)"
        }
    }
}

struct APIResponse<T: Decodable>: Decodable { let data: T? }

// MARK: - Raw API types

struct PurchaseOrderRaw: Codable {
    let id: String
    let project_id: String?; let po_number: String?; let vendor_id: String?
    let department_id: String?; let nominal_code: String?; let description: String?
    let currency: String?; let effective_date: AnyCodableValue?; let notes: String?
    let line_items: FlexibleLineItems?; let net_amount: AnyCodableValue?
    let status: String?; let assigned_to: String?; let raised_by: String?; let user_id: String?
    let approvals: FlexibleApprovals?; let vat_treatment: String?
    let delivery_address: FlexibleDeliveryAddress?; let delivery_date: AnyCodableValue?
    let rejection_reason: String?; let rejected_by: String?; let rejected_at: AnyCodableValue?
    let reassignment_reason: String?; let reassigned_by: String?; let reassigned_at: AnyCodableValue?
    let closure_reason: String?; let closed_by: String?; let closed_at: AnyCodableValue?
    let vat_amount: AnyCodableValue?; let gross_total: AnyCodableValue?
    let custom_fields: FlexibleCustomFields?
    let created_at: AnyCodableValue?; let updated_at: AnyCodableValue?
}

struct LineItemRaw: Codable {
    let id: String?; let description: String?; let quantity: AnyCodableValue?
    let unit_price: AnyCodableValue?; let total: AnyCodableValue?
    let account: String?; let department: String?; let expenditure_type: String?
    let rental_start: AnyCodableValue?; let rental_end: AnyCodableValue?
    let split_parent_id: String?; let custom_fields: [CustomFieldValue]?
}

struct ApprovalRaw: Codable {
    let user_id: String?; let tier_number: Int?; let approved_at: AnyCodableValue?
}

// MARK: - Flexible decoders (handle string or object)

enum FlexibleLineItems: Codable {
    case array([LineItemRaw]); case string(String)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let a = try? c.decode([LineItemRaw].self) { self = .array(a); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .array([])
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .array(let a): try c.encode(a); case .string(let s): try c.encode(s) }
    }
    var items: [LineItemRaw] {
        switch self {
        case .array(let a): return a
        case .string(let s):
            guard let d = s.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([LineItemRaw].self, from: d)) ?? []
        }
    }
}

enum FlexibleApprovals: Codable {
    case array([ApprovalRaw]); case string(String)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let a = try? c.decode([ApprovalRaw].self) { self = .array(a); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .array([])
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .array(let a): try c.encode(a); case .string(let s): try c.encode(s) }
    }
    var items: [ApprovalRaw] {
        switch self {
        case .array(let a): return a
        case .string(let s):
            guard let d = s.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([ApprovalRaw].self, from: d)) ?? []
        }
    }
}

enum FlexibleDeliveryAddress: Codable {
    case object(DeliveryAddress); case string(String); case null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let o = try? c.decode(DeliveryAddress.self) { self = .object(o); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .null
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .object(let o): try c.encode(o); case .string(let s): try c.encode(s); case .null: try c.encodeNil() }
    }
    var address: DeliveryAddress? {
        switch self {
        case .object(let o): return o
        case .string(let s):
            guard let d = s.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(DeliveryAddress.self, from: d)
        case .null: return nil
        }
    }
}

enum FlexibleCustomFields: Codable {
    case array([CustomFieldSection]); case string(String)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let a = try? c.decode([CustomFieldSection].self) { self = .array(a); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .array([])
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .array(let a): try c.encode(a); case .string(let s): try c.encode(s) }
    }
    var items: [CustomFieldSection] {
        switch self {
        case .array(let a): return a
        case .string(let s):
            guard let d = s.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([CustomFieldSection].self, from: d)) ?? []
        }
    }
}

// MARK: - Decode helper

func tryDecode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
    if let w = try? JSONDecoder().decode(APIResponse<T>.self, from: data), let r = w.data { return r }
    return try? JSONDecoder().decode(T.self, from: data)
}

// MARK: - Raw → Domain mapping

extension PurchaseOrderRaw {
    func toPO(vendors: [Vendor], departments: [Department]) -> PurchaseOrder {
        let v = vendors.first { $0.id == (vendor_id ?? "") }
        let d = departments.first { $0.id == (department_id ?? "") || $0.identifier == (department_id ?? "") }
        let items = (line_items?.items ?? []).map {
            LineItem(id: $0.id ?? UUID().uuidString, description: $0.description ?? "",
                     quantity: $0.quantity?.doubleValue ?? 1, unitPrice: $0.unit_price?.doubleValue ?? 0,
                     total: $0.total?.doubleValue ?? 0, account: $0.account ?? "",
                     department: $0.department ?? "", expenditureType: $0.expenditure_type ?? "Purchase")
        }
        let apps = (approvals?.items ?? []).map {
            Approval(userId: $0.user_id ?? "", tierNumber: $0.tier_number ?? 0, approvedAt: $0.approved_at?.int64Value ?? 0)
        }
        var po = PurchaseOrder()
        po.id = id; po.projectId = project_id ?? ""; po.userId = user_id ?? ""
        po.poNumber = po_number ?? ""; po.vendorId = vendor_id; po.departmentId = department_id
        po.nominalCode = nominal_code; po.description = description; po.currency = currency ?? "GBP"
        po.effectiveDate = effective_date?.int64Value; po.notes = notes
        po.netAmount = net_amount?.doubleValue ?? 0; po.status = status ?? "DRAFT"
        po.assignedTo = assigned_to; po.raisedBy = raised_by
        po.rejectedBy = rejected_by; po.rejectedAt = rejected_at?.int64Value
        po.rejectionReason = rejection_reason; po.reassignmentReason = reassignment_reason
        po.reassignedBy = reassigned_by; po.reassignedAt = reassigned_at?.int64Value
        po.vatTreatment = vat_treatment ?? "pending"; po.deliveryAddress = delivery_address?.address
        po.deliveryDate = delivery_date?.int64Value; po.closedBy = closed_by
        po.closedAt = closed_at?.int64Value; po.closureReason = closure_reason
        po.customFields = custom_fields?.items ?? []; po.vatAmount = vat_amount?.doubleValue
        po.grossTotal = gross_total?.doubleValue; po.approvals = apps
        po.createdAt = created_at?.int64Value ?? 0; po.updatedAt = updated_at?.int64Value ?? 0
        po.vendor = v?.name ?? ""; po.department = d?.displayName ?? ""; po.lineItems = items
        po.vendorAddress = [v?.address.line1, v?.address.city, v?.address.postalCode]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return po
    }
}
