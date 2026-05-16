//
//  AccountHubViewModel+enums.swift
//  ZillitPO
//

import Foundation

// AccountHub-scoped enums live here. Add new vendor / session enums
// to this file rather than the per-domain enum extensions.

extension AccountHubViewModel {
    enum AHAlert {
        case success
        case fail
        case confirmDelete(String)  // associated value = vendor id to delete
    }

    enum VendorTerms: String, CaseIterable {
        case days_7
        case days_14
        case days_30
        case days_60

        var rawValue: String {
            switch self {
            case .days_7:  return "net_7"
            case .days_14: return "net_14"
            case .days_30: return "net_30"
            case .days_60: return "net_60"
            }
        }
        var title: String {
            switch self {
            case .days_7:  return "7 Days"
            case .days_14: return "14 Days"
            case .days_30: return "30 Days"
            case .days_60: return "60 Days"
            }
        }
    }

    enum AHModules: String {
        case purchaseOrder = "purchase_order"
        case invoices      = "invoices"
        case cardExpenses  = "card_expenses"
        case cashExpenses  = "cash_expenses"
    }
}
