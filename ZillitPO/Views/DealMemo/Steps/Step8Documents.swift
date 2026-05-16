//
//  Step8Documents.swift
//  ZillitPO
//
//  Port of `Step8Documents.jsx` — signature workflow flags + supporting
//  document attachments. Demo wires the flags; attachment upload uses
//  the same `SwiftUIUtils.uploadAttachmentModel` shim (multipart in
//  demo, S3 in live).
//

import SwiftUI

struct Step8Documents: View {
    @EnvironmentObject var wiz: DMWizardState

    var body: some View {
        DMStepChrome(
            stepNumber: 8,
            title: "Additional Documents",
            subtitle: "Signing flow + supporting contract attachments."
        ) {
            DMStepSection(title: "Signature workflow")
            DMToggleRow("DocuSign — electronic signing",
                        subtitle: "Route the deal memo through DocuSign for crew + producer signatures",
                        isOn: $wiz.docuSignEnabled)
            DMToggleRow("Require crew counter-signature",
                        subtitle: "Crew member must sign before the deal can activate",
                        isOn: $wiz.requireCrewCounterSignature)
            DMToggleRow("Require senior accountant sign-off before issue",
                        subtitle: "Financial Controller / Production Accountant must approve",
                        isOn: $wiz.requireSeniorAccountantSignOff)
            DMToggleRow("Copy to production office",
                        subtitle: "Auto-CC the production office on the signed PDF",
                        isOn: $wiz.copyToProductionOffice)

            DMStepSection(title: "Attachments")
            VStack(alignment: .leading, spacing: 8) {
                Text("Contract, NDA, annexes")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Button(action: { /* TODO: file picker → SwiftUIUtils.uploadAttachmentModel */ }) {
                    HStack {
                        Image(systemName: "paperclip")
                        Text("Add attachment")
                        Spacer()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12).padding(.vertical, 12)
                    .foregroundColor(.goldDark)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldDark.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4])))
                }.buttonStyle(BorderlessButtonStyle())
            }
        }
    }
}
