//
//  CardExpensesModuleView.swift
//  ZillitPO
//

import SwiftUI
import WebKit

// MARK: - Tabs

enum CardExpenseTab: String, CaseIterable, Identifiable {
    case receipts = "Receipts"
    case card = "Card"
    case approval = "Cards for Approval"
    var id: String { rawValue }
}

enum ReceiptFilter: String, CaseIterable {
    case all = "All", pending = "Pending", matched = "Matched", unmatched = "No Match", personal = "Personal"
}

// MARK: - Card Expenses Module

struct CardExpensesModuleView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var activeTab: CardExpenseTab = .receipts

    private var visibleTabs: [CardExpenseTab] {
        if appState.isCardApprover {
            return [.receipts, .card, .approval]
        }
        return [.receipts, .card]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(visibleTabs) { tab in
                    let isActive = activeTab == tab
                    Button(action: { activeTab = tab }) {
                        HStack(spacing: 4) {
                            Text(tab.rawValue).font(.system(size: 12, weight: isActive ? .semibold : .regular)).lineLimit(1)
                            if tab == .approval {
                                let count = appState.cardsForApproval().count
                                if count > 0 {
                                    Text("\(count)").font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.white).padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Color.goldDark).cornerRadius(8)
                                }
                            }
                        }
                        .foregroundColor(isActive ? .goldDark : .secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10).contentShape(Rectangle())
                        .overlay(isActive ? Rectangle().fill(Color.goldDark).frame(height: 2) : nil, alignment: .bottom)
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)

            // Content
            switch activeTab {
            case .receipts: ReceiptsTabView().environmentObject(appState)
            case .card: CardTabView().environmentObject(appState)
            case .approval: CardsForApprovalTabView().environmentObject(appState)
            }
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Card Expenses"), displayMode: .inline)
        .onAppear { appState.loadAllCardExpenseData() }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Tab 1: Receipts
// ═══════════════════════════════════════════════════════════════════

struct ReceiptsTabView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var searchText = ""
    @State private var activeFilter: ReceiptFilter = .all
    @State private var showFilterSheet = false
    @State private var navigateToDetail = false
    @State private var navigateToUpload = false
    @State private var navigateToAddCode = false
    @State private var selectedReceipt: Receipt?
    @State private var codingReceipt: Receipt?
    @State private var deleteTarget: Receipt?
    @State private var showDeleteAlert = false

    private var filtered: [Receipt] {
        var list = appState.receipts
        switch activeFilter {
        case .pending:   list = list.filter { $0.matchStatus == "pending" || $0.matchStatus == "pending_coding" }
        case .matched:   list = list.filter { $0.matchStatus == "matched" || $0.matchStatus == "coded" || $0.matchStatus == "posted" }
        case .unmatched: list = list.filter { $0.matchStatus == "unmatched" }
        case .personal:  list = list.filter { $0.matchStatus == "personal" }
        case .all: break
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter { ($0.merchantDetected ?? "").lowercased().contains(q) || $0.originalName.lowercased().contains(q) || $0.uploaderName.lowercased().contains(q) }
        }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                // Filter + Search bar
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Button(action: { showFilterSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal.decrease")
                                    .font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                                Text(activeFilter.rawValue)
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.white).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .compatActionSheet(title: "Filter by Status", isPresented: $showFilterSheet, buttons:
                            ReceiptFilter.allCases.map { filter in
                                let label = filter == activeFilter ? "\(filter.rawValue) ✓" : filter.rawValue
                                return CompatActionSheetButton.default(label) { activeFilter = filter }
                            } + [.cancel()]
                        )
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                        TextField("Search receipts…", text: $searchText).font(.system(size: 14))
                    }.padding(10).background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }
                .padding(.horizontal, 16).padding(.top, 12)

                ScrollView {
                    VStack(spacing: 10) {
                        if filtered.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No receipts found").font(.system(size: 13)).foregroundColor(.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 40)
                            .background(Color.white).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                        } else {
                            ForEach(filtered) { r in
                                ReceiptRow(receipt: r,
                                    onTap: { selectedReceipt = r; navigateToDetail = true },
                                    onDelete: { deleteTarget = r; showDeleteAlert = true },
                                    onViewReceipt: { selectedReceipt = r; navigateToDetail = true },
                                    onAddCode: { codingReceipt = r; navigateToAddCode = true }
                                )
                            }
                        }
                    }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 80)
                }
            }

            // Floating upload button
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
        .background(
            Group {
                NavigationLink(destination: Group {
                    if let r = selectedReceipt { ReceiptDetailPage(receipt: r).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToDetail) { EmptyView() }.frame(width: 0, height: 0).hidden()

                NavigationLink(destination: UploadReceiptPage().environmentObject(appState), isActive: $navigateToUpload) { EmptyView() }
                    .frame(width: 0, height: 0).hidden()

                NavigationLink(destination: Group {
                    if let r = codingReceipt { AddCodeLineItemsPage(receipt: r).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToAddCode) { EmptyView() }.frame(width: 0, height: 0).hidden()
            }
        )
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Receipt"),
                message: Text("Are you sure you want to delete \"\(deleteTarget?.originalName ?? "this receipt")\"? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let t = deleteTarget { appState.deleteReceipt(t) }
                    deleteTarget = nil
                },
                secondaryButton: .cancel { deleteTarget = nil }
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Tab 2: Card
// ═══════════════════════════════════════════════════════════════════

struct CardTabView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToRequestCard = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 12) {
                    if appState.userCards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "creditcard").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                            Text("No cards yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                            Text("Request a new card to get started").font(.system(size: 12)).foregroundColor(.gray)
                        }.frame(maxWidth: .infinity).padding(.vertical, 40)
                        .background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    } else {
                        ForEach(appState.userCards) { card in
                            CardRow(card: card, isAccountant: appState.currentUser?.isAccountant ?? false)
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 80)
            }

            // Request new card button
            Button(action: { navigateToRequestCard = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Request Card").font(.system(size: 14, weight: .bold))
                }.foregroundColor(.black)
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.gold).cornerRadius(28)
            }.padding(.trailing, 20).padding(.bottom, 24)
        }
        .background(
            NavigationLink(destination: RequestCardPage().environmentObject(appState), isActive: $navigateToRequestCard) { EmptyView() }
                .frame(width: 0, height: 0).hidden()
        )
    }
}

struct CardRow: View {
    let card: ExpenseCard
    var isAccountant: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top: card icon + status
            HStack {
                Image(systemName: "creditcard.fill").font(.system(size: 18)).foregroundColor(.goldDark)
                Spacer()
                let (fg, bg) = cardStatusColor(card.status)
                Text(card.statusDisplay(isAccountant: isAccountant)).font(.system(size: 10, weight: .semibold)).foregroundColor(fg)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
            }

            if card.status == "active" || card.status == "suspended" {
                // ── Active / Suspended Card ──
                // Card number
                HStack(spacing: 2) {
                    Text("•••• •••• ••••").font(.system(size: 15, design: .monospaced)).foregroundColor(.gray)
                    Text(card.lastFour.isEmpty ? "0000" : card.lastFour)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                }
                // Holder + designation
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.bankName.isEmpty {
                    Text(card.bankName).font(.system(size: 11)).foregroundColor(.secondary)
                }

                // BS Control
                if !card.bsControlCode.isEmpty {
                    HStack {
                        Text("BS Control").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text(card.bsControlCode).font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.bgRaised).cornerRadius(6)
                }

                // Limit / Spent
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit))/mo")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Spent").font(.system(size: 10)).foregroundColor(.secondary)
                        Text(FormatUtils.formatGBP(card.spentAmount))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                }
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.bgRaised).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(card.spendPercent > 0.8 ? Color(red: 0.91, green: 0.29, blue: 0.48) : Color.gold)
                            .frame(width: geo.size.width * CGFloat(min(card.spendPercent, 1.0)), height: 6)
                    }
                }.frame(height: 6)

            } else if card.status == "requested" {
                // ── Requested ──
                Text("Awaiting Review").font(.system(size: 13, design: .monospaced)).foregroundColor(.gray)
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                }
                if card.monthlyLimit > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }

            } else if card.status == "pending" || card.status == "approved" || card.status == "override" {
                // ── Pending Approval / Approved / In-Progress ──
                let displayLabel = card.statusDisplay(isAccountant: isAccountant)
                let color: Color = (card.status == "pending") ? .orange : isAccountant ? .green : .goldDark
                Text(displayLabel).font(.system(size: 13, design: .monospaced)).foregroundColor(color)
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                HStack(spacing: 4) {
                    if !card.holderDesignation.isEmpty { Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary) }
                    if !card.bankName.isEmpty { Text("· \(card.bankName)").font(.system(size: 11)).foregroundColor(.secondary) }
                }
                // BS Control
                if !card.bsControlCode.isEmpty {
                    HStack {
                        Text("BS Control").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text(card.bsControlCode).font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.bgRaised).cornerRadius(6)
                }
                if card.monthlyLimit > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }

            } else if card.status == "rejected" {
                // ── Rejected ──
                Text("Rejected").font(.system(size: 13, design: .monospaced)).foregroundColor(.red)
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                }
                if card.monthlyLimit > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }
                if let reason = card.rejectionReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REJECTION REASON").font(.system(size: 8, weight: .bold)).foregroundColor(Color(red: 0.91, green: 0.29, blue: 0.48)).tracking(0.4)
                        Text(reason).font(.system(size: 12)).foregroundColor(.primary)
                        if let rejBy = card.rejectedBy, !rejBy.isEmpty {
                            HStack(spacing: 4) {
                                Text("By \(UsersData.byId[rejBy]?.fullName ?? rejBy)").font(.system(size: 10)).foregroundColor(.secondary)
                                if let rejAt = card.rejectedAt, rejAt > 0 {
                                    Text("· \(FormatUtils.formatDateTime(rejAt))").font(.system(size: 10)).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.06)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.2), lineWidth: 1))
                }

            } else {
                // ── Other status ──
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
        }
        .padding(14).background(Color.white).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private func cardStatusColor(_ s: String) -> (Color, Color) {
        switch s {
        case "active": return (.green, Color.green.opacity(0.1))
        case "requested": return (.orange, Color.orange.opacity(0.1))
        case "pending": return (.goldDark, Color.gold.opacity(0.15))
        case "approved", "override": return isAccountant ? (.green, Color.green.opacity(0.1)) : (.goldDark, Color.gold.opacity(0.15))
        case "rejected": return (.red, Color.red.opacity(0.1))
        case "suspended": return (.gray, Color.gray.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

struct RequestCardPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var proposedLimit = ""
    @State private var submitting = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Icon header
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard.fill").font(.system(size: 40)).foregroundColor(.gold)
                        Text("Request New Card").font(.system(size: 18, weight: .bold))
                        Text("Your request will be sent to the accounts team for review and approval.")
                            .font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                    .background(Color.white).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                    // Form card
                    VStack(spacing: 0) {
                        formRow(label: "Card Holder", value: appState.currentUser?.fullName ?? "—")
                        Divider().padding(.leading, 14)
                        formRow(label: "Department", value: appState.currentUser?.displayDepartment ?? "—")
                        Divider().padding(.leading, 14)
                        formRow(label: "Designation", value: appState.currentUser?.displayDesignation ?? "—")
                        Divider().padding(.leading, 14)

                        // Proposed limit input
                        HStack {
                            Text("Proposed Limit").font(.system(size: 12)).foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 2) {
                                Text("£").font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark)
                                TextField("e.g. 1500", text: $proposedLimit)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.goldDark)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                            .padding(6).background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Info note
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill").font(.system(size: 14)).foregroundColor(.blue)
                        Text("The accounts team will assign the card issuer, set the final limit, and process your request through the approval chain.")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.04)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.15), lineWidth: 1))

                }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 80)
            }

            // Submit bar
            HStack(spacing: 12) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel").font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())

                Button(action: {
                    guard !submitting, let limit = Double(proposedLimit), limit > 0 else { return }
                    submitting = true
                    appState.requestNewCard(proposedLimit: limit)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(submitting ? "Submitting..." : "Submit Request")
                    }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Double(proposedLimit) ?? 0 > 0 && !submitting ? Color.gold : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(Double(proposedLimit) ?? 0 <= 0 || submitting)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.white)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Request New Card"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
    }

    private func formRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Tab 3: Cards for Approval
// ═══════════════════════════════════════════════════════════════════

struct CardsForApprovalTabView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var rejectTarget: ExpenseCard?
    @State private var rejectReason = ""
    @State private var showRejectSheet = false

    private var cards: [ExpenseCard] { appState.cardsForApproval() }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 12) {
                    if cards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                            Text("No cards pending approval").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 40)
                        .background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    } else {
                        ForEach(cards) { card in
                            ApprovalCardRow(card: card, tierConfigs: appState.cardTierConfigRows, onApprove: {
                                appState.approveCard(card)
                            }, onReject: {
                                rejectTarget = card; showRejectSheet = true
                            })
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showRejectSheet) {
            NavigationView {
                ZStack {
                    Color.bgBase.edgesIgnoringSafeArea(.all)
                    VStack(alignment: .leading, spacing: 16) {
                        if let c = rejectTarget {
                            Text("Reject card request from \(c.holderName)").font(.system(size: 15, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reason").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                            TextField("Enter reason…", text: $rejectReason)
                                .font(.system(size: 14)).padding(10)
                                .background(Color.white).cornerRadius(8)
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
    }
}

struct ApprovalCardRow: View {
    let card: ExpenseCard
    let tierConfigs: [ApprovalTierConfig]
    let onApprove: () -> Void
    let onReject: () -> Void

    private var totalTiers: Int {
        let cfg = ApprovalHelpers.resolveConfig(tierConfigs, deptId: card.departmentId, amount: card.monthlyLimit)
            ?? ApprovalHelpers.resolveConfig(tierConfigs, deptId: nil, amount: card.monthlyLimit)
            ?? ApprovalHelpers.resolveConfig(tierConfigs, deptId: nil)
        return ApprovalHelpers.getTotalTiers(cfg)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top: card icon + Pending (0/2) badge
            HStack {
                Image(systemName: "creditcard.fill").font(.system(size: 18)).foregroundColor(.goldDark)
                Spacer()
                Text("Pending (\(card.approvals.count)/\(totalTiers))")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.orange)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1)).cornerRadius(4)
            }

            // Status label
            Text("Pending Approval").font(.system(size: 13, design: .monospaced)).foregroundColor(.orange)

            // Holder name + designation + bank
            Text(card.holderFullName).font(.system(size: 15, weight: .bold))
            HStack(spacing: 4) {
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                }
                if !card.bankName.isEmpty {
                    Text("· \(card.bankName)").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }

            // BS Control
            if !card.bsControlCode.isEmpty {
                HStack {
                    Text("BS Control").font(.system(size: 11)).foregroundColor(.secondary)
                    Spacer()
                    Text(card.bsControlCode).font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.bgRaised).cornerRadius(8)
            }

            // Proposed Limit
            if card.monthlyLimit > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                    Text("\(FormatUtils.formatGBP(card.monthlyLimit))/mo")
                        .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                }
            }

            // Approval Chain circles (Level 1, Level 2, etc.)
            if totalTiers > 0 {
                HStack(spacing: 0) {
                    ForEach(1...totalTiers, id: \.self) { tier in
                        let isApproved = card.approvals.contains { $0.tierNumber == tier }
                        let isCurrent = !isApproved && (tier == 1 || card.approvals.contains { $0.tierNumber == tier - 1 })

                        if tier > 1 {
                            Rectangle()
                                .fill(card.approvals.contains { $0.tierNumber == tier - 1 } ? Color.green.opacity(0.4) : Color.gray.opacity(0.3))
                                .frame(width: 20, height: 2)
                        }

                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(isApproved ? Color.green : isCurrent ? Color.gold : Color.gray.opacity(0.25))
                                    .frame(width: 28, height: 28)
                                if isApproved {
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                } else if isCurrent {
                                    Circle().fill(Color.white).frame(width: 10, height: 10)
                                }
                            }
                            Text("Level \(tier)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(isApproved ? .green : isCurrent ? .goldDark : .gray)
                            if isApproved {
                                let approver = card.approvals.first { $0.tierNumber == tier }
                                let name = approver.flatMap { UsersData.byId[$0.userId]?.fullName } ?? ""
                                if !name.isEmpty {
                                    Text(name).font(.system(size: 8, weight: .medium)).foregroundColor(.green).lineLimit(1)
                                }
                            } else {
                                Text("Awaiting").font(.system(size: 8)).foregroundColor(isCurrent ? .goldDark : .gray)
                            }
                        }.frame(minWidth: 60)
                    }
                }
                .padding(.vertical, 4)
            }

            // Approve / Reject buttons
            HStack(spacing: 10) {
                Spacer()
                Button(action: onReject) {
                    Text("Reject").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.red).cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle())
                Button(action: onApprove) {
                    Text("Approve").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.green).cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(14).background(Color.white).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt Card (matches web card layout)
// ═══════════════════════════════════════════════════════════════════

struct ReceiptRow: View {
    let receipt: Receipt
    var onTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onViewReceipt: (() -> Void)? = nil
    var onAddCode: (() -> Void)? = nil
    @State private var showFileViewer = false

    private var isImageType: Bool {
        ["jpg", "jpeg", "png", "heic", "heif"].contains(receipt.fileType.lowercased())
    }

    private var thumbnailURL: URL? {
        guard isImageType, !receipt.filePath.isEmpty else { return nil }
        return URL(string: "\(CardExpenseRequest.baseURL)\(receipt.filePath)")
    }

    private var fileViewURL: URL? {
        guard !receipt.filePath.isEmpty else { return nil }
        return URL(string: "\(CardExpenseRequest.baseURL)\(receipt.filePath)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail area — tap opens file viewer
            Button(action: { showFileViewer = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 0).fill(Color.bgRaised)
                    if let url = thumbnailURL {
                        ReceiptThumbnailView(url: url)
                    } else {
                        Image(systemName: receipt.fileType == "pdf" ? "doc.text.fill" : "photo.fill")
                            .font(.system(size: 28)).foregroundColor(.gray.opacity(0.4))
                    }
                }
                .frame(height: 120).frame(maxWidth: .infinity).clipped()
                .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showFileViewer) {
                if let docURL = fileViewURL {
                    ReceiptDocumentViewerSheet(url: docURL, fileName: receipt.originalName)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                // Filename + status badges
                HStack(alignment: .top) {
                    Text(receipt.originalName.isEmpty ? "Receipt" : receipt.originalName)
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                    Spacer()
                    receiptStatusBadge
                }

                // Tag badges (Urgent / Top-Up / Reassigned)
                let tags = receiptTags
                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags, id: \.label) { tag in
                            HStack(spacing: 3) {
                                if let icon = tag.icon {
                                    Image(systemName: icon).font(.system(size: 8))
                                }
                                Text(tag.label).font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(tag.color)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(tag.color.opacity(0.1)).cornerRadius(3)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(tag.color.opacity(0.2), lineWidth: 1))
                        }
                    }
                }

                // Add Code & Line Items button (when no code or needs coding)
                if receipt.nominalCode == nil || receipt.nominalCode?.isEmpty == true || receipt.matchStatus == "pending_coding" {
                    Button(action: { onAddCode?() }) {
                        Text("Add Code & Line Items")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.goldDark)
                            .frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(Color.gold.opacity(0.1)).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                }

                // Receipt Code
                if let code = receipt.nominalCode, !code.isEmpty {
                    HStack {
                        Text("RECEIPT CODE").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                        Spacer()
                        Text(code).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }

                // Extracted items count or merchant/amount
                let itemCount = receipt.lineItems.count
                if itemCount > 0 {
                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s") extracted")
                        .font(.system(size: 10)).foregroundColor(.gray)
                } else if receipt.merchantDetected != nil || receipt.amountDetected != nil {
                    VStack(spacing: 3) {
                        if let m = receipt.merchantDetected {
                            HStack {
                                Text("Merchant").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                                Spacer()
                                Text(m).font(.system(size: 10)).foregroundColor(.primary).lineLimit(1)
                            }
                        }
                        if let a = receipt.amountDetected {
                            HStack {
                                Text("Amount").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                                Spacer()
                                Text("£\(a)").font(.system(size: 10, weight: .semibold, design: .monospaced))
                            }
                        }
                    }
                    .padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                } else {
                    Text("No data extracted")
                        .font(.system(size: 10)).foregroundColor(.gray)
                        .frame(maxWidth: .infinity).padding(8)
                        .background(Color.bgRaised).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundColor(Color.borderColor))
                }

                // View Receipt button
                Button(action: { onViewReceipt?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text").font(.system(size: 10)).foregroundColor(.gray)
                        Text("View Receipt").font(.system(size: 10, weight: .semibold)).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())

                // Footer: file info + date + delete
                HStack {
                    Text("\(receipt.fileType.uppercased()) · \(receipt.fileSizeDisplay)")
                        .font(.system(size: 10)).foregroundColor(.gray)
                    Spacer()
                    if receipt.createdAt > 0 {
                        Text(FormatUtils.formatTimestamp(receipt.createdAt))
                            .font(.system(size: 10)).foregroundColor(.gray)
                    }
                    if let onDelete = onDelete, !["approved", "posted"].contains(receipt.matchStatus) {
                        Button(action: onDelete) {
                            Image(systemName: "trash").font(.system(size: 11)).foregroundColor(.gray)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .padding(10)
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private var receiptStatusBadge: some View {
        let (fg, bg) = statusColors(receipt.matchStatus)
        return Text(receipt.statusDisplay).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 2).background(bg).cornerRadius(3)
    }

    private struct TagInfo: Hashable {
        let label: String; let icon: String?; let color: Color
        func hash(into hasher: inout Hasher) { hasher.combine(label) }
        static func == (lhs: TagInfo, rhs: TagInfo) -> Bool { lhs.label == rhs.label }
    }

    private var receiptTags: [TagInfo] {
        var tags: [TagInfo] = []
        if let type = receipt.uploadType {
            if type.contains("urgent") { tags.append(TagInfo(label: "Urgent", icon: "flame.fill", color: Color(red: 0.91, green: 0.29, blue: 0.48))) }
            if type.contains("topup") { tags.append(TagInfo(label: "Top-Up", icon: "wallet.pass.fill", color: Color(red: 0, green: 0.6, blue: 0.5))) }
        }
        if receipt.reassignCount > 0 {
            tags.append(TagInfo(label: receipt.reassignCount > 1 ? "Reassigned x\(receipt.reassignCount)" : "Reassigned",
                                icon: nil, color: .orange))
        }
        return tags
    }

    private func statusColors(_ s: String) -> (Color, Color) {
        switch s {
        case "pending": return (.orange, Color.orange.opacity(0.1))
        case "pending_coding": return (Color(red: 0.91, green: 0.29, blue: 0.48), Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.1))
        case "coded": return (.blue, Color.blue.opacity(0.1))
        case "matched": return (Color(red: 0, green: 0.6, blue: 0.5), Color(red: 0, green: 0.6, blue: 0.5).opacity(0.1))
        case "posted": return (.green, Color.green.opacity(0.1))
        case "unmatched": return (Color(red: 0.91, green: 0.29, blue: 0.48), Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.1))
        case "personal": return (Color(red: 0.91, green: 0.29, blue: 0.48), Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.1))
        case "duplicate": return (.purple, Color.purple.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt Detail Page
// ═══════════════════════════════════════════════════════════════════

struct ReceiptDetailPage: View {
    let receipt: Receipt
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showDocumentViewer = false

    private var live: Receipt { appState.receipts.first(where: { $0.id == receipt.id }) ?? receipt }

    private var receiptDocumentURL: URL? {
        guard !live.filePath.isEmpty else { return nil }
        return URL(string: "\(CardExpenseRequest.baseURL)\(live.filePath)")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(live.displayMerchant).font(.system(size: 16, weight: .bold))
                            Spacer()
                            let sc = statusColor(live.matchStatus)
                            Text(live.statusDisplay).font(.system(size: 10, weight: .semibold)).foregroundColor(sc.0)
                                .padding(.horizontal, 8).padding(.vertical, 3).background(sc.1).cornerRadius(4)
                        }
                        // View Receipt button
                        Button(action: { showDocumentViewer = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill").font(.system(size: 10))
                                Text("View Receipt").font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.goldDark)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.gold.opacity(0.12)).cornerRadius(4)
                        }.buttonStyle(BorderlessButtonStyle())

                        if live.displayAmount > 0 {
                            Text(FormatUtils.formatGBP(live.displayAmount))
                                .font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        }
                        HStack(spacing: 4) {
                            Text("by").font(.system(size: 11)).foregroundColor(.secondary)
                            Text(live.uploaderName).font(.system(size: 11, weight: .semibold))
                            if !live.uploaderDepartment.isEmpty {
                                Text("· \(live.uploaderDepartment)").font(.system(size: 11)).foregroundColor(.secondary)
                            }
                        }
                        HStack(spacing: 8) {
                            if !live.fileType.isEmpty {
                                Text(live.fileType.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundColor(.gray)
                                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.08)).cornerRadius(4)
                            }
                            if !live.fileSizeDisplay.isEmpty { Text(live.fileSizeDisplay).font(.system(size: 10)).foregroundColor(.secondary) }
                            if let t = live.uploadType, !t.isEmpty {
                                Text(t.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundColor(.blue)
                                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.blue.opacity(0.08)).cornerRadius(4)
                            }
                        }
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Details
                    VStack(spacing: 0) {
                        dRow("Merchant", live.merchantDetected ?? "—")
                        Divider().padding(.leading, 14)
                        dRow("Amount", live.amountDetected.map { "£\($0)" } ?? "—")
                        Divider().padding(.leading, 14)
                        dRow("Date", live.dateDetected ?? "—")
                        if let c = live.nominalCode, !c.isEmpty { Divider().padding(.leading, 14); dRow("Receipt Code", c) }
                        Divider().padding(.leading, 14)
                        dRow("File", live.originalName)
                        Divider().padding(.leading, 14)
                        dRow("Status", live.statusDisplay)
                    }.background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Line items
                    if !live.lineItems.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("LINE ITEMS (\(live.lineItems.count))").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                            ForEach(Array(live.lineItems.enumerated()), id: \.offset) { idx, li in
                                HStack {
                                    if let c = li.code, !c.isEmpty {
                                        Text(c).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.blue)
                                            .padding(.horizontal, 4).padding(.vertical, 1).background(Color.blue.opacity(0.08)).cornerRadius(3)
                                    }
                                    Text(li.description ?? "—").font(.system(size: 11)).lineLimit(1)
                                    Spacer()
                                    Text(FormatUtils.formatGBP(li.amountValue)).font(.system(size: 11, weight: .medium, design: .monospaced))
                                }.padding(.horizontal, 14).padding(.vertical, 6)
                                if idx < live.lineItems.count - 1 { Divider().padding(.horizontal, 14) }
                            }
                            Divider().padding(.horizontal, 14)
                            HStack { Spacer(); Text("Total: ").font(.system(size: 12, weight: .semibold))
                                Text(FormatUtils.formatGBP(live.lineItems.reduce(0) { $0 + $1.amountValue }))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                            }.padding(.horizontal, 14).padding(.vertical, 8)
                        }.background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    // History
                    if !live.history.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("HISTORY").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                            ForEach(Array(live.history.enumerated()), id: \.offset) { idx, entry in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle().fill(Color.goldDark).frame(width: 8, height: 8).padding(.top, 4)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.action ?? "").font(.system(size: 12, weight: .semibold))
                                        if let d = entry.details, !d.isEmpty { Text(d).font(.system(size: 10)).foregroundColor(.secondary) }
                                        if let ts = entry.timestamp, ts > 0 { Text(FormatUtils.formatDateTime(ts)).font(.system(size: 9)).foregroundColor(.gray) }
                                    }
                                    Spacer()
                                }.padding(.horizontal, 14).padding(.vertical, 6)
                            }
                        }.background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }
                }.padding(.horizontal, 16).padding(.top, 14)
                .padding(.bottom, (live.matchStatus == "pending" && appState.currentUser?.isAccountant == true) ? 80 : 24)
            }

            if live.matchStatus == "pending" && appState.currentUser?.isAccountant == true {
                HStack(spacing: 10) {
                    Button(action: { appState.flagReceiptPersonal(live); presentationMode.wrappedValue.dismiss() }) {
                        Text("Flag Personal").font(.system(size: 13, weight: .bold)).foregroundColor(.purple)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                    Spacer()
                    Button(action: { appState.confirmReceipt(live); presentationMode.wrappedValue.dismiss() }) {
                        Text("Confirm").font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                            .padding(.horizontal, 20).padding(.vertical, 10).background(Color.gold).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())
                }.padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(UIColor.systemGroupedBackground))
                .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
            }
        }
        .navigationBarTitle(Text("Receipt Detail"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)); Text("Back").font(.system(size: 16)) }.foregroundColor(.goldDark)
            }
        )
        .sheet(isPresented: $showDocumentViewer) {
            if let docURL = receiptDocumentURL {
                ReceiptDocumentViewerSheet(url: docURL, fileName: live.originalName)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill").font(.system(size: 36)).foregroundColor(.gray)
                    Text("No document available").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
                    Text("This receipt does not have an uploaded file.").font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.center)
                    Button("Close") { showDocumentViewer = false }
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.goldDark).padding(.top, 8)
                }.padding(32)
            }
        }
    }

    private func dRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).font(.system(size: 12)).foregroundColor(.secondary); Spacer(); Text(value).font(.system(size: 12, weight: .semibold)).lineLimit(1) }
            .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func statusColor(_ s: String) -> (Color, Color) {
        switch s {
        case "pending", "pending_coding": return (.orange, Color.orange.opacity(0.1))
        case "coded": return (.blue, Color.blue.opacity(0.1))
        case "matched": return (Color(red: 0, green: 0.6, blue: 0.5), Color(red: 0, green: 0.6, blue: 0.5).opacity(0.1))
        case "posted": return (.green, Color.green.opacity(0.1))
        case "unmatched": return (Color(red: 0.91, green: 0.29, blue: 0.48), Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.1))
        case "personal": return (.purple, Color.purple.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Add Code & Line Items Page
// ═══════════════════════════════════════════════════════════════════

struct CodingLineItem: Identifiable {
    let id = UUID()
    var description: String = ""
    var amount: String = ""
    var code: String = ""
}

struct AddCodeLineItemsPage: View {
    let receipt: Receipt
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var nominalCode: String = ""
    @State private var lineItems: [CodingLineItem] = [CodingLineItem()]
    @State private var isSaving = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Receipt info card
                    receiptInfoCard

                    // Receipt Code
                    receiptCodeSection

                    // Extracted Items
                    lineItemsSection
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 80)
            }

            // Bottom bar: Cancel + Save Coding
            HStack(spacing: 12) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel").font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())

                Button(action: saveCoding) {
                    HStack(spacing: 6) {
                        if isSaving { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(isSaving ? "Saving..." : "Save Coding")
                    }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(!isSaving && !nominalCode.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gold : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isSaving || nominalCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.white)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Add Code & Line Items"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .onAppear { prefillFromReceipt() }
    }

    // MARK: - Receipt Info

    private var receiptInfoCard: some View {
        VStack(spacing: 0) {
            Text(receipt.originalName.isEmpty ? "Receipt" : receipt.originalName)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            Divider()

            infoRow("Merchant", receipt.merchantDetected ?? "—")
            Divider().padding(.leading, 14)
            infoRow("Amount", receipt.amountDetected.map { "£\($0)" } ?? "—")
            Divider().padding(.leading, 14)
            infoRow("Date", receipt.dateDetected ?? FormatUtils.formatTimestamp(receipt.createdAt))
            Divider().padding(.leading, 14)
            infoRow("File", "\(receipt.fileType.uppercased()) · \(receipt.fileSizeDisplay)")
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(.primary).lineLimit(1)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: - Receipt Code

    private var receiptCodeSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Receipt Code").font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                if let existing = receipt.nominalCode, !existing.isEmpty {
                    Text("Extracted: \(existing)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 0.6, blue: 0.5))
                }
                TextField("e.g. 5010", text: $nominalCode)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.goldDark)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(6).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("EXTRACTED ITEMS (\(lineItems.count))")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                Spacer()
                Button(action: { lineItems.append(CodingLineItem()) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Add Line").font(.system(size: 11, weight: .semibold))
                    }.foregroundColor(.goldDark)
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            // Column headers
            HStack(spacing: 0) {
                Text("ITEM NAME").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("TOTAL").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                    .frame(width: 70, alignment: .trailing)
                Text("CODE").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                    .frame(width: 60, alignment: .leading).padding(.leading, 8)
                if lineItems.count > 1 { Spacer().frame(width: 28) }
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Color.bgRaised)

            Divider()

            // Editable rows
            ForEach(lineItems) { item in
                let isLast = item.id == lineItems.last?.id
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        TextField("Item name", text: bindingForField(item.id, \.description))
                            .font(.system(size: 12)).foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                        TextField("0.00", text: bindingForField(item.id, \.amount))
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(.primary)
                            .multilineTextAlignment(.trailing).keyboardType(.decimalPad)
                            .frame(width: 70)
                        TextField("Code", text: bindingForField(item.id, \.code))
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(.goldDark)
                            .frame(width: 60).padding(.leading, 8)
                        if lineItems.count > 1 {
                            Button(action: { removeLine(item.id) }) {
                                Image(systemName: "minus.circle.fill").font(.system(size: 14)).foregroundColor(.red.opacity(0.6))
                            }.buttonStyle(BorderlessButtonStyle()).frame(width: 28)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    if !isLast { Divider().padding(.horizontal, 14) }
                }
            }

            // Total row
            Divider()
            HStack {
                Text("Total").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                Spacer()
                let total = lineItems.reduce(0.0) { $0 + (Double($1.amount) ?? 0) }
                Text(FormatUtils.formatGBP(total))
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Actions

    private func bindingForField(_ id: UUID, _ keyPath: WritableKeyPath<CodingLineItem, String>) -> Binding<String> {
        Binding<String>(
            get: { lineItems.first(where: { $0.id == id })?[keyPath: keyPath] ?? "" },
            set: { newValue in
                if let idx = lineItems.firstIndex(where: { $0.id == id }) {
                    lineItems[idx][keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func removeLine(_ id: UUID) {
        lineItems.removeAll { $0.id == id }
    }

    private func prefillFromReceipt() {
        nominalCode = receipt.nominalCode ?? ""
        if !receipt.lineItems.isEmpty {
            lineItems = receipt.lineItems.map { li in
                CodingLineItem(
                    description: li.description ?? "",
                    amount: li.amountValue > 0 ? String(format: "%.2f", li.amountValue) : "",
                    code: li.code ?? ""
                )
            }
        } else {
            lineItems = [CodingLineItem()]
        }
    }

    private func saveCoding() {
        guard !nominalCode.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true
        let items: [[String: Any]] = lineItems.filter { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty }.map {
            ["description": $0.description, "amount": Double($0.amount) ?? 0, "code": $0.code] as [String: Any]
        }
        appState.submitReceiptCoding(receipt, nominalCode: nominalCode.trimmingCharacters(in: .whitespaces), lineItems: items) { success in
            isSaving = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Upload Receipt Page
// ═══════════════════════════════════════════════════════════════════

struct UploadReceiptPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var step: Int = 1

    @State private var selectedImage: UIImage?
    @State private var selectedFileName: String?
    @State private var selectedFileURL: URL?
    @State private var showImagePicker = false
    @State private var navigateToCamera = false
    @State private var showDocumentPicker = false

    @State private var selectedOption: String? = nil  // nil, "urgent", or "topup"
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showError = false

    private var displayFileName: String {
        if let name = selectedFileName { return name }
        if selectedImage != nil { return "photo.jpg" }
        return "file"
    }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 20) {
                    if step == 1 { filePickerStep }
                    else if step == 2 { optionsStep }
                }.padding(.horizontal, 20).padding(.top, 20)
            }
        }
        .navigationBarTitle(Text("Upload Receipt"), displayMode: .inline)
        .sheet(isPresented: $showImagePicker) {
            ReceiptImagePicker(selectedImage: $selectedImage, isPresented: $showImagePicker)
                .onDisappear { if selectedImage != nil { selectedFileName = nil; selectedFileURL = nil; step = 2 } }
        }
        .background(
            NavigationLink(destination: ReceiptCameraPageWrapper(selectedImage: $selectedImage, isActive: $navigateToCamera, onCapture: {
                selectedFileName = nil; selectedFileURL = nil; step = 2
            }), isActive: $navigateToCamera) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .sheet(isPresented: $showDocumentPicker) {
            ReceiptDocumentPicker(selectedFileName: $selectedFileName, selectedFileURL: $selectedFileURL, isPresented: $showDocumentPicker)
                .onDisappear { if selectedFileName != nil { selectedImage = nil; step = 2 } }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(uploadError ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
    }

    // ── Step 1: File Picker ──

    private var filePickerStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "arrow.up.doc.fill").font(.system(size: 48)).foregroundColor(.gold)
                Text("Upload Receipt").font(.system(size: 20, weight: .bold))
                Text("Select a receipt photo or PDF to upload").font(.system(size: 13)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.white).cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8])).foregroundColor(Color.gold.opacity(0.4)))
            )

            VStack(spacing: 12) {
                pickerButton(icon: "camera.fill", title: "Take Photo", subtitle: "Capture receipt with camera") { navigateToCamera = true }
                pickerButton(icon: "photo.fill", title: "Photo Library", subtitle: "Choose from saved photos") { showImagePicker = true }
                pickerButton(icon: "doc.fill", title: "Choose File", subtitle: "Upload PDF or document") { showDocumentPicker = true }
            }

            HStack(spacing: 8) {
                ForEach(["JPG", "PNG", "HEIC", "PDF"], id: \.self) { fmt in
                    Text(fmt).font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.bgRaised).cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.borderColor, lineWidth: 1))
                }
            }
        }
    }

    // ── Step 2: Options ──

    private var optionsStep: some View {
        VStack(spacing: 16) {
            // Preview
            VStack(spacing: 12) {
                if let img = selectedImage {
                    Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 200).cornerRadius(8)
                } else if let name = selectedFileName {
                    Image(systemName: "doc.fill").font(.system(size: 48)).foregroundColor(.gold)
                    Text(name).font(.system(size: 14, weight: .medium)).multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 24).background(Color.white).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text("Upload Receipt").font(.system(size: 18, weight: .bold))
                Text("Upload \"\(displayFileName)\". Optionally select one option:")
                    .font(.system(size: 13)).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)

            // Urgent
            optionRadio(
                value: "urgent",
                icon: "exclamationmark.circle.fill",
                title: "Urgent",
                subtitle: "Mark this receipt as urgent for immediate processing",
                activeColor: Color(red: 0.91, green: 0.29, blue: 0.48)
            )

            // Top-Up
            optionRadio(
                value: "topup",
                icon: "wallet.pass.fill",
                title: "Send for Top-Up",
                subtitle: "Submit receipt and request a card top-up",
                activeColor: Color(red: 0, green: 0.6, blue: 0.5)
            )

            Spacer().frame(height: 4)

            HStack(spacing: 12) {
                Button("Change File") {
                    selectedImage = nil; selectedFileName = nil; selectedFileURL = nil
                    selectedOption = nil; step = 1
                }
                .font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity).frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                Button(action: submitUpload) {
                    HStack(spacing: 6) {
                        if isUploading { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(isUploading ? "Uploading..." : "Upload Receipt")
                    }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(!isUploading ? Color.gold : Color.gray.opacity(0.3)).cornerRadius(10)
                }.disabled(isUploading)
            }
        }
    }

    // ── Reusable ──

    private func pickerButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(.goldDark)
                    .frame(width: 36, height: 36).background(Color.gold.opacity(0.15)).cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.black)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.gray)
            }.padding(14).background(Color.white).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(BorderlessButtonStyle())
    }

    private func optionRadio(value: String, icon: String, title: String, subtitle: String, activeColor: Color) -> some View {
        let isActive = selectedOption == value
        return Button(action: { selectedOption = isActive ? nil : value }) {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20)).foregroundColor(isActive ? activeColor : .gray)
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(isActive ? activeColor : .gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(isActive ? activeColor : .primary)
                    Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
            }.padding(14).background(Color.white).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isActive ? activeColor : Color.borderColor, lineWidth: isActive ? 2 : 1))
        }.buttonStyle(PlainButtonStyle())
    }

    private func resizeImage(_ img: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = img.size.width, h = img.size.height
        guard max(w, h) > maxDimension else { return img }
        let scale = maxDimension / max(w, h)
        let newSize = CGSize(width: w * scale, height: h * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        img.draw(in: CGRect(origin: .zero, size: newSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? img
    }

    private func submitUpload() {
        guard let user = appState.currentUser else { return }
        isUploading = true; uploadError = nil

        var fileData: Data?
        var fileName = "receipt"
        var mimeType = "application/octet-stream"

        if let img = selectedImage {
            let resized = resizeImage(img, maxDimension: 2400)
            fileData = resized.jpegData(compressionQuality: 0.8)
            fileName = "receipt.jpg"; mimeType = "image/jpeg"
        } else if let url = selectedFileURL {
            let ext = url.pathExtension.lowercased()
            guard ["pdf", "jpg", "jpeg", "png", "heic", "heif"].contains(ext) else {
                uploadError = "Only JPEG, PNG and PDF are acceptable"; isUploading = false; showError = true; return
            }
            _ = url.startAccessingSecurityScopedResource()
            if ext == "heic" || ext == "heif" {
                if let rawData = try? Data(contentsOf: url), let img = UIImage(data: rawData) {
                    fileData = resizeImage(img, maxDimension: 2400).jpegData(compressionQuality: 0.8)
                }
                fileName = url.deletingPathExtension().lastPathComponent + ".jpg"; mimeType = "image/jpeg"
            } else {
                fileData = try? Data(contentsOf: url)
                fileName = url.lastPathComponent
                mimeType = ext == "pdf" ? "application/pdf" : ext == "png" ? "image/png" : "image/jpeg"
            }
            url.stopAccessingSecurityScopedResource()
        }

        guard let data = fileData else {
            uploadError = "Failed to read file"; isUploading = false; showError = true; return
        }

        let uploadType: String? = selectedOption

        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "\(CardExpenseRequest.baseURL)/api/v2/card-expenses/receipts/upload") else {
            uploadError = "Invalid URL"; isUploading = false; showError = true; return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")

        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data); body.append("\r\n".data(using: .utf8)!)
        addField("userId", user.id)
        addField("uploaderName", user.fullName)
        addField("uploaderDepartment", user.displayDepartment)
        if let type = uploadType { addField("uploadType", type) }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { _, response, error in
            DispatchQueue.main.async {
                isUploading = false
                if let error = error { uploadError = error.localizedDescription; showError = true; return }
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    uploadError = "Upload failed (\(http.statusCode))"; showError = true; return
                }
                appState.loadCardExpenseReceipts()
                presentationMode.wrappedValue.dismiss()
            }
        }.resume()
    }
}

// MARK: - Receipt Image Picker

struct ReceiptImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .photoLibrary; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ReceiptImagePicker
        init(_ parent: ReceiptImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage; parent.isPresented = false
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.isPresented = false }
    }
}

// MARK: - Receipt Camera Page

struct ReceiptCameraPage: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isActive: Bool
    var onCapture: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ReceiptCameraPage
        init(_ parent: ReceiptCameraPage) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage; parent.isActive = false; parent.onCapture()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.isActive = false }
    }
}

struct ReceiptCameraPageWrapper: View {
    @Binding var selectedImage: UIImage?
    @Binding var isActive: Bool
    var onCapture: () -> Void
    var body: some View {
        ReceiptCameraPage(selectedImage: $selectedImage, isActive: $isActive, onCapture: onCapture)
            .edgesIgnoringSafeArea(.all).navigationBarTitle("", displayMode: .inline).navigationBarHidden(true)
    }
}

// MARK: - Receipt Document Picker

struct ReceiptDocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileName: String?
    @Binding var selectedFileURL: URL?
    @Binding var isPresented: Bool
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            p = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .jpeg, .png, .image], asCopy: true)
        } else {
            p = UIDocumentPickerViewController(documentTypes: ["public.pdf", "public.jpeg", "public.png", "public.image"], in: .import)
        }
        p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: ReceiptDocumentPicker
        init(_ parent: ReceiptDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                guard ["pdf", "jpg", "jpeg", "png", "heic", "heif"].contains(url.pathExtension.lowercased()) else { parent.isPresented = false; return }
                parent.selectedFileURL = url; parent.selectedFileName = url.lastPathComponent
            }
            parent.isPresented = false
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { parent.isPresented = false }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt Thumbnail (async image loader, iOS 13 compatible)
// ═══════════════════════════════════════════════════════════════════

class ReceiptImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var failed = false

    func load(url: URL) {
        var request = URLRequest(url: url)
        request.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let data = data, let img = UIImage(data: data) {
                    self?.image = img
                } else {
                    self?.failed = true
                }
            }
        }.resume()
    }
}

struct ReceiptThumbnailView: View {
    let url: URL
    @ObservedObject private var loader = ReceiptImageLoader()

    var body: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable().scaledToFill()
            } else if loader.failed {
                Image(systemName: "photo.fill")
                    .font(.system(size: 28)).foregroundColor(.gray.opacity(0.4))
            } else {
                ActivityIndicator(isAnimating: true).frame(width: 20, height: 20)
            }
        }
        .onAppear { loader.load(url: url) }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt Document Viewer (PDF / Image)
// ═══════════════════════════════════════════════════════════════════

struct ReceiptDocumentViewerSheet: View {
    let url: URL
    var fileName: String = "Receipt"
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ReceiptWebViewContent(url: url)
                .edgesIgnoringSafeArea(.bottom)
                .navigationBarTitle(Text(fileName), displayMode: .inline)
                .navigationBarItems(trailing:
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark)
                )
        }
    }
}

struct ReceiptWebViewContent: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .systemGroupedBackground
        var request = URLRequest(url: url)
        request.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
