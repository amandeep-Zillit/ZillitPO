//
//  Step5Rates.swift
//  ZillitPO
//
//  Port of `Step5Rates.jsx` (2,161 LOC in live — heavily collapsed for
//  the demo scaffold). OT tiers + holiday pay + pension. The live file
//  has rate-bible lookups, role-specific defaults and tier-by-tier OT
//  calculators — those drop in over this scaffold.
//

import SwiftUI

struct Step5Rates: View {
    @EnvironmentObject var wiz: DMWizardState

    private let currencies = ["GBP", "USD", "EUR"]
    private let holidayPayTreatments = ["Rolled-up (paid with weekly rate)",
                                        "Accrued (separate payment)",
                                        "Not applicable"]
    private let pensionSchemes = ["NEST", "Auto-enrolment (default)", "Opt-out", "Salary sacrifice"]

    private var currencySymbol: String {
        DealMemoViewModel.currencySymbol(wiz.contractCurrency)
    }

    var body: some View {
        DMStepChrome(
            stepNumber: 5,
            title: "Rates & Compensation",
            subtitle: "Base rate, OT tiers and holiday-pay treatment."
        ) {
            DMFieldGroup("Contract Currency") {
                DMPicker(selection: $wiz.contractCurrency,
                         options: currencies, placeholder: "GBP")
            }
            DMFieldGroup("Daily Rate") {
                DMAmountField(amount: $wiz.dailyRate, currencySymbol: currencySymbol)
            }
            DMFieldGroup("Weekly Rate") {
                DMAmountField(amount: $wiz.weeklyRate, currencySymbol: currencySymbol)
            }

            DMStepSection(title: "Overtime tiers")

            DMFieldGroup("Tier 1 multiplier (after standard hours)") {
                DMAmountField(amount: $wiz.otTier1Multiplier, currencySymbol: "×")
            }
            DMFieldGroup("Tier 2 multiplier (e.g. after 12hr)") {
                DMAmountField(amount: $wiz.otTier2Multiplier, currencySymbol: "×")
            }

            DMStepSection(title: "Holiday & pension")

            DMFieldGroup("Holiday Pay Treatment") {
                DMPicker(selection: $wiz.holidayPayTreatment,
                         options: holidayPayTreatments,
                         placeholder: "Select treatment…")
            }
            DMFieldGroup("Pension Scheme") {
                DMPicker(selection: $wiz.pensionScheme,
                         options: pensionSchemes,
                         placeholder: "Select scheme…")
            }
        }
    }
}
