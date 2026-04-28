//
//  POViewModel+apis.swift
//  ZillitPO
//

import Foundation

extension POViewModel {

    // MARK: - Data Loading

    func loadVendors() {
        isLoadingVendors = true
        POCodableTask.fetchVendors { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingVendors = false
                switch result {
                case .success(let response):
                    self?.vendors = response?.data ?? []
                    debugPrint("✅ Loaded \(self?.vendors.count ?? 0) vendors")
                    // Re-hydrate vendor display fields on any POs / drafts
                    // that were mapped BEFORE vendors finished loading.
                    // Without this, the All Purchase Orders list shows blank
                    // vendor names for a flash (or indefinitely if the user
                    // never triggers another fetch) because `toPO` runs
                    // with an empty vendors array and stores the empty
                    // string. This re-populates `vendor` + `vendorAddress`
                    // from the fresh list.
                    self?.hydrateVendorDisplayFields()
                case .failure(let error):
                    debugPrint("❌ Fetch vendors failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    /// Patches the `vendor` (name) and `vendorAddress` display fields on
    /// every cached PO and draft using the current `vendors` list. Cheap
    /// dictionary lookup per item and does not re-request anything.
    /// Called after `loadVendors` so the vendor column in the All POs
    /// list no longer waits for the next full reload to populate.
    private func hydrateVendorDisplayFields() {
        guard !vendors.isEmpty else { return }
        let byId: [String: Vendor] = Dictionary(uniqueKeysWithValues: vendors.compactMap { v -> (String, Vendor)? in
            guard let id = v.id else { return nil }
            return (id, v)
        })
        func patch(_ list: [PurchaseOrder]) -> [PurchaseOrder] {
            list.map { po -> PurchaseOrder in
                // Only patch entries that lost the race (vendor name is
                // empty). Leave correctly-mapped entries untouched so we
                // don't trigger unnecessary view diffs.
                guard (po.vendor ?? "").isEmpty,
                      let vid = po.vendorId, !vid.isEmpty,
                      let v = byId[vid] else { return po }
                var updated = po
                updated.vendor = v.name ?? ""
                updated.vendorAddress = [v.address?.line1, v.address?.city, v.address?.postalCode]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                return updated
            }
        }
        purchaseOrders = patch(purchaseOrders)
        drafts = patch(drafts)
    }

    func loadApprovalTiers() {
        POCodableTask.fetchApprovalTiers { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.tierConfigRows = r?.data ?? [] }
            }
        }.urlDataTask?.resume()
    }

    func loadInvoiceApprovalTiers() {
        POCodableTask.fetchInvoiceApprovalTiers { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result {
                    self?.invoiceTierConfigRows = r?.data ?? []
                    self?.updateInvoiceApproverStatus()
                }
            }
        }.urlDataTask?.resume()
    }

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
                    debugPrint("✅ Loaded \(self?.vendors.count ?? 0) vendors")
                case .failure(let error):
                    debugPrint("❌ Fetch vendors failed: \(error)")
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
                    debugPrint("✅ Loaded \(self?.tierConfigRows.count ?? 0) tier configs")
                    // Debug: log tier details for pending count resolution
                    for row in self?.tierConfigRows ?? [] {
                        debugPrint("  📌 Tier scope=\(row.scope ?? "") deptId=\(row.departmentId ?? "nil") tiers=\(row.tiers?.count ?? 0)")
                    }
                case .failure(let error):
                    debugPrint("❌ Fetch tier configs failed: \(error)")
                }
                group.leave()
            }
        }
        if let task = tiersTask.urlDataTask { task.resume() } else { group.leave() }

        // Fetch invoice tier configs
        group.enter()
        let invoiceTiersTask = POCodableTask.fetchInvoiceApprovalTiers { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.invoiceTierConfigRows = response?.data ?? []
                    debugPrint("✅ Loaded \(self?.invoiceTierConfigRows.count ?? 0) invoice tier configs")
                    for row in self?.invoiceTierConfigRows ?? [] {
                        debugPrint("  📌 Invoice tier: module=\(row.module ?? "") scope=\(row.scope ?? "") deptId=\(row.departmentId ?? "nil") tiers=\(row.tiers?.count ?? 0)")
                        for tier in row.tiers ?? [] {
                            let userIds = (tier.rules ?? []).flatMap { $0.userIds ?? [] }
                            debugPrint("    🔹 Tier order=\(tier.order ?? 0) users=\(userIds)")
                        }
                    }
                case .failure(let error):
                    debugPrint("❌ Fetch invoice tier configs failed: \(error)")
                }
                group.leave()
            }
        }
        if let task = invoiceTiersTask.urlDataTask { task.resume() } else { group.leave() }

        // After shared resources load, compute approver visibility for the invoice sidebar badge
        group.notify(queue: .main) { [weak self] in
            self?.updateInvoiceApproverStatus()
            self?.isLoading = false
        }
        // Each PO / Invoice / PaymentRuns page loads its own data on appear.
    }

    func loadFloatFormTemplate() {
        POCodableTask.fetchFloatFormTemplate { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let tpl = response?.data
                    self?.floatFormTemplate = tpl
                    debugPrint("📋 Float form template: \(tpl?.template?.count ?? 0) sections")
                case .failure(let error):
                    debugPrint("❌ Fetch float form template failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadFormTemplate() {
        POCodableTask.fetchFormTemplate { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let tpl = response?.data
                    self?.formTemplate = tpl
                    debugPrint("📋 Form template: \(tpl?.template?.count ?? 0) sections")
                case .failure(let error):
                    debugPrint("❌ Fetch form template failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadPOs() {
        guard let user = currentUser else { isLoading = false; return }
        // Show the page-level loader when this call is made directly (e.g.
        // the user navigates to the PO list without having gone through
        // loadAllData). Without this the loader only surfaces when the
        // initial multi-call load happens to still be in flight.
        isLoading = true
        let info = ApprovalHelpers.getApproverDeptIds(tierConfigRows, userId: user.id ?? "")
        var params: [String: String] = [:]
        if info.isApproverInAllScope {
            params["department_ids"] = DepartmentsData.all.map { $0.id ?? "" }.filter { !$0.isEmpty }.joined(separator: ",")
        } else {
            let depts = Set([user.departmentId ?? ""] + info.approverDeptIds).filter { !$0.isEmpty }
            if depts.count > 1 { params["department_ids"] = depts.joined(separator: ",") }
            else if !(user.departmentId ?? "").isEmpty { params["department_id"] = user.departmentId ?? "" }
        }
        var path = "/api/v2/purchase-orders"
        if !params.isEmpty { path += "?" + params.map { "\($0.key)=\($0.value)" }.joined(separator: "&") }

        POCodableTask.fetchPurchaseOrders(path) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let raw = response?.data ?? []
                    let v = self?.vendors ?? []; let d = DepartmentsData.all
                    let pos: [PurchaseOrder] = raw
                        .filter { ($0.status ?? "") != "DRAFT" }
                        .map { var p = $0; p.enrich(vendors: v, departments: d); return p }
                    self?.purchaseOrders = pos
                    debugPrint("✅ Loaded \(pos.count) POs")
                    // Debug: log PO VAT details
                    for p in pos.prefix(5) {
                        let liVats = (p.lineItems ?? []).map { "\(($0.id ?? "").prefix(6))=\($0.vatTreatment ?? "")" }
                        debugPrint("  📥 PO \(p.poNumber ?? "") poVat=\(p.vatTreatment ?? "") amt=\(p.totalAmount) liVats=\(liVats)")
                    }
                case .failure(let error):
                    debugPrint("❌ Fetch POs failed: \(error)")
                }
                self?.isLoading = false
            }
        }.urlDataTask?.resume()
    }

    /// Non-accountant Approval Queue — POs where the signed-in user
    /// is listed as an approver (server-driven filtering; replaces the
    /// client-side `isVisible` filter used on the generic list). Hits
    /// `GET /api/v2/purchase-orders/approval` on the PO microservice.
    /// Populates `purchaseOrders` on success so the existing table UI
    /// picks it up without further changes.
    func loadApprovalQueue(onComplete: (() -> Void)? = nil) {
        isLoading = true
        POCodableTask.fetchApprovalQueue { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let raw = response?.data ?? []
                    let v = self?.vendors ?? []
                    let d = DepartmentsData.all
                    // Server already filters to non-DRAFT; we keep the
                    // belt-and-braces filter so stray drafts don't leak
                    // into the list if the backend changes.
                    let pos: [PurchaseOrder] = raw
                        .filter { ($0.status ?? "") != "DRAFT" }
                        .map { var p = $0; p.enrich(vendors: v, departments: d); return p }
                    self?.purchaseOrders = pos
                    debugPrint("✅ Loaded \(pos.count) approval-queue POs")
                case .failure(let error):
                    debugPrint("❌ Fetch approval queue failed: \(error)")
                }
                self?.isLoading = false
                onComplete?()
            }
        }.urlDataTask?.resume()
    }

    /// My POs tab — POs raised by the signed-in user (non-DRAFT).
    /// Hits `GET /api/v2/purchase-orders/my`. Server-filtered, so the
    /// view-model stores the result directly in `purchaseOrders`
    /// without a secondary `userId`-equality pass.
    func loadMyPOs(onComplete: (() -> Void)? = nil) {
        isLoading = true
        POCodableTask.fetchMyPOs { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let raw = response?.data ?? []
                    let v = self?.vendors ?? []
                    let d = DepartmentsData.all
                    let pos: [PurchaseOrder] = raw
                        .filter { ($0.status ?? "") != "DRAFT" }
                        .map { var p = $0; p.enrich(vendors: v, departments: d); return p }
                    self?.purchaseOrders = pos
                    debugPrint("✅ Loaded \(pos.count) my-POs")
                case .failure(let error):
                    debugPrint("❌ Fetch my POs failed: \(error)")
                }
                self?.isLoading = false
                onComplete?()
            }
        }.urlDataTask?.resume()
    }

    /// Refresh whichever tab is currently active. Used by the
    /// mutation flows (approve / reject / delete / post / close) so
    /// after an action the list shown to the user picks up the new
    /// state from the endpoint that populated it in the first place.
    /// Accountants on "All POs" still hit the generic list; everyone
    /// else routes to their per-tab endpoint.
    func refreshCurrentTab() {
        let acct = currentUser?.isAccountant == true
        switch activeTab {
        case .all:
            if acct { loadPOs() } else { loadApprovalQueue() }
        case .my:
            loadMyPOs()
        case .department:
            loadDepartmentPOs()
        default:
            loadPOs()
        }
    }

    /// My Department POs tab — POs under the user's department,
    /// scoped server-side via `?department_id=…`. Falls back to the
    /// current user's department when no id is passed. Returns early
    /// (clears the list) when there's no resolvable department, so
    /// the UI shows an empty state instead of the previous tab's
    /// cached rows.
    func loadDepartmentPOs(departmentId: String? = nil, onComplete: (() -> Void)? = nil) {
        let deptId = (departmentId?.isEmpty == false)
            ? (departmentId ?? "")
            : (currentUser?.departmentId ?? "")
        guard !deptId.isEmpty else {
            purchaseOrders = []
            isLoading = false
            onComplete?()
            return
        }
        isLoading = true
        let path = "/api/v2/purchase-orders?department_id=\(deptId)"
        POCodableTask.fetchPurchaseOrders(path) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let raw = response?.data ?? []
                    let v = self?.vendors ?? []
                    let d = DepartmentsData.all
                    let pos: [PurchaseOrder] = raw
                        .filter { ($0.status ?? "") != "DRAFT" }
                        .map { var p = $0; p.enrich(vendors: v, departments: d); return p }
                    self?.purchaseOrders = pos
                    debugPrint("✅ Loaded \(pos.count) department POs (\(deptId))")
                case .failure(let error):
                    debugPrint("❌ Fetch department POs failed: \(error)")
                }
                self?.isLoading = false
                onComplete?()
            }
        }.urlDataTask?.resume()
    }

    func loadDrafts() {
        isLoadingDrafts = true
        POCodableTask.fetchDrafts { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingDrafts = false
                switch result {
                case .success(let response):
                    let raw = response?.data ?? []
                    let v = self?.vendors ?? []; let d = DepartmentsData.all
                    let drafts: [PurchaseOrder] = raw.map { var p = $0; p.enrich(vendors: v, departments: d); return p }
                    self?.drafts = drafts
                    debugPrint("✅ Loaded \(drafts.count) drafts")
                case .failure(let error):
                    debugPrint("❌ Fetch drafts failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadTemplates() {
        isLoadingTemplates = true
        POCodableTask.fetchTemplates { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingTemplates = false
                switch result {
                case .success(let response):
                    let t = response?.data ?? []
                    self?.templates = t
                    debugPrint("📋 Templates: \(t.count)")
                case .failure(let error):
                    debugPrint("❌ Fetch templates failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Invoices

    func loadInvoices() {
        isLoadingInvoices = true
        let path = "/api/v2/invoices?perPage=200"
        POCodableTask.fetchInvoices(path) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingInvoices = false
                switch result {
                case .success(let response):
                    var invoices = response?.data ?? []
                    let v = self?.vendors ?? []
                    for i in invoices.indices {
                        let vendor = v.first { $0.id == (invoices[i].vendorId ?? "") }
                        invoices[i].enrich(vendor: vendor)
                    }
                    self?.invoices = invoices
                    self?.updateInvoiceApproverStatus()
                    // Mirror the inline `history` array from each invoice row
                    // into the per-invoice history cache so the History page
                    // has data instantly, before (or instead of) the separate
                    // /history endpoint returns.
                    for invoice in invoices where !(invoice.history?.isEmpty ?? true) {
                        let sorted = (invoice.history ?? []).sorted { ($0.timestamp ?? 0) > ($1.timestamp ?? 0) }
                        self?.invoiceHistory[invoice.id ?? ""] = sorted
                    }
                    let withFile = invoices.filter { ($0.file?.isEmpty == false) || ($0.uploadId?.isEmpty == false) }.count
                    debugPrint("✅ Loaded \(invoices.count) invoices (\(withFile) with attachments)")
                case .failure(let error):
                    debugPrint("❌ Fetch invoices failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    /// "Approval Queue" tab (non-accountant) — server-filtered list of
    /// invoices where the current user sits in an approval tier.
    /// Mirrors `loadApprovalQueue()` on the PO side.
    func loadApprovalQueueInvoices(onComplete: (() -> Void)? = nil) {
        isLoadingInvoices = true
        POCodableTask.fetchApprovalQueueInvoices { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingInvoices = false
                switch result {
                case .success(let response):
                    var invoices = response?.data ?? []
                    let v = self?.vendors ?? []
                    for i in invoices.indices {
                        invoices[i].enrich(vendor: v.first { $0.id == (invoices[i].vendorId ?? "") })
                    }
                    self?.invoices = invoices
                    self?.updateInvoiceApproverStatus()
                    debugPrint("✅ Loaded \(invoices.count) approval-queue invoices")
                case .failure(let error):
                    debugPrint("❌ Fetch approval-queue invoices failed: \(error)")
                }
                onComplete?()
            }
        }.urlDataTask?.resume()
    }

    /// "My Invoices" tab — invoices raised / uploaded by the current
    /// user. Server does the filter so the client stores the result
    /// directly in `self.invoices`.
    func loadMyInvoices(onComplete: (() -> Void)? = nil) {
        isLoadingInvoices = true
        POCodableTask.fetchMyInvoices { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingInvoices = false
                switch result {
                case .success(let response):
                    var invoices = response?.data ?? []
                    let v = self?.vendors ?? []
                    for i in invoices.indices {
                        invoices[i].enrich(vendor: v.first { $0.id == (invoices[i].vendorId ?? "") })
                    }
                    self?.invoices = invoices
                    self?.updateInvoiceApproverStatus()
                    debugPrint("✅ Loaded \(invoices.count) my-invoices")
                case .failure(let error):
                    debugPrint("❌ Fetch my invoices failed: \(error)")
                }
                onComplete?()
            }
        }.urlDataTask?.resume()
    }

    /// "My Department" tab — invoices scoped by `?department_id=…`.
    /// Falls back to the current user's department when no id is
    /// passed. Clears the list early when no department resolves so
    /// the UI doesn't show stale data from the previous tab.
    func loadDepartmentInvoices(departmentId: String? = nil, onComplete: (() -> Void)? = nil) {
        let deptId = (departmentId?.isEmpty == false)
            ? (departmentId ?? "")
            : (currentUser?.departmentId ?? "")
        guard !deptId.isEmpty else {
            invoices = []
            isLoadingInvoices = false
            onComplete?()
            return
        }
        isLoadingInvoices = true
        let path = "/api/v2/invoices?perPage=200&department_id=\(deptId)"
        POCodableTask.fetchInvoices(path) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingInvoices = false
                switch result {
                case .success(let response):
                    var invoices = response?.data ?? []
                    let v = self?.vendors ?? []
                    for i in invoices.indices {
                        invoices[i].enrich(vendor: v.first { $0.id == (invoices[i].vendorId ?? "") })
                    }
                    self?.invoices = invoices
                    self?.updateInvoiceApproverStatus()
                    debugPrint("✅ Loaded \(invoices.count) department invoices (\(deptId))")
                case .failure(let error):
                    debugPrint("❌ Fetch department invoices failed: \(error)")
                }
                onComplete?()
            }
        }.urlDataTask?.resume()
    }

    /// Dispatches to the correct per-tab loader for the currently
    /// active invoice tab + user role. Mirrors `refreshCurrentTab()`
    /// on the PO side and drives every post-mutation refresh
    /// (approve / reject / delete / upload) so the UI honours
    /// whichever endpoint populated the visible data.
    func refreshCurrentInvoiceTab() {
        let acct = currentUser?.isAccountant == true
        switch activeInvoiceTab {
        case .all:
            if acct { loadInvoices() } else { loadApprovalQueueInvoices() }
        case .my:
            loadMyInvoices()
        case .department:
            loadDepartmentInvoices()
        }
    }

    /// Fetches a single invoice by id (`GET /api/v2/invoices/{id}`) and
    /// replaces the cached copy in `self.invoices`. The list endpoint
    /// occasionally omits the `attachments` array — this call always
    /// returns the full row, so the detail page can resolve the real
    /// `stored_filename` and render the uploaded document.
    ///
    /// `isRefreshingInvoice` flips while the call is in flight so the
    /// detail page can show a loader — matches the pattern used by
    /// other tab-level refreshes across the app.
    func refreshInvoice(_ id: String, onComplete: (() -> Void)? = nil) {
        isRefreshingInvoice = true
        POCodableTask.fetchInvoice(id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isRefreshingInvoice = false
                switch result {
                case .success(let response):
                    if var fresh = response?.data {
                        let vendor = self?.vendors.first { $0.id == (fresh.vendorId ?? "") }
                        fresh.enrich(vendor: vendor)
                        if let idx = self?.invoices.firstIndex(where: { $0.id == fresh.id }) {
                            self?.invoices[idx] = fresh
                        } else {
                            self?.invoices.append(fresh)
                        }
                        debugPrint("✅ Refreshed invoice \(id) — file: \(fresh.file ?? "—")")
                    }
                case .failure(let error):
                    debugPrint("❌ Fetch invoice \(id) failed: \(error)")
                }
                onComplete?()
            }
        }.urlDataTask?.resume()
    }

    /// Fetches a single PO from `GET /api/v2/purchase-orders/{id}` and
    /// replaces the stale row in `purchaseOrders` (or `drafts`) so the
    /// detail page sees the latest status / approvals / line-items
    /// without reloading the whole list. Called on detail-page open —
    /// mirrors the invoice-side `refreshInvoice(_:)` pattern.
    func refreshPO(_ id: String, onComplete: (() -> Void)? = nil) {
        guard !id.isEmpty else { onComplete?(); return }
        isRefreshingPO = true
        POCodableTask.fetchPO(id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isRefreshingPO = false
                switch result {
                case .success(let response):
                    if var fresh = response?.data {
                        let v = self?.vendors ?? []
                        let d = DepartmentsData.all
                        fresh.enrich(vendors: v, departments: d)
                        if let idx = self?.purchaseOrders.firstIndex(where: { $0.id == fresh.id }) {
                            self?.purchaseOrders[idx] = fresh
                        } else if let idx = self?.drafts.firstIndex(where: { $0.id == fresh.id }) {
                            self?.drafts[idx] = fresh
                        } else {
                            self?.purchaseOrders.append(fresh)
                        }
                        if self?.selectedPO?.id == fresh.id { self?.selectedPO = fresh }
                        debugPrint("✅ Refreshed PO \(fresh.poNumber ?? id)")
                    }
                case .failure(let error):
                    debugPrint("❌ Fetch PO \(id) failed: \(error)")
                }
                onComplete?()
            }
        }.urlDataTask?.resume()
    }

    // MARK: - PO History + Queries
    //
    // Mirrors the invoice pair — list is keyed by PO id. Loaders are safe
    // to call on every detail-page open; the cached thread is replaced
    // atomically.

    /// Fetches the full audit trail for a PO
    /// (`GET /api/v2/purchase-orders/{id}/history?perPage=200`).
    func loadPOHistory(_ poId: String) {
        poHistoryLoading = true
        POCodableTask.fetchPOHistory(poId) { [weak self] result in
            DispatchQueue.main.async {
                self?.poHistoryLoading = false
                switch result {
                case .success(let response):
                    self?.poHistory[poId] = response?.data ?? []
                    debugPrint("✅ Loaded PO history for \(poId): \(response?.data?.count ?? 0) entries")
                case .failure(let error):
                    debugPrint("❌ Fetch PO history failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    /// Fetches the query thread raised against a PO via
    /// `GET /api/v2/account-hub/queries/entity/purchase_order/{id}`.
    /// Backend returns a single thread object with a `queries` array.
    func loadPOQueries(_ poId: String) {
        poQueriesLoading = true
        POCodableTask.fetchPOQueries(poId) { [weak self] result in
            DispatchQueue.main.async {
                self?.poQueriesLoading = false
                switch result {
                case .success(let response):
                    if let thread = response?.data {
                        self?.poQueries[poId] = thread
                        debugPrint("✅ Loaded PO query thread for \(poId): \((thread.messages ?? []).count) messages")
                    } else {
                        // Empty response — clear any stale thread so the
                        // empty state renders correctly on re-open.
                        self?.poQueries.removeValue(forKey: poId)
                    }
                case .failure(let error):
                    debugPrint("❌ Fetch PO queries failed: \(error)")
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
                    debugPrint("✅ Loaded invoice history for \(invoiceId): \(response?.data?.count ?? 0) entries")
                case .failure(let error):
                    debugPrint("❌ Fetch invoice history failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    /// Fetches the query thread raised against an invoice via
    /// GET /api/v2/account-hub/queries/entity/invoice/{id}. The backend
    /// returns a single thread object with a `queries` array of messages.
    func loadInvoiceQueries(_ invoiceId: String) {
        invoiceQueriesLoading = true
        POCodableTask.fetchInvoiceQueries(invoiceId) { [weak self] result in
            DispatchQueue.main.async {
                self?.invoiceQueriesLoading = false
                switch result {
                case .success(let response):
                    if let thread = response?.data {
                        self?.invoiceQueries[invoiceId] = thread
                        debugPrint("✅ Loaded invoice query thread for \(invoiceId): \((thread.messages ?? []).count) messages")
                    } else {
                        // Empty response → clear any stale thread so the
                        // empty state renders correctly.
                        self?.invoiceQueries.removeValue(forKey: invoiceId)
                    }
                case .failure(let error):
                    debugPrint("❌ Fetch invoice queries failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }


    // MARK: - Actions

    func approvePO(_ po: PurchaseOrder) {
        guard let u = currentUser, let cfg = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: po.departmentId, amount: po.totalAmount) else { return }
        let vis = ApprovalHelpers.getVisibility(po: po, config: cfg, userId: u.id ?? "")
        guard vis.canApprove, let next = vis.nextTier else { return }
        let body: [String: Any] = ["tier_number": next, "total_tiers": ApprovalHelpers.getTotalTiers(cfg)]
        POCodableTask.approvePO(po.id ?? "", body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.refreshCurrentTab(); self?.selectedPO = nil
                case .failure(let error):
                    debugPrint("❌ Approve PO failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func rejectPO() {
        guard let t = rejectTarget, !rejectReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let body: [String: Any] = ["rejection_reason": rejectReason.trimmingCharacters(in: .whitespaces)]
        POCodableTask.rejectPO(t.id ?? "", body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.refreshCurrentTab(); self?.rejectTarget = nil; self?.rejectReason = ""; self?.showRejectSheet = false; self?.selectedPO = nil
                case .failure(let error):
                    debugPrint("❌ Reject PO failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func deletePO(_ po: PurchaseOrder) {
        POCodableTask.deletePO(po.id ?? "") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ PO deleted"); self?.refreshCurrentTab(); self?.loadDrafts(); self?.popToRoot = true
                case .failure(let error):
                    debugPrint("❌ Delete PO failed: \(error)")
                }
                self?.deleteTarget = nil
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Post / Close (accountant-only lifecycle transitions)
    //
    // These wrap the new `/post` and `/close` endpoints introduced
    // alongside the web app's April 2026 PO overhaul. Post moves
    // APPROVED / ACCT_ENTERED → POSTED; close moves POSTED → CLOSED.
    // Both refresh the PO list on success so the list UI picks up the
    // new status + computed totals.

    /// Post an APPROVED / ACCT_ENTERED PO.
    /// - parameter po: the PO whose id drives the route.
    /// - parameter effectiveDate: optional override (ms since epoch).
    ///   When nil, the server keeps the existing `effective_date`.
    /// - parameter onComplete: fires on the main queue with success/error.
    func postPO(_ po: PurchaseOrder,
                effectiveDate: Int64? = nil,
                onComplete: @escaping (Bool, String?) -> Void) {
        // Body shape matches the web client exactly: camelCase for the
        // computed totals + line items, a nested snake_case `poDetails`
        // block so the server can recompute derived fields (gross total,
        // department display, etc.) without a second round-trip.
        let lineItemPayload: [[String: Any]] = (po.lineItems ?? []).map { item in
            var li: [String: Any] = [
                "id": item.id ?? "",
                "description": item.description ?? "",
                "quantity": item.quantity ?? 0,
                "unit_price": item.unitPrice ?? 0,
                "total": item.total ?? 0,
                "account": item.account ?? "",
                "department": item.department ?? "",
                "expenditure_type": item.expenditureType ?? "",
                "vat_treatment": item.vatTreatment ?? ""
            ]
            if let t = item.taxType    { li["tax_type"] = t }
            if let r = item.taxRate    { li["tax_rate"] = r }
            if let tags = item.tags    { li["tags"] = tags }
            return li
        }
        var poDetails: [String: Any] = [
            "description": po.description ?? "",
            "vendor_id": po.vendorId ?? "",
            "department_id": po.departmentId ?? "",
            "nominal_code": po.nominalCode ?? "",
            "currency": po.currency ?? "GBP",
            "notes": po.notes ?? ""
        ]
        if let da = po.deliveryAddress {
            poDetails["delivery_address"] = [
                "name": da.name ?? "", "email": da.email ?? "",
                "phone": da.phone ?? "", "phone_code": da.phoneCode ?? "",
                "line1": da.line1 ?? "", "line2": da.line2 ?? "",
                "city": da.city ?? "", "state": da.state ?? "",
                "postal_code": da.postalCode ?? "", "country": da.country ?? ""
            ]
        }
        if let dd = po.deliveryDate { poDetails["delivery_date"] = dd }

        var body: [String: Any] = [
            "vatTreatment": po.vatTreatment ?? "pending",
            "netTotal": po.netAmount ?? 0,
            "vatAmount": po.vatAmount ?? 0,
            "grossTotal": po.grossTotal ?? po.netAmount ?? 0,
            "lineItems": lineItemPayload,
            "poDetails": poDetails
        ]
        if let ed = effectiveDate ?? po.effectiveDate { body["effectiveDate"] = ed }

        POCodableTask.postPO(po.id ?? "", body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ PO posted (\(po.id ?? ""))")
                    self?.refreshCurrentTab()
                    onComplete(true, nil)
                case .failure(let error):
                    let msg = error.localizedDescription
                    debugPrint("❌ Post PO failed: \(msg)")
                    onComplete(false, msg)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Close a POSTED PO. `reason` is required by validation; the
    /// server rejects an empty string but accepts nil (omitted field).
    func closePO(_ po: PurchaseOrder,
                 reason: String,
                 effectiveDate: Int64? = nil,
                 onComplete: @escaping (Bool, String?) -> Void) {
        var body: [String: Any] = ["reason": reason]
        if let d = effectiveDate { body["effective_date"] = d }

        POCodableTask.closePO(po.id ?? "", body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ PO closed (\(po.id ?? ""))")
                    self?.refreshCurrentTab()
                    onComplete(true, nil)
                case .failure(let error):
                    let msg = error.localizedDescription
                    debugPrint("❌ Close PO failed: \(msg)")
                    onComplete(false, msg)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Bulk PATCH — reassign, set effective date, or bulk-close up to
    /// 100 POs in one call. `data` keys are snake_case and must match
    /// one of the server's allowed shapes; see `bulkUpdateSchema`
    /// (validators/v2/purchase-order.js) for the supported subset.
    func bulkUpdatePOs(ids: [String],
                       data: [String: Any],
                       onComplete: @escaping (Bool, String?) -> Void) {
        let body: [String: Any] = ["po_ids": ids, "data": data]
        POCodableTask.bulkUpdatePOs(body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Bulk update (\(ids.count) POs)")
                    self?.refreshCurrentTab()
                    onComplete(true, nil)
                case .failure(let error):
                    let msg = error.localizedDescription
                    debugPrint("❌ Bulk update failed: \(msg)")
                    onComplete(false, msg)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Resolve department identifier (e.g. "department_catering") to mongo ID, or return as-is if already a mongo ID
    private func resolveDeptId(_ raw: String) -> String {
        if let dept = DepartmentsData.all.first(where: { $0.identifier == raw }) { return dept.id ?? raw }
        return raw
    }

    func submitPO(_ fd: POFormData, onComplete: (() -> Void)? = nil) {
        guard let u = currentUser else { debugPrint("❌ submitPO: no currentUser"); return }; formSubmitting = true
        let dept = fd.departmentId.isEmpty ? (u.departmentId ?? "") : resolveDeptId(fd.departmentId)
        let cfg = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: dept, amount: fd.netAmount)
        let auto = ApprovalHelpers.getAutoApprovals(cfg, userId: u.id ?? "", deptId: dept)
        let lineItemPayloads: [[String: Any]] = fd.lineItems.map {
            var item: [String: Any] = ["id":$0.id ?? "","description":$0.description ?? "","quantity":$0.quantity ?? 0,"unit_price":$0.unitPrice ?? 0,"total":$0.total ?? 0,"account":$0.account ?? "","department":self.resolveDeptId($0.department ?? ""),"expenditure_type":$0.expenditureType ?? "","vat_treatment":$0.vatTreatment ?? ""]
            // Per-line tax fields (Apr 2026). Only included when set —
            // the server's validator rejects empty-string `tax_type`,
            // and a null `tax_rate` is legal.
            if let tt = $0.taxType, !tt.isEmpty { item["tax_type"] = tt }
            if let tr = $0.taxRate               { item["tax_rate"] = tr }
            if let tags = $0.tags                { item["tags"] = tags }
            // Include VAT in custom_fields so the API persists it
            var cfArr: [[String: String]] = [["name": "vat", "value": $0.vatTreatment ?? ""]]
            if let customVals = fd.lineItemCustomValues[$0.id ?? ""] {
                for (k, v) in customVals where !v.isEmpty && k != "vat" { cfArr.append(["name": k, "value": v]) }
            }
            item["custom_fields"] = cfArr
            return item
        }
        var p: [String: Any] = ["vendor_id": fd.vendorId, "department_id": dept, "nominal_code": fd.nominalCode,
            "description": fd.description, "currency": fd.currency, "vat_treatment": fd.vatTreatment,
            "notes": fd.notes, "net_amount": fd.netAmount, "status": "PENDING",
            "line_items": lineItemPayloads,
            "approvals": auto.map { ["user_id":$0.userId ?? "","tier_number":$0.tierNumber ?? 0,"approved_at":$0.approvedAt ?? 0] as [String: Any] }]
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
                    // Form always lands the user on "My POs" after
                    // submit, so fetch that tab's data directly —
                    // avoids a flash of the previous tab's list.
                    self?.activeTab = .my
                    self?.loadMyPOs()
                    self?.loadDrafts()
                    self?.showCreatePO = false
                    self?.resumeDraft = nil
                    self?.editingPO = nil
                    onComplete?()
                case .failure(let error):
                    debugPrint("❌ Submit PO failed: \(error)")
                }
            }
        }

        // Debug: log VAT values being sent
        debugPrint("📤 Submit PO: vat_treatment=\(fd.vatTreatment) existingId=\(fd.existingDraftId ?? "new")")
        for li in fd.lineItems {
            debugPrint("  📤 LI \((li.id ?? "").prefix(8)): vat=\(li.vatTreatment ?? "") desc=\(li.description ?? "") total=\(li.total ?? 0)")
        }

        if let eid = fd.existingDraftId {
            POCodableTask.updatePO(eid, p, completion).urlDataTask?.resume()
        } else {
            POCodableTask.createPO(p, completion).urlDataTask?.resume()
        }
    }

    func saveDraft(_ fd: POFormData, onComplete: (() -> Void)? = nil) {
        guard let u = currentUser else { debugPrint("❌ saveDraft: no currentUser"); return }
        // Flip the save-specific flag so only the Save button renders a
        // loader. `formSubmitting` is reserved for the Submit button so
        // the two actions don't share a spinner.
        formSaving = true
        let dept = fd.departmentId.isEmpty ? (u.departmentId ?? "") : resolveDeptId(fd.departmentId)

        let lineItemPayloads: [[String: Any]] = fd.lineItems.map {
            var item: [String: Any] = [
                "id": $0.id ?? "", "description": $0.description ?? "",
                "quantity": $0.quantity ?? 0, "unit_price": $0.unitPrice ?? 0, "total": $0.total ?? 0,
                "account": $0.account ?? "", "department": self.resolveDeptId($0.department ?? ""),
                "expenditure_type": $0.expenditureType ?? "", "vat_treatment": $0.vatTreatment ?? ""
            ]
            // Include VAT in custom_fields so the API persists it
            var cfArr: [[String: String]] = [["name": "vat", "value": $0.vatTreatment ?? ""]]
            if let customVals = fd.lineItemCustomValues[$0.id ?? ""] {
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
                self?.formSaving = false
                switch result {
                case .success:
                    debugPrint("✅ Draft saved")
                    self?.loadDrafts(); self?.showCreatePO = false; self?.resumeDraft = nil; self?.editingPO = nil; onComplete?()
                case .failure(let error):
                    debugPrint("❌ Save draft failed: \(error)")
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
        formSaving = true
        POCodableTask.createTemplate(body) { [weak self] result in
            DispatchQueue.main.async {
                self?.formSaving = false
                switch result {
                case .success:
                    debugPrint("✅ Template saved"); self?.loadTemplates(); onComplete?()
                case .failure(let error):
                    debugPrint("❌ Save template failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func updateTemplate(_ id: String, _ fd: POFormData, templateName: String, onComplete: (() -> Void)? = nil) {
        let body = buildTemplateBody(fd, templateName: templateName)
        if body.isEmpty { return }
        formSaving = true
        POCodableTask.updateTemplate(id, body) { [weak self] result in
            DispatchQueue.main.async {
                self?.formSaving = false
                switch result {
                case .success:
                    debugPrint("✅ Template updated"); self?.loadTemplates(); self?.editingTemplate = nil; onComplete?()
                case .failure(let error):
                    debugPrint("❌ Update template failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func deleteTemplate(_ id: String) {
        POCodableTask.deleteTemplate(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Template deleted"); self?.loadTemplates()
                case .failure(let error):
                    debugPrint("❌ Delete template failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func deleteDraft(_ id: String) {
        POCodableTask.deletePO(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Draft deleted"); self?.loadDrafts()
                case .failure(let error):
                    debugPrint("❌ Delete draft failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    /// Marks a vendor as verified via `POST /api/v2/vendors/{id}/verify`.
    /// On success the vendor's `verified` flag is flipped in the local
    /// list immediately so the detail page reflects the change without
    /// a full reload. `onComplete` delivers `true` on success, `false`
    /// on any network or server error.
    func verifyVendor(_ id: String, onComplete: @escaping (Bool) -> Void) {
        POCodableTask.verifyVendor(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Vendor verified: \(id)")
                    // Set verifiedAt to now so the computed `verified`
                    // property flips to true immediately while the reload
                    // fetches the authoritative server value.
                    if let idx = self?.vendors.firstIndex(where: { $0.id == id }) {
                        self?.vendors[idx].verifiedAt = Int64(Date().timeIntervalSince1970 * 1000)
                    }
                    self?.loadVendors()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Verify vendor failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func deleteVendor(_ id: String) {
        POCodableTask.deleteVendor(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Vendor deleted")
                    self?.vendors.removeAll { $0.id == id }
                    self?.loadVendors()
                case .failure(let error):
                    debugPrint("❌ Delete vendor failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    /// Updates an existing vendor via `PATCH /api/v2/vendors/{id}`. The
    /// body must match the same shape used by `createVendor` (name,
    /// contact_person, email, phone, address, vat_number,
    /// department_id). On success the vendor list is refreshed so the
    /// detail/list views pick up the new values. `onComplete` tells the
    /// caller whether the call succeeded so it can dismiss or surface an
    /// error.
    func updateVendor(id: String, body: [String: Any], onComplete: @escaping (Bool) -> Void) {
        POCodableTask.updateVendor(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Vendor updated: \(id)")
                    self?.loadVendors()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Update vendor failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Fetches the audit trail for a vendor via
    /// `GET /api/v2/vendors/{id}/history?perPage=200`. Stored by vendor
    /// id so the detail page can subscribe without re-fetching on every
    /// appear. Matches the `loadInvoiceHistory` / `loadPOHistory`
    /// pattern.
    func loadVendorHistory(_ vendorId: String) {
        vendorHistoryLoading = true
        POCodableTask.fetchVendorHistory(vendorId) { [weak self] result in
            DispatchQueue.main.async {
                self?.vendorHistoryLoading = false
                switch result {
                case .success(let response):
                    self?.vendorHistory[vendorId] = response?.data ?? []
                    debugPrint("✅ Loaded vendor history for \(vendorId): \(response?.data?.count ?? 0) entries")
                case .failure(let error):
                    debugPrint("❌ Fetch vendor history failed: \(error)")
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
        guard currentUser != nil,
              let cfg = ApprovalHelpers.resolveConfig(effectiveInvoiceTierConfigs, deptId: inv.departmentId, amount: inv.totalAmount)
        else { return }
        let vis = invoiceApprovalVisibility(for: inv)
        guard vis.canApprove, let next = vis.nextTier else { return }
        let body: [String: Any] = ["tier_number": next, "total_tiers": ApprovalHelpers.getTotalTiers(cfg)]
        POCodableTask.approveInvoice(inv.id ?? "", body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.refreshCurrentInvoiceTab(); self?.selectedInvoice = nil
                case .failure(let error):
                    debugPrint("❌ Approve invoice failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func rejectInvoice() {
        guard let t = rejectInvoiceTarget, !rejectInvoiceReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // Server now expects `{ reason }` on `/invoices/{id}/reject`
        // (see invoices-server validator Apr 2026). The older
        // `rejection_reason` key was silently ignored.
        let body: [String: Any] = ["reason": rejectInvoiceReason.trimmingCharacters(in: .whitespaces)]
        POCodableTask.rejectInvoice(t.id ?? "", body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.refreshCurrentInvoiceTab(); self?.rejectInvoiceTarget = nil
                    self?.rejectInvoiceReason = ""; self?.showRejectInvoiceSheet = false
                    self?.selectedInvoice = nil
                case .failure(let error):
                    debugPrint("❌ Reject invoice failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func deleteInvoice(_ inv: Invoice) {
        let isOwner = inv.userId == userId || inv.assignedTo == userId || inv.updatedBy == userId
        let hasNoApprovals = (inv.approvals ?? []).isEmpty
        let terminalStates: [InvoiceStatus] = [.approved, .paid, .rejected, .voided, .override_]
        let isTerminal = terminalStates.contains(inv.invoiceStatus)
        guard isOwner, hasNoApprovals, !isTerminal else { return }
        POCodableTask.deleteInvoice(inv.id ?? "") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Invoice deleted")
                    self?.deleteInvoiceTarget = nil
                    self?.refreshCurrentInvoiceTab()
                case .failure(let error):
                    debugPrint("❌ Delete invoice failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func submitInvoice(_ body: [String: Any], completion: @escaping (Bool, String?) -> Void) {
        POCodableTask.createInvoice(body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Invoice submitted")
                    self?.refreshCurrentInvoiceTab()
                    completion(true, nil)
                case .failure(let error):
                    debugPrint("❌ Submit invoice failed: \(error)")
                    completion(false, error.localizedDescription)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Accounts team: move invoice from inbox → approval (sends to
    /// approval chain). Now routes through the server's dedicated
    /// `POST /invoices/{id}/send-to-approval` endpoint (Apr 2026).
    /// The old `PATCH { status: "approval" }` path left any prior
    /// approvals in place; the new route resets them so the tier
    /// chain starts clean.
    func processInvoice(_ inv: Invoice,
                        onComplete: ((Bool, String?) -> Void)? = nil) {
        guard currentUser?.isAccountant == true else {
            onComplete?(false, "Only accountants can send invoices to approval.")
            return
        }
        POCodableTask.sendInvoiceToApproval(inv.id ?? "") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Invoice sent to approval (\(inv.id ?? ""))")
                    self?.refreshCurrentInvoiceTab()
                    onComplete?(true, nil)
                case .failure(let error):
                    debugPrint("❌ Send invoice to approval failed: \(error)")
                    onComplete?(false, error.localizedDescription)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Put an invoice on hold. `reason` is required by the server
    /// validator; `note` is optional additional context. The server
    /// snapshots the current status into `previous_status` so
    /// `releaseInvoiceHold` can restore it.
    func holdInvoice(_ inv: Invoice,
                     reason: String,
                     note: String? = nil,
                     onComplete: ((Bool, String?) -> Void)? = nil) {
        let trimmedReason = reason.trimmingCharacters(in: .whitespaces)
        guard !trimmedReason.isEmpty else {
            onComplete?(false, "Hold reason is required.")
            return
        }
        var body: [String: Any] = ["hold_reason": trimmedReason]
        if let n = note?.trimmingCharacters(in: .whitespaces), !n.isEmpty {
            body["hold_note"] = n
        }
        POCodableTask.holdInvoice(inv.id ?? "", body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Invoice held (\(inv.id ?? ""))")
                    self?.refreshCurrentInvoiceTab()
                    onComplete?(true, nil)
                case .failure(let error):
                    debugPrint("❌ Hold invoice failed: \(error)")
                    onComplete?(false, error.localizedDescription)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Release an invoice from hold — server restores it to
    /// `previous_status` (the snapshot taken at Hold time).
    func releaseInvoiceHold(_ inv: Invoice,
                            onComplete: ((Bool, String?) -> Void)? = nil) {
        POCodableTask.releaseInvoiceHold(inv.id ?? "") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Invoice released (\(inv.id ?? ""))")
                    self?.refreshCurrentInvoiceTab()
                    onComplete?(true, nil)
                case .failure(let error):
                    debugPrint("❌ Release invoice failed: \(error)")
                    onComplete?(false, error.localizedDescription)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Accountant-only: post an approved (or override-approved)
    /// invoice to the ledger, moving it to `ready_to_pay` so a
    /// payment run can pick it up.
    func postInvoiceToLedger(_ inv: Invoice,
                             onComplete: ((Bool, String?) -> Void)? = nil) {
        guard currentUser?.isAccountant == true else {
            onComplete?(false, "Only accountants can post invoices.")
            return
        }
        POCodableTask.postInvoiceToLedger(inv.id ?? "") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    debugPrint("✅ Invoice posted to ledger (\(inv.id ?? ""))")
                    self?.refreshCurrentInvoiceTab()
                    onComplete?(true, nil)
                case .failure(let error):
                    debugPrint("❌ Post invoice failed: \(error)")
                    onComplete?(false, error.localizedDescription)
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
                switch (inv.status ?? "").lowercased() {
                case "approval": return "PENDING"
                case "approved": return "APPROVED"
                case "rejected": return "REJECTED"
                default: return (inv.status ?? "").uppercased()
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
                                  totalTiers: canApprove ? 1 : 0, approvedCount: (inv.approvals ?? []).count,
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
        isLoadingPaymentRuns = true
        POCodableTask.fetchPaymentRuns { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    var runs = response?.data ?? []
                    // API doesn't embed invoice details — merge from static data where available
                    for i in runs.indices where (runs[i].invoices ?? []).isEmpty {
                        if let staticRun = PaymentRunsData.all.first(where: { $0.id == runs[i].id }) {
                            runs[i].invoices = staticRun.invoices
                        }
                    }
                    self?.paymentRuns = runs
                    self?.isLoadingPaymentRuns = false
                    debugPrint("✅ Loaded \(runs.count) payment runs")
                case .failure(let error):
                    debugPrint("❌ Fetch payment runs (/api/v2/payment-runs) failed: \(error)")
                    // Fallback: try account-hub path (also clears the flag inside)
                    self?.loadPaymentRunsFallback()
                }
            }
        }.urlDataTask?.resume()
    }

    private func loadPaymentRunsFallback() {
        // /api/v2/payment-runs failed — use static seed data.
        // The real data comes from /api/v2/invoices/active-runs (now the primary path).
        paymentRuns = PaymentRunsData.all
        isLoadingPaymentRuns = false
        debugPrint("⚠️ Using static payment runs (\(paymentRuns.count) items)")
    }

    func paymentRunApprovalVisibility(for run: PaymentRun) -> ApprovalVisibility {
        let isCreator = run.createdBy == userId
        let isPending = run.isPending
        // Use PO tier configs for payment run approval (same tier system)
        if let cfg = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: nil, amount: run.totalAmount)
            ?? ApprovalHelpers.resolveConfig(tierConfigRows, deptId: nil) {
            var fakePO = PurchaseOrder()
            fakePO.id = run.id; fakePO.userId = run.createdBy
            fakePO.status = isPending ? "PENDING" : (run.status ?? "").uppercased()
            fakePO.approvals = (run.approval ?? []).map { Approval(userId: $0.userId, tierNumber: $0.tierNumber, approvedAt: $0.approvedAt) }
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
                                  totalTiers: canApprove ? 1 : 0, approvedCount: (run.approval ?? []).count, isCreator: isCreator)
    }

    func approvePaymentRun(_ run: PaymentRun) {
        guard run.isPending else { return }
        let approvedTiers = Set((run.approval ?? []).map { $0.tierNumber ?? 0 })
        let cfg = ApprovalHelpers.resolveConfig(tierConfigRows, deptId: nil)
            ?? ApprovalHelpers.resolveConfig(invoiceTierConfigRows, deptId: nil)
        let totalTiers = max(cfg?.count ?? 2, 2)
        var nextTier = 1
        for t in 1...totalTiers { if !approvedTiers.contains(t) { nextTier = t; break } }
        let body: [String: Any] = ["tier_number": nextTier, "total_tiers": totalTiers]
        POCodableTask.approvePaymentRun(run.id ?? "", body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadPaymentRuns()
                case .failure(let error):
                    debugPrint("❌ Approve payment run failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func rejectPaymentRun() {
        guard let t = rejectPaymentRunTarget, !rejectPaymentRunReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let body: [String: Any] = ["rejection_reason": rejectPaymentRunReason.trimmingCharacters(in: .whitespaces)]
        POCodableTask.rejectPaymentRun(t.id ?? "", body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.showRejectPaymentRunSheet = false
                    self?.rejectPaymentRunTarget = nil
                    self?.rejectPaymentRunReason = ""
                    self?.loadPaymentRuns()
                case .failure(let error):
                    debugPrint("❌ Reject payment run failed: \(error)")
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
                        self?.invoiceAlerts = d.alerts ?? []
                        self?.invoiceTeamMembers = d.teamMembers ?? []
                        self?.invoiceRunAuth = d.runAuthorization ?? []
                        self?.invoiceAssignmentRules = d.assignmentRules ?? []
                        debugPrint("✅ Invoice settings: \((d.alerts ?? []).count) alerts, \((d.teamMembers ?? []).count) team, \((d.runAuthorization ?? []).count) run auth, \((d.assignmentRules ?? []).count) rules")
                    }
                case .failure(let error):
                    debugPrint("❌ Invoice settings failed: \(error)")
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
        // Upload goes to the invoices microservice on its dedicated
        // base URL (localhost:3004 in dev) — same host that serves
        // the rest of the `/api/v2/invoices/*` routes.
        guard let req = APIClient.shared.buildMultipartRequest(
            "/api/v2/invoices/upload",
            fileData: data, fileName: fileName, mimeType: mimeType, fieldName: "file"
        ) else {
            uploadError = "Failed to build upload request"; uploading = false; return
        }
        let task: URLSessionDataTask? = FCURLSession.sharedInstance.session?.codableResultTask(with: req) { [weak self] (result: Result<ZLGenericResponse<InvoiceExtraction>?, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let ext = response?.data {
                        self?.uploadExtraction = ext
                        self?.uploadId = ext.uploadId
                    }
                case .failure(let error):
                    self?.uploadError = error.localizedDescription
                }
                self?.uploading = false
            }
        }
        task?.resume()
    }

    func submitInvoiceUpload() {
        guard let ext = uploadExtraction, let type = invoiceType else { return }
        uploadSubmitting = true
        let gross = ext.grossValue
        // `net_amount` / `vat_amount` / `vat_rate` are deprecated on
        // the invoice create endpoint (see comment below); we no longer
        // pull `netValue` / `vatValue` here.
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
        // `net_amount` / `vat_amount` / `vat_rate` are deprecated on
        // the invoice create endpoint — the server now strips them
        // via the validator (see invoices-server validator update
        // Apr 2026). Gross is the single source of truth; per-line
        // tax comes from the line item's `tax_type` / `tax_rate`.
        if let d = ext.invoiceDate, !d.isEmpty { body["invoice_date"] = d }
        if let d = ext.dueDate, !d.isEmpty { body["due_date"] = d }
        if let n = ext.invoiceNumber, !n.isEmpty { body["invoice_number"] = n }
        if let p = ext.poNumber, !p.isEmpty { body["po_number"] = p }
        if !defaultDept.isEmpty { body["department_id"] = defaultDept }
        if let uid = uploadId { body["upload_id"] = uid }
        // Persist the uploaded filename on the invoice itself so the View
        // button (which keys off `invoice.file`) works immediately without
        // relying on the backend to copy it from the upload record.
        if let f = ext.file, !f.isEmpty { body["file"] = f }
        // Supplier details
        if let supplier = ext.supplier {
            var s: [String: Any] = [:]
            if let n = supplier.name, !n.isEmpty { s["name"] = n; body["supplier_name"] = n }
            if let a = supplier.address, !a.isEmpty { s["address"] = a }
            if let e = supplier.email, !e.isEmpty { s["email"] = e }
            if let p = supplier.phone, !p.isEmpty { s["phone"] = p }
            if let v = supplier.vatNumber, !v.isEmpty { s["vat_number"] = v }
            if !s.isEmpty { body["supplier"] = s }
        }
        // Line items
        if let items = ext.lineItems, !items.isEmpty {
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
                    self?.refreshCurrentInvoiceTab()
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
        invoiceRunAuth.contains { ($0.user ?? []).contains(userId) }
    }

    func openRunDetail(_ runId: String) {
        runDetailLoading = true
        selectedRunDetail = PaymentRunDetail(run: PaymentRun(), invoices: [])
        POCodableTask.getPaymentRun(runId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if var detail = response?.data {
                        // Enrich invoice vendor details from the loaded vendor list
                        let v = self?.vendors ?? []
                        if var invoices = detail.invoices {
                            for i in invoices.indices {
                                let vendor = v.first { $0.id == (invoices[i].vendorId ?? "") }
                                invoices[i].enrich(vendor: vendor)
                            }
                            detail.invoices = invoices
                        }
                        self?.selectedRunDetail = detail
                    }
                case .failure(let error):
                    debugPrint("❌ Fetch run detail failed: \(error)")
                    self?.selectedRunDetail = nil
                }
                self?.runDetailLoading = false
            }
        }.urlDataTask?.resume()
    }

    func approveRunAuth() {
        guard let detail = selectedRunDetail, let run = detail.run else { return }
        let sortedAuth = invoiceRunAuth.sorted { ($0.tier ?? 0) < ($1.tier ?? 0) }
        let nextLevel = sortedAuth.first { level in
            !(run.approval ?? []).contains { a in (a.tierNumber ?? 0) == (level.tier ?? 0) }
        }
        guard let level = nextLevel else { return }
        approvingRunId = run.id
        let body: [String: Any] = ["tier_number": level.tier ?? 0, "total_tiers": sortedAuth.count]
        POCodableTask.approvePaymentRun(run.id ?? "", body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.openRunDetail(run.id ?? ""); self?.loadPaymentRuns()
                case .failure(let error):
                    debugPrint("❌ Approve run failed: \(error)")
                }
                self?.approvingRunId = nil
            }
        }.urlDataTask?.resume()
    }
}
