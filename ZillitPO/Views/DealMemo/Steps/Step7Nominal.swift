//
//  Step7Nominal.swift
//  ZillitPO
//
//  Port of `Step7Nominal.jsx` — nominal coding for the accounts ledger.
//

import SwiftUI

struct Step7Nominal: View {
    @EnvironmentObject var wiz: DMWizardState

    private let taxCreditRates: [String] = ["10%", "16%", "25.5%", "29.25%", "Not eligible"]

    var body: some View {
        DMStepChrome(
            stepNumber: 7,
            title: "Nominal Coding",
            subtitle: "Accounts code, cost centre and tax-credit classification."
        ) {
            DMFieldGroup("Nominal Code") {
                DMTextField(text: $wiz.nominalCode, placeholder: "e.g. 4422")
            }
            DMFieldGroup("Cost Centre") {
                DMTextField(text: $wiz.costCentre, placeholder: "Department cost centre")
            }
            DMStepSection(title: "Tax-credit eligibility")
            DMToggleRow("Core Creative Classification",
                        subtitle: "Counts toward the core-creative tax-credit pool",
                        isOn: $wiz.coreCreativeClassification)
            DMToggleRow("UK Spend?",
                        subtitle: "Costs incurred and consumed in the UK",
                        isOn: $wiz.ukSpend)
            DMFieldGroup("Tax Credit Rate") {
                DMPicker(selection: $wiz.taxCreditRate, options: taxCreditRates, placeholder: "Select rate…")
            }
        }
    }
}
