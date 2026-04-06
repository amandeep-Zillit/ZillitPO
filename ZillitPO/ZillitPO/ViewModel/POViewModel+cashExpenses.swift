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
        if cashMeta?.is_coordinator == true {
            loadCodingQueue()
            loadApprovalQueueFloats()
            loadApprovalQueueClaims()
            loadActiveFloats()
            loadAllClaims()
        }
    }

    func loadMyFloats() {
        CashExpenseCodableTask.fetchMyFloats { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.myFloats = (r?.data ?? []).map { $0.toFloatRequest() }; print("✅ \(self?.myFloats.count ?? 0) my floats") }
                else if case .failure(let e) = result { print("❌ My floats failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadAllFloats() {
        CashExpenseCodableTask.fetchAllFloats { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.allFloats = (r?.data ?? []).map { $0.toFloatRequest() }; print("✅ \(self?.allFloats.count ?? 0) all floats") }
                else if case .failure(let e) = result { print("❌ All floats failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadActiveFloats() {
        CashExpenseCodableTask.fetchActiveFloats { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.activeFloats = (r?.data ?? []).map { $0.toFloatRequest() }; print("✅ \(self?.activeFloats.count ?? 0) active floats") }
                else if case .failure(let e) = result { print("❌ Active floats failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadApprovalQueueFloats() {
        CashExpenseCodableTask.fetchApprovalQueue { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.approvalQueueFloats = (r?.data ?? []).map { $0.toFloatRequest() }; print("✅ \(self?.approvalQueueFloats.count ?? 0) approval queue floats") }
                else if case .failure(let e) = result { print("❌ Approval queue failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadMyClaims() {
        CashExpenseCodableTask.fetchMyClaims { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.myClaims = (r?.data ?? []).map { $0.toClaimBatch() }; print("✅ \(self?.myClaims.count ?? 0) my claims") }
                else if case .failure(let e) = result { print("❌ My claims failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadMyBatches() {
        CashExpenseCodableTask.fetchMyBatches { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.myBatches = (r?.data ?? []).map { $0.toClaimBatch() }; print("✅ \(self?.myBatches.count ?? 0) my batches") }
                else if case .failure(let e) = result { print("❌ My batches failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadAllClaims() {
        CashExpenseCodableTask.fetchAllClaims { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.allClaims = (r?.data ?? []).map { $0.toClaimBatch() }; print("✅ \(self?.allClaims.count ?? 0) all claims") }
                else if case .failure(let e) = result { print("❌ All claims failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadCodingQueue() {
        CashExpenseCodableTask.fetchCodingQueue { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.codingQueue = (r?.data ?? []).map { $0.toClaimBatch() }; print("✅ \(self?.codingQueue.count ?? 0) coding queue") }
                else if case .failure(let e) = result { print("❌ Coding queue failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadAuditQueue() {
        CashExpenseCodableTask.fetchAuditQueue { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.auditQueue = (r?.data ?? []).map { $0.toClaimBatch() }; print("✅ \(self?.auditQueue.count ?? 0) audit queue") }
                else if case .failure(let e) = result { print("❌ Audit queue failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadApprovalQueueClaims() {
        CashExpenseCodableTask.fetchApprovalQueueClaims { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.approvalQueueClaims = (r?.data ?? []).map { $0.toClaimBatch() }; print("✅ \(self?.approvalQueueClaims.count ?? 0) approval queue claims") }
                else if case .failure(let e) = result { print("❌ Approval queue claims failed: \(e)") }
            }
        }.urlDataTask?.resume()
    }

    func loadSignOffQueue() {
        CashExpenseCodableTask.fetchSignOffQueue { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self?.signOffQueue = (r?.data ?? []).map { $0.toClaimBatch() }; print("✅ \(self?.signOffQueue.count ?? 0) sign-off queue") }
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

    func loadAllCashExpenseData() {
        loadCashExpenseMetadata()
        loadMyClaims()
        loadMyBatches()
        loadMyFloats()
        if currentUser?.isAccountant == true {
            loadAllClaims()
            loadAllFloats()
            loadActiveFloats()
            loadApprovalQueueFloats()
            loadAuditQueue()
            loadApprovalQueueClaims()
            loadSignOffQueue()
        }
        // Coordinator data is loaded in loadRoleSpecificCashData() after metadata returns
    }

    var myPettyCashClaims: [ClaimBatch] { myClaims.filter { $0.isPettyCash } }
    var myOOPClaims: [ClaimBatch] { myClaims.filter { $0.isOutOfPocket } }
    var allPettyCashClaims: [ClaimBatch] { allClaims.filter { $0.isPettyCash } }
    var allOOPClaims: [ClaimBatch] { allClaims.filter { $0.isOutOfPocket } }
}
