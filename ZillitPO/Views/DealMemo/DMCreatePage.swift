//
//  DMCreatePage.swift
//  ZillitPO
//
//  Wizard host — matches the iOS design. Owns the `DMWizardState`
//  StateObject and injects it via `environmentObject` into every step
//  view. Tapping a row pushes that step's screen; each step's "Next"
//  button calls `wiz.markCompleted(n)` and the row's badge flips to
//  green automatically.
//

import SwiftUI

struct DMCreatePage: View {
    @EnvironmentObject var dm: DealMemoViewModel
    @StateObject private var wiz = DMWizardState()
    @Environment(\.presentationMode) var presentationMode

    /// Single sheet binding driven by step number; SwiftUI navigation
    /// (push) is rendered via the 10 hidden `NavigationLink`s further
    /// down. We use selection-based links so taps on any row push the
    /// matching step.
    @State private var pushedStep: Int? = nil

    private var draftingFor: (name: String, role: String) {
        let name = dm.myDeal.map { dm.crewName(for: $0) } ?? "James Okafor"
        let role = "Gaffer · Electrical"
        return (name, role)
    }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    draftingForHeader
                    draftProgressCard
                    stepListHeader
                    stepList
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            // Hidden links — one per step. SwiftUI 14-compatible
            // navigation; activated by `pushedStep` matching the step #.
            stepNavigationLinks
        }
        .environmentObject(wiz)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { presentationMode.wrappedValue.dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        Text("Deals").font(.system(size: 15))
                    }.foregroundColor(.goldDark)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("New Deal Memo").font(.system(size: 15, weight: .semibold))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { /* TODO: persist current step state as draft */ }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.goldDark)
            }
        }
    }

    // MARK: - Header

    private var draftingForHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DRAFTING FOR")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.goldDark)
                .tracking(0.8)
            Text(draftingFor.name)
                .font(.system(size: 28, weight: .bold))
            Text(draftingFor.role)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Draft progress card

    private var draftProgressCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Draft progress").font(.system(size: 13))
                Spacer()
                Text("\(wiz.completedSteps.count) / \(Self.steps.count) steps")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.goldDark)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.bgRaised).frame(height: 6)
                    Capsule()
                        .fill(Color.goldDark)
                        .frame(width: geo.size.width * CGFloat(wiz.progress), height: 6)
                }
            }
            .frame(height: 6)

            HStack(spacing: 10) {
                Button(action: { pushedStep = wiz.currentStep }) {
                    Text(wiz.completedSteps.isEmpty ? "Start" : "Resume draft")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.goldDark)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }.buttonStyle(BorderlessButtonStyle())

                Button(action: { wiz.discard() }) {
                    Text("Discard")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                        .foregroundColor(.primary)
                }.buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(16)
        .background(Color.bgSurface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderSubtle, lineWidth: 1))
    }

    // MARK: - Step list

    private var stepListHeader: some View {
        Text("DEAL MEMO — \(Self.steps.count) STEPS")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .tracking(0.8)
    }

    private var stepList: some View {
        VStack(spacing: 10) {
            ForEach(Self.steps) { step in
                DMStepRow(
                    step: step,
                    state: state(for: step.number),
                    onTap: { pushedStep = step.number }
                )
            }
        }
    }

    private func state(for n: Int) -> DMStepRowState {
        if wiz.completedSteps.contains(n) { return .completed }
        if n == wiz.currentStep           { return .current }
        return .pending
    }

    // MARK: - Hidden navigation links (one per step)

    @ViewBuilder
    private var stepNavigationLinks: some View {
        ForEach(Self.steps) { step in
            NavigationLink(
                destination: stepDestination(step.number),
                tag: step.number,
                selection: $pushedStep
            ) { EmptyView() }
            .hidden()
        }
    }

    @ViewBuilder
    private func stepDestination(_ n: Int) -> some View {
        switch n {
        case 1:  Step1Territory().environmentObject(wiz).environmentObject(dm)
        case 2:  Step2Crew().environmentObject(wiz).environmentObject(dm)
        case 3:  Step3Compliance().environmentObject(wiz).environmentObject(dm)
        case 4:  Step4DealStructure().environmentObject(wiz).environmentObject(dm)
        case 5:  Step5Rates().environmentObject(wiz).environmentObject(dm)
        case 6:  Step6Allowances().environmentObject(wiz).environmentObject(dm)
        case 7:  Step7Nominal().environmentObject(wiz).environmentObject(dm)
        case 8:  Step8Documents().environmentObject(wiz).environmentObject(dm)
        case 9:  Step9Payroll().environmentObject(wiz).environmentObject(dm)
        case 10: Step10Preview().environmentObject(wiz).environmentObject(dm)
        default: EmptyView()
        }
    }

    // MARK: - Step catalogue

    struct Step: Identifiable {
        let number: Int
        let title: String
        let subtitle: String
        let hasAIBadge: Bool
        var id: Int { number }
    }

    static let steps: [Step] = [
        .init(number: 1,  title: "Territory & Union",      subtitle: "Agreement & ruleset",     hasAIBadge: false),
        .init(number: 2,  title: "Crew Details",           subtitle: "Identity & employment",   hasAIBadge: false),
        .init(number: 3,  title: "Compliance & Onboarding",subtitle: "IR35, RTW, docs",         hasAIBadge: false),
        .init(number: 4,  title: "Deal Structure",         subtitle: "Type, dates, guarantees", hasAIBadge: true),
        .init(number: 5,  title: "Rates & Compensation",   subtitle: "OT tiers, HP treatment",  hasAIBadge: false),
        .init(number: 6,  title: "Allowances & Rentals",   subtitle: "Kit, car, per diem",      hasAIBadge: false),
        .init(number: 7,  title: "Nominal Coding",         subtitle: "Accounts & cost centres", hasAIBadge: false),
        .init(number: 8,  title: "Additional Documents",   subtitle: "Contract, NDA, annexes",  hasAIBadge: false),
        .init(number: 9,  title: "Payroll Start Form",     subtitle: "Bureau & export",         hasAIBadge: false),
        .init(number: 10, title: "Preview & Issue",        subtitle: "Sign & activate",         hasAIBadge: false),
    ]
}

// MARK: - Step row state + row view (shared)

enum DMStepRowState { case completed, current, pending }

struct DMStepRow: View {
    let step: DMCreatePage.Step
    let state: DMStepRowState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                statusBubble
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.system(size: 15, weight: state == .current ? .semibold : .regular))
                        .foregroundColor(state == .current ? Color.goldDark : .primary)
                    Text(step.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if step.hasAIBadge && state == .current {
                    Text("AI")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(red: 0.62, green: 0.40, blue: 0.85).opacity(0.18))
                        .foregroundColor(Color(red: 0.62, green: 0.40, blue: 0.85))
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(state == .current ? Color.goldDark.opacity(0.06) : Color.bgSurface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(state == .current ? Color.goldDark.opacity(0.35) : Color.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(BorderlessButtonStyle())
    }

    private var statusBubble: some View {
        ZStack {
            Circle().fill(bubbleFill).frame(width: 28, height: 28)
            statusContent
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
        case .current:
            Text("\(step.number)").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
        case .pending:
            Text("\(step.number)").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
        }
    }

    private var bubbleFill: Color {
        switch state {
        case .completed: return Color(red: 0.21, green: 0.64, blue: 0.37)
        case .current:   return Color.goldDark
        case .pending:   return Color.bgRaised
        }
    }
}

// MARK: - Step chrome (reused by all 10 step views)

struct DMStepChrome<Content: View>: View {
    let stepNumber: Int
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    @EnvironmentObject var wiz: DMWizardState
    @Environment(\.presentationMode) var presentationMode

    private var canGoBack: Bool { stepNumber > 1 }
    private var canGoNext: Bool { stepNumber < 10 }
    private var isFinal: Bool { stepNumber == 10 }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        content()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 96)
                }
                navBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Step \(stepNumber) of 10")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("STEP \(stepNumber)")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(.goldDark)
            Text(title).font(.system(size: 22, weight: .bold))
            Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary)
        }
    }

    private var navBar: some View {
        HStack(spacing: 10) {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Text(canGoBack ? "Back" : "Cancel")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    .foregroundColor(.primary)
            }.buttonStyle(BorderlessButtonStyle())

            Button(action: advance) {
                Text(isFinal ? "Submit deal memo" : "Save & continue")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.goldDark)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }.buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.bgSurface)
        .overlay(Rectangle().fill(Color.borderColor).frame(height: 0.5), alignment: .top)
    }

    private func advance() {
        wiz.markCompleted(stepNumber)
        presentationMode.wrappedValue.dismiss()
    }
}
