//
//  TimecardViewModel+enums.swift
//  ZillitPO
//

import Foundation

/// 6 landing destinations from `TimecardLandingModule.jsx`. Visibility
/// rules:
///   - `.approvalQueue`      → gated by `metadata.is_approver`
///   - `.assignedTimecards`  → gated by `metadata.is_completer`
///   - `.timecardConfig`     → gated by `metadata.is_accountant`
///   - others                → always visible
enum TimecardLandingView: String, CaseIterable, Identifiable {
    case weekly              = "weekly-timecard"
    case myTimecards         = "my-timecards"
    case approvalQueue       = "approval-queue"
    case assignedTimecards   = "assigned-timecards"
    case crewReview          = "crew-review"
    case timecardConfig      = "config"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly:            return "Weekly Timecard"
        case .myTimecards:       return "My Time Cards"
        case .approvalQueue:     return "Approval Queue"
        case .assignedTimecards: return "Assigned Timecards"
        case .crewReview:        return "Review Inbox"
        case .timecardConfig:    return "Timecard Config"
        }
    }

    /// SF Symbol approximation of the React AntD icon used for each card.
    var icon: String {
        switch self {
        case .weekly:            return "calendar"
        case .myTimecards:       return "clock.arrow.circlepath"
        case .approvalQueue:     return "checkmark.seal"
        case .assignedTimecards: return "person.3"
        case .crewReview:        return "tray.full"
        case .timecardConfig:    return "gearshape"
        }
    }

    /// Accent tint per card — pulled from `TimecardLandingModule.jsx`
    /// `VIEWS[].color`.
    var tintHex: String {
        switch self {
        case .weekly:            return "#fc9404"
        case .myTimecards:       return "#6366f1"
        case .approvalQueue:     return "#10b981"
        case .assignedTimecards: return "#14b8a6"
        case .crewReview:        return "#2dd4bf"
        case .timecardConfig:    return "#8b5cf6"
        }
    }
}

extension TimecardViewModel {
    enum TCAlert {
        case success
        case fail
        case confirmDeleteTimecard(Timecard)
    }

    /// Visible landing cards for the current user — same rules as
    /// `TimecardLandingModule.jsx`'s `VIEWS.filter`.
    var visibleLandingViews: [TimecardLandingView] {
        TimecardLandingView.allCases.filter {
            switch $0 {
            case .weekly, .myTimecards, .crewReview: return true
            case .approvalQueue:                     return isApprover
            case .assignedTimecards:                 return isCompleter
            case .timecardConfig:                    return isAccountant
            }
        }
    }
}
