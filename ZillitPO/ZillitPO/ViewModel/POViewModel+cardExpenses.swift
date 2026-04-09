//
//  POViewModel+cardExpenses.swift
//  ZillitPO
//

import Foundation

extension POViewModel {

    // MARK: - Load Receipts

    func loadAllCardReceipts() {
        CardExpenseCodableTask.fetchTransactions("all") { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result {
                    self?.cardReceipts = (r?.data ?? []).map { $0.toCardTransaction() }
                    print("✅ Loaded \(self?.cardReceipts.count ?? 0) card receipts (all)")
                } else if case .failure(let e) = result { print("❌ All card receipts failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadMyCardReceipts() {
        CardExpenseCodableTask.fetchTransactions("my") { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result {
                    self?.myCardReceipts = (r?.data ?? []).map { $0.toCardTransaction() }
                    print("✅ Loaded \(self?.myCardReceipts.count ?? 0) my card receipts")
                } else if case .failure(let e) = result { print("❌ My card receipts failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadCardTransactions() {
        CardExpenseCodableTask.fetchTransactions("") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.cardTransactions = (response?.data ?? []).map { $0.toCardTransaction() }
                    print("✅ Loaded \(self?.cardTransactions.count ?? 0) card transactions")
                case .failure(let error):
                    print("❌ Fetch card transactions failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadTopUpQueue() {
        CardExpenseCodableTask.fetchTopUps { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result {
                    // Web shows only card top-ups, not cash-float entries
                    let all = (r?.data ?? []).map { $0.toTopUpItem() }
                    self?.topUpQueue = all.filter { $0.entityType.lowercased() == "card" }
                    print("✅ Loaded \(self?.topUpQueue.count ?? 0) top-up items (filtered card only from \(all.count))")
                } else if case .failure(let e) = result { print("❌ Top-ups failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadSmartAlerts() {
        CardExpenseCodableTask.fetchSmartAlerts { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result {
                    self?.smartAlerts = (r?.data ?? []).map { $0.toSmartAlert() }
                    print("✅ Loaded \(self?.smartAlerts.count ?? 0) smart alerts")
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

    func loadCardHistory() {
        CardExpenseCodableTask.fetchCardHistory { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result {
                    self?.cardHistory = (r?.data ?? []).map { $0.toCardTransaction() }
                    print("✅ Loaded \(self?.cardHistory.count ?? 0) card history items")
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
        CardExpenseCodableTask.fetchMyReceipts("") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.receipts = (response?.data ?? []).map { $0.toReceipt() }
                    print("✅ Loaded \(self?.receipts.count ?? 0) my receipts")
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

    func loadUserCards() {
        let params = currentUser?.isAccountant == true ? "" : "my=true"
        CardExpenseCodableTask.fetchCards(params) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.userCards = (response?.data ?? []).map { $0.toCard() }
                    print("✅ Loaded \(self?.userCards.count ?? 0) user cards")
                case .failure(let error):
                    print("❌ Fetch user cards failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadAllRequestedCards() {
        // Server filters to cards where current user is an approver
        CardExpenseCodableTask.fetchCards("status=pending&for_approval=true") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.allCards = (response?.data ?? []).map { $0.toCard() }
                    print("✅ Loaded \(self?.allCards.count ?? 0) cards for approval")
                    self?.updateCardApproverStatus()
                case .failure(let error):
                    print("❌ Fetch cards for approval failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadCardApprovalTiers() {
        CardExpenseCodableTask.fetchCardApprovalTiers { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.cardTierConfigRows = response?.data ?? []
                    print("✅ Loaded \(self?.cardTierConfigRows.count ?? 0) card tier configs")
                    self?.updateCardApproverStatus()
                case .failure(let error):
                    print("❌ Fetch card tiers failed: \(error)")
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

    func requestNewCard(proposedLimit: Double) {
        guard let u = currentUser else { return }
        let body: [String: Any] = [
            "card_holder_name": u.fullName,
            "holder_id": u.id,
            "department_name": u.displayDepartment,
            "proposed_limit": proposedLimit
        ]
        CardExpenseCodableTask.createCard(body) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result { print("✅ Card requested"); self?.loadUserCards() }
                else if case .failure(let e) = result { print("❌ Request card failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Load All Card Expense Data

    func loadAllCardExpenseData() {
        loadCardExpenseReceipts()
        loadCardTransactions()
        loadMyCardReceipts()
        loadUserCards()
        loadCardApprovalTiers()
        loadAllRequestedCards()
        if currentUser?.isAccountant == true {
            loadAllCardReceipts()
            loadTopUpQueue()
            loadSmartAlerts()
            loadCardHistory()
        }
    }
}
