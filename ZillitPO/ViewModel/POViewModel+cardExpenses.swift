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
                    self?.topUpQueue = all.filter { $0.entityType?.lowercased() == "card" }
                    // Also populate the cash queue for reuse across modules
                    self?.cashTopUpQueue = all.filter { $0.entityType?.lowercased() == "cash" }
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

    func resolveSmartAlert(_ id: String, note: String = "") {
        // Optimistic local update
        guard let idx = smartAlerts.firstIndex(where: { $0.id == id }) else { return }
        var a = smartAlerts[idx]
        a.status = "resolved"
        a.resolvedAt = Int64(Date().timeIntervalSince1970 * 1000)
        a.resolution = note
        smartAlerts[idx] = a
        // Persist to backend
        var body: [String: Any] = ["user_id": userId]
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { body["note"] = trimmed }
        CardExpenseCodableTask.resolveAlert(id, body) { result in
            DispatchQueue.main.async {
                if case .success = result { print("✅ Smart alert resolved: \(id)") }
                else if case .failure(let e) = result { print("❌ Resolve alert failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func dismissSmartAlert(_ id: String) {
        // Optimistic local removal
        smartAlerts.removeAll { $0.id == id }
        // Persist to backend
        CardExpenseCodableTask.dismissAlert(id) { result in
            DispatchQueue.main.async {
                if case .success = result { print("✅ Smart alert dismissed: \(id)") }
                else if case .failure(let e) = result { print("❌ Dismiss alert failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func investigateSmartAlert(_ id: String) {
        guard let idx = smartAlerts.firstIndex(where: { $0.id == id }) else { return }
        var a = smartAlerts[idx]
        a.status = "under_investigation"
        smartAlerts[idx] = a
        print("✅ Smart alert under investigation: \(id)")
    }

    func revertSmartAlert(_ id: String) {
        guard let idx = smartAlerts.firstIndex(where: { $0.id == id }) else { return }
        var a = smartAlerts[idx]
        a.status = "active"
        smartAlerts[idx] = a
        print("✅ Smart alert reverted to active: \(id)")
    }

    // MARK: - Manual Receipt Matching

    func matchReceipt(_ receiptId: String, transactionId: String, completion: @escaping (Bool) -> Void) {
        let body: [String: Any] = ["transaction_id": transactionId, "user_id": userId]
        CardExpenseCodableTask.matchReceipt(receiptId, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Receipt matched: \(receiptId) → txn \(transactionId)")
                    self?.loadInboxReceipts()
                    self?.loadCardExpenseMeta()
                    completion(true)
                case .failure(let e):
                    print("❌ Match receipt failed: \(e)")
                    completion(false)
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Top-Up Actions

    /// Marks a top-up as fully completed. The server reads the topup record by id and
    /// ignores the request body, so we send `{}`. The `amount` / `note` params are kept
    /// for backward-compat with older call sites and are simply not transmitted.
    func markTopUpCompleted(_ id: String, amount: Double? = nil, note: String = "", completion: ((Bool) -> Void)? = nil) {
        _ = amount; _ = note  // intentionally unused — /complete endpoint expects empty body
        CardExpenseCodableTask.markTopUp(id, [:]) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.topUpQueue.removeAll { $0.id == id }
                    self?.loadCardExpenseMeta()
                    print("✅ Top-up marked completed: \(id)")
                    completion?(true)
                case .failure(let e):
                    print("❌ Mark top-up failed: \(e)")
                    completion?(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func skipTopUp(_ id: String, completion: ((Bool) -> Void)? = nil) {
        CardExpenseCodableTask.skipTopUp(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.topUpQueue.removeAll { $0.id == id }
                    self?.loadCardExpenseMeta()
                    print("✅ Top-up skipped: \(id)")
                    completion?(true)
                case .failure(let e):
                    print("❌ Skip top-up failed: \(e)")
                    completion?(false)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Records a partial top-up. Hits a separate endpoint `/topups/{id}/partial`
    /// which accepts `{ amount?, note }`. If `amount` is nil the server uses the
    /// topup's stored amount.
    func partialTopUp(_ id: String, amount: Double? = nil, note: String, completion: ((Bool) -> Void)? = nil) {
        var body: [String: Any] = [:]
        if let amt = amount, amt > 0 { body["amount"] = amt }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { body["note"] = trimmed }
        CardExpenseCodableTask.partialTopUp(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.topUpQueue.removeAll { $0.id == id }
                    self?.loadCardExpenseMeta()
                    print("✅ Partial top-up recorded: \(id)")
                    completion?(true)
                case .failure(let e):
                    print("❌ Partial top-up failed: \(e)")
                    completion?(false)
                }
            }
        }.urlDataTask?.resume()
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
                if case .success = result {
                    print("✅ Receipt confirmed")
                    self?.loadCardExpenseReceipts()
                    self?.loadInboxReceipts()
                    self?.loadCardExpenseMeta()
                }
                else if case .failure(let e) = result { print("❌ Confirm receipt failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    /// Attach / confirm a receipt from the inbox and refresh the inbox list.
    func attachInboxReceipt(_ id: String) {
        CardExpenseCodableTask.confirmReceipt(id) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    print("✅ Inbox receipt attached: \(id)")
                    self?.loadInboxReceipts()
                    self?.loadCardExpenseMeta()
                }
                else if case .failure(let e) = result { print("❌ Attach inbox receipt failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func flagReceiptPersonal(_ receipt: Receipt) {
        CardExpenseCodableTask.flagReceiptPersonal(receipt.id) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    print("✅ Flagged personal")
                    self?.loadCardExpenseReceipts()
                    self?.loadInboxReceipts()
                    self?.loadCardExpenseMeta()
                }
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
                if case .success = result {
                    print("✅ Receipt deleted")
                    self?.loadCardExpenseReceipts()
                    self?.loadInboxReceipts()
                    self?.loadCardExpenseMeta()
                }
                else if case .failure(let e) = result { print("❌ Delete receipt failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Load Cards

    func loadCard(_ id: String, completion: @escaping (ExpenseCard) -> Void) {
        CardExpenseCodableTask.fetchCard(id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let raw = response?.data {
                        let card = raw.toCard()
                        print("✅ Loaded card \(id): holder=\(card.holderFullName) status=\(card.status ?? "") limit=\(card.monthlyLimit ?? 0) balance=\(card.currentBalance ?? 0) dept=\(card.department ?? "") bank=\(card.bankName)")
                        completion(card)
                    } else {
                        print("⚠️ Load card \(id): empty response body")
                    }
                case .failure(let error):
                    print("❌ Load card \(id) failed: \(error)")
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
        fakePO.departmentId = card.departmentId; fakePO.approvals = card.approvals ?? []; fakePO.netAmount = card.monthlyLimit
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

    func loadCardHistoryById(_ id: String, completion: @escaping ([CardHistoryEntry]) -> Void) {
        CardExpenseCodableTask.fetchCardHistoryById(id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let r):
                    let entries = (r?.data ?? []).map { $0.toEntry() }
                    completion(entries)
                case .failure(let e):
                    print("❌ Fetch card history failed: \(e)")
                    completion([])
                }
            }
        }.urlDataTask?.resume()
    }

    /// Fetches the audit trail for a specific receipt (backing a CardTransaction).
    /// GET /api/v2/card-expenses/receipts/{id}/history
    func loadReceiptHistory(_ receiptId: String, completion: @escaping ([CardHistoryEntry]) -> Void) {
        CardExpenseCodableTask.fetchReceiptHistory(receiptId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let r):
                    let entries = (r?.data ?? []).map { $0.toEntry() }
                    completion(entries)
                case .failure(let e):
                    print("❌ Fetch receipt history failed: \(e)")
                    completion([])
                }
            }
        }.urlDataTask?.resume()
    }

    /// Fetches the query thread raised against a card receipt (surfaced as a
    /// CardTransaction in My Transactions).
    /// GET /api/v2/account-hub/queries/entity/card_receipt/{receiptId}
    func loadReceiptQueries(_ receiptId: String) {
        receiptQueriesLoading = true
        CardExpenseCodableTask.fetchEntityQueries("card_receipt", receiptId) { [weak self] result in
            DispatchQueue.main.async {
                self?.receiptQueriesLoading = false
                switch result {
                case .success(let response):
                    if let thread = response?.data {
                        self?.receiptQueries[receiptId] = thread
                        print("✅ Loaded receipt query thread for \(receiptId): \((thread.messages ?? []).count) messages")
                    } else {
                        self?.receiptQueries.removeValue(forKey: receiptId)
                    }
                case .failure(let error):
                    print("❌ Fetch receipt queries failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func suspendCard(id: String, reason: String = "", completion: @escaping (Bool) -> Void) {
        var body: [String: Any] = ["user_id": userId]
        if !reason.isEmpty { body["reason"] = reason }

        // Optimistic update — replace whole struct so SwiftUI diffing sees the change.
        // (ExpenseCard.== only compares ids, so mutating a property in place
        // wouldn't trigger list re-renders.)
        applyStatusChange(id: id, newStatus: "suspended")

        CardExpenseCodableTask.suspendCard(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Card suspended: \(id)")
                    self?.objectWillChange.send()
                    completion(true)
                case .failure(let e):
                    print("❌ Suspend card failed: \(e)")
                    completion(false)
                }
            }
        }.urlDataTask?.resume()
    }

    enum CardType: String { case digital, physical }

    func activateCard(id: String, cardNumber: String = "", cardType: CardType = .physical, completion: @escaping (Bool, String?) -> Void) {
        var body: [String: Any] = ["user_id": userId, "card_type": cardType.rawValue]
        if !cardNumber.isEmpty {
            switch cardType {
            case .physical: body["physical_card_number"] = cardNumber
            case .digital:  body["digital_card_number"]  = cardNumber
            }
        }

        // Snapshot the pre-mutation state so we can roll back if the
        // API call fails. Previously a failure left the local card
        // marked "active" with the wrong card number — an optimistic
        // update with no rollback.
        let prevUserCard = userCards.first { $0.id == id }
        let prevAllCard  = allCards.first  { $0.id == id }

        applyStatusChange(id: id, newStatus: "active")
        if !cardNumber.isEmpty {
            // Optimistically set the card number on the matching field so detail/list shows it.
            func patch(_ c: ExpenseCard) -> ExpenseCard {
                var m = c
                switch cardType {
                case .physical: m.physicalCardNumber = cardNumber
                case .digital:  m.digitalCardNumber  = cardNumber
                }
                if cardNumber.count >= 4 { m.lastFour = String(cardNumber.suffix(4)) }
                return m
            }
            if let idx = userCards.firstIndex(where: { $0.id == id }) { userCards[idx] = patch(userCards[idx]) }
            if let idx = allCards.firstIndex(where: { $0.id == id })  { allCards[idx]  = patch(allCards[idx]) }
        }

        CardExpenseCodableTask.activateCard(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Card activated (\(cardType.rawValue)): \(id)")
                    self?.objectWillChange.send()
                    completion(true, nil)
                case .failure(let e):
                    print("❌ Activate card failed: \(e)")
                    // Roll back the optimistic status + card-number
                    // patch so the list doesn't falsely show the card
                    // as activated. Surface the server error message
                    // so the caller can display it.
                    if let prev = prevUserCard, let idx = self?.userCards.firstIndex(where: { $0.id == id }) {
                        self?.userCards[idx] = prev
                    }
                    if let prev = prevAllCard, let idx = self?.allCards.firstIndex(where: { $0.id == id }) {
                        self?.allCards[idx] = prev
                    }
                    let message = Self.extractServerErrorMessage(e)
                    completion(false, message)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Pulls a human-readable message out of a network error. Server
    /// error bodies often arrive as HTML with the real message inside
    /// a `<pre>` block (Express/Koa default error pages). Fall back to
    /// `localizedDescription` when the body isn't shaped like that.
    private static func extractServerErrorMessage(_ error: Error) -> String {
        let raw = error.localizedDescription
        if let preStart = raw.range(of: "<pre>"),
           let preEnd = raw.range(of: "</pre>", range: preStart.upperBound..<raw.endIndex) {
            var body = String(raw[preStart.upperBound..<preEnd.lowerBound])
            body = body.replacingOccurrences(of: "<br>", with: "\n")
            let entities: [(String, String)] = [
                ("&quot;", "\""), ("&amp;", "&"), ("&lt;", "<"),
                ("&gt;", ">"), ("&nbsp;", " "), ("&#39;", "'")
            ]
            for (k, v) in entities { body = body.replacingOccurrences(of: k, with: v) }
            let firstLine = body.split(separator: "\n").first.map(String.init) ?? body
            let cleaned = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { return cleaned }
        }
        return raw
    }

    func reactivateCard(id: String, completion: @escaping (Bool) -> Void) {
        let body: [String: Any] = ["user_id": userId]

        applyStatusChange(id: id, newStatus: "active")

        CardExpenseCodableTask.reactivateCard(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Card reactivated: \(id)")
                    self?.objectWillChange.send()
                    completion(true)
                case .failure(let e):
                    print("❌ Reactivate card failed: \(e)")
                    completion(false)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Replace the card at `id` in both userCards and allCards with a copy whose
    /// `status` has been updated. Whole-struct replacement forces SwiftUI's
    /// ForEach to re-render each row (bypassing the id-only Equatable check).
    private func applyStatusChange(id: String, newStatus: String) {
        if let idx = userCards.firstIndex(where: { $0.id == id }) {
            var c = userCards[idx]
            c.status = newStatus
            userCards[idx] = c
        }
        if let idx = allCards.firstIndex(where: { $0.id == id }) {
            var c = allCards[idx]
            c.status = newStatus
            allCards[idx] = c
        }
        objectWillChange.send()
    }

    func deleteCardRequest(id: String, completion: @escaping (Bool) -> Void) {
        CardExpenseCodableTask.deleteCard(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Card request deleted: \(id)")
                    self?.userCards.removeAll { $0.id == id }
                    self?.allCards.removeAll { $0.id == id }
                    self?.loadUserCards()
                    completion(true)
                case .failure(let e):
                    print("❌ Delete card request failed: \(e)")
                    completion(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func updateCardRequest(id: String, proposedLimit: Double, bsControlCode: String, justification: String, bankAccountId: String, completion: @escaping (Bool) -> Void) {
        // Re-submit uses PATCH /cards/{id}. The backend keys on `card_limit`
        // for the actual limit field (not `monthly_limit` / `proposed_limit`,
        // which map to other fields). Include all three for safety.
        var body: [String: Any] = [
            "card_limit":     proposedLimit,
            "monthly_limit":  proposedLimit,
            "proposed_limit": proposedLimit,
            "user_id":        userId
        ]
        body["bs_control_code"] = bsControlCode
        body["justification"]   = justification
        if !bankAccountId.isEmpty  { body["bank_account_id"] = bankAccountId }

        // Optimistic local update FIRST so UI shows new values immediately.
        // Build a new struct instance and replace the element wholesale — this
        // ensures the @Published array emits cleanly and any view observing
        // userCards/allCards (including CardDetailPage.liveCard via onReceive)
        // re-renders with the new values.
        func mutated(_ c: ExpenseCard) -> ExpenseCard {
            var m = c
            m.monthlyLimit   = proposedLimit
            m.proposedLimit  = proposedLimit
            m.bsControlCode  = bsControlCode
            m.justification  = justification
            m.status         = "requested"
            m.approvals      = []
            m.approvedBy     = nil
            m.approvedAt     = nil
            return m
        }
        if let idx = userCards.firstIndex(where: { $0.id == id }) {
            userCards[idx] = mutated(userCards[idx])
        }
        if let idx = allCards.firstIndex(where: { $0.id == id }) {
            allCards[idx] = mutated(allCards[idx])
        }
        // Explicit publisher nudge in case SwiftUI's diffing relies on Equatable
        // (which on ExpenseCard only compares id).
        objectWillChange.send()

        CardExpenseCodableTask.updateCard(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Card resubmitted: \(id)")
                    // Re-fetch the specific card so local state matches the
                    // authoritative server truth (server-side fields like
                    // updated_at, cleared approvals, etc. come through).
                    self?.loadCard(id) { fresh in
                        guard let self = self else { return }
                        if let idx = self.userCards.firstIndex(where: { $0.id == id }) {
                            self.userCards[idx] = fresh
                        }
                        if let idx = self.allCards.firstIndex(where: { $0.id == id }) {
                            self.allCards[idx] = fresh
                        }
                        self.objectWillChange.send()
                    }
                    completion(true)
                case .failure(let e):
                    print("❌ Resubmit card failed: \(e)")
                    completion(false)
                }
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
        // Also load approval queue so the "Approval Queue" tab visibility can be determined.
        // isCardApprover flips to true when allCards is non-empty, which enables the tab.
        loadAllRequestedCards()
    }
}
