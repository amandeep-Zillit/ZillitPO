//
//  POViewModel+cashExpenses.swift
//  ZillitPO
//

import Foundation

extension POViewModel {

    func loadCashExpenseMetadata() {
        CashExpenseCodableTask.fetchMetadata { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result {
                    self?.cashMeta = r?.data
                    print("✅ Cash metadata: approver=\(self?.cashMeta?.is_approver ?? false) coord=\(self?.cashMeta?.is_coordinator ?? false)")
                    // Load role-specific data after metadata is available
                    self?.loadRoleSpecificCashData()
                } else if case .failure(let e) = result { print("❌ Cash metadata failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    private func loadRoleSpecificCashData() {
        // Each tile/page now fetches its own data on appear; nothing to load here.
    }

    /// Fetches the combined float + batch history timeline via
    /// GET /api/v2/cash-expenses/float-requests/{id}/history.
    func loadFloatHistory(_ id: String, completion: @escaping ([FloatHistoryEntry]) -> Void) {
        CashExpenseCodableTask.fetchFloatHistory(id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let r):
                    let entries = r?.data ?? []
                    print("✅ Float history loaded: \(id) — \(entries.count) entries")
                    completion(entries)
                case .failure(let e):
                    print("❌ Float history failed: \(e)")
                    completion([])
                }
            }
        }.urlDataTask?.resume()
    }

    /// Fetch full float details (float row + posted batches + top-ups + returns + totals).
    /// Matches backend endpoint GET /float-requests/{id}/details.
    func loadFloatDetails(_ id: String, completion: @escaping (FloatDetailsResponse?) -> Void) {
        CashExpenseCodableTask.fetchFloatDetails(id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let r):
                    if let d = r?.data {
                        print("✅ Float details loaded: \(id) — \(d.batches.count) batches, \(d.topups.count) topups, \(d.returns.count) returns")
                        completion(d)
                    } else {
                        print("⚠️ Float details empty for: \(id)")
                        completion(nil)
                    }
                case .failure(let e):
                    print("❌ Float details failed: \(e)")
                    completion(nil)
                }
            }
        }.urlDataTask?.resume()
    }

    func approveFloatRequest(id: String, tierNumber: Int, totalTiers: Int, completion: @escaping (Bool) -> Void) {
        let body: [String: Any] = ["tier_number": tierNumber, "total_tiers": totalTiers, "user_id": userId]
        CashExpenseCodableTask.approveFloat(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Float approved: \(id) (tier \(tierNumber)/\(totalTiers))")
                    self?.loadApprovalQueueFloats()
                    completion(true)
                case .failure(let e):
                    print("❌ Approve float failed: \(e)")
                    completion(false)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Accountant override — single-click approval that bypasses the tier
    /// chain. Sends `override: true` alongside the standard approve payload
    /// so the backend stores `ACCT_OVERRIDE` on the float.
    func overrideFloatRequest(id: String, completion: @escaping (Bool) -> Void) {
        let body: [String: Any] = [
            "override": true,
            "user_id": userId
        ]
        CashExpenseCodableTask.approveFloat(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Float overridden: \(id)")
                    self?.loadApprovalQueueFloats()
                    completion(true)
                case .failure(let e):
                    print("❌ Override float failed: \(e)")
                    completion(false)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Records a manual cash return against a float — posts to
    /// /float-requests/{id}/record-return with the web's payload:
    ///   `{ return_amount, received_date (ms), return_reason, reason_notes, notes }`
    /// Triggers a reload of active floats on success so the UI updates.
    func recordFloatReturn(id: String,
                           amount: Double,
                           dateMs: Int64,
                           reason: String,
                           notes: String,
                           completion: @escaping (Bool, String?) -> Void) {
        let trimmed = notes.trimmingCharacters(in: .whitespaces)
        var body: [String: Any] = [
            "return_amount": amount,
            "received_date": dateMs,
            "return_reason": reason
        ]
        // Web sends BOTH `reason_notes` and `notes` with the same value
        if !trimmed.isEmpty {
            body["reason_notes"] = trimmed
            body["notes"] = trimmed
        } else {
            body["reason_notes"] = NSNull()
            body["notes"] = NSNull()
        }
        CashExpenseCodableTask.recordFloatReturn(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Cash return recorded for float \(id): £\(amount) — \(reason)")
                    self?.loadActiveFloats()
                    completion(true, nil)
                case .failure(let e):
                    let raw = e.localizedDescription
                    // Server error bodies are HTML; pull the pg message out
                    // of the `<pre>…</pre>` block so the UI doesn't show the
                    // entire page source as the error.
                    let cleaned = Self.cleanServerErrorBody(raw)
                    print("❌ Record cash return failed: \(cleaned)")
                    completion(false, cleaned)
                }
            }
        }.urlDataTask?.resume()
    }

    /// Extract the meaningful error message from a server error body.
    /// Express/Koa default error pages wrap the Postgres error in a
    /// `<pre>…</pre>` block; we strip everything else and decode HTML
    /// entities so the user sees the actual DB message.
    private static func cleanServerErrorBody(_ raw: String) -> String {
        // Find <pre>…</pre>
        var body = raw
        if let preStart = body.range(of: "<pre>"),
           let preEnd = body.range(of: "</pre>", range: preStart.upperBound..<body.endIndex) {
            body = String(body[preStart.upperBound..<preEnd.lowerBound])
        }
        // Drop <br> tags + take first meaningful line (pg messages are long
        // and end with a stack trace we don't want to surface).
        body = body.replacingOccurrences(of: "<br>", with: "\n")
        // Decode a handful of common HTML entities that `&quot;` etc would
        // otherwise leak through.
        let entities: [(String, String)] = [
            ("&quot;", "\""), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&nbsp;", " "), ("&#39;", "'")
        ]
        for (k, v) in entities { body = body.replacingOccurrences(of: k, with: v) }
        // Only the first line (the DB error); subsequent lines are stack.
        let firstLine = body.split(separator: "\n").first.map(String.init) ?? body
        return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func rejectFloatRequest(id: String, reason: String, completion: @escaping (Bool) -> Void) {
        let body: [String: Any] = ["reason": reason, "user_id": userId]
        CashExpenseCodableTask.rejectFloat(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Float rejected: \(id)")
                    self?.loadApprovalQueueFloats()
                    completion(true)
                case .failure(let e):
                    print("❌ Reject float failed: \(e)")
                    completion(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func loadMyFloats() {
        isLoadingMyFloats = true
        CashExpenseCodableTask.fetchMyFloats { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMyFloats = false
                if case .success(let r) = result { self?.myFloats = (r?.data ?? []).map { $0.toFloatRequest() } }
                else if case .failure(let e) = result { print("❌ My floats failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadAllFloats() {
        isLoadingAllFloats = true
        CashExpenseCodableTask.fetchAllFloats { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingAllFloats = false
                if case .success(let r) = result { self?.allFloats = (r?.data ?? []).map { $0.toFloatRequest() } }
                else if case .failure(let e) = result { print("❌ All floats failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadActiveFloats() {
        isLoadingActiveFloats = true
        CashExpenseCodableTask.fetchActiveFloats { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingActiveFloats = false
                if case .success(let r) = result { self?.activeFloats = (r?.data ?? []).map { $0.toFloatRequest() } }
                else if case .failure(let e) = result { print("❌ Active floats failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadApprovalQueueFloats() {
        isLoadingApprovalFloats = true
        CashExpenseCodableTask.fetchApprovalQueue { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingApprovalFloats = false
                if case .success(let r) = result { self?.approvalQueueFloats = (r?.data ?? []).map { $0.toFloatRequest() } }
                else if case .failure(let e) = result { print("❌ Approval queue failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadMyClaims() {
        isLoadingMyClaims = true
        CashExpenseCodableTask.fetchMyClaims { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMyClaims = false
                if case .success(let r) = result { self?.myClaims = (r?.data ?? []).map { $0.toClaimBatch() } }
                else if case .failure(let e) = result { print("❌ My claims failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadMyBatches() {
        isLoadingMyBatches = true
        CashExpenseCodableTask.fetchMyBatches { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMyBatches = false
                if case .success(let r) = result { self?.myBatches = (r?.data ?? []).map { $0.toClaimBatch() } }
                else if case .failure(let e) = result { print("❌ My batches failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadAllClaims() {
        isLoadingAllClaims = true
        CashExpenseCodableTask.fetchAllClaims { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingAllClaims = false
                if case .success(let r) = result { self?.allClaims = (r?.data ?? []).map { $0.toClaimBatch() } }
                else if case .failure(let e) = result { print("❌ All claims failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadCodingQueue() {
        isLoadingCodingQueue = true
        CashExpenseCodableTask.fetchCodingQueue { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingCodingQueue = false
                if case .success(let r) = result { self?.codingQueue = (r?.data ?? []).map { $0.toClaimBatch() } }
                else if case .failure(let e) = result { print("❌ Coding queue failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadAuditQueue() {
        isLoadingAuditQueue = true
        CashExpenseCodableTask.fetchAuditQueue { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingAuditQueue = false
                if case .success(let r) = result { self?.auditQueue = (r?.data ?? []).map { $0.toClaimBatch() } }
                else if case .failure(let e) = result { print("❌ Audit queue failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadApprovalQueueClaims() {
        isLoadingApprovalClaims = true
        CashExpenseCodableTask.fetchApprovalQueueClaims { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingApprovalClaims = false
                if case .success(let r) = result { self?.approvalQueueClaims = (r?.data ?? []).map { $0.toClaimBatch() } }
                else if case .failure(let e) = result { print("❌ Approval queue claims failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadSignOffQueue() {
        isLoadingSignOffQueue = true
        CashExpenseCodableTask.fetchSignOffQueue { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingSignOffQueue = false
                if case .success(let r) = result { self?.signOffQueue = (r?.data ?? []).map { $0.toClaimBatch() } }
                else if case .failure(let e) = result { print("❌ Sign-off queue failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func submitFloatRequest(_ body: [String: Any], completion: @escaping (Bool, String?) -> Void) {
        CashExpenseCodableTask.createFloatRequest(body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Float request submitted")
                    self?.loadMyFloats()
                    self?.loadActiveFloats()
                    completion(true, nil)
                case .failure(let e):
                    print("❌ Float request failed: \(e)")
                    completion(false, e.localizedDescription)
                }
            }
        }.urlDataTask?.resume()
    }

    func loadPaymentRouting() {
        CashExpenseCodableTask.fetchPaymentRouting { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result, let data = r?.data {
                    self?.paymentRouting = data
                    print("✅ Payment routing: \(data.bacsBatches.count) BACS, \(data.payrollBatches.count) payroll")
                } else if case .failure(let e) = result {
                    print("❌ Payment routing failed: \(e)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadAllCashExpenseData() {
        // Lightweight hub loader — only metadata. Each tile/page loads its own data on appear.
        loadCashExpenseMetadata()
    }

    var myPettyCashClaims: [ClaimBatch] { myClaims.filter { $0.isPettyCash } }
    var myOOPClaims: [ClaimBatch] { myClaims.filter { $0.isOutOfPocket } }
    var allPettyCashClaims: [ClaimBatch] { allClaims.filter { $0.isPettyCash } }
    var allOOPClaims: [ClaimBatch] { allClaims.filter { $0.isOutOfPocket } }
}
