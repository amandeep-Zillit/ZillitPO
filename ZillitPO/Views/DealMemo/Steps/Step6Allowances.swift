//
//  Step6Allowances.swift
//  ZillitPO
//
//  Port of `Step6Allowances.jsx` + `Step6CreditConditions.jsx` (web has
//  two Step-6 files that share the wizard slot). Per diem, kit rental,
//  car allowance, travel zone, distant-location flag, credit conditions.
//

import SwiftUI

struct Step6Allowances: View {
    @EnvironmentObject var wiz: DMWizardState

    private let kitFrequencies = ["Daily", "Weekly", "Per shoot day", "Fixed for term"]
    private let travelZones = ["Zone 1 — Local",
                               "Zone 2 — Day-trip",
                               "Zone 3 — Overnight required",
                               "Distant location"]

    private var currencySymbol: String {
        DealMemoViewModel.currencySymbol(wiz.contractCurrency)
    }

    var body: some View {
        DMStepChrome(
            stepNumber: 6,
            title: "Allowances & Rentals",
            subtitle: "Per diem, kit, car and travel-zone elections."
        ) {
            DMFieldGroup("Per Diem (daily)") {
                DMAmountField(amount: $wiz.perDiemDaily, currencySymbol: currencySymbol)
            }
            DMFieldGroup("Kit Rental") {
                DMAmountField(amount: $wiz.kitRentalAmount, currencySymbol: currencySymbol)
            }
            DMFieldGroup("Kit Rental Frequency") {
                DMPicker(selection: $wiz.kitRentalFrequency, options: kitFrequencies, placeholder: "Select…")
            }
            DMFieldGroup("Car Allowance") {
                DMAmountField(amount: $wiz.carAllowance, currencySymbol: currencySymbol)
            }
            DMFieldGroup("Travel Zone Election") {
                DMPicker(selection: $wiz.travelZoneElection, options: travelZones, placeholder: "Select zone…")
            }
            DMToggleRow("Distant location applies to this engagement",
                        subtitle: "Triggers additional per diem + travel allowances",
                        isOn: $wiz.distantLocationApplies)

            DMStepSection(title: "Credit conditions")

            DMFieldGroup("Bookend Credit") {
                DMTextField(text: $wiz.bookendCredit,
                            placeholder: "e.g. \"Gaffer – James Okafor\" main titles")
            }
        }
    }
}
