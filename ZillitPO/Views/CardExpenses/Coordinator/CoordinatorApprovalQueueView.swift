import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Coordinator Approval Queue (two sections — Cards / Receipts & Transactions)
// ═══════════════════════════════════════════════════════════════════

struct CoordinatorApprovalQueueView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var section: String = "cards"
    @State private var rejectTarget: ExpenseCard?
    @State private var rejectReason = ""
    @State private var showRejectSheet = false
    /// Override-card sheet state. The button is gated behind
    /// `appState.cashMeta?.canOverride == true`; when the user lacks the
    /// permission these stay unused and the button is hidden.
    @State private var overrideTarget: ExpenseCard?
    @State private var overrideReason = ""
    @State private var showOverrideSheet = false

    /// Shim a card into a PurchaseOrder so we can reuse the existing
    /// `ApprovalHelpers.getVisibility` (which is keyed on POs).
    private func cardAsPO(_ card: ExpenseCard) -> PurchaseOrder {
        var po = PurchaseOrder()
        po.id = card.id
        po.userId = card.holderId
        po.departmentId = card.departmentId
        po.status = "PENDING"
        po.approvals = card.approvals ?? []
        po.netAmount = card.monthlyLimit ?? 0
        return po
    }

    private var cards: [ExpenseCard] { appState.cardsForApproval() }
    private var transactions: [CardTransaction] { appState.cardApprovalQueueItems }

    var body: some View {
        VStack(spacing: 12) {
            // Two stat cards
            HStack(spacing: 10) {
                sectionCard(key: "cards", icon: "creditcard.fill", title: "Cards", subtitle: "\(cards.count) pending approval", count: cards.count)
                sectionCard(key: "tx", icon: "doc.text", title: "Receipts / Transactions", subtitle: "\(transactions.count) items", count: transactions.count)
            }
            .frame(height: 70)
            .padding(.horizontal, 16).padding(.top, 12)

            // Active section content
            if section == "cards" {
                ScrollView {
                    VStack(spacing: 12) {
                        if appState.isLoadingCards && cards.isEmpty {
                            LoaderView()
                                .frame(maxWidth: .infinity, minHeight: 400)
                        } else if cards.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "creditcard").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No cards pending your approval.").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 400)
                        } else {
                            ForEach(cards) { card in
                                let cardVis = ApprovalHelpers
                                    .resolveConfig(appState.cardTierConfigRows,
                                                   deptId: card.departmentId,
                                                   amount: card.monthlyLimit ?? 0)
                                    .map { ApprovalHelpers.getVisibility(po: cardAsPO(card), config: $0, userId: appState.userId) }
                                let canApproveCard = cardVis?.canApprove ?? false
                                let canOverrideCard = (appState.cashMeta?.canOverride == true)
                                ApprovalCardRow(
                                    card: card,
                                    tierConfigs: appState.cardTierConfigRows,
                                    canApprove: canApproveCard,
                                    canOverride: canOverrideCard,
                                    onApprove: { appState.approveCard(card) },
                                    onReject: { rejectTarget = card; showRejectSheet = true },
                                    onOverride: canOverrideCard ? { overrideTarget = card; showOverrideSheet = true } : nil
                                )
                            }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 24)
                }
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        if appState.isLoadingCardApprovals && appState.cardApprovalQueueItems.isEmpty {
                            LoaderView()
                        } else if transactions.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No receipts or transactions awaiting approval.").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 400)
                        } else {
                            ForEach(transactions) { tx in
                                NavigationLink(destination: CardTransactionDetailPage(transaction: tx).environmentObject(appState)) {
                                    CardTransactionRow(transaction: tx)
                                }.buttonStyle(PlainButtonStyle())
                            }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 24)
                }
            }
        }
        .background(Color.bgBase)
        .onAppear {
            appState.loadAllRequestedCards()    // GET /card-expenses/cards?status=pending&for_approval=true
            appState.loadCardApprovalQueue()    // GET /card-expenses/approvals
        }
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

    private func sectionCard(key: String, icon: String, title: String, subtitle: String, count: Int) -> some View {
        let isActive = section == key
        return Button(action: { section = key }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(.goldDark)
                    .frame(width: 28, height: 28).background(Color.gold.opacity(0.15)).cornerRadius(6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle().fill(Color.goldDark).frame(width: 20, height: 20)
                    Text("\(count)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.bgSurface).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isActive ? Color.goldDark : Color.borderColor, lineWidth: isActive ? 2 : 1))
        }.buttonStyle(PlainButtonStyle())
    }
}
