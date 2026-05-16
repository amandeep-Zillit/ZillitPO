//
//  InvoicesCodableTask.swift
//  ZillitPO
//
//  Typed task wrappers for every InvoicesRequest endpoint.
//

import Foundation

enum InvoicesCodableTask {

    // MARK: - Invoices
    case fetchInvoices(InvoiceTab, String?, (Result<ZLGenericResponse<[InvoiceRaw]>?, Error>) -> Void)
    case fetchInvoice(String, (Result<ZLGenericResponse<InvoiceRaw>?, Error>) -> Void)
    case uploadInvoice(InvoiceUploadRequest, (Result<ZLGenericResponse<InvoiceExtraction>?, Error>) -> Void)
    case createInvoice([String: Any], (Result<Data?, Error>) -> Void)
    case createInvoiceData(Data, (Result<Data?, Error>) -> Void)
    /// Live returns `DocumentModel?` directly via its generic
    /// `codableResultTask<T: Decodable>`. Demo's `APIClient.codableResultTask`
    /// wraps every response in `APIResponse<T>`, so the demo signature
    /// stays on `Data?` — the actual attachment refresh isn't needed in
    /// the demo's stub VM port.
    case updateInvoice(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deleteInvoice(String, (Result<Data?, Error>) -> Void)
    case approveInvoice(String, [String: Any], (Result<Data?, Error>) -> Void)
    case rejectInvoice(String, [String: Any], (Result<Data?, Error>) -> Void)
    case holdInvoice(String, [String: Any], (Result<Data?, Error>) -> Void)
    case releaseInvoiceHold(String, (Result<Data?, Error>) -> Void)
    case sendInvoiceToApproval(String, (Result<Data?, Error>) -> Void)
    case postInvoiceToLedger(String, (Result<Data?, Error>) -> Void)
    case fetchInvoiceHistory(String, (Result<ZLGenericResponse<[InvoiceHistoryEntry]>?, Error>) -> Void)

    // MARK: - Invoice Settings
    case getInvoiceSettings((Result<ZLGenericResponse<InvoiceSettings>?, Error>) -> Void)
    case updateInvoiceSettings([String: Any], (Result<Data?, Error>) -> Void)

    // MARK: - Payment Runs
    case fetchPaymentRuns((Result<ZLGenericResponse<[PaymentRunRaw]>?, Error>) -> Void)
    case getPaymentRun(String, (Result<ZLGenericResponse<PaymentRunDetailRaw>?, Error>) -> Void)
    case approvePaymentRun(String, [String: Any], (Result<Data?, Error>) -> Void)
    case rejectPaymentRun(String, [String: Any], (Result<Data?, Error>) -> Void)
}

extension InvoicesCodableTask: FCCodableDataTask {
    var urlDataTask: URLSessionDataTask? {
        switch self {

        // MARK: Invoices
        case .fetchInvoices(let tab, let deptID, let completion):
            guard let urlRequest = InvoicesRequest.fetchInvoices(tab, deptID).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .fetchInvoice(let id, let completion):
            guard let urlRequest = InvoicesRequest.fetchInvoice(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .uploadInvoice(let body, let completion):
            guard let urlRequest = InvoicesRequest.uploadInvoice(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .createInvoice(let body, let completion):
            guard let urlRequest = InvoicesRequest.createInvoice(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .createInvoiceData(let data, let completion):
            guard let urlRequest = InvoicesRequest.createInvoiceData(data).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .updateInvoice(let id, let body, let completion):
            guard let urlRequest = InvoicesRequest.updateInvoice(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .deleteInvoice(let id, let completion):
            guard let urlRequest = InvoicesRequest.deleteInvoice(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .approveInvoice(let id, let body, let completion):
            guard let urlRequest = InvoicesRequest.approveInvoice(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .rejectInvoice(let id, let body, let completion):
            guard let urlRequest = InvoicesRequest.rejectInvoice(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .holdInvoice(let id, let body, let completion):
            guard let urlRequest = InvoicesRequest.holdInvoice(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .releaseInvoiceHold(let id, let completion):
            guard let urlRequest = InvoicesRequest.releaseInvoiceHold(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .sendInvoiceToApproval(let id, let completion):
            guard let urlRequest = InvoicesRequest.sendInvoiceToApproval(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .postInvoiceToLedger(let id, let completion):
            guard let urlRequest = InvoicesRequest.postInvoiceToLedger(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .fetchInvoiceHistory(let id, let completion):
            guard let urlRequest = InvoicesRequest.fetchInvoiceHistory(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Invoice Settings
        case .getInvoiceSettings(let completion):
            guard let urlRequest = InvoicesRequest.getInvoiceSettings.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .updateInvoiceSettings(let body, let completion):
            guard let urlRequest = InvoicesRequest.updateInvoiceSettings(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Payment Runs
        case .fetchPaymentRuns(let completion):
            guard let urlRequest = InvoicesRequest.fetchPaymentRuns.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .getPaymentRun(let id, let completion):
            guard let urlRequest = InvoicesRequest.getPaymentRun(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .approvePaymentRun(let id, let body, let completion):
            guard let urlRequest = InvoicesRequest.approvePaymentRun(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .rejectPaymentRun(let id, let body, let completion):
            guard let urlRequest = InvoicesRequest.rejectPaymentRun(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)
        }
    }
}
