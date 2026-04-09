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

        // Fetch invoice tier configs
        group.enter()
        let invoiceTiersTask = POCodableTask.fetchInvoiceApprovalTiers { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.invoiceTierConfigRows = response?.data ?? []
                    print("✅ Loaded \(self?.invoiceTierConfigRows.count ?? 0) invoice tier configs")
                    for row in self?.invoiceTierConfigRows ?? [] {
                        print("  📌 Invoice tier: module=\(row.module) scope=\(row.scope) deptId=\(row.departmentId ?? "nil") tiers=\(row.tiers.count)")
                        for tier in row.tiers {
                            let userIds = tier.rules.flatMap { $0.userIds }
                            print("    🔹 Tier order=\(tier.order) users=\(userIds)")
                        }
                    }
                case .failure(let error):
                    print("❌ Fetch invoice tier configs failed: \(error)")
                }
                group.leave()
            }
        }
        if let task = invoiceTiersTask.urlDataTask { task.resume() } else { group.leave() }

        // After all complete, load POs, drafts, invoices, payment runs, settings, and form template
        group.notify(queue: .main) { [weak self] in
            self?.updateInvoiceApproverStatus()
            self?.loadPOs()
            self?.loadDrafts()
            self?.loadInvoices()
            self?.loadPaymentRuns()
            self?.loadInvoiceSettings()
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
                    self?.updateInvoiceApproverStatus()
                    print("✅ Loaded \(invoices.count) invoices")
                case .failure(let error):
                    print("❌ Fetch invoices failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadInvoiceHistory(_ invoiceId: String) {
        invoiceHistoryLoading = true
        POCodableTask.fetchInvoiceHistory(invoiceId) { [weak self] result in
            DispatchQueue.main.async {
                self?.invoiceHistoryLoading = false
                switch result {
                case .success(let response):
                    self?.invoiceHistory[invoiceId] = response?.data ?? []
                    print("✅ Loaded invoice history for \(invoiceId): \(response?.data?.count ?? 0) entries")
                case .failure(let error):
                    print("❌ Fetch invoice history failed: \(error)")
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

    // MARK: - Invoice Actions

    /// Effective tier configs for invoices: use invoice-specific if available, otherwise fall back to PO tiers
    var effectiveInvoiceTierConfigs: [ApprovalTierConfig] {
        if !invoiceTierConfigRows.isEmpty { return invoiceTierConfigRows }
        return tierConfigRows
    }

    func approveInvoice(_ inv: Invoice) {
        guard let u = currentUser,
              let cfg = ApprovalHelpers.resolveConfig(effectiveInvoiceTierConfigs, deptId: inv.departmentId, amount: inv.totalAmount)
        else { return }
        let vis = invoiceApprovalVisibility(for: inv)
        guard vis.canApprove, let next = vis.nextTier else { return }
        let body: [String: Any] = ["tier_number": next, "total_tiers": ApprovalHelpers.getTotalTiers(cfg)]
        POCodableTask.approveInvoice(inv.id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadInvoices(); self?.selectedInvoice = nil
                case .failure(let error):
                    print("❌ Approve invoice failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func rejectInvoice() {
        guard let t = rejectInvoiceTarget, !rejectInvoiceReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let body: [String: Any] = ["rejection_reason": rejectInvoiceReason.trimmingCharacters(in: .whitespaces)]
        POCodableTask.rejectInvoice(t.id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadInvoices(); self?.rejectInvoiceTarget = nil
                    self?.rejectInvoiceReason = ""; self?.showRejectInvoiceSheet = false
                    self?.selectedInvoice = nil
                case .failure(let error):
                    print("❌ Reject invoice failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func deleteInvoice(_ inv: Invoice) {
        let isOwner = inv.userId == userId || inv.assignedTo == userId || inv.updatedBy == userId
        let hasNoApprovals = inv.approvals.isEmpty
        let terminalStates: [InvoiceStatus] = [.approved, .paid, .rejected, .voided, .override_]
        let isTerminal = terminalStates.contains(inv.invoiceStatus)
        guard isOwner, hasNoApprovals, !isTerminal else { return }
        POCodableTask.deleteInvoice(inv.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Invoice deleted")
                    self?.deleteInvoiceTarget = nil
                    self?.loadInvoices()
                case .failure(let error):
                    print("❌ Delete invoice failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func submitInvoice(_ body: [String: Any], completion: @escaping (Bool, String?) -> Void) {
        POCodableTask.createInvoice(body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Invoice submitted")
                    self?.loadInvoices()
                    completion(true, nil)
                case .failure(let error):
                    print("❌ Submit invoice failed: \(error)")
                    completion(false, error.localizedDescription)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Accounts team: move invoice from inbox → approval (sends to approval chain)
    func processInvoice(_ inv: Invoice) {
        guard currentUser?.isAccountant == true else { return }
        let body: [String: Any] = ["status": "approval"]
        POCodableTask.updateInvoice(inv.id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Invoice processed → approval")
                    self?.loadInvoices()
                case .failure(let error):
                    print("❌ Process invoice failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func invoiceApprovalVisibility(for inv: Invoice) -> ApprovalVisibility {
        let isCreator = inv.userId == userId
        let isAssigned = inv.assignedTo == userId
        let isPendingApproval = inv.invoiceStatus == .approval

        // Try tier-based approval first
        let tiers = effectiveInvoiceTierConfigs
        let cfg = ApprovalHelpers.resolveConfig(tiers, deptId: inv.departmentId, amount: inv.totalAmount)
            ?? ApprovalHelpers.resolveConfig(tiers, deptId: inv.departmentId)

        if let cfg = cfg {
            let mappedStatus: String = {
                switch inv.status.lowercased() {
                case "approval": return "PENDING"
                case "approved": return "APPROVED"
                case "rejected": return "REJECTED"
                default: return inv.status.uppercased()
                }
            }()
            var fakePO = PurchaseOrder()
            fakePO.id = inv.id; fakePO.userId = inv.userId; fakePO.status = mappedStatus
            fakePO.departmentId = inv.departmentId; fakePO.approvals = inv.approvals
            fakePO.netAmount = inv.grossAmount
            let tierVis = ApprovalHelpers.getVisibility(po: fakePO, config: cfg, userId: userId)
            // If tier config says user can approve (and they're not the creator), use that
            if tierVis.canApprove && !isCreator { return tierVis }
            // If tier config gives visibility info, return it but also check assigned_to
            if tierVis.totalTiers > 0 {
                let canApprove = isAssigned && isPendingApproval && !isCreator
                return ApprovalVisibility(visible: tierVis.visible || isAssigned,
                                          canApprove: canApprove || tierVis.canApprove,
                                          nextTier: tierVis.nextTier,
                                          totalTiers: tierVis.totalTiers,
                                          approvedCount: tierVis.approvedCount,
                                          isCreator: isCreator)
            }
        }

        // Fallback: assigned_to based approval (no tier config)
        let canApprove = isAssigned && isPendingApproval && !isCreator
        let visible = isCreator || isAssigned || (currentUser?.isAccountant == true)
        return ApprovalVisibility(visible: visible, canApprove: canApprove, nextTier: canApprove ? 1 : nil,
                                  totalTiers: canApprove ? 1 : 0, approvedCount: inv.approvals.count,
                                  isCreator: isCreator)
    }

    func updateInvoiceApproverStatus() {
        let assigned = invoices.contains(where: { $0.assignedTo == userId })
        let isAcct = currentUser?.isAccountant == true
        // Any user in an invoice tier (dept or global) sees the Approval tab
        // Payment run canApprove is separately restricted to global-scope or accountants
        let invoiceInfo = ApprovalHelpers.getApproverDeptIds(invoiceTierConfigRows, userId: userId)
        let inInvoiceTiers = invoiceInfo.isApproverInAllScope || !invoiceInfo.approverDeptIds.isEmpty
        let poInfo = ApprovalHelpers.getApproverDeptIds(tierConfigRows, userId: userId)
        let inPOTiers = poInfo.isApproverInAllScope || !poInfo.approverDeptIds.isEmpty
        isInvoiceApprover = assigned || isAcct || inInvoiceTiers || inPOTiers
    }

    var isCurrentUserInvoiceApprover: Bool { isInvoiceApprover }

    // MARK: - Payment Runs

    func loadPaymentRuns() {
        POCodableTask.fetchPaymentRuns { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    var runs = (response?.data ?? []).map { $0.toPaymentRun() }
                    // API doesn't embed invoice details — merge from static data where available
                    for i in runs.indices where runs[i].invoices.isEmpty {
                        if let staticRun = PaymentRunsData.all.first(where: { $0.id == runs[i].id }) {
                            runs[i].invoices = staticRun.invoices
                        }
                    }
                    self?.paymentRuns = runs
                    print("✅ Loaded \(runs.count) payment runs")
                case .failure(let error):
                    print("❌ Fetch payment runs (/api/v2/payment-runs) failed: \(error)")
                    // Fallback: try account-hub path
                    self?.loadPaymentRunsFallback()
                }
            }
        }.urlDataTask?.resume()
    }

    private func loadPaymentRunsFallback() {
        // /api/v2/payment-runs failed — use static seed data.
        // The real data comes from /api/v2/invoices/active-runs (now the primary path).
        paymentRuns = PaymentRunsData.all
        print("⚠️ Using static payment runs (\(paymentRuns.count) items)")
    }

    func paymentRunApprovalVisibility(for run: PaymentRun) -> ApprovalVisibility {
        let isCreator = run.createdBy == userId
        let isPending = run.isPending
        // Use PO tier configs for payment run approval (same tier system)
        if let cfg = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: nil, amount: run.totalAmount)
            ?? ApprovalHelpers.resolveConfig(tierConfigRows, deptId: nil) {
            var fakePO = PurchaseOrder()
            fakePO.id = run.id; fakePO.userId = run.createdBy
            fakePO.status = isPending ? "PENDING" : run.status.uppercased()
            fakePO.approvals = run.approval.map { Approval(userId: $0.userId, tierNumber: $0.tierNumber, approvedAt: $0.approvedAt) }
            fakePO.netAmount = run.totalAmount
            let vis = ApprovalHelpers.getVisibility(po: fakePO, config: cfg, userId: userId)
            if vis.canApprove || vis.totalTiers > 0 { return vis }
        }
        // Fallback: only "all"-scope tier members or accountants can approve payment runs
        // (dept-level PO approvers should NOT be able to approve company-wide payment runs)
        let info = ApprovalHelpers.getApproverDeptIds(tierConfigRows, userId: userId)
        let canApprove = (info.isApproverInAllScope || currentUser?.isAccountant == true) && isPending && !isCreator
        let visible = canApprove || isCreator || (currentUser?.isAccountant == true)
        return ApprovalVisibility(visible: visible, canApprove: canApprove, nextTier: canApprove ? 1 : nil,
                                  totalTiers: canApprove ? 1 : 0, approvedCount: run.approval.count, isCreator: isCreator)
    }

    func approvePaymentRun(_ run: PaymentRun) {
        guard run.isPending else { return }
        let approvedTiers = Set(run.approval.map { $0.tierNumber })
        let cfg = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: nil)
            ?? ApprovalHelpers.resolveConfig(invoiceTierConfigRows, deptId: nil)
        let totalTiers = max(cfg?.count ?? 2, 2)
        var nextTier = 1
        for t in 1...totalTiers { if !approvedTiers.contains(t) { nextTier = t; break } }
        let body: [String: Any] = ["tier_number": nextTier, "total_tiers": totalTiers]
        POCodableTask.approvePaymentRun(run.id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadPaymentRuns()
                case .failure(let error):
                    print("❌ Approve payment run failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func rejectPaymentRun() {
        guard let t = rejectPaymentRunTarget, !rejectPaymentRunReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let body: [String: Any] = ["rejection_reason": rejectPaymentRunReason.trimmingCharacters(in: .whitespaces)]
        POCodableTask.rejectPaymentRun(t.id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.showRejectPaymentRunSheet = false
                    self?.rejectPaymentRunTarget = nil
                    self?.rejectPaymentRunReason = ""
                    self?.loadPaymentRuns()
                case .failure(let error):
                    print("❌ Reject payment run failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Invoice Settings

    func loadInvoiceSettings() {
        POCodableTask.getInvoiceSettings { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let d = response?.data {
                        self?.invoiceAlerts = d.alerts
                        self?.invoiceTeamMembers = d.teamMembers
                        self?.invoiceRunAuth = d.runAuthorization
                        self?.invoiceAssignmentRules = d.assignmentRules
                        print("✅ Invoice settings: \(d.alerts.count) alerts, \(d.teamMembers.count) team, \(d.runAuthorization.count) run auth, \(d.assignmentRules.count) rules")
                    }
                case .failure(let error):
                    print("❌ Invoice settings failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Invoice Upload

    func uploadInvoiceFile(_ data: Data, fileName: String, mimeType: String) {
        uploading = true
        uploadError = nil
        uploadExtraction = nil
        uploadId = nil
        guard let req = APIClient.shared.buildMultipartRequest(
            "/api/v2/invoices/upload", fileData: data, fileName: fileName, mimeType: mimeType, fieldName: "file"
        ) else {
            uploadError = "Failed to build upload request"; uploading = false; return
        }
        let task: URLSessionDataTask = APIClient.shared.codableResultTask(with: req) { [weak self] (result: Result<APIResponse<InvoiceExtraction>?, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let ext = response?.data {
                        self?.uploadExtraction = ext
                        self?.uploadId = ext.upload_id
                    }
                case .failure(let error):
                    self?.uploadError = error.localizedDescription
                }
                self?.uploading = false
            }
        }
        task.resume()
    }

    func submitInvoiceUpload() {
        guard let ext = uploadExtraction, let type = invoiceType else { return }
        uploadSubmitting = true
        let gross = ext.grossValue
        let net = ext.netValue
        let vat = ext.vatValue
        let payMethod: String = {
            switch type {
            case "wire": return "wire"
            case "cheque": return "cheque"
            default: return "bacs"
            }
        }()
        let defaultDept = DepartmentsData.all.first { $0.identifier == currentUser?.departmentIdentifier }?.id ?? ""

        var body: [String: Any] = [
            "description": uploadFileName.isEmpty ? "Uploaded invoice" : uploadFileName,
            "pay_method": payMethod,
            "currency": ext.currency ?? "GBP",
            "status": "inbox",
        ]
        body["gross_amount"] = gross
        if net > 0 { body["net_amount"] = net }
        if vat > 0 { body["vat_amount"] = vat }
        if let d = ext.invoice_date, !d.isEmpty { body["invoice_date"] = d }
        if let d = ext.due_date, !d.isEmpty { body["due_date"] = d }
        if let n = ext.invoice_number, !n.isEmpty { body["invoice_number"] = n }
        if let p = ext.po_number, !p.isEmpty { body["po_number"] = p }
        if !defaultDept.isEmpty { body["department_id"] = defaultDept }
        if let uid = uploadId { body["upload_id"] = uid }
        // Supplier details
        if let supplier = ext.supplier {
            var s: [String: Any] = [:]
            if let n = supplier.name, !n.isEmpty { s["name"] = n; body["supplier_name"] = n }
            if let a = supplier.address, !a.isEmpty { s["address"] = a }
            if let e = supplier.email, !e.isEmpty { s["email"] = e }
            if let p = supplier.phone, !p.isEmpty { s["phone"] = p }
            if let v = supplier.vat_number, !v.isEmpty { s["vat_number"] = v }
            if !s.isEmpty { body["supplier"] = s }
        }
        // Line items
        if let items = ext.line_items, !items.isEmpty {
            body["line_items"] = items.map { item -> [String: Any] in
                var li: [String: Any] = [:]
                if let d = item.description, !d.isEmpty { li["description"] = d }
                if item.quantityValue > 0 { li["quantity"] = item.quantityValue }
                if item.unitPriceValue > 0 { li["unit_price"] = item.unitPriceValue }
                if item.amountValue > 0 { li["amount"] = item.amountValue }
                return li
            }
        }

        POCodableTask.createInvoice(body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.uploadSubmitted = true; self?.uploadSubmitting = false; self?.showTypeSelect = false
                    self?.loadInvoices()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self?.closeInvoiceUpload() }
                case .failure(let error):
                    self?.uploadError = error.localizedDescription; self?.uploadSubmitting = false
                }
            }
        }.urlDataTask?.resume()
    }

    func closeInvoiceUpload() {
        showUploadPreview = false; uploadFileName = ""; uploadFileData = nil; uploadFileMimeType = ""
        uploading = false; uploadError = nil; uploadExtraction = nil; uploadId = nil
        showTypeSelect = false; invoiceType = nil; uploadSubmitting = false; uploadSubmitted = false
    }

    // MARK: - Payment Run Detail (run auth based)

    var isRunAuthApprover: Bool {
        invoiceRunAuth.contains { $0.user.contains(userId) }
    }

    func openRunDetail(_ runId: String) {
        runDetailLoading = true
        selectedRunDetail = PaymentRunDetail(run: PaymentRun(), invoices: [])
        POCodableTask.getPaymentRun(runId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let raw = response?.data {
                        let run = raw.run?.toPaymentRun() ?? PaymentRun()
                        let v = self?.vendors ?? []
                        let d = DepartmentsData.all
                        let invoices = (raw.invoices ?? []).map { $0.toInvoice(vendors: v, departments: d) }
                        self?.selectedRunDetail = PaymentRunDetail(run: run, invoices: invoices)
                    }
                case .failure(let error):
                    print("❌ Fetch run detail failed: \(error)")
                    self?.selectedRunDetail = nil
                }
                self?.runDetailLoading = false
            }
        }.urlDataTask?.resume()
    }

    func approveRunAuth() {
        guard let detail = selectedRunDetail else { return }
        let sortedAuth = invoiceRunAuth.sorted { $0.tier < $1.tier }
        let nextLevel = sortedAuth.first { level in
            !detail.run.approval.contains { a in a.tierNumber == level.tier }
        }
        guard let level = nextLevel else { return }
        approvingRunId = detail.run.id
        let body: [String: Any] = ["tier_number": level.tier, "total_tiers": sortedAuth.count]
        POCodableTask.approvePaymentRun(detail.run.id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.openRunDetail(detail.run.id); self?.loadPaymentRuns()
                case .failure(let error):
                    print("❌ Approve run failed: \(error)")
                }
                self?.approvingRunId = nil
            }
        }.urlDataTask?.resume()
    }
}
