import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Out of Pocket Module (role-based tabs)
// ═══════════════════════════════════════════════════════════════════

struct OutOfPocketModuleView: View {
    @EnvironmentObject var appState: POViewModel

    private var isAcct: Bool { appState.currentUser?.isAccountant == true }
    private var isApprover: Bool { appState.cashMeta?.isApprover == true }
    private var isSenior: Bool { appState.cashMeta?.isSenior == true }

    private var isCoord: Bool { appState.cashMeta?.isCoordinator == true }

    private var tabs: [String] {
        if isAcct {
            return ["Payment Routing"]
        }
        if isCoord {
            return ["Submit Receipts", "Receipts History"]
        }
        // User (Crew)
        return ["Submit Receipts", "Receipts History"]
    }

    @State private var activeTab = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    let isActive = activeTab == tab
                    Button(action: { activeTab = tab }) {
                        Text(tab).font(.system(size: 11, weight: isActive ? .semibold : .regular)).lineLimit(1)
                            .foregroundColor(isActive ? .goldDark : .secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .overlay(isActive ? Rectangle().fill(Color.goldDark).frame(height: 2) : nil, alignment: .bottom)
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)

            oopTabContent
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Out of Pocket"), displayMode: .inline)
        .onAppear {
            if activeTab.isEmpty { activeTab = isAcct ? "Payment Routing" : "Submit Receipts" }
            appState.loadCashExpenseMetadata()
        }
    }

    private func oopStatCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(.primary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(10)
        .background(Color.bgSurface).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
    }

    private func oopStatsCards(_ claims: [ClaimBatch], firstLabel: String) -> some View {
        let total = claims.reduce(0.0) { $0 + ($1.totalGross ?? 0) }
        let claimants = Set(claims.map { $0.userId ?? "" }).count
        return HStack(spacing: 8) {
            oopStatCard(label: firstLabel, value: "\(claims.count)")
            oopStatCard(label: "TOTAL VALUE", value: FormatUtils.formatGBP(total))
            oopStatCard(label: "CLAIMANTS", value: "\(claimants)")
        }
        .frame(height: 64)
        .padding(.horizontal, 16).padding(.top, 12)
    }

    @ViewBuilder
    private var oopTabContent: some View {
        switch activeTab {
        case "Post & Ledger":
            let c = appState.allOOPClaims.filter { ["READY_TO_POST", "POSTED"].contains(($0.status ?? "").uppercased()) }
            VStack(spacing: 0) {
                oopStatsCards(c, firstLabel: "BATCHES")
                ClaimsListView(claims: c, title: "Post & Ledger", isLoading: appState.isLoadingAllClaims, hideFilterSearch: true).environmentObject(appState)
            }
            .onAppear { appState.loadAllClaims() }
        case "Payment Routing":
            PaymentRoutingView().environmentObject(appState)
        case "Approval Queue":
            ApprovalQueuePage().environmentObject(appState)
        case "History":
            let c = appState.allOOPClaims
            VStack(spacing: 0) {
                oopStatsCards(c, firstLabel: "BATCHES")
                ClaimsListView(claims: c, title: "History", isLoading: appState.isLoadingAllClaims).environmentObject(appState)
            }
            .onAppear { appState.loadAllClaims() }
        case "Coding Queue":
            ClaimsListView(claims: appState.codingQueue, title: "Coding Queue", isLoading: appState.isLoadingCodingQueue, filterMode: .expenseType).environmentObject(appState)
                .onAppear { appState.loadCodingQueue() }
        case "Submit Receipts":
            SubmitClaimFormView(expenseType: "oop").environmentObject(appState)
        case "Receipts History":
            ClaimsListView(claims: appState.myOOPClaims, title: "Receipts History", isLoading: appState.isLoadingMyClaims, filterMode: .myClaims).environmentObject(appState)
                .onAppear { appState.loadMyClaims() }
        default: EmptyView()
        }
    }
}
