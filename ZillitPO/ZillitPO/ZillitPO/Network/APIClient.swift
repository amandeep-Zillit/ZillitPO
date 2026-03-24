import Foundation

// MARK: - Protocols (matching Zillit main app pattern)

protocol POURLRequestProtocol {
    var urlRequest: URLRequest? { get }
}

protocol PODataTaskProtocol {
    var urlDataTask: URLSessionDataTask? { get }
}

// MARK: - HTTP Method

enum HTTPMethodType: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - API Client (iOS 13 compatible — no async/await)

class APIClient {
    static let shared = APIClient()
    var baseURL = "https://accounthub-dev.zillit.com"
    var projectId = ""
    var userId = ""
    var isAccountant = false

    let session = URLSession.shared

    private func headers() -> [String: String] {
        ["Content-Type": "application/json", "x-project-id": projectId,
         "x-user-id": userId, "x-is-accountant": String(isAccountant)]
    }

    // MARK: - Build URLRequest (used by PORequest enum)

    func buildRequest(_ method: HTTPMethodType, _ path: String, body: Any? = nil) -> URLRequest? {
        let urlString = path.hasPrefix("http") ? path : "\(baseURL)\(path)"
        guard let url = URL(string: urlString) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.timeoutInterval = 30
        for (k, v) in headers() { req.setValue(v, forHTTPHeaderField: k) }
        if let body = body, let data = try? JSONSerialization.data(withJSONObject: body) {
            req.httpBody = data
        }
        return req
    }

    // MARK: - Codable Result Task (typed response — matches Zillit main app pattern)

    func codableResultTask<T: Decodable>(with request: URLRequest, completion: @escaping (Result<APIResponse<T>?, Error>) -> Void) -> URLSessionDataTask {
        let method = request.httpMethod ?? "GET"
        let urlString = request.url?.absoluteString ?? ""
        print("[\(method)] \(urlString)")

        return session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("  ❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            guard let data = data, let http = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            if http.statusCode == 204 {
                print("  ✅ \(http.statusCode) (no content)")
                completion(.success(nil))
                return
            }
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? ""
                print("  ❌ \(http.statusCode): \(msg.prefix(200))")
                completion(.failure(APIError.serverError(http.statusCode, msg)))
                return
            }
            print("  ✅ \(http.statusCode) (\(data.count) bytes)")

            // Use tryDecode to match original decode behavior exactly
            let decoded = tryDecode(T.self, from: data)
            if decoded == nil {
                let raw = String(data: data, encoding: .utf8) ?? "<binary>"
                print("  ⚠️ Decode failed for \(T.self). Raw: \(raw.prefix(500))")
            }
            completion(.success(APIResponse<T>(data: decoded)))
        }
    }

    // MARK: - Data Result Task (raw Data response — for mutations, PDF, etc.)

    func dataResultTask(with request: URLRequest, completion: @escaping (Result<Data?, Error>) -> Void) -> URLSessionDataTask {
        let method = request.httpMethod ?? "GET"
        let urlString = request.url?.absoluteString ?? ""
        print("[\(method)] \(urlString)")

        return session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("  ❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            guard let data = data, let http = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            if http.statusCode == 204 {
                print("  ✅ \(http.statusCode) (no content)")
                completion(.success(Data()))
                return
            }
            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? ""
                print("  ❌ \(http.statusCode): \(msg.prefix(200))")
                completion(.failure(APIError.serverError(http.statusCode, msg)))
                return
            }
            print("  ✅ \(http.statusCode) (\(data.count) bytes)")
            completion(.success(data))
        }
    }
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

struct APIResponse<T: Decodable>: Decodable {
    let data: T?
    init(data: T?) { self.data = data }
}

// MARK: - Raw API types

struct PurchaseOrderRaw: Codable {
    var id: String
    var project_id: String?; var po_number: String?; var vendor_id: String?
    var department_id: String?; var nominal_code: String?; var description: String?
    var currency: String?; var effective_date: Int?; var notes: String?
    var line_items: FlexibleLineItems?; var net_amount: Int?
    var status: String?; var assigned_to: String?; var raised_by: String?; var user_id: String?
    var approvals: FlexibleApprovals?; var vat_treatment: String?
    var delivery_address: FlexibleDeliveryAddress?; var delivery_date: Int?
    var rejection_reason: String?; var rejected_by: String?; var rejected_at: Int?
    var reassignment_reason: String?; var reassigned_by: String?; var reassigned_at: Int?
    var closure_reason: String?; var closed_by: String?; var closed_at: Int?
    var vat_amount: Int?; var gross_total: Int?
    var custom_fields: FlexibleCustomFields?
    var created_at: Int?; var updated_at: Int?

    enum CodingKeys: String, CodingKey {
        case id, project_id, po_number, vendor_id, department_id, nominal_code, description
        case currency, effective_date, notes, line_items, net_amount, status, assigned_to
        case raised_by, user_id, approvals, vat_treatment, delivery_address, delivery_date
        case rejection_reason, rejected_by, rejected_at, reassignment_reason, reassigned_by
        case reassigned_at, closure_reason, closed_by, closed_at, vat_amount, gross_total
        case custom_fields, created_at, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        project_id = try? c.decode(String.self, forKey: .project_id)
        po_number = try? c.decode(String.self, forKey: .po_number)
        vendor_id = try? c.decode(String.self, forKey: .vendor_id)
        department_id = try? c.decode(String.self, forKey: .department_id)
        nominal_code = try? c.decode(String.self, forKey: .nominal_code)
        description = try? c.decode(String.self, forKey: .description)
        currency = try? c.decode(String.self, forKey: .currency)
        notes = try? c.decode(String.self, forKey: .notes)
        status = try? c.decode(String.self, forKey: .status)
        assigned_to = try? c.decode(String.self, forKey: .assigned_to)
        raised_by = try? c.decode(String.self, forKey: .raised_by)
        user_id = try? c.decode(String.self, forKey: .user_id)
        vat_treatment = try? c.decode(String.self, forKey: .vat_treatment)
        rejection_reason = try? c.decode(String.self, forKey: .rejection_reason)
        rejected_by = try? c.decode(String.self, forKey: .rejected_by)
        reassignment_reason = try? c.decode(String.self, forKey: .reassignment_reason)
        reassigned_by = try? c.decode(String.self, forKey: .reassigned_by)
        closure_reason = try? c.decode(String.self, forKey: .closure_reason)
        closed_by = try? c.decode(String.self, forKey: .closed_by)
        line_items = try? c.decode(FlexibleLineItems.self, forKey: .line_items)
        approvals = try? c.decode(FlexibleApprovals.self, forKey: .approvals)
        delivery_address = try? c.decode(FlexibleDeliveryAddress.self, forKey: .delivery_address)
        custom_fields = try? c.decode(FlexibleCustomFields.self, forKey: .custom_fields)
        // Flexible Int fields (handle string/double/int from API)
        effective_date = flexibleIntDecode(c, .effective_date)
        net_amount = flexibleIntDecode(c, .net_amount)
        delivery_date = flexibleIntDecode(c, .delivery_date)
        rejected_at = flexibleIntDecode(c, .rejected_at)
        reassigned_at = flexibleIntDecode(c, .reassigned_at)
        closed_at = flexibleIntDecode(c, .closed_at)
        vat_amount = flexibleIntDecode(c, .vat_amount)
        gross_total = flexibleIntDecode(c, .gross_total)
        created_at = flexibleIntDecode(c, .created_at)
        updated_at = flexibleIntDecode(c, .updated_at)
    }
}

struct LineItemRaw: Codable {
    var id: String?; var description: String?; var quantity: Int?
    var unit_price: Int?; var total: Int?
    var account: String?; var department: String?; var expenditure_type: String?
    var rental_start: Int?; var rental_end: Int?
    var split_parent_id: String?; var custom_fields: [CustomFieldValue]?

    enum CodingKeys: String, CodingKey {
        case id, description, quantity, unit_price, total, account, department
        case expenditure_type, rental_start, rental_end, split_parent_id, custom_fields
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decode(String.self, forKey: .id)
        description = try? c.decode(String.self, forKey: .description)
        account = try? c.decode(String.self, forKey: .account)
        department = try? c.decode(String.self, forKey: .department)
        expenditure_type = try? c.decode(String.self, forKey: .expenditure_type)
        split_parent_id = try? c.decode(String.self, forKey: .split_parent_id)
        custom_fields = try? c.decode([CustomFieldValue].self, forKey: .custom_fields)
        // Flexible Int fields
        quantity = flexibleIntDecode(c, .quantity)
        unit_price = flexibleIntDecode(c, .unit_price)
        total = flexibleIntDecode(c, .total)
        rental_start = flexibleIntDecode(c, .rental_start)
        rental_end = flexibleIntDecode(c, .rental_end)
    }
}

struct ApprovalRaw: Codable {
    var user_id: String?; var tier_number: Int?; var approved_at: Int?

    enum CodingKeys: String, CodingKey {
        case user_id, tier_number, approved_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try? c.decode(String.self, forKey: .user_id)
        tier_number = flexibleIntDecode(c, .tier_number)
        approved_at = flexibleIntDecode(c, .approved_at)
    }
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
                     quantity: Double($0.quantity ?? 1), unitPrice: Double($0.unit_price ?? 0),
                     total: Double($0.total ?? 0), account: $0.account ?? "",
                     department: $0.department ?? "", expenditureType: $0.expenditure_type ?? "Purchase")
        }
        let apps = (approvals?.items ?? []).map {
            Approval(userId: $0.user_id ?? "", tierNumber: $0.tier_number ?? 0, approvedAt: Int64($0.approved_at ?? 0))
        }
        var po = PurchaseOrder()
        po.id = id; po.projectId = project_id ?? ""; po.userId = user_id ?? ""
        po.poNumber = po_number ?? ""; po.vendorId = vendor_id; po.departmentId = department_id
        po.nominalCode = nominal_code; po.description = description; po.currency = currency ?? "GBP"
        po.effectiveDate = effective_date.map { Int64($0) }; po.notes = notes
        po.netAmount = Double(net_amount ?? 0); po.status = status ?? "DRAFT"
        po.assignedTo = assigned_to; po.raisedBy = raised_by
        po.rejectedBy = rejected_by; po.rejectedAt = rejected_at.map { Int64($0) }
        po.rejectionReason = rejection_reason; po.reassignmentReason = reassignment_reason
        po.reassignedBy = reassigned_by; po.reassignedAt = reassigned_at.map { Int64($0) }
        po.vatTreatment = vat_treatment ?? "pending"; po.deliveryAddress = delivery_address?.address
        po.deliveryDate = delivery_date.map { Int64($0) }; po.closedBy = closed_by
        po.closedAt = closed_at.map { Int64($0) }; po.closureReason = closure_reason
        po.customFields = custom_fields?.items ?? []; po.vatAmount = vat_amount.map { Double($0) }
        po.grossTotal = gross_total.map { Double($0) }; po.approvals = apps
        po.createdAt = Int64(created_at ?? 0); po.updatedAt = Int64(updated_at ?? 0)
        po.vendor = v?.name ?? ""; po.department = d?.displayName ?? ""; po.lineItems = items
        po.vendorAddress = [v?.address.line1, v?.address.city, v?.address.postalCode]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return po
    }
}
