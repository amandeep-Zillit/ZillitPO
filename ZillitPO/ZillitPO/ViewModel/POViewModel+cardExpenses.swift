//
//  POViewModel+cardExpenses.swift
//  ZillitPO
//

import Foundation

extension POViewModel {

    // MARK: - Load Receipts

    // MARK: - Metadata (drives hub tile counts)

    func loadCardExpenseMeta() {
        CardExpenseCodableTask.fetchMetadata { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result, let data = r?.data {
                    self?.cardExpenseMeta = data
                    print("✅ Loaded card expense meta")
                } else if case .failure(let e) = result {
                    print("❌ Card expense meta failed: \(e)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadAllCardReceipts() {
        isLoadingReceipts = true
        CardExpenseCodableTask.fetchTransactions("all") { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingReceipts = false
                if case .success(let r) = result {
                    self?.cardReceipts = (r?.data ?? []).map { $0.toCardTransaction() }
                } else if case .failure(let e) = result { print("❌ All card receipts failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    /// Load Receipt Inbox — calls the /receipts endpoint directly with the correct ReceiptRaw type.
    func loadInboxReceipts() {
        isLoadingInboxReceipts = true
        CardExpenseCodableTask.fetchAllReceipts { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingInboxReceipts = false
                switch result {
                case .success(let response):
                    self?.inboxReceipts = (response?.data ?? []).map { $0.toReceipt() }
                    print("✅ Loaded inbox receipts: \(self?.inboxReceipts.count ?? 0)")
                case .failure(let error):
                    print("❌ Inbox receipts failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadReceiptDetail(id: String) {
        isLoadingReceiptDetail = true
        currentReceiptDetail = nil
        CardExpenseCodableTask.fetchReceiptDetail(id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingReceiptDetail = false
                switch result {
                case .success(let response):
                    if let raw = response?.data { self?.currentReceiptDetail = raw.toReceipt() }
                case .failure(let error):
                    print("❌ Receipt detail failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadMyCardReceipts() {
        isLoadingReceipts = true
        CardExpenseCodableTask.fetchTransactions("my") { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingReceipts = false
                if case .success(let r) = result {
                    self?.myCardReceipts = (r?.data ?? []).map { $0.toCardTransaction() }
                } else if case .failure(let e) = result { print("❌ My card receipts failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadCardTransactions() {
        isLoadingCardTxns = true
        CardExpenseCodableTask.fetchTransactions("") { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingCardTxns = false
                switch result {
                case .success(let response):
                    self?.cardTransactions = (response?.data ?? []).map { $0.toCardTransaction() }
                case .failure(let error):
                    print("❌ Fetch card transactions failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadTopUpQueue() {
        isLoadingTopUps = true
        CardExpenseCodableTask.fetchTopUps { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingTopUps = false
                if case .success(let r) = result {
                    let all = (r?.data ?? []).map { $0.toTopUpItem() }
                    self?.topUpQueue = all.filter { $0.entityType.lowercased() == "card" }
                } else if case .failure(let e) = result { print("❌ Top-ups failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadSmartAlerts() {
        isLoadingSmartAlerts = true
        CardExpenseCodableTask.fetchSmartAlerts { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingSmartAlerts = false
                if case .success(let r) = result {
                    self?.smartAlerts = (r?.data ?? []).map { $0.toSmartAlert() }
                } else if case .failure(let e) = result { print("❌ Smart alerts failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func resolveSmartAlert(_ id: String) {
        guard let idx = smartAlerts.firstIndex(where: { $0.id == id }) else { return }
        var a = smartAlerts[idx]
        a.status = "resolved"
        a.resolvedAt = Int64(Date().timeIntervalSince1970 * 1000)
        smartAlerts[idx] = a
    }

    func dismissSmartAlert(_ id: String) {
        smartAlerts.removeAll { $0.id == id }
    }

    func overrideApprovalItem(_ id: String, reason: String, completion: @escaping (Bool) -> Void) {
        let body: [String: Any] = ["reason": reason, "user_id": userId]
        CardExpenseCodableTask.overrideApproval(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.cardApprovalQueueItems.removeAll { $0.id == id }
                    print("✅ Approval overridden: \(id)")
                    completion(true)
                case .failure(let e):
                    print("❌ Override approval failed: \(e)")
                    completion(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func loadCardApprovalQueue() {
        isLoadingCardApprovals = true
        CardExpenseCodableTask.fetchApprovalQueue { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingCardApprovals = false
                if case .success(let r) = result {
                    self?.cardApprovalQueueItems = (r?.data ?? []).map { $0.toCardTransaction() }
                } else if case .failure(let e) = result { print("❌ Approval queue failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadPendingCoding() {
        isLoadingPendingCoding = true
        CardExpenseCodableTask.fetchPendingCoding { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingPendingCoding = false
                if case .success(let r) = result {
                    self?.pendingCodingItems = (r?.data ?? []).map { $0.toPendingCodingItem() }
                } else if case .failure(let e) = result { print("❌ Pending coding failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadPendingCodingItemById(_ id: String) {
        CardExpenseCodableTask.fetchPendingCodingItem(id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if case .success(let r) = result, let raw = r?.data {
                    let updated = raw.toPendingCodingItem()
                    if let idx = self.pendingCodingItems.firstIndex(where: { $0.id == id }) {
                        self.pendingCodingItems[idx] = updated
                    }
                    print("✅ Loaded pending coding item detail \(id)")
                } else if case .failure(let e) = result {
                    print("❌ Fetch pending coding item failed: \(e)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadCardHistory() {
        isLoadingCardHistory = true
        CardExpenseCodableTask.fetchCardHistory { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingCardHistory = false
                if case .success(let r) = result {
                    self?.cardHistory = (r?.data ?? []).map { $0.toCardTransaction() }
                } else if case .failure(let e) = result { print("❌ Card history failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func updateCardTransaction(id: String, merchant: String, amount: String, nominalCode: String, notes: String) {
        guard let idx = cardTransactions.firstIndex(where: { $0.id == id }) else { return }
        var t = cardTransactions[idx]
        t.merchant = merchant
        t.description = merchant
        if let a = Double(amount), a > 0 { t.amount = a }
        t.nominalCode = nominalCode
        t.notes = notes
        cardTransactions[idx] = t
        print("✅ Card transaction \(id) updated locally")

        // Best-effort backend update
        let body: [String: Any] = [
            "description": merchant,
            "amount": amount,
            "nominal_code": nominalCode,
            "code_description": notes
        ]
        guard let req = CardExpenseRequest.updateTransaction(id, body).urlRequest else { return }
        APIClient.shared.dataResultTask(with: req) { result in
            DispatchQueue.main.async {
                if case .failure(let e) = result { print("❌ Update transaction backend failed: \(e)") }
                else { print("✅ Update transaction backend succeeded") }
            }
        }.resume()
    }

    func loadCardExpenseReceipts() {
        isLoadingReceipts = true
        CardExpenseCodableTask.fetchMyReceipts("") { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingReceipts = false
                switch result {
                case .success(let response):
                    self?.receipts = (response?.data ?? []).map { $0.toReceipt() }
                case .failure(let error):
                    print("❌ Fetch receipts failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func updateReceiptDetails(id: String, merchant: String, amount: String, date: String, nominalCode: String) {
        guard let idx = receipts.firstIndex(where: { $0.id == id }) else { return }
        var r = receipts[idx]
        r.merchantDetected = merchant.isEmpty ? nil : merchant
        r.amountDetected = amount.isEmpty ? nil : amount
        r.dateDetected = date.isEmpty ? nil : date
        r.nominalCode = nominalCode.isEmpty ? nil : nominalCode
        receipts[idx] = r
        print("✅ Receipt \(id) details updated locally")
    }

    func confirmReceipt(_ receipt: Receipt) {
        CardExpenseCodableTask.confirmReceipt(receipt.id) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result { print("✅ Receipt confirmed"); self?.loadCardExpenseReceipts() }
                else if case .failure(let e) = result { print("❌ Confirm receipt failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    /// Attach / confirm a receipt from the inbox and refresh the inbox list.
    func attachInboxReceipt(_ id: String) {
        CardExpenseCodableTask.confirmReceipt(id) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result { print("✅ Inbox receipt attached: \(id)"); self?.loadInboxReceipts() }
                else if case .failure(let e) = result { print("❌ Attach inbox receipt failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func flagReceiptPersonal(_ receipt: Receipt) {
        CardExpenseCodableTask.flagReceiptPersonal(receipt.id) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result { print("✅ Flagged personal"); self?.loadCardExpenseReceipts() }
                else if case .failure(let e) = result { print("❌ Flag failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func submitReceiptCoding(_ receipt: Receipt, nominalCode: String, lineItems: [[String: Any]], completion: @escaping (Bool) -> Void) {
        let body: [String: Any] = ["nominal_code": nominalCode, "line_items": lineItems]
        CardExpenseCodableTask.submitCoding(receipt.id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Coding saved"); self?.loadCardExpenseReceipts(); completion(true)
                case .failure(let e):
                    print("❌ Submit coding failed: \(e)"); completion(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func deleteReceipt(_ receipt: Receipt) {
        CardExpenseCodableTask.deleteReceipt(receipt.id) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result { print("✅ Receipt deleted"); self?.loadCardExpenseReceipts() }
                else if case .failure(let e) = result { print("❌ Delete receipt failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Load Cards

    func loadCard(_ id: String, completion: @escaping (ExpenseCard) -> Void) {
        CardExpenseCodableTask.fetchCard(id) { result in
            DispatchQueue.main.async {
                if case .success(let response) = result, let raw = response?.data {
                    completion(raw.toCard())
                }
            }
        }.urlDataTask?.resume()
    }

    func loadUserCards() {
        isLoadingCards = true
        let params = currentUser?.isAccountant == true ? "" : "my=true"
        CardExpenseCodableTask.fetchCards(params) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingCards = false
                switch result {
                case .success(let response):
                    self?.userCards = (response?.data ?? []).map { $0.toCard() }
                case .failure(let error):
                    print("❌ Fetch user cards failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadAllRequestedCards() {
        isLoadingCards = true
        CardExpenseCodableTask.fetchCards("status=pending&for_approval=true") { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingCards = false
                switch result {
                case .success(let response):
                    self?.allCards = (response?.data ?? []).map { $0.toCard() }
                    self?.updateCardApproverStatus()
                case .failure(let error):
                    print("❌ Fetch cards for approval failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Card Approval

    func updateCardApproverStatus() {
        let info = ApprovalHelpers.getApproverDeptIds(cardTierConfigRows, userId: userId)
        let inTiers = info.isApproverInAllScope || !info.approverDeptIds.isEmpty
        isCardApprover = inTiers || !allCards.isEmpty || (currentUser?.isAccountant == true)
    }

    func cardsForApproval() -> [ExpenseCard] {
        // Server already filters via for_approval=true
        return allCards
    }

    func approveCard(_ card: ExpenseCard) {
        let cfg = ApprovalHelpers.resolveConfig(cardTierConfigRows, deptId: card.departmentId, amount: card.monthlyLimit)
            ?? ApprovalHelpers.resolveConfig(cardTierConfigRows, deptId: card.departmentId)
        guard let cfg = cfg else { return }
        var fakePO = PurchaseOrder()
        fakePO.id = card.id; fakePO.userId = card.holderId; fakePO.status = "PENDING"
        fakePO.departmentId = card.departmentId; fakePO.approvals = card.approvals; fakePO.netAmount = card.monthlyLimit
        let vis = ApprovalHelpers.getVisibility(po: fakePO, config: cfg, userId: userId)
        guard vis.canApprove, let next = vis.nextTier else { return }
        let body: [String: Any] = ["tier_number": next, "total_tiers": ApprovalHelpers.getTotalTiers(cfg), "user_id": userId]
        CardExpenseCodableTask.approveCard(card.id, body) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result { print("✅ Card approved"); self?.loadAllRequestedCards(); self?.loadUserCards() }
                else if case .failure(let e) = result { print("❌ Approve card failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func rejectCard(_ card: ExpenseCard, reason: String) {
        let body: [String: Any] = ["rejection_reason": reason, "user_id": userId]
        CardExpenseCodableTask.rejectCard(card.id, body) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result { print("✅ Card rejected"); self?.loadAllRequestedCards(); self?.loadUserCards() }
                else if case .failure(let e) = result { print("❌ Reject card failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func overrideCard(_ card: ExpenseCard) {
        let body: [String: Any] = ["user_id": userId]
        CardExpenseCodableTask.overrideCard(card.id, body) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result { print("✅ Card overridden"); self?.loadAllRequestedCards(); self?.loadUserCards() }
                else if case .failure(let e) = result { print("❌ Override card failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func requestNewCard(userId: String, holderName: String, departmentName: String,
                        bankAccountId: String, proposedLimit: Double,
                        bsControlCode: String, justification: String) {
        var body: [String: Any] = [
            "holder_id":       userId,
            "card_holder_name": holderName,
            "department_name": departmentName,
            "proposed_limit":  proposedLimit
        ]
        if !bankAccountId.isEmpty   { body["bank_account_id"]  = bankAccountId }
        if !bsControlCode.isEmpty   { body["bs_control_code"]  = bsControlCode }
        if !justification.isEmpty   { body["justification"]    = justification }

        CardExpenseCodableTask.createCard(body) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result { self?.loadUserCards() }
                else if case .failure(let e) = result { print("❌ Request card failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadBankAccounts() {
        CardExpenseCodableTask.fetchBankAccounts { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result {
                    self?.bankAccounts = (r?.data ?? []).map { $0.toProductionBankAccount() }
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Load All Card Expense Data

    func loadAllCardExpenseData() {
        // Lightweight hub loader — only metadata. Each tile/page loads its own data on appear.
        loadCardExpenseMeta()
    }
}
