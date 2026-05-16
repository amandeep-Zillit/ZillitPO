//
//  InvoicesViewModel+apis.swift
//  ZillitPO
//
//  Stub for now — only the methods the new entry view triggers are
//  implemented. The full live `+apis` (invoice CRUD, history, payment
//  runs, hold/release, upload, settings, etc.) drops in unchanged on
//  copy-paste to live.
//

import Foundation

extension InvoicesViewModel {

    func loadInvoiceApprovalTiers() {
        AccountHubCodableTask.fetchApprovalTiers("invoices") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.invoiceTierConfigRows = response?.data ?? []
                case .failure(let error):
                    debugPrint("❌ Fetch invoice approval tiers failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadInvoices(tab: InvoiceTab = .all, deptID: String? = nil) {
        isLoadingInvoices = true
        InvoicesCodableTask.fetchInvoices(tab, deptID) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingInvoices = false
                switch result {
                case .success(let response):
                    let v = self?.vendors ?? []
                    let d = DepartmentsData.all
                    self?.invoices = (response?.data ?? []).map { $0.toInvoice(vendors: v, departments: d) }
                case .failure(let error):
                    debugPrint("❌ Fetch invoices failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadPaymentRuns() {
        isLoadingPaymentRuns = true
        InvoicesCodableTask.fetchPaymentRuns { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingPaymentRuns = false
                switch result {
                case .success(let response):
                    self?.paymentRuns = (response?.data ?? []).map { $0.toPaymentRun() }
                case .failure(let error):
                    debugPrint("❌ Fetch payment runs failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }
}
