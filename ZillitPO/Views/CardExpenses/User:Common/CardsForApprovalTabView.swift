import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Tab 3: Cards for Approval
// ═══════════════════════════════════════════════════════════════════

struct CardsForApprovalTabView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var rejectTarget: ExpenseCard?
    @State private var rejectReason = ""
    @State private var showRejectSheet = false
    /// Override sheet state — only relevant when the user has card-
    /// override permission. Hidden otherwise.
    @State private var overrideTarget: ExpenseCard?
    @State private var overrideReason = ""
    @State private var showOverrideSheet = false

    private var cards: [ExpenseCard] { appState.cardsForApproval() }

    /// Per-card visibility check — returns `true` only when the current
    /// user is allowed to approve at this card's active tier. Used to
    /// gate the inline Approve / Reject buttons on every row.
    private func canApprove(_ card: ExpenseCard) -> Bool {
        guard let cfg = ApprovalHelpers.resolveConfig(
            appState.cardTierConfigRows,
            deptId: card.departmentId,
            amount: card.monthlyLimit ?? 0
        ) else { return false }
        var po = PurchaseOrder()
        po.id = card.id
        po.userId = card.holderId
        po.departmentId = card.departmentId
        po.status = "PENDING"
        po.approvals = card.approvals ?? []
        po.netAmount = card.monthlyLimit ?? 0
        return ApprovalHelpers.getVisibility(po: po, config: cfg, userId: appState.userId).canApprove
    }

    /// Whether the current user has card-override privilege.
    private var canOverride: Bool { appState.cashMeta?.canOverride == true }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 12) {
                    if appState.isLoadingCards && cards.isEmpty {
                        LoaderView()
                            .frame(maxWidth: .infinity, minHeight: 480)
                    } else if cards.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark.seal").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                            Text("No cards pending approval").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 480)
                    } else {
                        ForEach(cards) { card in
                            ApprovalCardRow(
                                card: card,
                                tierConfigs: appState.cardTierConfigRows,
                                canApprove: canApprove(card),
                                canOverride: canOverride,
                                onApprove: { appState.approveCard(card) },
                                onReject: { rejectTarget = card; showRejectSheet = true },
                                onOverride: canOverride ? {
                                    overrideTarget = card; showOverrideSheet = true
                                } : nil
                            )
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
            }
        }
        .onAppear { appState.loadAllRequestedCards() }
        .sheet(isPresented: $showRejectSheet) {
            NavigationView {
                ZStack {
                    Color.bgBase.edgesIgnoringSafeArea(.all)
                    VStack(alignment: .leading, spacing: 16) {
                        if let c = rejectTarget {
                            Text("Reject card request from \(c.holderName ?? "")").font(.system(size: 15, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reason").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                            TextField("Enter reason…", text: $rejectReason)
                                .font(.system(size: 14)).padding(10)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        Spacer()
                    }.padding()
                }
                .navigationBarTitle(Text("Reject Card"), displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") { showRejectSheet = false; rejectReason = "" }.foregroundColor(.goldDark),
                    trailing: Button("Reject") {
                        guard let c = rejectTarget, !rejectReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        appState.rejectCard(c, reason: rejectReason.trimmingCharacters(in: .whitespaces))
                        showRejectSheet = false; rejectReason = ""; rejectTarget = nil
                    }.foregroundColor(.red).font(.system(size: 16, weight: .bold))
                )
            }
        }
        .sheet(isPresented: $showOverrideSheet) {
            NavigationView {
                ZStack {
                    Color.bgBase.edgesIgnoringSafeArea(.all)
                    VStack(alignment: .leading, spacing: 16) {
                        if let c = overrideTarget {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "bolt.fill").font(.system(size: 14)).foregroundColor(.orange)
                                Text("This will approve the card for \(c.holderFullName), bypassing the normal approval chain.")
                                    .font(.system(size: 12)).foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.08)).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Override reason (optional)").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                            TextField("Reason…", text: $overrideReason)
                                .font(.system(size: 14)).padding(10)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        Spacer()
                    }.padding()
                }
                .navigationBarTitle(Text("Override Card Approval"), displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") { showOverrideSheet = false; overrideReason = ""; overrideTarget = nil }.foregroundColor(.goldDark),
                    trailing: Button("Override") {
                        guard let c = overrideTarget else { return }
                        appState.overrideCard(c)
                        showOverrideSheet = false; overrideReason = ""; overrideTarget = nil
                    }.foregroundColor(.orange).font(.system(size: 16, weight: .bold))
                )
            }
        }
    }
}
