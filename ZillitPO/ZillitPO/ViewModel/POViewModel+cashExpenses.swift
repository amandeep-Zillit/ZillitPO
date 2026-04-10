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
