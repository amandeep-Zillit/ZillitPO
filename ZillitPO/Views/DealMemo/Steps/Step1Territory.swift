//
//  Step1Territory.swift
//  ZillitPO
//
//  Port of `client/src/components/deal-memo/steps/Step1Territory.jsx` —
//  Production entity + production type + territory + budget band +
//  union/agreement + ruleset.
//

import SwiftUI

struct Step1Territory: View {
    @EnvironmentObject var wiz: DMWizardState

    private let entities = ["Project Dusk Ltd", "Project Dusk Productions", "Project Dusk Films"]
    private let productionTypes = ["Feature Film", "TV Drama", "Commercial", "Documentary", "Streaming Series"]
    private let territories = ["UK", "US", "EU", "Global"]
    private let budgetBands = ["< £1m", "£1–5m", "£5–10m", "£10–25m", "> £25m"]
    private let unions = ["BECTU", "PACT", "Equity", "NABET", "IATSE", "Non-union"]
    private let rulesets = ["BECTU Standard", "PACT/BECTU Major", "Equity West End", "Custom"]

    var body: some View {
        DMStepChrome(
            stepNumber: 1,
            title: "Territory & Union",
            subtitle: "Agreement & ruleset that govern this deal."
        ) {
            DMFieldGroup("Production Entity") {
                DMPicker(selection: $wiz.productionEntity, options: entities, placeholder: "Select entity…")
            }
            DMFieldGroup("Production Type") {
                DMPicker(selection: $wiz.productionType, options: productionTypes, placeholder: "Select type…")
            }
            DMFieldGroup("Territory") {
                DMPicker(selection: $wiz.territory, options: territories, placeholder: "Select territory…")
            }
            DMFieldGroup("Budget Band") {
                DMPicker(selection: $wiz.budgetBand, options: budgetBands, placeholder: "Select band…")
            }
            DMFieldGroup("Union / Agreement") {
                DMPicker(selection: $wiz.unionAgreement, options: unions, placeholder: "Select agreement…")
            }
            DMFieldGroup("Ruleset") {
                DMPicker(selection: $wiz.ruleset, options: rulesets, placeholder: "Select ruleset…")
            }
        }
    }
}
