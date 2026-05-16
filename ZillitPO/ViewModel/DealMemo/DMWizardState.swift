//
//  DMWizardState.swift
//  ZillitPO
//
//  Wizard state container — port of `client/src/components/deal-memo/hooks/useWizardData.js`.
//  One @StateObject lives at the DMCreatePage level and is injected into
//  every step view via @EnvironmentObject. Each step binds the fields it
//  owns; the host page reads `completedSteps` + `currentStep` to drive
//  the 10-step list display.
//

import Foundation
import SwiftUI

final class DMWizardState: ObservableObject {

    // MARK: - Navigation state
    @Published var currentStep: Int = 1
    @Published var completedSteps: Set<Int> = []

    // MARK: - Step 1: Territory & Union
    @Published var productionEntity: String = ""
    @Published var productionType: String = ""        // film / tv-drama / commercial / …
    @Published var territory: String = ""             // UK / US / EU / Global
    @Published var budgetBand: String = ""            // <£1m / £1-5m / £5-10m / >£10m
    @Published var unionAgreement: String = ""        // BECTU / NABET / Equity / non-union
    @Published var ruleset: String = ""

    // MARK: - Step 2: Crew Details
    @Published var crewMemberId: String = ""
    @Published var crewMemberName: String = ""
    @Published var department: String = ""
    @Published var jobTitle: String = ""
    @Published var customJobTitle: String = ""
    @Published var crewType: String = ""              // permanent / freelance / day-call
    @Published var reportsTo: String = ""

    // MARK: - Step 3: Compliance & Onboarding
    @Published var ir35Status: String = ""            // inside / outside / not-applicable
    @Published var rtwVerified: Bool = false
    @Published var dataConsent: Bool = false
    @Published var documentsReceived: Bool = false

    // MARK: - Step 4: Deal Structure
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 30 * 6) // ~6 months
    @Published var billingBasis: String = "Weekly"    // Weekly / Daily / Hourly / Fixed
    @Published var prepShootWrapSchedule: String = ""
    @Published var negotiatedNoticeTerms: String = ""
    @Published var dealNotes: String = ""

    // MARK: - Step 5: Rates & Compensation
    @Published var dailyRate: Double = 0
    @Published var weeklyRate: Double = 0
    @Published var contractCurrency: String = "GBP"
    @Published var otTier1Multiplier: Double = 1.5    // 1.5×
    @Published var otTier2Multiplier: Double = 2.0    // 2.0×
    @Published var holidayPayTreatment: String = ""   // rolled-up / accrued
    @Published var pensionScheme: String = ""

    // MARK: - Step 6: Allowances & Rentals
    @Published var perDiemDaily: Double = 0
    @Published var kitRentalAmount: Double = 0
    @Published var kitRentalFrequency: String = "Weekly"
    @Published var carAllowance: Double = 0
    @Published var travelZoneElection: String = ""    // Zone 1 / 2 / 3 / Distant
    @Published var distantLocationApplies: Bool = false

    // MARK: - Step 6b: Credit Conditions
    @Published var creditConditions: [String] = []
    @Published var bookendCredit: String = ""

    // MARK: - Step 7: Nominal Coding
    @Published var nominalCode: String = ""
    @Published var costCentre: String = ""
    @Published var coreCreativeClassification: Bool = false
    @Published var ukSpend: Bool = false
    @Published var taxCreditRate: String = ""

    // MARK: - Step 8: Additional Documents
    @Published var docuSignEnabled: Bool = true
    @Published var requireCrewCounterSignature: Bool = true
    @Published var requireSeniorAccountantSignOff: Bool = false
    @Published var copyToProductionOffice: Bool = true

    // MARK: - Step 9: Payroll Start Form
    @Published var firstPayPeriodStart: Date = Date()
    @Published var payFrequency: String = "Weekly"    // Weekly / Bi-weekly / Monthly
    @Published var autoSyncToPayroll: Bool = true
    @Published var notifyPayrollContact: Bool = true
    @Published var includePdfInBureauExport: Bool = true

    // MARK: - API

    /// Mark a step complete and advance the cursor.
    func markCompleted(_ step: Int) {
        completedSteps.insert(step)
        if step < 10 { currentStep = max(currentStep, step + 1) }
    }

    /// Reset the wizard — wired to the "Discard" button on DMCreatePage.
    func discard() {
        currentStep = 1
        completedSteps.removeAll()
        // (Demo: we don't bother resetting individual fields since the
        //  user is about to navigate away. Live's useWizardData clears
        //  via setData({}).)
    }

    var progress: Double {
        guard !completedSteps.isEmpty else { return 0 }
        return Double(completedSteps.count) / 10.0
    }
}
