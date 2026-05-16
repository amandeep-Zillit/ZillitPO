//
//  Step4DealStructure.swift
//  ZillitPO
//
//  Port of `Step4DealStructure.jsx` — dates, billing basis, notice terms,
//  prep/shoot/wrap schedule, deal-specific notes. The AI badge on the
//  step row indicates this step accepts AI-assisted fill-in from the
//  prior crew member's deal.
//

import SwiftUI

struct Step4DealStructure: View {
    @EnvironmentObject var wiz: DMWizardState

    private let billingBases = ["Weekly", "Daily", "Hourly", "Fixed"]

    var body: some View {
        DMStepChrome(
            stepNumber: 4,
            title: "Deal Structure",
            subtitle: "Type, dates and guarantees."
        ) {
            DMFieldGroup("Start Date") {
                DMDateField(date: $wiz.startDate)
            }
            DMFieldGroup("Estimated End Date") {
                DMDateField(date: $wiz.endDate)
            }
            DMFieldGroup("Billing Basis") {
                DMPicker(selection: $wiz.billingBasis, options: billingBases, placeholder: "Select basis…")
            }
            DMFieldGroup("Set Prep / Shoot / Wrap Schedule") {
                DMTextField(text: $wiz.prepShootWrapSchedule,
                            placeholder: "e.g. 2 wks prep, 12 wks shoot, 1 wk wrap")
            }
            DMFieldGroup("Negotiated Notice Terms") {
                DMTextField(text: $wiz.negotiatedNoticeTerms,
                            placeholder: "e.g. 3 weeks rolling / 10 days during prep")
            }
            DMFieldGroup("Deal Notes") {
                TextEditor(text: $wiz.dealNotes)
                    .font(.system(size: 14))
                    .frame(minHeight: 90)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            }
        }
    }
}
