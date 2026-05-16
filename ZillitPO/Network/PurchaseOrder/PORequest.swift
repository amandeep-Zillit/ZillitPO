//
//  PORequest.swift
//  ZillitPO
//
//  PO microservice endpoints — POs, vendors (dict-body), templates, form
//  template. Mirrors live's `Controller/AccountHub/Network/PurchaseOrder/PORequest.swift`.
//

import Foundation

enum PORequest {

    // MARK: - Vendors
    case fetchVendors
    case fetchVendorById(String)                 // id → GET /vendors/{id}
    case createVendor([String: Any])
    case updateVendor(String, [String: Any])     // id, body → PATCH /vendors/{id}
    case deleteVendor(String)
    case verifyVendor(String)                    // id → POST /vendors/{id}/verify
    case fetchVendorHistory(String)              // id → GET /vendors/{id}/history

    // MARK: - Purchase Orders
    case fetchPurchaseOrders(String)             // deptId (empty = all) → GET /purchase-orders
    case fetchPO(String)                         // id → GET /purchase-orders/{id}
    case fetchDrafts
    case createPO([String: Any])
    case updatePO(String, [String: Any])         // id, body
    case createPOData(Data)                      // Encodable-body variant
    case updatePOData(String, Data)              // id, Encodable-body variant
    case deletePO(String)
    case approvePO(String, [String: Any])        // id, body
    case rejectPO(String, [String: Any])         // id, body
    case generatePDF(String, [String: Any])      // id, body
    case fetchPOHistory(String)                  // id → /purchase-orders/{id}/history
    case fetchApprovalQueue                      // GET  /purchase-orders/approval
    case fetchMyPOs                              // GET  /purchase-orders/my
    case bulkUpdatePOs([String: Any])            // PATCH /purchase-orders/bulk
    case postPO(String, [String: Any])           // POST /purchase-orders/{id}/post
    case closePO(String, [String: Any])          // POST /purchase-orders/{id}/close

    // MARK: - Templates
    case fetchTemplates
    case createTemplate([String: Any])
    case updateTemplate(String, [String: Any])   // id, body
    case deleteTemplate(String)

    // MARK: - Form Template
    case fetchFormTemplate
    case fetchFloatFormTemplate
}

extension PORequest: FCURLRequestProtocol {
    var urlRequest: URLRequest? {
        switch self {

        // MARK: Vendors
        case .fetchVendors:
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors?per_page=200"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchVendorById(let id):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .createVendor(let body):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .updateVendor(let id, let body):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .deleteVendor(let id):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject

        case .verifyVendor(let id):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors/\(id)/verify"
            return FCURLRequest(urlPath: endPoint, type: .post, body: [:]).requestObject

        case .fetchVendorHistory(let id):
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)vendors/\(id)/history?perPage=200"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Form Template
        case .fetchFormTemplate:
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/form-templates?module=purchase_orders"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchFloatFormTemplate:
            let endPoint = "\(ServerRequest.ACC_HUB_BASE_URL)account-hub/form-templates?module=cash_expenses"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        // MARK: Purchase Orders
        case .fetchPurchaseOrders(let deptId):
            let endPoint: String
            if deptId.isEmpty {
                endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders"
            } else {
                endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders?department_id=\(deptId)"
            }
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchPO(let id):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchDrafts:
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders?status=DRAFT"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .createPO(let body):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .updatePO(let id, let body):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .createPOData(let data):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders"
            return FCURLRequest(urlPath: endPoint, type: .post, body: data).requestObject

        case .updatePOData(let id, let data):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: data).requestObject

        case .deletePO(let id):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject

        case .approvePO(let id, let body):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/\(id)/approve"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .rejectPO(let id, let body):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/\(id)/reject"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .generatePDF(let id, let body):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/\(id)/pdf"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .fetchPOHistory(let id):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/\(id)/history?perPage=200"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchApprovalQueue:
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/approval"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .fetchMyPOs:
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/my"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .bulkUpdatePOs(let body):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/bulk"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .postPO(let id, let body):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/\(id)/post"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .closePO(let id, let body):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/\(id)/close"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        // MARK: Templates
        case .fetchTemplates:
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/templates"
            return FCURLRequest(urlPath: endPoint, type: .get).requestObject

        case .createTemplate(let body):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/templates"
            return FCURLRequest(urlPath: endPoint, type: .post, body: body).requestObject

        case .updateTemplate(let id, let body):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/templates/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .patch, body: body).requestObject

        case .deleteTemplate(let id):
            let endPoint = "\(ServerRequest.PO_BASE_URL)purchase-orders/templates/\(id)"
            return FCURLRequest(urlPath: endPoint, type: .delete).requestObject
        }
    }
}
