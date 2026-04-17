//
//  CardExpensesModuleView.swift
//  ZillitPO
//

import SwiftUI
import WebKit

// MARK: - Tabs

enum CardExpenseTab: String, CaseIterable, Identifiable {
    case receipts = "My Transactions"
    case card = "Card"
    case approval = "Approval Queue"
    case coding = "Coding Queue"
    var id: String { rawValue }
}

enum ReceiptFilter: String, CaseIterable {
    case all = "All"
    case pendingReceipt = "Pending Receipt"
    case pendingCode = "Pending Code"
    case awaitingApproval = "Awaiting Approval"
    case approved = "Approved"
    case queried = "Queried"
    case underReview = "Under Review"
    case escalated = "Escalated"
    case posted = "Posted"
}

// MARK: - Card Expenses Module

struct CardExpensesModuleView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var activeTab: CardExpenseTab = .receipts

    private var isCoordinator: Bool { appState.cardExpenseMeta.isCoordinator ?? false }

    private var visibleTabs: [CardExpenseTab] {
        if isCoordinator {
            return [.receipts, .card, .approval, .coding]
        }
        if appState.isCardApprover {
            return [.receipts, .card, .approval]
        }
        return [.receipts, .card]
    }

    var body: some View {
        Group {
            if appState.currentUser?.isAccountant == true {
                CardExpensesAccountantHub().environmentObject(appState)
            } else {
                VStack(spacing: 0) {
                    // Tab bar — full width for user/approver, scrollable for coordinator
                    if isCoordinator {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(visibleTabs) { tab in
                                    cardTabButton(tab)
                                }
                            }
                        }
                        .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)
                    } else {
                        HStack(spacing: 0) {
                            ForEach(visibleTabs) { tab in
                                cardTabButton(tab).frame(maxWidth: .infinity)
                            }
                        }
                        .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)
                    }

                    // Content
                    switch activeTab {
                    case .receipts: ReceiptsTabView().environmentObject(appState)
                    case .card: CardTabView().environmentObject(appState)
                    case .approval:
                        if isCoordinator {
                            CoordinatorApprovalQueueView().environmentObject(appState)
                        } else {
                            CardsForApprovalTabView().environmentObject(appState)
                        }
                    case .coding:
                        CardCodingQueuePage().environmentObject(appState)
                    }
                }
            }
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Card Expenses"), displayMode: .inline)
        .onAppear { appState.loadAllCardExpenseData() }
    }

    @ViewBuilder
    private func cardTabButton(_ tab: CardExpenseTab) -> some View {
        let isActive = activeTab == tab
        Button(action: { activeTab = tab }) {
            HStack(spacing: 4) {
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                if tab == .approval {
                    let count = appState.cardsForApproval().count
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.goldDark).cornerRadius(8)
                    }
                }
            }
            .foregroundColor(isActive ? .goldDark : .secondary)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .contentShape(Rectangle())
            .overlay(isActive ? Rectangle().fill(Color.goldDark).frame(height: 2) : nil, alignment: .bottom)
        }.buttonStyle(BorderlessButtonStyle())
    }
}
