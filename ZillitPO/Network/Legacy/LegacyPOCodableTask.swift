//
//  LegacyPOCodableTask.swift
//  ZillitPO
//

import Foundation

enum LegacyPOCodableTask {
    // MARK: - Vendors (typed responses)
    case fetchVendors((Result<APIResponse<[Vendor]>?, Error>) -> Void)
    case createVendor([String: Any], (Result<Data?, Error>) -> Void)
    case deleteVendor(String, (Result<Data?, Error>) -> Void)

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

extension LegacyPOCodableTask: PODataTaskProtocol {
    var urlDataTask: URLSessionDataTask? {
        switch self {

        // MARK: Vendors
        case .fetchVendors(let completion):
            guard let urlRequest = LegacyPORequest.fetchVendors.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .createVendor(let body, let completion):
            guard let urlRequest = LegacyPORequest.createVendor(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .deleteVendor(let id, let completion):
            guard let urlRequest = LegacyPORequest.deleteVendor(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Approval Tiers
        case .fetchApprovalTiers(let completion):
            guard let urlRequest = LegacyPORequest.fetchApprovalTiers.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Purchase Orders
        case .fetchPurchaseOrders(let path, let completion):
            guard let urlRequest = LegacyPORequest.fetchPurchaseOrders(path).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .fetchDrafts(let completion):
            guard let urlRequest = LegacyPORequest.fetchDrafts.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .createPO(let body, let completion):
            guard let urlRequest = LegacyPORequest.createPO(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .updatePO(let id, let body, let completion):
            guard let urlRequest = LegacyPORequest.updatePO(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .deletePO(let id, let completion):
            guard let urlRequest = LegacyPORequest.deletePO(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .approvePO(let id, let body, let completion):
            guard let urlRequest = LegacyPORequest.approvePO(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .rejectPO(let id, let body, let completion):
            guard let urlRequest = LegacyPORequest.rejectPO(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .generatePDF(let id, let body, let completion):
            guard let urlRequest = LegacyPORequest.generatePDF(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .fetchPOHistory(let id, let completion):
            guard let urlRequest = LegacyPORequest.fetchPOHistory(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .fetchPOQueries(let id, let completion):
            guard let urlRequest = LegacyPORequest.fetchPOQueries(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Templates
        case .fetchTemplates(let completion):
            guard let urlRequest = LegacyPORequest.fetchTemplates.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .createTemplate(let body, let completion):
            guard let urlRequest = LegacyPORequest.createTemplate(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .updateTemplate(let id, let body, let completion):
            guard let urlRequest = LegacyPORequest.updateTemplate(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .deleteTemplate(let id, let completion):
            guard let urlRequest = LegacyPORequest.deleteTemplate(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Form Template
        case .fetchFormTemplate(let completion):
            guard let urlRequest = LegacyPORequest.fetchFormTemplate.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .fetchFloatFormTemplate(let completion):
            guard let urlRequest = LegacyPORequest.fetchFloatFormTemplate.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Invoices
        case .fetchInvoices(let path, let completion):
            guard let urlRequest = LegacyPORequest.fetchInvoices(path).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .createInvoice(let body, let completion):
            guard let urlRequest = LegacyPORequest.createInvoice(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .updateInvoice(let id, let body, let completion):
            guard let urlRequest = LegacyPORequest.updateInvoice(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .deleteInvoice(let id, let completion):
            guard let urlRequest = LegacyPORequest.deleteInvoice(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .approveInvoice(let id, let body, let completion):
            guard let urlRequest = LegacyPORequest.approveInvoice(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .rejectInvoice(let id, let body, let completion):
            guard let urlRequest = LegacyPORequest.rejectInvoice(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .fetchInvoiceHistory(let id, let completion):
            guard let urlRequest = LegacyPORequest.fetchInvoiceHistory(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .fetchInvoiceQueries(let id, let completion):
            guard let urlRequest = LegacyPORequest.fetchInvoiceQueries(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Invoice Approval Tiers
        case .fetchInvoiceApprovalTiers(let completion):
            guard let urlRequest = LegacyPORequest.fetchInvoiceApprovalTiers.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Invoice Settings
        case .getInvoiceSettings(let completion):
            guard let urlRequest = LegacyPORequest.getInvoiceSettings.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .updateInvoiceSettings(let body, let completion):
            guard let urlRequest = LegacyPORequest.updateInvoiceSettings(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Payment Runs
        case .fetchPaymentRuns(let completion):
            guard let urlRequest = LegacyPORequest.fetchPaymentRuns.urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .getPaymentRun(let id, let completion):
            guard let urlRequest = LegacyPORequest.getPaymentRun(id).urlRequest else { return nil }
            return APIClient.shared.codableResultTask(with: urlRequest, completion: completion)

        case .approvePaymentRun(let id, let body, let completion):
            guard let urlRequest = LegacyPORequest.approvePaymentRun(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)

        case .rejectPaymentRun(let id, let body, let completion):
            guard let urlRequest = LegacyPORequest.rejectPaymentRun(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: urlRequest, completion: completion)
        }
    }
}
