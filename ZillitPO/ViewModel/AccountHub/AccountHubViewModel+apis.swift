//
//  AccountHubViewModel+apis.swift
//  ZillitPO
//

import Foundation

extension AccountHubViewModel {

    // MARK: - Query Threads

    func loadQueryThread(entityType: String, entityId: String) {
        queryThreadLoading = true
        AccountHubCodableTask.fetchEntityQueries(entityType, entityId) { [weak self] result in
            DispatchQueue.main.async {
                self?.queryThreadLoading = false
                switch result {
                case .success(let response):
                    if let thread = response?.data {
                        self?.queryThreads[entityId] = thread
                        debugPrint("✅ Loaded query thread [\(entityType)/\(entityId)]: \((thread.messages ?? []).count) msgs")
                    }
                case .failure(let error):
                    debugPrint("❌ Load query thread failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func sendQueryMessage(entityType: String, entityId: String, message: String) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let userId = currentUser?.userID
        // Note: Demo path simplified — the optimistic-inject + add/create
        // split lives in live's full file. Demo just routes through the
        // dict-body `sendQuery` and reloads.
        let body: [String: Any] = [
            "entity_type": entityType,
            "entity_id": entityId,
            "query": message,
            "queried_by": userId ?? "",
            "queried_at": now,
        ]
        AccountHubCodableTask.sendPOQuery(entityId, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadQueryThread(entityType: entityType, entityId: entityId)
                case .failure(let error):
                    debugPrint("❌ Send query failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    /// Live: marks query-thread badge notifications read via Firebase RTDB.
    /// Demo: no-op (FirebaseRTDB shim swallows the call).
    func readQueryThreadBadge(entityType: String, entityId: String, level1: String) {
        guard !entityId.isEmpty, !level1.isEmpty else { return }
        let isAcct = FormatUtils.isAccountant(currentUser?.departmentIdentifier ?? "")
        let unit: String
        let tool: ToolType
        switch entityType {
        case "purchase_order":
            unit = "purchase_order_label"; tool = .po
        case "invoice":
            unit = "invoice_label"; tool = isAcct ? .accountHub : .po
        case "card_receipt":
            unit = "card_expenses_label"; tool = isAcct ? .accountHub : .cardExpenses
        case "cash_expenses", "cash_claim":
            unit = "cash_expenses_label"; tool = isAcct ? .accountHub : .cashExpenses
        default:
            return
        }
        FirebaseRTDB.shared.refInstance.readToolMessage(
            unit, action: tool, level1: level1, level2: "query_chat", level3: entityId
        )
    }

    // MARK: - Vendors directory

    func loadVendors(completion: (() -> Void)? = nil) {
        isLoadingVendors = true
        POCodableTask.fetchVendors { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingVendors = false
                switch result {
                case .success(let response):
                    self?.vendors = response?.data ?? []
                    debugPrint("✅ Loaded \(self?.vendors.count ?? 0) vendors")
                case .failure(let error):
                    debugPrint("❌ Fetch vendors failed: \(error)")
                }
                completion?()
            }
        }.urlDataTask?.resume()
    }

    func loadVendorDetail(_ id: String, completion: (() -> Void)? = nil) {
        POCodableTask.fetchVendorById(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let full = response?.data,
                       let idx = self?.vendors.firstIndex(where: { $0.id == id }) {
                        // Patch fields onto cached vendor. Demo's Vendor doesn't
                        // store flat bank fields (the shimmed extension reads
                        // nil for them), so this is a no-op for bank — but
                        // basic fields are refreshed.
                        var v = self?.vendors[idx] ?? full
                        v.name = full.name ?? v.name
                        v.email = full.email ?? v.email
                        v.contactPerson = full.contactPerson ?? v.contactPerson
                        self?.vendors[idx] = v
                    }
                case .failure(let error):
                    debugPrint("❌ Fetch vendor detail failed: \(error)")
                }
                completion?()
            }
        }.urlDataTask?.resume()
    }

    func createVendor(_ body: VendorRequestBody, onComplete: @escaping (Bool) -> Void) {
        AccountHubCodableTask.createVendor(body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadVendors()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Create vendor failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func verifyVendor(_ id: String, onComplete: @escaping (Bool) -> Void) {
        POCodableTask.verifyVendor(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let idx = self?.vendors.firstIndex(where: { $0.id == id }) {
                        self?.vendors[idx].verifiedAt = Int(Date().timeIntervalSince1970 * 1000)
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
        POCodableTask.deleteVendor(id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success: debugPrint("✅ Vendor deleted: \(id)")
                case .failure(let error): debugPrint("❌ Delete vendor failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func updateVendor(id: String, body: VendorRequestBody, bankBody: VendorBankDetailsUpdateBody? = nil, onComplete: @escaping (Bool) -> Void) {
        AccountHubCodableTask.updateVendor(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadVendors { [weak self] in self?.loadVendorDetail(id) }
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Update vendor failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func loadVendorHistory(_ vendorId: String) {
        vendorHistoryLoading = true
        POCodableTask.fetchVendorHistory(vendorId) { [weak self] result in
            DispatchQueue.main.async {
                self?.vendorHistoryLoading = false
                switch result {
                case .success(let response):
                    self?.vendorHistory[vendorId] = response?.data ?? []
                case .failure(let error):
                    debugPrint("❌ Fetch vendor history failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Bank Accounts

    func loadBankAccounts(type: String? = nil, active: Bool? = nil, completion: (() -> Void)? = nil) {
        isLoadingBankAccounts = true
        AccountHubCodableTask.fetchBankAccounts(type: type, active: active) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingBankAccounts = false
                switch result {
                case .success(let response):
                    self?.bankAccounts = response?.data ?? []
                case .failure(let error):
                    debugPrint("❌ Fetch bank accounts failed: \(error)")
                }
                completion?()
            }
        }.urlDataTask?.resume()
    }

    func createBankAccount(_ body: HubBankAccountRequestBody, onComplete: @escaping (Bool) -> Void) {
        AccountHubCodableTask.createBankAccount(body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadBankAccounts()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Create bank account failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func fetchBankAccount(id: String, onComplete: @escaping (HubBankAccount?) -> Void) {
        AccountHubCodableTask.fetchBankAccount(id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response): onComplete(response?.data)
                case .failure(let error):
                    debugPrint("❌ Fetch bank account failed: \(error)")
                    onComplete(nil)
                }
            }
        }.urlDataTask?.resume()
    }

    func updateBankAccount(id: String, body: HubBankAccountRequestBody, onComplete: @escaping (Bool) -> Void) {
        AccountHubCodableTask.updateBankAccount(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadBankAccounts()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Update bank account failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func deleteBankAccount(id: String, onComplete: @escaping (Bool) -> Void) {
        AccountHubCodableTask.deleteBankAccount(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.bankAccounts.removeAll { $0.id == id }
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Delete bank account failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }
}
