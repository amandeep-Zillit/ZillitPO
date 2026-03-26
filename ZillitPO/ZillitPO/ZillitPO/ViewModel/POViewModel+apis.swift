//
//  POViewModel+apis.swift
//  ZillitPO
//

import Foundation

extension POViewModel {

    // MARK: - Data Loading

    func loadAllData() {
        isLoading = true
        let group = DispatchGroup()

        // Fetch vendors
        group.enter()
        let vendorsTask = POCodableTask.fetchVendors { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.vendors = response?.data ?? []
                    print("✅ Loaded \(self?.vendors.count ?? 0) vendors")
                case .failure(let error):
                    print("❌ Fetch vendors failed: \(error)")
                }
                group.leave()
            }
        }
        if let task = vendorsTask.urlDataTask { task.resume() } else { group.leave() }

        // Fetch tier configs
        group.enter()
        let tiersTask = POCodableTask.fetchApprovalTiers { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.tierConfigRows = response?.data ?? []
                    print("✅ Loaded \(self?.tierConfigRows.count ?? 0) tier configs")
                    // Debug: log tier details for pending count resolution
                    for row in self?.tierConfigRows ?? [] {
                        print("  📌 Tier scope=\(row.scope) deptId=\(row.departmentId ?? "nil") tiers=\(row.tiers.count)")
                    }
                case .failure(let error):
                    print("❌ Fetch tier configs failed: \(error)")
                }
                group.leave()
            }
        }
        if let task = tiersTask.urlDataTask { task.resume() } else { group.leave() }

        // Fetch templates
        group.enter()
        let templatesTask = POCodableTask.fetchTemplates { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.templates = response?.data ?? []
                    print("✅ Loaded \(self?.templates.count ?? 0) templates")
                case .failure(let error):
                    print("❌ Fetch templates failed: \(error)")
                }
                group.leave()
            }
        }
        if let task = templatesTask.urlDataTask { task.resume() } else { group.leave() }

        // After all three complete, load POs, drafts, and form template
        group.notify(queue: .main) { [weak self] in
            self?.loadPOs()
            self?.loadDrafts()
            self?.loadFormTemplate()
        }
    }

    func loadFormTemplate() {
        POCodableTask.fetchFormTemplate { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let tpl = response?.data
                    self?.formTemplate = tpl
                    print("📋 Form template: \(tpl?.template.count ?? 0) sections")
                    if let sections = tpl?.template {
                        for s in sections {
                            let fieldLabels = s.fields.map { "\($0.name)[\($0.label ?? "nil")]sd=\($0.systemDefault ?? false)" }
                            print("  📌 Section key=\(s.key) label=\(s.label) order=\(s.order) sysDefault=\(s.isSystemDefault) fields=\(fieldLabels)")
                        }
                    }
                case .failure(let error):
                    print("❌ Fetch form template failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
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

        POCodableTask.fetchPurchaseOrders(path) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let raw = response?.data ?? []
                    let v = self?.vendors ?? []; let d = DepartmentsData.all
                    let pos = raw.filter { ($0.status ?? "") != "DRAFT" }.map { $0.toPO(vendors: v, departments: d) }
                    self?.purchaseOrders = pos
                    print("✅ Loaded \(pos.count) POs")
                    // Debug: log PO VAT details
                    for p in pos.prefix(5) {
                        let liVats = p.lineItems.map { "\($0.id.prefix(6))=\($0.vatTreatment)" }
                        print("  📥 PO \(p.poNumber) poVat=\(p.vatTreatment) amt=\(p.totalAmount) liVats=\(liVats)")
                    }
                case .failure(let error):
                    print("❌ Fetch POs failed: \(error)")
                }
                self?.isLoading = false
            }
        }.urlDataTask?.resume()
    }

    func loadDrafts() {
        POCodableTask.fetchDrafts { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let raw = response?.data ?? []
                    let v = self?.vendors ?? []; let d = DepartmentsData.all
                    let drafts = raw.map { $0.toPO(vendors: v, departments: d) }
                    self?.drafts = drafts
                    print("✅ Loaded \(drafts.count) drafts")
                case .failure(let error):
                    print("❌ Fetch drafts failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadTemplates() {
        POCodableTask.fetchTemplates { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let t = response?.data ?? []
                    self?.templates = t
                    print("📋 Templates: \(t.count)")
                case .failure(let error):
                    print("❌ Fetch templates failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Invoices

    func loadInvoices() {
        let path = "/api/v2/invoices?per_page=200"
        POCodableTask.fetchInvoices(path) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let raw = response?.data ?? []
                    let v = self?.vendors ?? []; let d = DepartmentsData.all
                    let invoices = raw.map { $0.toInvoice(vendors: v, departments: d) }
                    self?.invoices = invoices
                    print("✅ Loaded \(invoices.count) invoices")
                case .failure(let error):
                    print("❌ Fetch invoices failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Actions

    func approvePO(_ po: PurchaseOrder) {
        guard let u = currentUser, let cfg = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: po.departmentId, amount: po.totalAmount) else { return }
        let vis = ApprovalHelpers.getVisibility(po: po, config: cfg, userId: u.id)
        guard vis.canApprove, let next = vis.nextTier else { return }
        let body: [String: Any] = ["tier_number": next, "total_tiers": ApprovalHelpers.getTotalTiers(cfg)]
        POCodableTask.approvePO(po.id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadPOs(); self?.selectedPO = nil
                case .failure(let error):
                    print("❌ Approve PO failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func rejectPO() {
        guard let t = rejectTarget, !rejectReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let body: [String: Any] = ["rejection_reason": rejectReason.trimmingCharacters(in: .whitespaces)]
        POCodableTask.rejectPO(t.id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadPOs(); self?.rejectTarget = nil; self?.rejectReason = ""; self?.showRejectSheet = false; self?.selectedPO = nil
                case .failure(let error):
                    print("❌ Reject PO failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func deletePO(_ po: PurchaseOrder) {
        POCodableTask.deletePO(po.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ PO deleted"); self?.loadPOs(); self?.loadDrafts(); self?.popToRoot = true
                case .failure(let error):
                    print("❌ Delete PO failed: \(error)")
                }
                self?.deleteTarget = nil
            }
        }.urlDataTask?.resume()
    }

    /// Resolve department identifier (e.g. "department_catering") to mongo ID, or return as-is if already a mongo ID
    private func resolveDeptId(_ raw: String) -> String {
        if let dept = DepartmentsData.all.first(where: { $0.identifier == raw }) { return dept.id }
        return raw
    }

    func submitPO(_ fd: POFormData, onComplete: (() -> Void)? = nil) {
        guard let u = currentUser else { print("❌ submitPO: no currentUser"); return }; formSubmitting = true
        let dept = fd.departmentId.isEmpty ? u.departmentId : resolveDeptId(fd.departmentId)
        let cfg = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: dept, amount: fd.netAmount)
        let auto = ApprovalHelpers.getAutoApprovals(cfg, userId: u.id, deptId: dept)
        let lineItemPayloads: [[String: Any]] = fd.lineItems.map {
            var item: [String: Any] = ["id":$0.id,"description":$0.description,"quantity":$0.quantity,"unit_price":$0.unitPrice,"total":$0.total,"account":$0.account,"department":self.resolveDeptId($0.department),"expenditure_type":$0.expenditureType,"vat_treatment":$0.vatTreatment]
            // Include VAT in custom_fields so the API persists it
            var cfArr: [[String: String]] = [["name": "vat", "value": $0.vatTreatment]]
            if let customVals = fd.lineItemCustomValues[$0.id] {
                for (k, v) in customVals where !v.isEmpty && k != "vat" { cfArr.append(["name": k, "value": v]) }
            }
            item["custom_fields"] = cfArr
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

        let completion: (Result<Data?, Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                self?.formSubmitting = false
                switch result {
                case .success:
                    self?.loadPOs(); self?.loadDrafts(); self?.showCreatePO = false; self?.resumeDraft = nil; self?.editingPO = nil; self?.activeTab = .my; onComplete?()
                case .failure(let error):
                    print("❌ Submit PO failed: \(error)")
                }
            }
        }

        // Debug: log VAT values being sent
        print("📤 Submit PO: vat_treatment=\(fd.vatTreatment) existingId=\(fd.existingDraftId ?? "new")")
        for li in fd.lineItems {
            print("  📤 LI \(li.id.prefix(8)): vat=\(li.vatTreatment) desc=\(li.description) total=\(li.total)")
        }

        if let eid = fd.existingDraftId {
            POCodableTask.updatePO(eid, p, completion).urlDataTask?.resume()
        } else {
            POCodableTask.createPO(p, completion).urlDataTask?.resume()
        }
    }

    func saveDraft(_ fd: POFormData, onComplete: (() -> Void)? = nil) {
        guard let u = currentUser else { print("❌ saveDraft: no currentUser"); return }
        let dept = fd.departmentId.isEmpty ? u.departmentId : resolveDeptId(fd.departmentId)

        let lineItemPayloads: [[String: Any]] = fd.lineItems.map {
            var item: [String: Any] = [
                "id": $0.id, "description": $0.description,
                "quantity": $0.quantity, "unit_price": $0.unitPrice, "total": $0.total,
                "account": $0.account, "department": self.resolveDeptId($0.department),
                "expenditure_type": $0.expenditureType, "vat_treatment": $0.vatTreatment
            ]
            // Include VAT in custom_fields so the API persists it
            var cfArr: [[String: String]] = [["name": "vat", "value": $0.vatTreatment]]
            if let customVals = fd.lineItemCustomValues[$0.id] {
                for (k, v) in customVals where !v.isEmpty && k != "vat" { cfArr.append(["name": k, "value": v]) }
            }
            item["custom_fields"] = cfArr
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

        let completion: (Result<Data?, Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Draft saved")
                    self?.loadDrafts(); self?.showCreatePO = false; self?.resumeDraft = nil; self?.editingPO = nil; onComplete?()
                case .failure(let error):
                    print("❌ Save draft failed: \(error)")
                }
            }
        }

        if let eid = fd.existingDraftId {
            POCodableTask.updatePO(eid, p, completion).urlDataTask?.resume()
        } else {
            POCodableTask.createPO(p, completion).urlDataTask?.resume()
        }
    }

    func saveTemplate(_ fd: POFormData, templateName: String, onComplete: (() -> Void)? = nil) {
        let body = buildTemplateBody(fd, templateName: templateName)
        if body.isEmpty { return }
        POCodableTask.createTemplate(body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Template saved"); self?.loadTemplates(); onComplete?()
                case .failure(let error):
                    print("❌ Save template failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func updateTemplate(_ id: String, _ fd: POFormData, templateName: String, onComplete: (() -> Void)? = nil) {
        let body = buildTemplateBody(fd, templateName: templateName)
        if body.isEmpty { return }
        POCodableTask.updateTemplate(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Template updated"); self?.loadTemplates(); self?.editingTemplate = nil; onComplete?()
                case .failure(let error):
                    print("❌ Update template failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func deleteTemplate(_ id: String) {
        POCodableTask.deleteTemplate(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Template deleted"); self?.loadTemplates()
                case .failure(let error):
                    print("❌ Delete template failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func deleteDraft(_ id: String) {
        POCodableTask.deletePO(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Draft deleted"); self?.loadDrafts()
                case .failure(let error):
                    print("❌ Delete draft failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func deleteVendor(_ id: String) {
        POCodableTask.deleteVendor(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Vendor deleted")
                    self?.vendors.removeAll { $0.id == id }
                    self?.loadAllData()
                case .failure(let error):
                    print("❌ Delete vendor failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }
}
