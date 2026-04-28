import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Generic Card List Page (for hub tiles)
// ═══════════════════════════════════════════════════════════════════

enum CardListSource {
    case inbox, all, pending, approval, topUps, history, alerts
}

struct CardListPage: View {
    let title: String
    let source: CardListSource
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToUpload = false

    private var items: [CardTransaction] {
        switch source {
        case .inbox:
            return appState.cardTransactions.filter { ["pending", "pending_receipt"].contains(($0.status ?? "").lowercased()) && !$0.hasReceipt }
        case .all:
            return appState.cardTransactions
        case .pending:
            return appState.cardTransactions.filter { ["pending_coding", "pending_code", "pending_receipt", "pending"].contains(($0.status ?? "").lowercased()) }
        case .approval:
            return appState.cardTransactions.filter { ["awaiting_approval", "escalated", "under_review"].contains(($0.status ?? "").lowercased()) }
        case .topUps:
            // Top-Up uses dedicated TopUpToDoPage; no fallback list here
            return []
        case .history:
            return appState.cardHistory.isEmpty
                ? appState.cardTransactions.filter { ($0.status ?? "").lowercased() == "posted" }
                : appState.cardHistory
        case .alerts:
            // Smart Alerts uses dedicated SmartAlertsPage now
            return []
        }
    }

    private var isLoadingForSource: Bool {
        switch source {
        case .history:                        return appState.isLoadingCardHistory
        case .inbox, .all, .pending, .approval: return appState.isLoadingCardTxns
        default:                              return false
        }
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 10) {
                    if isLoadingForSource && items.isEmpty {
                        LoaderView()
                    } else if items.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "tray").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("Nothing here yet").font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 480)
                    } else {
                        ForEach(items) { tx in
                            NavigationLink(destination: CardTransactionDetailPage(transaction: tx).environmentObject(appState)) {
                                CardTransactionRow(transaction: tx)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 90)
            }

            if source == .inbox {
                Button(action: { navigateToUpload = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text("Upload Receipt").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(Color.gold).cornerRadius(28)
                }
                .padding(.trailing, 20).padding(.bottom, 24)
            }
        }
        .background(Color.bgBase)
        .background(
            NavigationLink(destination: UploadReceiptPage().environmentObject(appState),
                           isActive: $navigateToUpload) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .navigationBarTitle(Text(title), displayMode: .inline)
        .onAppear {
            // Each tile page only loads its own API
            switch source {
            case .topUps: appState.loadTopUpQueue()
            case .alerts: appState.loadSmartAlerts()
            case .history: appState.loadCardHistory()
            case .approval, .all, .pending, .inbox: appState.loadCardTransactions()
            }
        }
    }
}
