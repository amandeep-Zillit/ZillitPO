import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Expenses — Accountant Hub
// ═══════════════════════════════════════════════════════════════════

struct CardExpensesAccountantHub: View {
    @EnvironmentObject var appState: POViewModel

    private var meta: CardExpenseMeta { appState.cardExpenseMeta }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                hubTile(icon: "creditcard.fill", color: .goldDark, title: "Card Register",
                        subtitle: "View & manage company cards",
                        count: (meta.cardRegister ?? 0) > 0 ? (meta.cardRegister ?? 0) : appState.userCards.count,
                        destination: AnyView(CardRegisterPage().environmentObject(appState)))

                hubTile(icon: "tray.full.fill", color: .orange, title: "Receipt Inbox",
                        subtitle: "Receipts awaiting transaction match",
                        count: meta.receiptInbox ?? 0,
                        destination: AnyView(ReceiptInboxPage().environmentObject(appState)))

                hubTile(icon: "list.bullet.rectangle.fill", color: .blue, title: "All Transactions",
                        subtitle: "Every card transaction",
                        count: meta.allTransactions ?? 0,
                        destination: AnyView(AllTransactionsPage().environmentObject(appState)))

                hubTile(icon: "clock.badge.exclamationmark.fill", color: .purple, title: "Pending Coding",
                        subtitle: "Receipts awaiting budget coding",
                        count: meta.pendingCoding ?? 0,
                        destination: AnyView(PendingCodingPage().environmentObject(appState)))

                hubTile(icon: "person.badge.shield.checkmark.fill", color: .goldDark, title: "Approval Queue",
                        subtitle: "Awaiting your approval",
                        count: meta.approvalQueue ?? 0,
                        destination: AnyView(AccountantApprovalQueuePage().environmentObject(appState)))

                hubTile(icon: "wallet.pass.fill", color: Color(red: 0, green: 0.6, blue: 0.5), title: "Top-Up To Do",
                        subtitle: "Pending top-ups to action",
                        count: meta.topUps ?? 0,
                        destination: AnyView(TopUpToDoPage().environmentObject(appState)))

                hubTile(icon: "clock.arrow.circlepath", color: .gray, title: "History",
                        subtitle: "Posted & completed transactions",
                        count: meta.history ?? 0,
                        destination: AnyView(CardListPage(title: "History", source: .history).environmentObject(appState)))

                hubTile(icon: "exclamationmark.triangle.fill", color: .red, title: "Smart Alerts",
                        subtitle: "Flagged or unusual activity",
                        count: meta.smartAlerts ?? 0,
                        destination: AnyView(SmartAlertsPage().environmentObject(appState)))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .onAppear { appState.loadCardExpenseMeta() }
    }

    private func hubTile(icon: String, color: Color, title: String, subtitle: String, count: Int, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(.white)
                    .frame(width: 38, height: 38).background(color).cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.system(size: 15, weight: .semibold))
                        if count > 0 {
                            Text("\(count)").font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(color).cornerRadius(8)
                        }
                    }
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(color)
            }
            .padding(14).background(Color.bgSurface).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(PlainButtonStyle())
    }
}
