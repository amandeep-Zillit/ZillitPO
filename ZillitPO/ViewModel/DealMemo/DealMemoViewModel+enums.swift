//
//  DealMemoViewModel+enums.swift
//  ZillitPO
//

import Foundation

/// Tab catalogue from `DealMemoModule.jsx`. Visibility rules are applied
/// in `DealMemoViewModel.visibleTabs`:
///   - `.overview`, `.deals`, `.ratesBible` → accountant only
///   - `.myDeal`                            → non-accountant only
///   - `.approvalQueue`                     → gated by `metadata.is_approver`
enum DealMemoTab: String, CaseIterable, Identifiable {
    case overview       = "overview"
    case deals          = "deals"
    case myDeal         = "my-deal"
    case approvalQueue  = "approval-queue"
    case ratesBible     = "rates-bible"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview:      return "Overview"
        case .deals:         return "All Deals"
        case .myDeal:        return "My Deal"
        case .approvalQueue: return "Approval Queue"
        case .ratesBible:    return "Rates Bible"
        }
    }
}

extension DealMemoViewModel {
    enum DMAlert {
        case success
        case fail
        case confirmDeleteDeal(DealMemo)
    }

    /// Visible tabs for the current user — same rules as
    /// `DealMemoTabShell` in the React module.
    var visibleTabs: [DealMemoTab] {
        DealMemoTab.allCases.filter {
            switch $0 {
            case .overview, .deals, .ratesBible: return isAccountant
            case .myDeal:                        return !isAccountant
            case .approvalQueue:                 return isApprover
            }
        }
    }
}
