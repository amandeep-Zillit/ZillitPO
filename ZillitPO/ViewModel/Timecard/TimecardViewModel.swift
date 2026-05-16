//
//  TimecardViewModel.swift
//  ZillitPO
//
//  Owns time-card state — weekly timecards, my summary, approval
//  queue, daily-login records, metadata. Reads `AccountHubViewModel`
//  for currentUser parity but otherwise stands alone.
//

import SwiftUI
import Combine

class TimecardViewModel: ObservableObject {
    @Published var userId = Util.getLoginUserID()
    @Published var currentUser: LoginUserData?

    weak var hub: AccountHubViewModel?

    // Metadata (drives card visibility on the landing)
    @Published var metadata: TimecardMetadata?
    @Published var isLoadingMetadata = false

    // Weekly timecards
    @Published var timecards: [Timecard] = []
    @Published var isLoadingTimecards = false

    // My summary (week summaries + days worked count)
    @Published var mySummary: [TimecardSummary] = []
    @Published var isLoadingMySummary = false

    // Approval queue
    @Published var approvalQueue: [Timecard] = []
    @Published var isLoadingApprovalQueue = false

    // Current week's timecard detail
    @Published var currentTimecard: Timecard?
    @Published var currentHistory: [TimecardHistoryEntry] = []
    @Published var isLoadingCurrent = false

    // Daily-login state
    @Published var dailyLoginToday: DailyLogin?
    @Published var dailyLoginRange: [DailyLogin] = []
    @Published var isLoadingDailyLogin = false

    // UI state
    @Published var activeView: TimecardLandingView = .weekly
    @Published var weekStartingMs: Int64 = TimecardViewModel.mondayMs(of: Date())

    // Selection state for batch approve/reject (Approval Queue)
    @Published var selectedForBatch: Set<String> = []

    // Reject sheet
    @Published var showRejectSheet = false
    @Published var rejectTarget: Timecard?
    @Published var rejectReason = ""

    // Alert
    @Published var alertType: TCAlert? = nil
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false

    init() {
        currentUser = appUserDefault.getLoginUserData()
    }

    func bind(to hub: AccountHubViewModel) {
        self.hub = hub
    }

    var isAccountant: Bool { metadata?.isAccountant ?? false }
    var isApprover: Bool   { metadata?.isApprover   ?? false }
    var isCompleter: Bool  { metadata?.isCompleter  ?? false }

    // MARK: - Date helpers

    /// Returns Monday-00:00 of the week containing `date`, in epoch ms (UTC).
    static func mondayMs(of date: Date) -> Int64 {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let monday = cal.date(from: comps) else {
            return Int64(date.timeIntervalSince1970 * 1000)
        }
        return Int64(monday.timeIntervalSince1970 * 1000)
    }
}
