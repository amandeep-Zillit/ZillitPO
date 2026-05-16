//
//  TimecardViewModel+apis.swift
//  ZillitPO
//
//  Network actions for the time-card module. One method per
//  `timecardsApi.*` + `dailyLoginApi.*` call.
//

import Foundation

extension TimecardViewModel {

    // MARK: - Metadata

    func loadMetadata(completion: (() -> Void)? = nil) {
        isLoadingMetadata = true
        TimecardCodableTask.getMetadata { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMetadata = false
                switch result {
                case .success(let response): self?.metadata = response?.data
                case .failure(let error): debugPrint("❌ Fetch timecard metadata failed: \(error)")
                }
                completion?()
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Weekly timecards

    func loadTimecards(status: String? = nil, weekStarting: Int64? = nil) {
        isLoadingTimecards = true
        var query: [String: String] = [:]
        if let s = status, !s.isEmpty { query["status"] = s }
        if let w = weekStarting { query["week_starting"] = String(w) }
        TimecardCodableTask.list(query) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingTimecards = false
                switch result {
                case .success(let response): self?.timecards = response?.data ?? []
                case .failure(let error): debugPrint("❌ List timecards failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadMySummary() {
        isLoadingMySummary = true
        TimecardCodableTask.mySummary([:]) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingMySummary = false
                switch result {
                case .success(let response): self?.mySummary = response?.data ?? []
                case .failure(let error): debugPrint("❌ Fetch my-summary failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadApprovalQueue() {
        isLoadingApprovalQueue = true
        TimecardCodableTask.listForApproval { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingApprovalQueue = false
                switch result {
                case .success(let response): self?.approvalQueue = response?.data ?? []
                case .failure(let error): debugPrint("❌ Fetch approval queue failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadTimecard(_ id: String) {
        isLoadingCurrent = true
        TimecardCodableTask.getOne(id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingCurrent = false
                switch result {
                case .success(let response): self?.currentTimecard = response?.data
                case .failure(let error): debugPrint("❌ Fetch timecard failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadHistory(_ id: String) {
        TimecardCodableTask.getHistory(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response): self?.currentHistory = response?.data ?? []
                case .failure(let error): debugPrint("❌ Fetch history failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Lifecycle actions

    func submitTimecard(_ id: String, body: [String: Any] = [:], onComplete: @escaping (Bool) -> Void) {
        TimecardCodableTask.submit(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadTimecards()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Submit timecard failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func approveTimecard(_ id: String, body: [String: Any] = [:], onComplete: @escaping (Bool) -> Void) {
        TimecardCodableTask.approve(id, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadApprovalQueue()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Approve timecard failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func rejectTimecard(_ id: String, reason: String, onComplete: @escaping (Bool) -> Void) {
        TimecardCodableTask.reject(id, ["reason": reason]) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadApprovalQueue()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Reject timecard failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func approveBatch(_ ids: [String], onComplete: @escaping (Bool) -> Void) {
        TimecardCodableTask.approveBatch(ids) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadApprovalQueue()
                    self?.selectedForBatch.removeAll()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Batch approve failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func rejectBatch(_ ids: [String], reason: String, onComplete: @escaping (Bool) -> Void) {
        TimecardCodableTask.rejectBatch(ids, reason) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadApprovalQueue()
                    self?.selectedForBatch.removeAll()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Batch reject failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func markPaid(_ id: String, onComplete: @escaping (Bool) -> Void) {
        TimecardCodableTask.markPaid(id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadTimecards()
                    onComplete(true)
                case .failure(let error):
                    debugPrint("❌ Mark paid failed: \(error)")
                    onComplete(false)
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Daily Login

    /// Loads the daily-login record for "today" (start-of-day in user TZ).
    func loadDailyLoginToday() {
        let ms = TimecardViewModel.startOfDayMs(Date())
        DailyLoginCodableTask.getForDate(ms) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response): self?.dailyLoginToday = response?.data
                case .failure(let error):    debugPrint("❌ Fetch daily login failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loadDailyLoginRange(from: Int64, to: Int64) {
        isLoadingDailyLogin = true
        let q = ["date_from": String(from), "date_to": String(to)]
        DailyLoginCodableTask.list(q) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingDailyLogin = false
                switch result {
                case .success(let response): self?.dailyLoginRange = response?.data ?? []
                case .failure(let error):    debugPrint("❌ Fetch daily login range failed: \(error)")
                }
            }
        }.urlDataTask?.resume()
    }

    func loginNow(onComplete: ((Bool) -> Void)? = nil) {
        let dayMs = TimecardViewModel.startOfDayMs(Date())
        let body: [String: Any] = [
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "manual": false,
        ]
        DailyLoginCodableTask.login(dayMs, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadDailyLoginToday()
                    onComplete?(true)
                case .failure(let error):
                    debugPrint("❌ Daily login failed: \(error)")
                    onComplete?(false)
                }
            }
        }.urlDataTask?.resume()
    }

    func logoutNow(onComplete: ((Bool) -> Void)? = nil) {
        let dayMs = TimecardViewModel.startOfDayMs(Date())
        let body: [String: Any] = [
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "manual": false,
        ]
        DailyLoginCodableTask.logout(dayMs, body) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadDailyLoginToday()
                    onComplete?(true)
                case .failure(let error):
                    debugPrint("❌ Daily logout failed: \(error)")
                    onComplete?(false)
                }
            }
        }.urlDataTask?.resume()
    }

    // MARK: - Boot

    /// Equivalent of `TimecardLandingModule`'s `.useEffect` —
    /// metadata + daily-login today fetched on entry.
    func bootstrap() {
        loadMetadata()
        loadDailyLoginToday()
    }

    // MARK: - Helpers

    /// Start-of-day (00:00) in the user's current timezone, in epoch ms.
    static func startOfDayMs(_ date: Date) -> Int64 {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        return Int64(start.timeIntervalSince1970 * 1000)
    }
}
