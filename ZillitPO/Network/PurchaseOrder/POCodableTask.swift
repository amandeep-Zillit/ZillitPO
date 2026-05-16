//
//  POCodableTask.swift
//  ZillitPO
//
//  Typed task wrappers for every PORequest endpoint. Mirrors live's
//  `Controller/AccountHub/Network/PurchaseOrder/POCodableTask.swift`.
//

import Foundation

enum POCodableTask {
    // MARK: - Vendors
    case fetchVendors((Result<ZLGenericResponse<[Vendor]>?, Error>) -> Void)
    case fetchVendorById(String, (Result<ZLGenericResponse<Vendor>?, Error>) -> Void)
    case createVendor([String: Any], (Result<Data?, Error>) -> Void)
    case updateVendor(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deleteVendor(String, (Result<Data?, Error>) -> Void)
    case verifyVendor(String, (Result<Data?, Error>) -> Void)
    case fetchVendorHistory(String, (Result<ZLGenericResponse<[InvoiceHistoryEntry]>?, Error>) -> Void)

    // MARK: - Purchase Orders
    case fetchPurchaseOrders(String, (Result<ZLGenericResponse<[PurchaseOrderRaw]>?, Error>) -> Void)
    case fetchPO(String, (Result<ZLGenericResponse<PurchaseOrderRaw>?, Error>) -> Void)
    case fetchDrafts((Result<ZLGenericResponse<[PurchaseOrderRaw]>?, Error>) -> Void)
    case createPO([String: Any], (Result<Data?, Error>) -> Void)
    case updatePO(String, [String: Any], (Result<Data?, Error>) -> Void)
    case createPOData(Data, (Result<Data?, Error>) -> Void)
    case updatePOData(String, Data, (Result<Data?, Error>) -> Void)
    case deletePO(String, (Result<Data?, Error>) -> Void)
    case approvePO(String, [String: Any], (Result<Data?, Error>) -> Void)
    case rejectPO(String, [String: Any], (Result<Data?, Error>) -> Void)
    case generatePDF(String, [String: Any], (Result<ZLGenericResponse<POPdfViewer>?, Error>) -> Void)
    case fetchPOHistory(String, (Result<ZLGenericResponse<[InvoiceHistoryEntry]>?, Error>) -> Void)
    case fetchApprovalQueue((Result<ZLGenericResponse<[PurchaseOrderRaw]>?, Error>) -> Void)
    case fetchMyPOs((Result<ZLGenericResponse<[PurchaseOrderRaw]>?, Error>) -> Void)
    case bulkUpdatePOs([String: Any], (Result<Data?, Error>) -> Void)
    case postPO(String, [String: Any], (Result<Data?, Error>) -> Void)
    case closePO(String, [String: Any], (Result<Data?, Error>) -> Void)

    // MARK: - Templates
    case fetchTemplates((Result<ZLGenericResponse<[POTemplate]>?, Error>) -> Void)
    case createTemplate([String: Any], (Result<Data?, Error>) -> Void)
    case updateTemplate(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deleteTemplate(String, (Result<Data?, Error>) -> Void)

    // MARK: - Form Template
    case fetchFormTemplate((Result<ZLGenericResponse<FormTemplateResponse>?, Error>) -> Void)
    case fetchFloatFormTemplate((Result<ZLGenericResponse<FormTemplateResponse>?, Error>) -> Void)
}

extension POCodableTask: FCCodableDataTask {
    var urlDataTask: URLSessionDataTask? {
        switch self {

        // MARK: Vendors
        case .fetchVendors(let completion):
            guard let urlRequest = PORequest.fetchVendors.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .fetchVendorById(let id, let completion):
            guard let urlRequest = PORequest.fetchVendorById(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .createVendor(let body, let completion):
            guard let urlRequest = PORequest.createVendor(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .updateVendor(let id, let body, let completion):
            guard let urlRequest = PORequest.updateVendor(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .deleteVendor(let id, let completion):
            guard let urlRequest = PORequest.deleteVendor(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .verifyVendor(let id, let completion):
            guard let urlRequest = PORequest.verifyVendor(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .fetchVendorHistory(let id, let completion):
            guard let urlRequest = PORequest.fetchVendorHistory(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        // MARK: Purchase Orders
        case .fetchPurchaseOrders(let id, let completion):
            guard let urlRequest = PORequest.fetchPurchaseOrders(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .fetchPO(let id, let completion):
            guard let urlRequest = PORequest.fetchPO(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .fetchDrafts(let completion):
            guard let urlRequest = PORequest.fetchDrafts.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .createPO(let body, let completion):
            guard let urlRequest = PORequest.createPO(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .updatePO(let id, let body, let completion):
            guard let urlRequest = PORequest.updatePO(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .createPOData(let data, let completion):
            guard let urlRequest = PORequest.createPOData(data).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .updatePOData(let id, let data, let completion):
            guard let urlRequest = PORequest.updatePOData(id, data).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .deletePO(let id, let completion):
            guard let urlRequest = PORequest.deletePO(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .approvePO(let id, let body, let completion):
            guard let urlRequest = PORequest.approvePO(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .rejectPO(let id, let body, let completion):
            guard let urlRequest = PORequest.rejectPO(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .generatePDF(let id, let body, let completion):
            guard let urlRequest = PORequest.generatePDF(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .fetchPOHistory(let id, let completion):
            guard let urlRequest = PORequest.fetchPOHistory(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .fetchApprovalQueue(let completion):
            guard let urlRequest = PORequest.fetchApprovalQueue.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .fetchMyPOs(let completion):
            guard let urlRequest = PORequest.fetchMyPOs.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .bulkUpdatePOs(let body, let completion):
            guard let urlRequest = PORequest.bulkUpdatePOs(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .postPO(let id, let body, let completion):
            guard let urlRequest = PORequest.postPO(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .closePO(let id, let body, let completion):
            guard let urlRequest = PORequest.closePO(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Templates
        case .fetchTemplates(let completion):
            guard let urlRequest = PORequest.fetchTemplates.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .createTemplate(let body, let completion):
            guard let urlRequest = PORequest.createTemplate(body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .updateTemplate(let id, let body, let completion):
            guard let urlRequest = PORequest.updateTemplate(id, body).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        case .deleteTemplate(let id, let completion):
            guard let urlRequest = PORequest.deleteTemplate(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.dataResultTask(with: urlRequest, completion: completion)

        // MARK: Form Template
        case .fetchFormTemplate(let completion):
            guard let urlRequest = PORequest.fetchFormTemplate.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)

        case .fetchFloatFormTemplate(let completion):
            guard let urlRequest = PORequest.fetchFloatFormTemplate.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: urlRequest, completion: completion)
        }
    }
}
