//
//  POCodableTask.swift
//  ZillitPO
//

import Foundation

enum POCodableTask {
    // MARK: - Vendors (typed responses)
    case fetchVendors((Result<APIResponse<[Vendor]>?, Error>) -> Void)
    case createVendor([String: Any], (Result<Data?, Error>) -> Void)
    case updateVendor(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deleteVendor(String, (Result<Data?, Error>) -> Void)
    case fetchVendorHistory(String, (Result<APIResponse<[InvoiceHistoryEntry]>?, Error>) -> Void)

    // MARK: - Approval Tiers (typed response)
    case fetchApprovalTiers((Result<APIResponse<[ApprovalTierConfig]>?, Error>) -> Void)

    // MARK: - Purchase Orders (typed responses)
    case fetchPurchaseOrders(String, (Result<APIResponse<[PurchaseOrderRaw]>?, Error>) -> Void)
    case fetchDrafts((Result<APIResponse<[PurchaseOrderRaw]>?, Error>) -> Void)
    case createPO([String: Any], (Result<Data?, Error>) -> Void)
    case updatePO(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deletePO(String, (Result<Data?, Error>) -> Void)
    case approvePO(String, [String: Any], (Result<Data?, Error>) -> Void)
    case rejectPO(String, [String: Any], (Result<Data?, Error>) -> Void)
    case generatePDF(String, [String: Any], (Result<Data?, Error>) -> Void)
    case fetchPOHistory(String, (Result<APIResponse<[InvoiceHistoryEntry]>?, Error>) -> Void)
    case fetchPOQueries(String, (Result<APIResponse<InvoiceQueryThread>?, Error>) -> Void)
    // New (Apr 2026):
    case fetchApprovalQueue((Result<APIResponse<[PurchaseOrderRaw]>?, Error>) -> Void)
    case fetchMyPOs((Result<APIResponse<[PurchaseOrderRaw]>?, Error>) -> Void)
    case bulkUpdatePOs([String: Any], (Result<Data?, Error>) -> Void)
    case postPO(String, [String: Any], (Result<Data?, Error>) -> Void)
    case closePO(String, [String: Any], (Result<Data?, Error>) -> Void)

    // MARK: - Templates (typed responses)
    case fetchTemplates((Result<APIResponse<[POTemplate]>?, Error>) -> Void)
    case createTemplate([String: Any], (Result<Data?, Error>) -> Void)
    case updateTemplate(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deleteTemplate(String, (Result<Data?, Error>) -> Void)

    // MARK: - Form Template (typed response)
    case fetchFormTemplate((Result<APIResponse<FormTemplateResponse>?, Error>) -> Void)
    case fetchFloatFormTemplate((Result<APIResponse<FormTemplateResponse>?, Error>) -> Void)

    // MARK: - Invoices (typed responses)
    case fetchInvoices(String, (Result<APIResponse<[InvoiceRaw]>?, Error>) -> Void)
    case createInvoice([String: Any], (Result<Data?, Error>) -> Void)
    case updateInvoice(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deleteInvoice(String, (Result<Data?, Error>) -> Void)
    case approveInvoice(String, [String: Any], (Result<Data?, Error>) -> Void)
    case rejectInvoice(String, [String: Any], (Result<Data?, Error>) -> Void)
    case fetchInvoiceHistory(String, (Result<APIResponse<[InvoiceHistoryEntry]>?, Error>) -> Void)
    case fetchInvoiceQueries(String, (Result<APIResponse<InvoiceQueryThread>?, Error>) -> Void)

    // MARK: - Invoice Approval Tiers (typed response)
    case fetchInvoiceApprovalTiers((Result<APIResponse<[ApprovalTierConfig]>?, Error>) -> Void)

    // MARK: - Invoice Settings
    case getInvoiceSettings((Result<APIResponse<InvoiceSettingsRaw>?, Error>) -> Void)
    case updateInvoiceSettings([String: Any], (Result<Data?, Error>) -> Void)

    // MARK: - Payment Runs (typed responses)
    case fetchPaymentRuns((Result<APIResponse<[PaymentRunRaw]>?, Error>) -> Void)
    case getPaymentRun(String, (Result<APIResponse<PaymentRunDetailRaw>?, Error>) -> Void)
    case approvePaymentRun(String, [String: Any], (Result<Data?, Error>) -> Void)
    case rejectPaymentRun(String, [String: Any], (Result<Data?, Error>) -> Void)

}

extension POCodableTask: PODataTaskProtocol {
    var urlDataTask: URLSessionDataTask? {
        switch self {

        // MARK: Vendors
        case .fetchVendors(let completion):
            guard let urlRequest = PORequest.fetchVendors.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .createVendor(let body, let completion):
            guard let urlRequest = PORequest.createVendor(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .updateVendor(let id, let body, let completion):
            guard let urlRequest = PORequest.updateVendor(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .deleteVendor(let id, let completion):
            guard let urlRequest = PORequest.deleteVendor(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .fetchVendorHistory(let id, let completion):
            guard let urlRequest = PORequest.fetchVendorHistory(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Approval Tiers
        case .fetchApprovalTiers(let completion):
            guard let urlRequest = PORequest.fetchApprovalTiers.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Purchase Orders
        case .fetchPurchaseOrders(let path, let completion):
            guard let urlRequest = PORequest.fetchPurchaseOrders(path).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .fetchDrafts(let completion):
            guard let urlRequest = PORequest.fetchDrafts.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .createPO(let body, let completion):
            guard let urlRequest = PORequest.createPO(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .updatePO(let id, let body, let completion):
            guard let urlRequest = PORequest.updatePO(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .deletePO(let id, let completion):
            guard let urlRequest = PORequest.deletePO(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .approvePO(let id, let body, let completion):
            guard let urlRequest = PORequest.approvePO(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .rejectPO(let id, let body, let completion):
            guard let urlRequest = PORequest.rejectPO(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .generatePDF(let id, let body, let completion):
            guard let urlRequest = PORequest.generatePDF(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .fetchPOHistory(let id, let completion):
            guard let urlRequest = PORequest.fetchPOHistory(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .fetchPOQueries(let id, let completion):
            guard let urlRequest = PORequest.fetchPOQueries(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .fetchApprovalQueue(let completion):
            guard let urlRequest = PORequest.fetchApprovalQueue.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .fetchMyPOs(let completion):
            guard let urlRequest = PORequest.fetchMyPOs.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .bulkUpdatePOs(let body, let completion):
            guard let urlRequest = PORequest.bulkUpdatePOs(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .postPO(let id, let body, let completion):
            guard let urlRequest = PORequest.postPO(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .closePO(let id, let body, let completion):
            guard let urlRequest = PORequest.closePO(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Templates
        case .fetchTemplates(let completion):
            guard let urlRequest = PORequest.fetchTemplates.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .createTemplate(let body, let completion):
            guard let urlRequest = PORequest.createTemplate(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .updateTemplate(let id, let body, let completion):
            guard let urlRequest = PORequest.updateTemplate(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .deleteTemplate(let id, let completion):
            guard let urlRequest = PORequest.deleteTemplate(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Form Template
        case .fetchFormTemplate(let completion):
            guard let urlRequest = PORequest.fetchFormTemplate.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .fetchFloatFormTemplate(let completion):
            guard let urlRequest = PORequest.fetchFloatFormTemplate.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Invoices
        case .fetchInvoices(let path, let completion):
            guard let urlRequest = PORequest.fetchInvoices(path).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .createInvoice(let body, let completion):
            guard let urlRequest = PORequest.createInvoice(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .updateInvoice(let id, let body, let completion):
            guard let urlRequest = PORequest.updateInvoice(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .deleteInvoice(let id, let completion):
            guard let urlRequest = PORequest.deleteInvoice(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .approveInvoice(let id, let body, let completion):
            guard let urlRequest = PORequest.approveInvoice(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .rejectInvoice(let id, let body, let completion):
            guard let urlRequest = PORequest.rejectInvoice(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .fetchInvoiceHistory(let id, let completion):
            guard let urlRequest = PORequest.fetchInvoiceHistory(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .fetchInvoiceQueries(let id, let completion):
            guard let urlRequest = PORequest.fetchInvoiceQueries(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Invoice Approval Tiers
        case .fetchInvoiceApprovalTiers(let completion):
            guard let urlRequest = PORequest.fetchInvoiceApprovalTiers.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Invoice Settings
        case .getInvoiceSettings(let completion):
            guard let urlRequest = PORequest.getInvoiceSettings.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .updateInvoiceSettings(let body, let completion):
            guard let urlRequest = PORequest.updateInvoiceSettings(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Payment Runs
        case .fetchPaymentRuns(let completion):
            guard let urlRequest = PORequest.fetchPaymentRuns.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .getPaymentRun(let id, let completion):
            guard let urlRequest = PORequest.getPaymentRun(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .approvePaymentRun(let id, let body, let completion):
            guard let urlRequest = PORequest.approvePaymentRun(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .rejectPaymentRun(let id, let body, let completion):
            guard let urlRequest = PORequest.rejectPaymentRun(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)
        }
    }
}
