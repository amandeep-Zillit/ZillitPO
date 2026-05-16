//
//  DealMemoViewModel+apis.swift
//  ZillitPO
//
//  Network actions for the deal-memo module. One method per
//  `dealMemoApi.*` call in `client/src/api/deal-memo/deal-memo.js`.
//

import Foundation

extension DealMemoViewModel {

    // MARK: - Metadata (gates approval-queue tab)

    func loadMetadata(completion: (() -> Void)? = nil) {
        isLoadingMetadata = true
        DealMemoCodableTask.getMetadata { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMetadata = false
                switch result {
                case .success(let response):
                    self?.metadata = response?.data
                case .failure(let error):
                    debugPrint("❌ Fetch deal-memo metadata failed: \(error)")
                }
                completion?()
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Overview

    func loadOverview() {
        isLoadingOverview = true
        overviewError = nil
        DealMemoCodableTask.getOverview { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingOverview = false
                switch result {
                case .success(let response):
                    self?.overview = response?.data
                case .failure(let error):
                    self?.overviewError = "Failed to load overview"
                    debugPrint("❌ Fetch deal-memo overview failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Deals list

    func loadDeals(query: [String: String] = [:]) {
        isLoadingDeals = true
        DealMemoCodableTask.listDeals(query) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingDeals = false
                switch result {
                case .success(let response):
                    self?.deals = response?.data ?? []
                case .failure(let error):
                    debugPrint("❌ List deal memos failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - My deal

    func loadMyDeal() {
        isLoadingMyDeal = true
        DealMemoCodableTask.getMyDeal { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMyDeal = false
                switch result {
                case .success(let response):
                    self?.myDeal = response?.data
                case .failure(let error):
                    debugPrint("❌ Fetch my deal failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Approval queue

    func loadApprovalQueue() {
        isLoadingApprovalQueue = true
        DealMemoCodableTask.listApprovalQueue { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingApprovalQueue = false
                switch result {
                case .success(let response):
                    self?.approvalQueue = response?.data
                    self?.approvalTotals = response?.totals
                case .failure(let error):
                    debugPrint("❌ Fetch approval queue failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Deal detail

    func loadDealDetail(_ id: String) {
        isLoadingDealDetail = true
        DealMemoCodableTask.getDeal(id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingDealDetail = false
                switch result {
                case .success(let response):
                    self?.currentDeal = response?.data
                case .failure(let error):
                    debugPrint("❌ Fetch deal detail failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadDealHistory(_ id: String) {
        DealMemoCodableTask.getDealHistory(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.currentDealHistory = response?.data ?? []
                case .failure(let error):
                    debugPrint("❌ Fetch deal history failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Lifecycle actions

    func submitDeal(_ id: String, onComplete: @escaping (Bool) -> Void) {
        DealMemoCodableTask.submitDeal(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadDeals()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Submit deal failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func approveDeal(_ id: String, signature: String?, comment: String?, onComplete: @escaping (Bool) -> Void) {
        var body: [String: Any] = [:]
        if let s = signature { body["signature"] = s }
        if let c = comment   { body["comment"]   = c }
        DealMemoCodableTask.approveDeal(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadApprovalQueue()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Approve deal failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func rejectDeal(_ id: String, reason: String, onComplete: @escaping (Bool) -> Void) {
        DealMemoCodableTask.rejectDeal(id, ["reason": reason]) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadApprovalQueue()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Reject deal failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func activateDeal(_ id: String, onComplete: @escaping (Bool) -> Void) {
        DealMemoCodableTask.activateDeal(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadDeals()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Activate deal failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func deleteDeal(_ id: String, onComplete: @escaping (Bool) -> Void) {
        DealMemoCodableTask.deleteDeal(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.deals.removeAll { $0._id == id }
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Delete deal failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Combined boot

    /// Equivalent of DealMemoModule's `.useEffect` — fetches metadata
    /// once on entry so the approval-queue tab can be gated correctly.
    /// The per-tab `loadOverview` / `loadDeals` / `loadMyDeal` /
    /// `loadApprovalQueue` calls fire from each page's `.onAppear`.
    func bootstrap() {
        loadMetadata()
    }
}
