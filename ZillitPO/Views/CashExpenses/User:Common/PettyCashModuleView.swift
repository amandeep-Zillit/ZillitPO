import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Petty Cash Module (role-based tabs)
// ═══════════════════════════════════════════════════════════════════

struct PettyCashModuleView: View {
    @EnvironmentObject var appState: POViewModel

    private var isAcct: Bool { appState.currentUser?.isAccountant == true }
    private var isCoord: Bool { appState.cashMeta?.isCoordinator == true }
    private var isSenior: Bool { appState.cashMeta?.isSenior == true }

    /// A float is "open" when it's not in a terminal state.
    /// Terminal statuses (backend FloatRequestService): CLOSED, CANCELLED, REJECTED.
    private var hasOpenFloat: Bool {
        let terminal: Set<String> = ["CLOSED", "CANCELLED", "REJECTED"]
        return appState.myFloats.contains { !terminal.contains(($0.status ?? "").uppercased()) }
    }

    /// Whether the New Float button should be visible for the current role/tab.
    /// Hidden while underlying data is still loading so the button only appears
    /// once we know whether the user/account is in a state to create a float.
    private var showNewFloatButton: Bool {
        if isAcct {
            // Accountants see the button on the Active Floats register (to add on behalf of users).
            // Wait for activeFloats to finish loading so it shows up after the loader, not over it.
            return activeTab == "Active Floats" && !appState.isLoadingActiveFloats
        }
        // Crew / coordinator request new floats from the Float Request tab.
        // Wait for myFloats to load so we know whether they already have an open float.
        return activeTab == "Float Request" && !appState.isLoadingMyFloats
    }

    /// Whether the button should be disabled (tappable → opens form).
    private var newFloatDisabled: Bool {
        // Accountants can always create floats — on behalf of any user, no personal open-float restriction
        if isAcct { return false }
        // Crew/coord can only have one open float at a time
        return hasOpenFloat
    }

    private var tabs: [String] {
        if isAcct {
            return ["Active Floats", "Top-ups"]
        }
        if isCoord {
            return ["Active Floats", "Float Request", "Submit Receipts", "Receipts History"]
        }
        // User (Crew)
        return ["Float Request", "Submit Receipts", "Receipts History"]
    }

    @State private var activeTab = ""
    @State private var navigateToNewFloat = false

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Tab bar
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

                // Info banner — sits directly under the tab bar and shows
                // only on the tabs where the New Float button is visible
                // but disabled (Active Floats / Float Request for a user
                // who already has an open float). `showNewFloatButton`
                // already gates this to those two tabs, so switching to
                // Submit Receipts / Receipts History hides the banner.
                if showNewFloatButton && newFloatDisabled {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.goldDark)
                            .padding(.top, 1)
                        Text("You can't create a new float until your previous float is closed, cancelled or approved.")
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gold.opacity(0.12))
                    .overlay(Rectangle().fill(Color.gold.opacity(0.3)).frame(height: 1), alignment: .bottom)
                }

                // Content
                cashTabContent
            }

            if showNewFloatButton {
                Button(action: { navigateToNewFloat = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text("New Float").font(.system(size: 14, weight: .bold))
                    }
                    // Solid disabled state — swap fg/bg to a neutral grey
                    // pair so the button stays fully opaque (no see-through
                    // onto the list behind) but clearly reads as inactive.
                    // Gold/black when enabled — matches the rest of the UI.
                    .foregroundColor(newFloatDisabled ? Color(white: 0.55) : .black)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(newFloatDisabled ? Color(white: 0.85) : Color.gold)
                    .cornerRadius(28)
                }
                .disabled(newFloatDisabled)
                .padding(.trailing, 20).padding(.bottom, 24)
            }
        }
        .background(
            NavigationLink(destination: FloatRequestFormView().environmentObject(appState).navigationBarTitle(Text("New Float"), displayMode: .inline), isActive: $navigateToNewFloat) { EmptyView() }
                .frame(width: 0, height: 0).hidden()
        )
        .background(Color.bgBase)
        .navigationBarTitle(Text("Petty Cash"), displayMode: .inline)
        .onAppear {
            if activeTab.isEmpty { activeTab = isAcct ? "Active Floats" : isCoord ? "Active Floats" : "Float Request" }
            appState.loadCashExpenseMetadata()
        }
    }

    @ViewBuilder
    private var cashTabContent: some View {
        switch activeTab {
        case "Active Floats":
            FloatsListView(floats: appState.activeFloats).environmentObject(appState)
                .onAppear { appState.loadActiveFloats() }
        case "Post & Ledger":
            ClaimsListView(claims: appState.allPettyCashClaims.filter { ["READY_TO_POST", "POSTED"].contains(($0.status ?? "").uppercased()) }, title: "Post & Ledger", isLoading: appState.isLoadingAllClaims, hideFilterSearch: true).environmentObject(appState)
                .onAppear { appState.loadAllClaims() }
        case "Approval Queue":
            ApprovalQueuePage().environmentObject(appState)
        case "History":
            ClaimsListView(claims: appState.allPettyCashClaims, title: "History", isLoading: appState.isLoadingAllClaims).environmentObject(appState)
                .onAppear { appState.loadAllClaims() }
        case "Top-ups":
            CashTopUpsView().environmentObject(appState)
        case "Coding Queue":
            CodingQueueListView(claims: appState.codingQueue, isLoading: appState.isLoadingCodingQueue).environmentObject(appState)
                .onAppear { appState.loadCodingQueue() }
        case "Float Request":
            FloatRequestListView().environmentObject(appState)
                .onAppear { appState.loadMyFloats() }
        case "Submit Receipts":
            SubmitClaimFormView(expenseType: "pc").environmentObject(appState)
        case "Receipts History":
            ClaimsListView(claims: appState.myPettyCashClaims, title: "Receipts History", isLoading: appState.isLoadingMyClaims, filterMode: .myClaims).environmentObject(appState)
                .onAppear { appState.loadMyClaims() }
        default: EmptyView()
        }
    }
}
