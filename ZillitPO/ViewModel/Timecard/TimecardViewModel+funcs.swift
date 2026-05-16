//
//  TimecardViewModel+funcs.swift
//  ZillitPO
//

import Foundation
import SwiftUI

extension TimecardViewModel {
    func prepareAlert(type: TimecardViewModel.TCAlert, title: String, message: String) {
        self.alertType = type
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }

    // MARK: - Formatting helpers

    /// "Mon, 11 Mar" — week-row label.
    static func dayLabel(_ ms: Int64?) -> String {
        guard let ms = ms, ms > 0 else { return "—" }
        let df = DateFormatter(); df.dateFormat = "EEE, d MMM"
        df.locale = Locale(identifier: "en_GB")
        return df.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }

    /// "Week of 11 Mar" — list header on My Time Cards.
    static func weekOfLabel(_ ms: Int64?) -> String {
        guard let ms = ms, ms > 0 else { return "—" }
        let df = DateFormatter(); df.dateFormat = "d MMM yyyy"
        df.locale = Locale(identifier: "en_GB")
        return "Week of " + df.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }

    /// "Wednesday, 3 May 2026" — Daily Login section subhead (matches React's `toLocaleDateString` output).
    static func longDateLabel(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "EEEE, d MMMM yyyy"
        df.locale = Locale(identifier: "en_GB")
        return df.string(from: date)
    }

    /// "8h 30m" — net hours-worked label.
    static func hoursLabel(_ h: Double?) -> String {
        guard let h = h, h > 0 else { return "—" }
        let hrs = Int(h)
        let mins = Int(round((h - Double(hrs)) * 60))
        if mins == 0 { return "\(hrs)h" }
        return "\(hrs)h \(mins)m"
    }

    /// "£1,250" — gross-pay column.
    static func grossLabel(_ amount: Double?, currency: String?) -> String {
        guard let a = amount, a > 0 else { return "—" }
        let sym: String
        switch (currency ?? "GBP").uppercased() {
        case "USD": sym = "$"
        case "EUR": sym = "€"
        default:    sym = "£"
        }
        return sym + NumberFormatter.localizedString(from: NSNumber(value: Int(a.rounded())), number: .decimal)
    }
}
