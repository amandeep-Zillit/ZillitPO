//
//  CardExpenseCodableTask.swift
//  ZillitPO
//

import Foundation

enum CardExpenseCodableTask {
    // Receipts
    case fetchAllReceipts((Result<ZLGenericResponse<[Receipt]>?, Error>) -> Void)
    case fetchMyReceipts(String, (Result<ZLGenericResponse<[Receipt]>?, Error>) -> Void)
    case confirmReceipt(String, (Result<Data?, Error>) -> Void)
    case deleteReceipt(String, (Result<Data?, Error>) -> Void)
    case flagReceiptPersonal(String, (Result<Data?, Error>) -> Void)
    case submitCoding(String, [String: Any], (Result<Data?, Error>) -> Void)

    // Transactions
    case fetchTransactions(String, (Result<ZLGenericResponse<[CardTransaction]>?, Error>) -> Void)

    // Cards
    case fetchCards(String, (Result<ZLGenericResponse<[ExpenseCard]>?, Error>) -> Void)
    case fetchAllCards((Result<ZLGenericResponse<[ExpenseCard]>?, Error>) -> Void)
    case fetchCard(String, (Result<ZLGenericResponse<ExpenseCard>?, Error>) -> Void)
    case createCard([String: Any], (Result<Data?, Error>) -> Void)
    case updateCard(String, [String: Any], (Result<Data?, Error>) -> Void)
    case deleteCard(String, (Result<Data?, Error>) -> Void)
    case fetchCardHistoryById(String, (Result<ZLGenericResponse<[CardHistoryEntry]>?, Error>) -> Void)
    case fetchReceiptHistory(String, (Result<ZLGenericResponse<[CardHistoryEntry]>?, Error>) -> Void)
    case fetchEntityQueries(String, String, (Result<ZLGenericResponse<InvoiceQueryThread>?, Error>) -> Void)
    case suspendCard(String, [String: Any], (Result<Data?, Error>) -> Void)
    case reactivateCard(String, [String: Any], (Result<Data?, Error>) -> Void)
    case activateCard(String, [String: Any], (Result<Data?, Error>) -> Void)
    case approveCard(String, [String: Any], (Result<Data?, Error>) -> Void)
    case rejectCard(String, [String: Any], (Result<Data?, Error>) -> Void)
    case overrideCard(String, [String: Any], (Result<Data?, Error>) -> Void)

    // Metadata
    case fetchMetadata((Result<ZLGenericResponse<CardExpenseMeta>?, Error>) -> Void)

    // Accountant Hub queues
    case fetchTopUps((Result<ZLGenericResponse<[TopUpItem]>?, Error>) -> Void)
    case fetchSmartAlerts((Result<ZLGenericResponse<[SmartAlert]>?, Error>) -> Void)
    case fetchCardHistory((Result<ZLGenericResponse<[CardTransaction]>?, Error>) -> Void)
    case fetchPendingCoding((Result<ZLGenericResponse<[PendingCodingItem]>?, Error>) -> Void)
    case fetchPendingCodingItem(String, (Result<ZLGenericResponse<PendingCodingItem>?, Error>) -> Void)
    case fetchReceiptDetail(String, (Result<ZLGenericResponse<Receipt>?, Error>) -> Void)
    case fetchApprovalQueue((Result<ZLGenericResponse<[CardTransaction]>?, Error>) -> Void)
    case overrideApproval(String, [String: Any], (Result<Data?, Error>) -> Void)

    // Receipt matching
    case matchReceipt(String, [String: Any], (Result<Data?, Error>) -> Void)

    // Top-Up actions
    case markTopUp(String, [String: Any], (Result<Data?, Error>) -> Void)
    case skipTopUp(String, (Result<Data?, Error>) -> Void)
    case partialTopUp(String, [String: Any], (Result<Data?, Error>) -> Void)

    // Smart Alert actions
    case resolveAlert(String, [String: Any], (Result<Data?, Error>) -> Void)
    case dismissAlert(String, (Result<Data?, Error>) -> Void)
    case investigateAlert(String, [String: Any], (Result<Data?, Error>) -> Void)
    case revertAlert(String, [String: Any], (Result<Data?, Error>) -> Void)

    // Bank Accounts
    case fetchBankAccounts((Result<ZLGenericResponse<[ProductionBankAccount]>?, Error>) -> Void)

    // Approval Tiers (card expenses)
    case fetchCardApprovalTiers((Result<ZLGenericResponse<[ApprovalTierConfig]>?, Error>) -> Void)
}

extension CardExpenseCodableTask: FCCodableDataTask {
    var urlDataTask: URLSessionDataTask? {
        switch self {

        // Receipts
        case .fetchAllReceipts(let completion):
            guard let req = CardExpenseRequest.fetchAllReceipts.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .fetchMyReceipts(let userId, let completion):
            guard let req = CardExpenseRequest.fetchMyReceipts(userId).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .confirmReceipt(let id, let completion):
            guard let req = CardExpenseRequest.confirmReceipt(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .deleteReceipt(let id, let completion):
            guard let req = CardExpenseRequest.deleteReceipt(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .flagReceiptPersonal(let id, let completion):
            guard let req = CardExpenseRequest.flagReceiptPersonal(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .submitCoding(let id, let body, let completion):
            guard let req = CardExpenseRequest.submitCoding(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        // Transactions
        case .fetchTransactions(let params, let completion):
            let request: CardExpenseRequest = {
                switch params {
                case "my":  return .fetchMyReceipts("")
                case "all": return .fetchAllReceipts
                default:    return .fetchTransactions(params)
                }
            }()
            guard let req = request.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        // Cards
        case .fetchCards(let params, let completion):
            guard let req = CardExpenseRequest.fetchCards(params).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .fetchAllCards(let completion):
            guard let req = CardExpenseRequest.fetchCards("").urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .fetchCard(let id, let completion):
            guard let req = CardExpenseRequest.getCard(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .createCard(let body, let completion):
            guard let req = CardExpenseRequest.createCard(body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .updateCard(let id, let body, let completion):
            guard let req = CardExpenseRequest.updateCardReq(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .deleteCard(let id, let completion):
            guard let req = CardExpenseRequest.deleteCardReq(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .fetchCardHistoryById(let id, let completion):
            guard let req = CardExpenseRequest.fetchCardHistoryById(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .fetchReceiptHistory(let id, let completion):
            guard let req = CardExpenseRequest.fetchReceiptHistory(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .fetchEntityQueries(let entityType, let entityId, let completion):
            guard let req = CardExpenseRequest.fetchEntityQueries(entityType, entityId).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .suspendCard(let id, let body, let completion):
            guard let req = CardExpenseRequest.suspendCardReq(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .reactivateCard(let id, let body, let completion):
            guard let req = CardExpenseRequest.reactivateCardReq(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .activateCard(let id, let body, let completion):
            guard let req = CardExpenseRequest.activateCardReq(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .approveCard(let id, let body, let completion):
            guard let req = CardExpenseRequest.approveCardReq(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .rejectCard(let id, let body, let completion):
            guard let req = CardExpenseRequest.rejectCardReq(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .overrideCard(let id, let body, let completion):
            guard let req = CardExpenseRequest.overrideCardReq(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        // Metadata
        case .fetchMetadata(let completion):
            guard let req = CardExpenseRequest.fetchMetadata.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        // Accountant Hub queues
        case .fetchTopUps(let completion):
            guard let req = CardExpenseRequest.fetchTopUps.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)
        case .fetchSmartAlerts(let completion):
            guard let req = CardExpenseRequest.fetchSmartAlerts.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)
        case .fetchCardHistory(let completion):
            guard let req = CardExpenseRequest.fetchCardHistory.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .fetchPendingCoding(let completion):
            guard let req = CardExpenseRequest.fetchPendingCoding.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .fetchPendingCodingItem(let id, let completion):
            guard let req = CardExpenseRequest.getReceipt(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .fetchReceiptDetail(let id, let completion):
            guard let req = CardExpenseRequest.fetchReceiptDetail(id).urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .fetchApprovalQueue(let completion):
            guard let req = CardExpenseRequest.fetchApprovalQueue.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .overrideApproval(let id, let body, let completion):
            guard let req = CardExpenseRequest.overrideApproval(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        // Receipt matching
        case .matchReceipt(let id, let body, let completion):
            guard let req = CardExpenseRequest.matchReceipt(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        // Top-Up actions
        case .markTopUp(let id, let body, let completion):
            guard let req = CardExpenseRequest.markTopUp(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .skipTopUp(let id, let completion):
            guard let req = CardExpenseRequest.skipTopUp(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .partialTopUp(let id, let body, let completion):
            guard let req = CardExpenseRequest.partialTopUp(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        // Smart Alert actions
        case .resolveAlert(let id, let body, let completion):
            guard let req = CardExpenseRequest.resolveAlert(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .dismissAlert(let id, let completion):
            guard let req = CardExpenseRequest.dismissAlert(id).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .investigateAlert(let id, let body, let completion):
            guard let req = CardExpenseRequest.investigateAlert(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .revertAlert(let id, let body, let completion):
            guard let req = CardExpenseRequest.revertAlert(id, body).urlRequest else { return nil }
            return APIClient.shared.dataResultTask(with: req, completion: completion)

        case .fetchBankAccounts(let completion):
            guard let req = CardExpenseRequest.fetchBankAccounts.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)

        case .fetchCardApprovalTiers(let completion):
            guard let req = CardExpenseRequest.fetchCardApprovalTiers.urlRequest else { return nil }
            return FCURLSession.sharedInstance.session?.codableResultTask(with: req, completion: completion)
        }
    }
}
