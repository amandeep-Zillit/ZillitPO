//
//  DealMemoViewModel+funcs.swift
//  ZillitPO
//

import Foundation

extension DealMemoViewModel {
    func prepareAlert(type: DealMemoViewModel.DMAlert, title: String, message: String) {
        self.alertType = type
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }

    /// Currency symbol helper used by overview / deals tables. Matches
    /// the React string-switch in `shapeRecentRow`.
    static func currencySymbol(_ code: String?) -> String {
        switch code {
        case "USD": return "$"
        case "EUR": return "€"
        default:    return "£"
        }
    }

    /// Formats a daily-rate row the way `DMOverviewPage.shapeRecentRow` does.
    func formattedDailyRate(_ deal: DealMemo) -> String {
        guard let rate = deal.rates?.daily?.rate else { return "—" }
        let sym = Self.currencySymbol(deal.rates?.contractCurrency)
        return "\(sym)\(NumberFormatter.localizedString(from: NSNumber(value: rate), number: .decimal))"
    }

    /// Crew name + position resolution — port of `shapeRecentRow`.
    func crewName(for deal: DealMemo) -> String {
        if let n = deal.crewDetails?.crewName, !n.isEmpty { return n }
        if let uid = deal.userId, let u = UsersData.byId[uid] {
            return u.fullName ?? "—"
        }
        return "—"
    }

    func position(for deal: DealMemo) -> String {
        if let custom = deal.crewDetails?.customDesignation, !custom.isEmpty { return custom }
        if let id = deal.crewDetails?.designationIdentifier, !id.isEmpty {
            return FormatUtils.formatLabel(id)
        }
        if let did = deal.designationId, !did.isEmpty { return FormatUtils.formatLabel(did) }
        return "—"
    }
}
