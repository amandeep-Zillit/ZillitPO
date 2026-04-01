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

    // MARK: - Build Multipart Request (for file uploads)

    func buildMultipartRequest(_ path: String, fileData: Data, fileName: String, mimeType: String, fieldName: String = "file") -> URLRequest? {
        let urlString = path.hasPrefix("http") ? path : "\(baseURL)\(path)"
        guard let url = URL(string: urlString) else { return nil }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(projectId, forHTTPHeaderField: "x-project-id")
        req.setValue(userId, forHTTPHeaderField: "x-user-id")
        req.setValue(String(isAccountant), forHTTPHeaderField: "x-is-accountant")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
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
    var line_items: FlexibleLineItems?; var net_amount: Double?
    var status: String?; var assigned_to: String?; var raised_by: String?; var user_id: String?
    var approvals: FlexibleApprovals?; var vat_treatment: String?
    var delivery_address: FlexibleDeliveryAddress?; var delivery_date: Int?
    var rejection_reason: String?; var rejected_by: String?; var rejected_at: Int?
    var reassignment_reason: String?; var reassigned_by: String?; var reassigned_at: Int?
    var closure_reason: String?; var closed_by: String?; var closed_at: Int?
    var vat_amount: Double?; var gross_total: Double?
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
        // Flexible fields (handle string/double/int from API)
        effective_date = flexibleIntDecode(c, .effective_date)
        net_amount = flexibleDoubleDecode(c, .net_amount)
        delivery_date = flexibleIntDecode(c, .delivery_date)
        rejected_at = flexibleIntDecode(c, .rejected_at)
        reassigned_at = flexibleIntDecode(c, .reassigned_at)
        closed_at = flexibleIntDecode(c, .closed_at)
        vat_amount = flexibleDoubleDecode(c, .vat_amount)
        gross_total = flexibleDoubleDecode(c, .gross_total)
        created_at = flexibleIntDecode(c, .created_at)
        updated_at = flexibleIntDecode(c, .updated_at)
    }
}

struct LineItemRaw: Codable {
    var id: String?; var description: String?; var quantity: Double?
    var unit_price: Double?; var total: Double?
    var account: String?; var department: String?; var expenditure_type: String?
    var vat_treatment: String?
    var rental_start: Int?; var rental_end: Int?
    var split_parent_id: String?; var custom_fields: [CustomFieldValue]?

    enum CodingKeys: String, CodingKey {
        case id, description, quantity, unit_price, total, account, department
        case expenditure_type, vat_treatment, rental_start, rental_end, split_parent_id, custom_fields
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decode(String.self, forKey: .id)
        description = try? c.decode(String.self, forKey: .description)
        account = try? c.decode(String.self, forKey: .account)
        department = try? c.decode(String.self, forKey: .department)
        expenditure_type = try? c.decode(String.self, forKey: .expenditure_type)
        vat_treatment = try? c.decode(String.self, forKey: .vat_treatment)
        split_parent_id = try? c.decode(String.self, forKey: .split_parent_id)
        custom_fields = try? c.decode([CustomFieldValue].self, forKey: .custom_fields)
        // Flexible fields
        quantity = flexibleDoubleDecode(c, .quantity)
        unit_price = flexibleDoubleDecode(c, .unit_price)
        total = flexibleDoubleDecode(c, .total)
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

// MARK: - Invoice Raw API type

struct InvoiceRaw: Codable {
    var id: String
    var project_id: String?; var invoice_number: String?; var vendor_id: String?
    var department_id: String?; var description: String?
    var currency: String?; var gross_amount: Double?
    var status: String?; var approval_status: String?; var user_id: String?
    var pay_method: String?; var cost_centre: String?; var assigned_to: String?
    var supplier_name: String?; var reference: String?
    var hold_reason: String?; var hold_note: String?; var is_overdue: Bool?
    var approvals: FlexibleApprovals?
    var approved_by: String?; var approved_at: Int?
    var po_id: String?; var po_number: String?; var po_ids: [String]?
    var line_items: FlexibleLineItems?
    var rejection_reason: String?; var rejected_by: String?; var rejected_at: Int?
    var tags: [String]?
    var invoice_date: Int?; var due_date: Int?; var effective_date: Int?
    var created_at: Int?; var updated_at: Int?; var updated_by: String?
    var upload_id: String?; var file: String?

    enum CodingKeys: String, CodingKey {
        case id, project_id, invoice_number, vendor_id, department_id, description
        case currency, gross_amount, status, approval_status, user_id
        case pay_method, cost_centre, assigned_to, supplier_name, reference
        case hold_reason, hold_note, is_overdue
        case approvals, approved_by, approved_at
        case po_id, po_number, po_ids, line_items
        case rejection_reason, rejected_by, rejected_at
        case tags, invoice_date, due_date, effective_date
        case created_at, updated_at, updated_by
        case upload_id, file
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        project_id = try? c.decode(String.self, forKey: .project_id)
        invoice_number = try? c.decode(String.self, forKey: .invoice_number)
        vendor_id = try? c.decode(String.self, forKey: .vendor_id)
        department_id = try? c.decode(String.self, forKey: .department_id)
        description = try? c.decode(String.self, forKey: .description)
        currency = try? c.decode(String.self, forKey: .currency)
        status = try? c.decode(String.self, forKey: .status)
        approval_status = try? c.decode(String.self, forKey: .approval_status)
        user_id = try? c.decode(String.self, forKey: .user_id)
        pay_method = try? c.decode(String.self, forKey: .pay_method)
        cost_centre = try? c.decode(String.self, forKey: .cost_centre)
        assigned_to = try? c.decode(String.self, forKey: .assigned_to)
        supplier_name = try? c.decode(String.self, forKey: .supplier_name)
        reference = try? c.decode(String.self, forKey: .reference)
        hold_reason = try? c.decode(String.self, forKey: .hold_reason)
        hold_note = try? c.decode(String.self, forKey: .hold_note)
        is_overdue = try? c.decode(Bool.self, forKey: .is_overdue)
        approved_by = try? c.decode(String.self, forKey: .approved_by)
        po_id = try? c.decode(String.self, forKey: .po_id)
        po_number = try? c.decode(String.self, forKey: .po_number)
        po_ids = try? c.decode([String].self, forKey: .po_ids)
        rejection_reason = try? c.decode(String.self, forKey: .rejection_reason)
        rejected_by = try? c.decode(String.self, forKey: .rejected_by)
        updated_by = try? c.decode(String.self, forKey: .updated_by)
        tags = try? c.decode([String].self, forKey: .tags)
        approvals = try? c.decode(FlexibleApprovals.self, forKey: .approvals)
        line_items = try? c.decode(FlexibleLineItems.self, forKey: .line_items)
        // Flexible fields (API returns timestamps as strings or ints)
        gross_amount = flexibleDoubleDecode(c, .gross_amount)
        invoice_date = flexibleIntDecode(c, .invoice_date)
        due_date = flexibleIntDecode(c, .due_date)
        effective_date = flexibleIntDecode(c, .effective_date)
        approved_at = flexibleIntDecode(c, .approved_at)
        rejected_at = flexibleIntDecode(c, .rejected_at)
        created_at = flexibleIntDecode(c, .created_at)
        updated_at = flexibleIntDecode(c, .updated_at)
        upload_id = try? c.decode(String.self, forKey: .upload_id)
        file = try? c.decode(String.self, forKey: .file)
    }
}

extension InvoiceRaw {
    func toInvoice(vendors: [Vendor], departments: [Department]) -> Invoice {
        let v = vendors.first { $0.id == (vendor_id ?? "") }
        let d = departments.first { $0.id == (department_id ?? "") || $0.identifier == (department_id ?? "") }
        let items = (line_items?.items ?? []).map { raw -> LineItem in
            var li = LineItem(id: raw.id ?? UUID().uuidString, description: raw.description ?? "",
                     quantity: raw.quantity ?? 1, unitPrice: raw.unit_price ?? 0,
                     total: raw.total ?? 0, account: raw.account ?? "",
                     department: raw.department ?? "", expenditureType: raw.expenditure_type ?? "Purchase",
                     vatTreatment: raw.vat_treatment ?? "pending")
            li.customFields = raw.custom_fields ?? []
            return li
        }
        let apps = (approvals?.items ?? []).map {
            Approval(userId: $0.user_id ?? "", tierNumber: $0.tier_number ?? 0, approvedAt: Int64($0.approved_at ?? 0))
        }
        var inv = Invoice()
        inv.id = id; inv.projectId = project_id ?? ""; inv.userId = user_id ?? ""
        inv.invoiceNumber = invoice_number ?? ""; inv.vendorId = vendor_id; inv.departmentId = department_id
        inv.description = description; inv.currency = currency ?? "GBP"
        inv.grossAmount = gross_amount ?? 0
        inv.status = status ?? "draft"; inv.approvalStatus = approval_status ?? "pending"
        inv.payMethod = pay_method; inv.costCentre = cost_centre; inv.assignedTo = assigned_to
        inv.supplierName = v?.name ?? supplier_name ?? ""; inv.reference = reference
        inv.vendorAddress = v?.address.formatted ?? ""
        inv.vendorEmail = v?.email ?? ""
        inv.vendorPhone = v != nil ? "\(v!.phone.countryCode) \(v!.phone.number)".trimmingCharacters(in: .whitespaces) : ""
        inv.vendorContact = v?.contactPerson ?? ""
        inv.vendorVatNumber = v?.vatNumber
        inv.holdReason = hold_reason; inv.holdNote = hold_note; inv.isOverdue = is_overdue ?? false
        inv.poId = po_id; inv.poNumber = po_number; inv.poIds = po_ids ?? []
        inv.approvals = apps; inv.approvedBy = approved_by
        inv.approvedAt = approved_at.map { Int64($0) }
        inv.rejectedBy = rejected_by; inv.rejectedAt = rejected_at.map { Int64($0) }
        inv.rejectionReason = rejection_reason; inv.tags = tags ?? []
        inv.invoiceDate = invoice_date.map { Int64($0) }
        inv.dueDate = due_date.map { Int64($0) }
        inv.effectiveDate = effective_date.map { Int64($0) }
        inv.createdAt = Int64(created_at ?? 0); inv.updatedAt = Int64(updated_at ?? 0); inv.updatedBy = updated_by
        inv.uploadId = upload_id; inv.file = file
        inv.department = d?.displayName ?? ""; inv.lineItems = items
        return inv
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
        let poLevelVat = vat_treatment ?? "pending"
        let items = (line_items?.items ?? []).map { raw -> LineItem in
            // Read VAT from: 1) line item vat_treatment field, 2) custom_fields "vat", 3) PO-level
            let cfVat = raw.custom_fields?.first(where: { $0.name == "vat" })?.value
            let liVat = raw.vat_treatment ?? cfVat ?? poLevelVat
            var li = LineItem(id: raw.id ?? UUID().uuidString, description: raw.description ?? "",
                     quantity: raw.quantity ?? 1, unitPrice: raw.unit_price ?? 0,
                     total: raw.total ?? 0, account: raw.account ?? "",
                     department: raw.department ?? "", expenditureType: raw.expenditure_type ?? "Purchase",
                     vatTreatment: liVat)
            // Preserve other custom fields (exclude "vat" since it's now on the model)
            li.customFields = (raw.custom_fields ?? []).filter { $0.name != "vat" }
            return li
        }
        let apps = (approvals?.items ?? []).map {
            Approval(userId: $0.user_id ?? "", tierNumber: $0.tier_number ?? 0, approvedAt: Int64($0.approved_at ?? 0))
        }
        var po = PurchaseOrder()
        po.id = id; po.projectId = project_id ?? ""; po.userId = user_id ?? ""
        po.poNumber = po_number ?? ""; po.vendorId = vendor_id; po.departmentId = department_id
        po.nominalCode = nominal_code; po.description = description; po.currency = currency ?? "GBP"
        po.effectiveDate = effective_date.map { Int64($0) }; po.notes = notes
        let rawNetAmount = net_amount ?? 0
        let computedNet = items.filter { $0.splitParentId == nil }.reduce(0.0) { $0 + ($1.quantity * $1.unitPrice) }
        po.netAmount = rawNetAmount > 0 ? rawNetAmount : computedNet
        po.status = status ?? "DRAFT"
        po.assignedTo = assigned_to; po.raisedBy = raised_by
        po.rejectedBy = rejected_by; po.rejectedAt = rejected_at.map { Int64($0) }
        po.rejectionReason = rejection_reason; po.reassignmentReason = reassignment_reason
        po.reassignedBy = reassigned_by; po.reassignedAt = reassigned_at.map { Int64($0) }
        po.vatTreatment = vat_treatment ?? "pending"; po.deliveryAddress = delivery_address?.address
        po.deliveryDate = delivery_date.map { Int64($0) }; po.closedBy = closed_by
        po.closedAt = closed_at.map { Int64($0) }; po.closureReason = closure_reason
        po.customFields = custom_fields?.items ?? []; po.vatAmount = vat_amount
        po.grossTotal = gross_total; po.approvals = apps
        po.createdAt = Int64(created_at ?? 0); po.updatedAt = Int64(updated_at ?? 0)
        po.vendor = v?.name ?? ""; po.department = d?.displayName ?? ""; po.lineItems = items
        po.vendorAddress = [v?.address.line1, v?.address.city, v?.address.postalCode]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return po
    }
}

// MARK: - Payment Run Raw API type

struct PaymentRunInvoiceRaw: Codable {
    var id: String?
    var invoice_number: String?
    var supplier_name: String?
    var description: String?
    var due_date: Int64?
    var gross_amount: Double?
    var currency: String?

    enum CodingKeys: String, CodingKey {
        case id, invoice_number, supplier_name, description, due_date, gross_amount, currency
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decode(String.self, forKey: .id)
        invoice_number = try? c.decode(String.self, forKey: .invoice_number)
        supplier_name = try? c.decode(String.self, forKey: .supplier_name)
        description = try? c.decode(String.self, forKey: .description)
        gross_amount = flexibleDoubleDecode(c, .gross_amount)
        currency = try? c.decode(String.self, forKey: .currency)
        if let v = try? c.decode(Int64.self, forKey: .due_date) { due_date = v }
        else if let s = try? c.decode(String.self, forKey: .due_date) { due_date = Int64(s) }
        else if let d = try? c.decode(Double.self, forKey: .due_date) { due_date = Int64(d) }
        else { due_date = nil }
    }
}

struct PaymentRunApprovalRaw: Codable {
    var user_id: String?
    var approved_at: Int64?
    var tier_number: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try? c.decode(String.self, forKey: .user_id)
        tier_number = try? c.decode(Int.self, forKey: .tier_number)
        if let v = try? c.decode(Int64.self, forKey: .approved_at) { approved_at = v }
        else if let s = try? c.decode(String.self, forKey: .approved_at) { approved_at = Int64(s) }
        else if let d = try? c.decode(Double.self, forKey: .approved_at) { approved_at = Int64(d) }
        else { approved_at = nil }
    }

    enum CodingKeys: String, CodingKey {
        case user_id, approved_at, tier_number
    }
}

struct PaymentRunRaw: Codable {
    var id: String
    var project_id: String?
    var name: String?
    var number: String?
    var pay_method: String?
    var approval: [PaymentRunApprovalRaw]?
    var status: String?
    var total_amount: Double?
    var created_by: String?
    var created_at: Int64?
    var updated_at: Int64?
    var rejected_by: String?
    var rejected_at: Int64?
    var rejection_reason: String?
    var invoice_count: Int?
    var computed_total: Double?
    var invoices: [PaymentRunInvoiceRaw]?

    enum CodingKeys: String, CodingKey {
        case id, project_id, name, number, pay_method, approval, status, invoices
        case total_amount, created_by, created_at, updated_at
        case rejected_by, rejected_at, rejection_reason
        case invoice_count, computed_total
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        project_id = try? c.decode(String.self, forKey: .project_id)
        name = try? c.decode(String.self, forKey: .name)
        number = try? c.decode(String.self, forKey: .number)
        pay_method = try? c.decode(String.self, forKey: .pay_method)
        approval = try? c.decode([PaymentRunApprovalRaw].self, forKey: .approval)
        status = try? c.decode(String.self, forKey: .status)
        created_by = try? c.decode(String.self, forKey: .created_by)
        rejected_by = try? c.decode(String.self, forKey: .rejected_by)
        rejection_reason = try? c.decode(String.self, forKey: .rejection_reason)
        invoice_count = try? c.decode(Int.self, forKey: .invoice_count)
        invoices = try? c.decode([PaymentRunInvoiceRaw].self, forKey: .invoices)
        total_amount = flexibleDoubleDecode(c, .total_amount)
        computed_total = flexibleDoubleDecode(c, .computed_total)
        if let v = try? c.decode(Int64.self, forKey: .created_at) { created_at = v }
        else if let s = try? c.decode(String.self, forKey: .created_at) { created_at = Int64(s) ?? 0 }
        else { created_at = 0 }
        if let v = try? c.decode(Int64.self, forKey: .updated_at) { updated_at = v }
        else if let s = try? c.decode(String.self, forKey: .updated_at) { updated_at = Int64(s) ?? 0 }
        else { updated_at = 0 }
        if let v = try? c.decode(Int64.self, forKey: .rejected_at) { rejected_at = v }
        else if let s = try? c.decode(String.self, forKey: .rejected_at) { rejected_at = Int64(s) }
        else { rejected_at = nil }
    }

    func toPaymentRun() -> PaymentRun {
        var pr = PaymentRun()
        pr.id = id
        pr.projectId = project_id ?? ""
        pr.name = name ?? ""
        pr.number = number ?? ""
        pr.payMethod = pay_method ?? ""
        pr.approval = (approval ?? []).map {
            PaymentRunApproval(userId: $0.user_id ?? "", approvedAt: $0.approved_at ?? 0, tierNumber: $0.tier_number ?? 0)
        }
        pr.status = status ?? "pending"
        pr.totalAmount = total_amount ?? 0
        pr.createdBy = created_by ?? ""
        pr.createdAt = created_at ?? 0
        pr.updatedAt = updated_at ?? 0
        pr.rejectedBy = rejected_by
        pr.rejectedAt = rejected_at
        pr.rejectionReason = rejection_reason
        pr.invoiceCount = invoice_count ?? 0
        pr.computedTotal = computed_total ?? 0
        pr.invoices = (invoices ?? []).map {
            PaymentRunInvoice(
                id: $0.id ?? UUID().uuidString,
                invoiceNumber: $0.invoice_number ?? "",
                supplierName: $0.supplier_name ?? "",
                description: $0.description ?? "",
                dueDate: $0.due_date,
                amount: $0.gross_amount ?? 0,
                currency: $0.currency ?? "GBP"
            )
        }
        return pr
    }
}
