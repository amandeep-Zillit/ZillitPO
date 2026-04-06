//
//  POViewModel+cardExpenses.swift
//  ZillitPO
//

import Foundation

extension POViewModel {

    // MARK: - Load Receipts

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
        CardExpenseCodableTask.fetchCards("my=true") { [weak self] result in
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
        loadUserCards()
        loadCardApprovalTiers()
        loadAllRequestedCards()
    }
}
