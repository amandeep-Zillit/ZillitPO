import SwiftUI
import Combine

// MARK: - AppState (iOS 13 compatible — Combine, no async/await)

class AppState: ObservableObject {
    @Published var projectId = ProjectData.projectId
    @Published var userId = "mock-u-cat2" // Sophie Turner
    @Published var currentUser: AppUser?

    @Published var purchaseOrders: [PurchaseOrder] = []
    @Published var vendors: [Vendor] = []
    @Published var templates: [POTemplate] = []
    @Published var drafts: [PurchaseOrder] = []
    @Published var tierConfigRows: [ApprovalTierConfig] = []
    @Published var formTemplate: FormTemplateResponse?

    @Published var isLoading = false
    @Published var activeTab: DeptTab = .all
    @Published var showCreatePO = false
    @Published var editingPO: PurchaseOrder?
    @Published var selectedPO: PurchaseOrder?
    @Published var formSubmitting = false
    @Published var searchText = ""
    @Published var activeFilter: QuickFilter = .all
    @Published var sortKey: SortKey = .dateDesc
    @Published var showRejectSheet = false
    @Published var rejectTarget: PurchaseOrder?
    @Published var rejectReason = ""
    @Published var deleteTarget: PurchaseOrder?
    @Published var deleteTemplateId: String?
    @Published var deleteDraftId: String?
    @Published var deleteVendorId: String?
    @Published var resumeDraft: PurchaseOrder?
    @Published var editingTemplate: POTemplate?
    @Published var prefilledVendorId: String?
    @Published var popToRoot = false

    private var cancellables = Set<AnyCancellable>()

    init() { currentUser = UsersData.byId[userId]; configureAPI() }

    func switchUser(_ id: String) {
        userId = id; currentUser = UsersData.byId[id]; configureAPI(); loadAllData()
    }

    private func configureAPI() {
        let c = APIClient.shared; c.projectId = projectId; c.userId = userId
        c.isAccountant = currentUser?.isAccountant ?? false
    }

    // MARK: - Data Loading

    func loadAllData() {
        isLoading = true
        let vendorsPub = APIClient.shared.get("/api/v2/vendors?per_page=200")
            .map { tryDecode([Vendor].self, from: $0) ?? [] }
            .replaceError(with: [])
        let tiersPub = APIClient.shared.get("/api/v2/approval-tiers?module=purchase_orders")
            .map { data -> [ApprovalTierConfig] in
                if let result = tryDecode([ApprovalTierConfig].self, from: data) { return result }
                // Debug: log raw response on decode failure
                let raw = String(data: data, encoding: .utf8) ?? "<binary>"
                print("⚠️ Tier config decode failed. Raw: \(raw.prefix(500))")
                return []
            }
            .replaceError(with: [])
        let templatesPub = APIClient.shared.get("/api/v2/purchase-orders/templates")
            .map { tryDecode([POTemplate].self, from: $0) ?? [] }
            .replaceError(with: [])

        Publishers.Zip3(vendorsPub, tiersPub, templatesPub)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v, t, tp in
                guard let self = self else { return }
                self.vendors = v; print("✅ Loaded \(v.count) vendors")
                self.tierConfigRows = t; print("✅ Loaded \(t.count) tier configs")
                self.templates = tp; print("✅ Loaded \(tp.count) templates")
                self.loadPOs()
                self.loadDrafts()
                self.loadFormTemplate()
            }
            .store(in: &cancellables)
    }

    func loadFormTemplate() {
        APIClient.shared.get("/api/v2/purchase-orders/form-templates?module=purchase_orders")
            .map { data -> FormTemplateResponse? in
                let result = tryDecode(FormTemplateResponse.self, from: data)
                if result == nil, let raw = String(data: data, encoding: .utf8) {
                    print("⚠️ Form template decode failed. Raw: \(raw.prefix(500))")
                }
                return result
            }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tpl in
                self?.formTemplate = tpl
                print("📋 Form template: \(tpl?.template.count ?? 0) sections")
                if let sections = tpl?.template {
                    for s in sections {
                        let fieldLabels = s.fields.map { "\($0.name)[\($0.label ?? "nil")]sd=\($0.systemDefault ?? false)" }
                        print("  📌 Section key=\(s.key) label=\(s.label) order=\(s.order) sysDefault=\(s.isSystemDefault) fields=\(fieldLabels)")
                    }
                }
            }
            .store(in: &cancellables)
    }

    func loadPOs() {
        guard let user = currentUser else { isLoading = false; return }
        let info = ApprovalHelpers.getApproverDeptIds(tierConfigRows, userId: user.id)
        var params: [String: String] = [:]
        if info.isApproverInAllScope {
            params["department_ids"] = DepartmentsData.all.map { $0.id }.joined(separator: ",")
        } else {
            let depts = Set([user.departmentId] + info.approverDeptIds).filter { !$0.isEmpty }
            if depts.count > 1 { params["department_ids"] = depts.joined(separator: ",") }
            else if !user.departmentId.isEmpty { params["department_id"] = user.departmentId }
        }
        var path = "/api/v2/purchase-orders"
        if !params.isEmpty { path += "?" + params.map { "\($0.key)=\($0.value)" }.joined(separator: "&") }

        APIClient.shared.get(path)
            .map { [weak self] data -> [PurchaseOrder] in
                let raw = tryDecode([PurchaseOrderRaw].self, from: data) ?? []
                let v = self?.vendors ?? []; let d = DepartmentsData.all
                return raw.filter { ($0.status ?? "") != "DRAFT" }.map { $0.toPO(vendors: v, departments: d) }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pos in
                self?.purchaseOrders = pos; self?.isLoading = false
                print("✅ Loaded \(pos.count) POs")
            }
            .store(in: &cancellables)
    }

    func loadDrafts() {
        APIClient.shared.get("/api/v2/purchase-orders?status=DRAFT")
            .map { [weak self] data -> [PurchaseOrder] in
                let raw = tryDecode([PurchaseOrderRaw].self, from: data) ?? []
                let v = self?.vendors ?? []; let d = DepartmentsData.all
                return raw.map { $0.toPO(vendors: v, departments: d) }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] d in self?.drafts = d; print("✅ Loaded \(d.count) drafts") }
            .store(in: &cancellables)
    }

    func loadTemplates() {
        APIClient.shared.get("/api/v2/purchase-orders/templates")
            .map { data -> [POTemplate] in
                let result = tryDecode([POTemplate].self, from: data) ?? []
                if result.isEmpty, let raw = String(data: data, encoding: .utf8) {
                    print("⚠️ Templates decode returned empty. Raw: \(raw.prefix(500))")
                }
                return result
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] t in self?.templates = t; print("📋 Templates: \(t.count)") }
            .store(in: &cancellables)
    }

    // MARK: - Filtered POs

    var filteredPOs: [PurchaseOrder] {
        guard let user = currentUser else { return [] }
        var list = purchaseOrders
        switch activeTab {
        case .all: list = list.filter { isVisible($0) }
        case .my: list = list.filter { $0.userId == user.id }
        case .department: list = list.filter { ($0.departmentId ?? "") == user.departmentId && $0.userId != user.id }
        default: return []
        }
        switch activeFilter {
        case .all: break
        case .pending: list = list.filter { $0.poStatus == .pending }
        case .approved: list = list.filter { $0.poStatus == .approved || $0.poStatus == .acctEntered }
        case .rejected: list = list.filter { $0.poStatus == .rejected }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter { $0.poNumber.lowercased().contains(q) || $0.vendor.lowercased().contains(q) || ($0.description ?? "").lowercased().contains(q) }
        }
        switch sortKey {
        case .dateDesc: list.sort { $0.createdAt > $1.createdAt }
        case .amountDesc: list.sort { $0.totalAmount > $1.totalAmount }
        case .vendorAsc: list.sort { $0.vendor < $1.vendor }
        }
        return list
    }

    func isVisible(_ po: PurchaseOrder) -> Bool {
        guard let u = currentUser else { return false }
        if po.userId == u.id || (po.departmentId ?? "") == u.departmentId { return true }
        if po.approvals.contains(where: { $0.userId == u.id }) { return true }
        if let c = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: po.departmentId, amount: po.totalAmount) {
            return ApprovalHelpers.getVisibility(po: po, config: c, userId: u.id).visible
        }
        return false
    }

    var tabCounts: [DeptTab: Int] {
        guard let u = currentUser else { return [:] }
        return [.all: purchaseOrders.filter { isVisible($0) }.count,
                .my: purchaseOrders.filter { $0.userId == u.id }.count,
                .department: purchaseOrders.filter { ($0.departmentId ?? "") == u.departmentId && $0.userId != u.id }.count]
    }

    var pendingCount: Int { filteredPOs.filter { $0.poStatus == .pending }.count }
    var approvedCount: Int { filteredPOs.filter { $0.poStatus == .approved || $0.poStatus == .acctEntered }.count }
    var totalValue: Double { filteredPOs.reduce(0) { $0 + VATHelpers.calcVat($1.totalAmount, treatment: $1.vatTreatment).gross } }

    // MARK: - Actions

    func approvePO(_ po: PurchaseOrder) {
        guard let u = currentUser, let cfg = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: po.departmentId, amount: po.totalAmount) else { return }
        let vis = ApprovalHelpers.getVisibility(po: po, config: cfg, userId: u.id)
        guard vis.canApprove, let next = vis.nextTier else { return }
        APIClient.shared.post("/api/v2/purchase-orders/\(po.id)/approve",
            body: ["tier_number": next, "total_tiers": ApprovalHelpers.getTotalTiers(cfg)])
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] _ in self?.loadPOs(); self?.selectedPO = nil })
            .store(in: &cancellables)
    }

    func rejectPO() {
        guard let t = rejectTarget, !rejectReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        APIClient.shared.post("/api/v2/purchase-orders/\(t.id)/reject",
            body: ["rejection_reason": rejectReason.trimmingCharacters(in: .whitespaces)])
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] _ in
                self?.loadPOs(); self?.rejectTarget = nil; self?.rejectReason = ""; self?.showRejectSheet = false; self?.selectedPO = nil
            })
            .store(in: &cancellables)
    }

    func deletePO(_ po: PurchaseOrder) {
        APIClient.shared.del("/api/v2/purchase-orders/\(po.id)")
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] c in
                if case .failure(let e) = c { print("❌ Delete PO failed: \(e)") }
                self?.deleteTarget = nil
            }, receiveValue: { [weak self] _ in
                print("✅ PO deleted"); self?.loadPOs(); self?.loadDrafts()
            })
            .store(in: &cancellables)
    }

    func submitPO(_ fd: POFormData, onComplete: (() -> Void)? = nil) {
        guard let u = currentUser else { print("❌ submitPO: no currentUser"); return }; formSubmitting = true
        let dept = u.departmentId.isEmpty ? fd.departmentId : u.departmentId
        let cfg = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: dept, amount: fd.netAmount)
        let auto = ApprovalHelpers.getAutoApprovals(cfg, userId: u.id, deptId: dept)
        let lineItemPayloads: [[String: Any]] = fd.lineItems.map {
            var item: [String: Any] = ["id":$0.id,"description":$0.description,"quantity":$0.quantity,"unit_price":$0.unitPrice,"total":$0.total,"account":$0.account,"department":$0.department,"expenditure_type":$0.expenditureType]
            if let customVals = fd.lineItemCustomValues[$0.id] {
                var cfArr: [[String: String]] = []
                for (k, v) in customVals where !v.isEmpty { cfArr.append(["name": k, "value": v]) }
                if !cfArr.isEmpty { item["custom_fields"] = cfArr }
            }
            return item
        }
        var p: [String: Any] = ["vendor_id": fd.vendorId, "department_id": dept, "nominal_code": fd.nominalCode,
            "description": fd.description, "currency": fd.currency, "vat_treatment": fd.vatTreatment,
            "notes": fd.notes, "net_amount": fd.netAmount, "status": "PENDING",
            "line_items": lineItemPayloads,
            "approvals": auto.map { ["user_id":$0.userId,"tier_number":$0.tierNumber,"approved_at":$0.approvedAt] as [String: Any] }]
        if let d = fd.effectiveDate { p["effective_date"] = Int64(d.timeIntervalSince1970 * 1000) }
        if let d = fd.deliveryDate { p["delivery_date"] = Int64(d.timeIntervalSince1970 * 1000) }
        if let da = fd.deliveryAddress {
            p["delivery_address"] = ["name": da.name ?? "", "email": da.email ?? "", "phone": da.phone ?? "",
                "line1": da.line1 ?? "", "line2": da.line2 ?? "", "city": da.city ?? "",
                "state": da.state ?? "", "postal_code": da.postalCode ?? "", "country": da.country ?? ""] as [String: Any]
        }
        if !fd.customFieldValues.isEmpty {
            var cfSections: [String: [[String: String]]] = [:]
            for (k, v) in fd.customFieldValues where !v.isEmpty {
                let parts = k.split(separator: "_", maxSplits: 1)
                let sec = parts.count > 1 ? String(parts[0]) : "custom"
                let name = parts.count > 1 ? String(parts[1]) : k
                cfSections[sec, default: []].append(["name": name, "value": v])
            }
            p["custom_fields"] = cfSections.map { ["section": $0.key, "fields": $0.value] as [String: Any] }
        }

        let pub: AnyPublisher<Data, Error>
        if let eid = fd.existingDraftId { pub = APIClient.shared.patch("/api/v2/purchase-orders/\(eid)", body: p) }
        else { pub = APIClient.shared.post("/api/v2/purchase-orders", body: p) }

        pub.receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in self?.formSubmitting = false },
                  receiveValue: { [weak self] _ in self?.loadPOs(); self?.loadDrafts(); self?.showCreatePO = false; self?.resumeDraft = nil; self?.editingPO = nil; self?.activeTab = .my; onComplete?() })
            .store(in: &cancellables)
    }

    func saveDraft(_ fd: POFormData, onComplete: (() -> Void)? = nil) {
        guard let u = currentUser else { print("❌ saveDraft: no currentUser"); return }
        let dept = u.departmentId.isEmpty ? fd.departmentId : u.departmentId

        // Line items — full payload
        let lineItemPayloads: [[String: Any]] = fd.lineItems.map {
            var item: [String: Any] = [
                "id": $0.id, "description": $0.description,
                "quantity": $0.quantity, "unit_price": $0.unitPrice, "total": $0.total,
                "account": $0.account, "department": $0.department,
                "expenditure_type": $0.expenditureType
            ]
            if let customVals = fd.lineItemCustomValues[$0.id] {
                var cfArr: [[String: String]] = []
                for (k, v) in customVals where !v.isEmpty { cfArr.append(["name": k, "value": v]) }
                if !cfArr.isEmpty { item["custom_fields"] = cfArr }
            }
            return item
        }

        var p: [String: Any] = [
            "department_id": dept, "nominal_code": fd.nominalCode,
            "description": fd.description, "currency": fd.currency, "vat_treatment": fd.vatTreatment,
            "notes": fd.notes, "net_amount": fd.netAmount, "status": "DRAFT",
            "line_items": lineItemPayloads
        ]
        if !fd.vendorId.isEmpty { p["vendor_id"] = fd.vendorId }
        if let d = fd.effectiveDate { p["effective_date"] = Int64(d.timeIntervalSince1970 * 1000) }
        if let d = fd.deliveryDate { p["delivery_date"] = Int64(d.timeIntervalSince1970 * 1000) }
        if let da = fd.deliveryAddress {
            p["delivery_address"] = [
                "name": da.name ?? "", "email": da.email ?? "",
                "phone_code": da.phoneCode ?? "", "phone": da.phone ?? "",
                "line1": da.line1 ?? "", "line2": da.line2 ?? "",
                "city": da.city ?? "", "state": da.state ?? "",
                "postal_code": da.postalCode ?? "", "country": da.country ?? ""
            ] as [String: Any]
        }
        if !fd.customFieldValues.isEmpty {
            var cfSections: [String: [[String: String]]] = [:]
            for (k, v) in fd.customFieldValues where !v.isEmpty {
                let parts = k.split(separator: "_", maxSplits: 1)
                let sec = parts.count > 1 ? String(parts[0]) : "custom"
                let fieldName = parts.count > 1 ? String(parts[1]) : k
                cfSections[sec, default: []].append(["name": fieldName, "value": v])
            }
            p["custom_fields"] = cfSections.map { ["section": $0.key, "fields": $0.value] as [String: Any] }
        }

        let pub: AnyPublisher<Data, Error>
        if let eid = fd.existingDraftId { pub = APIClient.shared.patch("/api/v2/purchase-orders/\(eid)", body: p) }
        else { pub = APIClient.shared.post("/api/v2/purchase-orders", body: p) }

        pub.receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { c in
                if case .failure(let e) = c { print("❌ Save draft failed: \(e)") }
            }, receiveValue: { [weak self] _ in
                print("✅ Draft saved")
                self?.loadDrafts(); self?.showCreatePO = false; self?.resumeDraft = nil; self?.editingPO = nil; onComplete?()
            })
            .store(in: &cancellables)
    }

    private func buildTemplateBody(_ fd: POFormData, templateName: String) -> [String: Any] {
        guard let u = currentUser else { return [:] }
        let dept: String = {
            if let d = DepartmentsData.all.first(where: { $0.identifier == fd.departmentId }) { return d.id }
            if !u.departmentId.isEmpty { return u.departmentId }
            return fd.departmentId
        }()
        let name = templateName.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : templateName.trimmingCharacters(in: .whitespaces)

        // Line items — full payload matching web client
        let lineItemPayloads: [[String: Any]] = fd.lineItems.map {
            var item: [String: Any] = [
                "id": $0.id, "description": $0.description,
                "quantity": $0.quantity, "unit_price": $0.unitPrice, "total": $0.total,
                "account": $0.account, "department": $0.department,
                "expenditure_type": $0.expenditureType
            ]
            if let customVals = fd.lineItemCustomValues[$0.id] {
                var cfArr: [[String: String]] = []
                for (k, v) in customVals where !v.isEmpty { cfArr.append(["name": k, "value": v]) }
                if !cfArr.isEmpty { item["custom_fields"] = cfArr }
            }
            return item
        }

        var body: [String: Any] = [
            "template_name": name,
            "department_id": dept, "nominal_code": fd.nominalCode,
            "description": fd.description, "currency": fd.currency,
            "vat_treatment": fd.vatTreatment,
            "notes": fd.notes, "net_amount": fd.netAmount,
            "line_items": lineItemPayloads
        ]
        if !fd.vendorId.isEmpty { body["vendor_id"] = fd.vendorId }

        // Dates — epoch milliseconds matching web client
        if let d = fd.effectiveDate { body["effective_date"] = Int64(d.timeIntervalSince1970 * 1000) }
        if let d = fd.deliveryDate { body["delivery_date"] = Int64(d.timeIntervalSince1970 * 1000) }

        // Delivery address
        if let da = fd.deliveryAddress {
            body["delivery_address"] = [
                "name": da.name ?? "", "email": da.email ?? "",
                "phone_code": da.phoneCode ?? "", "phone": da.phone ?? "",
                "line1": da.line1 ?? "", "line2": da.line2 ?? "",
                "city": da.city ?? "", "state": da.state ?? "",
                "postal_code": da.postalCode ?? "", "country": da.country ?? ""
            ] as [String: Any]
        }

        // Custom fields — grouped by section matching web client
        if !fd.customFieldValues.isEmpty {
            var cfSections: [String: [[String: String]]] = [:]
            for (k, v) in fd.customFieldValues where !v.isEmpty {
                let parts = k.split(separator: "_", maxSplits: 1)
                let sec = parts.count > 1 ? String(parts[0]) : "custom"
                let fieldName = parts.count > 1 ? String(parts[1]) : k
                cfSections[sec, default: []].append(["name": fieldName, "value": v])
            }
            body["custom_fields"] = cfSections.map { ["section": $0.key, "fields": $0.value] as [String: Any] }
        }

        return body
    }

    func saveTemplate(_ fd: POFormData, templateName: String, onComplete: (() -> Void)? = nil) {
        let body = buildTemplateBody(fd, templateName: templateName)
        if body.isEmpty { return }
        APIClient.shared.post("/api/v2/purchase-orders/templates", body: body)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { c in
                if case .failure(let e) = c { print("❌ Save template failed: \(e)") }
            }, receiveValue: { [weak self] _ in
                print("✅ Template saved"); self?.loadTemplates(); onComplete?()
            })
            .store(in: &cancellables)
    }

    func updateTemplate(_ id: String, _ fd: POFormData, templateName: String, onComplete: (() -> Void)? = nil) {
        let body = buildTemplateBody(fd, templateName: templateName)
        if body.isEmpty { return }
        APIClient.shared.patch("/api/v2/purchase-orders/templates/\(id)", body: body)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { c in
                if case .failure(let e) = c { print("❌ Update template failed: \(e)") }
            }, receiveValue: { [weak self] _ in
                print("✅ Template updated"); self?.loadTemplates(); self?.editingTemplate = nil; onComplete?()
            })
            .store(in: &cancellables)
    }

    func deleteTemplate(_ id: String) {
        APIClient.shared.del("/api/v2/purchase-orders/templates/\(id)")
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { c in
                if case .failure(let e) = c { print("❌ Delete template failed: \(e)") }
            }, receiveValue: { [weak self] _ in
                print("✅ Template deleted"); self?.loadTemplates()
            })
            .store(in: &cancellables)
    }

    func deleteDraft(_ id: String) {
        APIClient.shared.del("/api/v2/purchase-orders/\(id)")
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { c in
                if case .failure(let e) = c { print("❌ Delete draft failed: \(e)") }
            }, receiveValue: { [weak self] _ in
                print("✅ Draft deleted"); self?.loadDrafts()
            })
            .store(in: &cancellables)
    }

    func deleteVendor(_ id: String) {
        APIClient.shared.del("/api/v2/vendors/\(id)")
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { c in
                if case .failure(let e) = c { print("❌ Delete vendor failed: \(e)") }
            }, receiveValue: { [weak self] _ in
                print("✅ Vendor deleted")
                self?.vendors.removeAll { $0.id == id }
                self?.loadAllData()
            })
            .store(in: &cancellables)
    }
}

// MARK: - Enums

enum DeptTab: String, CaseIterable, Identifiable {
    case all = "All POs", my = "My POs", department = "My Dept"
    case vendors = "Vendors"
    var id: String { rawValue }
}

enum QuickFilter: String, CaseIterable { case all = "All", pending = "Pending", approved = "Approved", rejected = "Rejected" }
enum SortKey: String, CaseIterable { case dateDesc = "Date ↓", amountDesc = "Amount ↓", vendorAsc = "Vendor A-Z" }

struct POFormData {
    var vendorId = ""; var departmentId = ""; var nominalCode = ""; var description = ""
    var currency = "GBP"; var vatTreatment = "pending"; var effectiveDate: Date?; var deliveryDate: Date?
    var notes = ""; var lineItems: [LineItem] = [LineItem()]; var existingDraftId: String?
    var deliveryAddress: DeliveryAddress?
    var customFieldValues: [String: String] = [:]
    var lineItemCustomValues: [String: [String: String]] = [:]
    var termsOfEngagement: [String] = []
    var netAmount: Double { lineItems.filter { $0.splitParentId == nil }.reduce(0) { $0 + $1.total } }
}
