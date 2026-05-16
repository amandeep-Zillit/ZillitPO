//
//  Step2Crew.swift
//  ZillitPO
//
//  Port of `Step2Crew.jsx`. Crew member identity + employment.
//

import SwiftUI

struct Step2Crew: View {
    @EnvironmentObject var wiz: DMWizardState
    @EnvironmentObject var dm: DealMemoViewModel

    private let crewTypes = ["Permanent", "Freelance (Schedule D)", "Day Call", "Loan-out"]
    private let departmentList: [String] = {
        DepartmentsData.all.compactMap { $0.identifier }.sorted()
    }()

    var body: some View {
        DMStepChrome(
            stepNumber: 2,
            title: "Crew Details",
            subtitle: "Who the deal memo is for."
        ) {
            DMFieldGroup("Crew Member") {
                DMTextField(text: $wiz.crewMemberName, placeholder: "— Select Crew Member —")
            }
            DMFieldGroup("Department") {
                DMPicker(selection: $wiz.department, options: departmentList, placeholder: "Select department…")
            }
            DMFieldGroup("Job Title / Role") {
                DMTextField(text: $wiz.jobTitle, placeholder: "e.g. Gaffer")
            }
            DMFieldGroup("Custom Job Title") {
                DMTextField(text: $wiz.customJobTitle, placeholder: "Enter job title / credit…")
            }
            DMFieldGroup("Crew Type") {
                DMPicker(selection: $wiz.crewType, options: crewTypes, placeholder: "Select type…")
            }
            DMFieldGroup("Reports To") {
                DMTextField(text: $wiz.reportsTo, placeholder: "Department head, line producer…")
            }
        }
    }
}
