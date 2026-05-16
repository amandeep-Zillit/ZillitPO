//
//  Step3Compliance.swift
//  ZillitPO
//
//  Port of `Step3Compliance.jsx` — IR35 status + RTW + data consent + docs.
//

import SwiftUI

struct Step3Compliance: View {
    @EnvironmentObject var wiz: DMWizardState

    private let ir35Options = ["Inside IR35", "Outside IR35", "Not applicable (employed)", "To be assessed"]

    var body: some View {
        DMStepChrome(
            stepNumber: 3,
            title: "Compliance & Onboarding",
            subtitle: "IR35, Right-to-Work and pre-engagement docs."
        ) {
            DMFieldGroup("IR35 Status") {
                DMPicker(selection: $wiz.ir35Status, options: ir35Options, placeholder: "Select status…")
            }
            DMStepSection(title: "Pre-engagement checks")
            DMToggleRow("Right-to-Work verified",
                        subtitle: "Passport / share-code seen and recorded",
                        isOn: $wiz.rtwVerified)
            DMToggleRow("Data privacy consent",
                        subtitle: "Crew member has signed the GDPR data-handling notice",
                        isOn: $wiz.dataConsent)
            DMToggleRow("All onboarding documents received",
                        subtitle: "Bank details, P45/P46, emergency contact",
                        isOn: $wiz.documentsReceived)
        }
    }
}
