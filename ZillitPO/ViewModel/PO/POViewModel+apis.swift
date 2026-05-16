//
//  POViewModel+apis.swift
//  ZillitPO
//
//  Stub for now — only the methods the new `AccountHubAccountantView`
//  entry needs are implemented. The full live `+apis` (purchase-order
//  CRUD, drafts, templates, history, queries, approvals, PDF, etc.)
//  drops in unchanged on copy-paste to live.
//

import Foundation

extension POViewModel {

    func loadApprovalTiers() {
        AccountHubCodableTask.fetchApprovalTiers("purchase_orders") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.tierConfigRows = response?.data ?? []
                case .failure(let error):
                    debugPrint("❌ Fetch PO approval tiers failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadPurchaseOrders() {
        isLoading = true
        POCodableTask.fetchPurchaseOrders("") { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let response):
                    let v = self?.vendors ?? []
                    let d = DepartmentsData.all
                    let raw = response?.data ?? []
                    self?.purchaseOrders = raw.filter { ($0.status ?? "") != "DRAFT" }
                        .map { $0.toPO(vendors: v, departments: d) }
                    self?.hydrateVendorDisplayFields()
                case .failure(let error):
                    debugPrint("❌ Fetch POs failed: \(error)")
                }
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
                    let v = self?.vendors ?? []
                    let d = DepartmentsData.all
                    self?.drafts = (response?.data ?? []).map { $0.toPO(vendors: v, departments: d) }
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
                    self?.templates = response?.data ?? []
                case .failure(let error):
                    debugPrint("❌ Fetch templates failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadFormTemplate() {
        POCodableTask.fetchFormTemplate { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.formTemplate = response?.data
                case .failure(let error):
                    debugPrint("❌ Fetch form template failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    /// One-shot loader fired from the entry view's `.onAppear`.
    func loadAllData() {
        loadPurchaseOrders()
        loadDrafts()
        loadTemplates()
        loadFormTemplate()
    }
}
