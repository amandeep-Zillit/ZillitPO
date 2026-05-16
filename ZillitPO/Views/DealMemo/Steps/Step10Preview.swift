//
//  Step10Preview.swift
//  ZillitPO
//
//  Port of `Step10Preview.jsx` — final review + submit step. Shows a
//  read-only summary of every prior step's data; "Submit deal memo"
//  hits the create endpoint via `DealMemoViewModel`.
//

import SwiftUI

struct Step10Preview: View {
    @EnvironmentObject var wiz: DMWizardState
    @EnvironmentObject var dm: DealMemoViewModel

    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private var currencySymbol: String {
        DealMemoViewModel.currencySymbol(wiz.contractCurrency)
    }

    var body: some View {
        DMStepChrome(
            stepNumber: 10,
            title: "Preview & Issue",
            subtitle: "Review the deal memo before issuing for signature."
        ) {
            sectionCard("Territory & Union", rows: [
                ("Production entity", wiz.productionEntity),
                ("Production type",   wiz.productionType),
                ("Territory",         wiz.territory),
                ("Budget band",       wiz.budgetBand),
                ("Union / Agreement", wiz.unionAgreement),
                ("Ruleset",           wiz.ruleset),
            ])

            sectionCard("Crew", rows: [
                ("Crew member",    wiz.crewMemberName),
                ("Department",     FormatUtils.formatLabel(wiz.department)),
                ("Job title",      wiz.jobTitle.isEmpty ? wiz.customJobTitle : wiz.jobTitle),
                ("Crew type",      wiz.crewType),
                ("Reports to",     wiz.reportsTo),
            ])

            sectionCard("Compliance", rows: [
                ("IR35 status",            wiz.ir35Status),
                ("Right-to-Work verified", wiz.rtwVerified ? "Yes" : "No"),
                ("Data consent",           wiz.dataConsent ? "Yes" : "No"),
                ("Docs received",          wiz.documentsReceived ? "Yes" : "No"),
            ])

            sectionCard("Deal Structure", rows: [
                ("Start date",     dateFmt.string(from: wiz.startDate)),
                ("End date",       dateFmt.string(from: wiz.endDate)),
                ("Billing basis",  wiz.billingBasis),
                ("Schedule",       wiz.prepShootWrapSchedule),
                ("Notice terms",   wiz.negotiatedNoticeTerms),
            ])

            sectionCard("Rates", rows: [
                ("Currency",     wiz.contractCurrency),
                ("Daily",        "\(currencySymbol)\(format(wiz.dailyRate))"),
                ("Weekly",       "\(currencySymbol)\(format(wiz.weeklyRate))"),
                ("OT Tier 1",    "\(format(wiz.otTier1Multiplier))×"),
                ("OT Tier 2",    "\(format(wiz.otTier2Multiplier))×"),
                ("Holiday pay",  wiz.holidayPayTreatment),
                ("Pension",      wiz.pensionScheme),
            ])

            sectionCard("Allowances", rows: [
                ("Per diem",       "\(currencySymbol)\(format(wiz.perDiemDaily))"),
                ("Kit rental",     "\(currencySymbol)\(format(wiz.kitRentalAmount)) \(wiz.kitRentalFrequency)"),
                ("Car allowance",  "\(currencySymbol)\(format(wiz.carAllowance))"),
                ("Travel zone",    wiz.travelZoneElection),
                ("Distant loc.",   wiz.distantLocationApplies ? "Yes" : "No"),
            ])

            sectionCard("Coding", rows: [
                ("Nominal code", wiz.nominalCode),
                ("Cost centre",  wiz.costCentre),
                ("Core creative",wiz.coreCreativeClassification ? "Yes" : "No"),
                ("UK spend",     wiz.ukSpend ? "Yes" : "No"),
                ("Tax credit",   wiz.taxCreditRate),
            ])

            sectionCard("Signatures", rows: [
                ("DocuSign",                  wiz.docuSignEnabled ? "Enabled" : "Disabled"),
                ("Crew counter-signature",    wiz.requireCrewCounterSignature ? "Required" : "Not required"),
                ("Senior accountant sign-off",wiz.requireSeniorAccountantSignOff ? "Required" : "Not required"),
                ("Copy to production office", wiz.copyToProductionOffice ? "Yes" : "No"),
            ])

            sectionCard("Payroll", rows: [
                ("First pay period", dateFmt.string(from: wiz.firstPayPeriodStart)),
                ("Frequency",        wiz.payFrequency),
                ("Auto-sync",        wiz.autoSyncToPayroll ? "On" : "Off"),
                ("Notify payroll",   wiz.notifyPayrollContact ? "On" : "Off"),
                ("PDF in export",    wiz.includePdfInBureauExport ? "On" : "Off"),
            ])
        }
    }

    // MARK: - Section card

    @ViewBuilder
    private func sectionCard(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 14).padding(.vertical, 12)

            Divider().background(Color.borderSubtle)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    Text(row.0)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 130, alignment: .leading)
                    Text(row.1.isEmpty ? "—" : row.1)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(row.1.isEmpty ? .secondary : .primary)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
            }
        }
        .background(Color.bgSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderSubtle, lineWidth: 1))
    }

    private func format(_ d: Double) -> String {
        if d.truncatingRemainder(dividingBy: 1) == 0 {
            return NumberFormatter.localizedString(from: NSNumber(value: Int(d)), number: .decimal)
        }
        return NumberFormatter.localizedString(from: NSNumber(value: d), number: .decimal)
    }
}
