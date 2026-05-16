//
//  DealMemoModule.swift
//  ZillitPO
//
//  Tab shell for the Deal Memo module. Mirrors `DealMemoModule.jsx` —
//  defaults to Overview for accountants, My Deal for everyone else;
//  Approval Queue is gated on `metadata.is_approver`. Tab visibility
//  rules live in `DealMemoViewModel.visibleTabs`.
//

import SwiftUI

struct DealMemoModule: View {

    @StateObject private var dm = DealMemoViewModel()
    @State private var didBoot = false

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                header
                tabBar
                Divider().background(Color.borderColor)
                ScrollView {
                    activePage.padding(.top, 8)
                }
            }
        }
        .navigationBarTitle(Text("Deal Memo"), displayMode: .inline)
        .environmentObject(dm)
        .onAppear {
            guard !didBoot else { return }
            didBoot = true
            dm.bootstrap()
            // Pre-load the landing tab so the first paint is data-driven.
            switch dm.defaultTab {
            case .overview:      dm.loadOverview()
            case .myDeal:        dm.loadMyDeal()
            default:             break
            }
            if dm.activeTab == .overview && dm.isAccountant {
                // activeTab default is `.overview`; if the user is a non-
                // accountant the per-page `.onAppear` will fire the right
                // load when their default tab (`.myDeal`) becomes active.
            } else {
                dm.activeTab = dm.defaultTab
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Contracts")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text("Deal Memo")
                .font(.system(size: 20, weight: .bold))
            Text("Create and manage crew deal memos — rates, allowances, contract periods, and signature workflows.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(dm.visibleTabs) { tab in
                    Button(action: { selectTab(tab) }) {
                        Text(tab.label)
                            .font(.system(size: 12, weight: dm.activeTab == tab ? .semibold : .regular))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(
                                ZStack(alignment: .bottom) {
                                    Color.clear
                                    if dm.activeTab == tab {
                                        Rectangle().fill(Color.goldDark).frame(height: 2)
                                    }
                                }
                            )
                            .foregroundColor(dm.activeTab == tab ? .goldDark : .secondary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var activePage: some View {
        switch dm.activeTab {
        case .overview:      DMOverviewPage()
        case .deals:         DMDealsPage()
        case .myDeal:        DMMyDealPage()
        case .approvalQueue: DMApprovalQueuePage()
        case .ratesBible:    DMRatesBiblePage()
        }
    }

    private func selectTab(_ tab: DealMemoTab) {
        dm.activeTab = tab
        switch tab {
        case .overview:      if dm.overview == nil { dm.loadOverview() }
        case .deals:         if dm.deals.isEmpty { dm.loadDeals() }
        case .myDeal:        if dm.myDeal == nil { dm.loadMyDeal() }
        case .approvalQueue: if dm.approvalQueue == nil { dm.loadApprovalQueue() }
        case .ratesBible:    break
        }
    }
}
