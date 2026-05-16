//
//  Step9Payroll.swift
//  ZillitPO
//
//  Port of `Step9Payroll.jsx` — payroll bureau export setup.
//

import SwiftUI

struct Step9Payroll: View {
    @EnvironmentObject var wiz: DMWizardState

    private let payFrequencies = ["Weekly", "Bi-weekly", "Monthly", "Custom"]

    var body: some View {
        DMStepChrome(
            stepNumber: 9,
            title: "Payroll Start Form",
            subtitle: "Bureau & export configuration."
        ) {
            DMFieldGroup("First Pay Period Start") {
                DMDateField(date: $wiz.firstPayPeriodStart)
            }
            DMFieldGroup("Pay Frequency") {
                DMPicker(selection: $wiz.payFrequency, options: payFrequencies, placeholder: "Select frequency…")
            }
            DMStepSection(title: "Bureau settings")
            DMToggleRow("Auto-sync deal memo changes to payroll",
                        subtitle: "Edits to this deal memo update the bureau export automatically",
                        isOn: $wiz.autoSyncToPayroll)
            DMToggleRow("Notify payroll contact on issue",
                        subtitle: "Email the payroll team when the deal memo is issued",
                        isOn: $wiz.notifyPayrollContact)
            DMToggleRow("Include deal memo PDF in bureau export",
                        subtitle: "Attach the signed PDF to the next bureau drop",
                        isOn: $wiz.includePdfInBureauExport)
        }
    }
}
