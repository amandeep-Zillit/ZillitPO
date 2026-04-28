import SwiftUI
import UIKit

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Transaction Detail Page
// ═══════════════════════════════════════════════════════════════════

struct CardTransactionDetailPage: View {
    let transaction: CardTransaction
    var allowEdit: Bool = true
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var navigateToEdit = false
    @State private var showOverrideSheet = false
    @State private var overrideReason = ""
    @State private var isOverriding = false
    @State private var showHistory = false
    @State private var showQueries = false
    @State private var showActionsMenu = false
    @State private var historyEntries: [CardHistoryEntry] = []
    @State private var isLoadingHistory = false

    private var live: CardTransaction {
        appState.cardTransactions.first(where: { $0.id == transaction.id })
            ?? appState.cardApprovalQueueItems.first(where: { $0.id == transaction.id })
            ?? transaction
    }

    private var isInApprovalQueue: Bool {
        appState.cardApprovalQueueItems.contains(where: { $0.id == transaction.id })
    }

    private var isLocked: Bool {
        let s = (live.status ?? "").lowercased()
        return s == "approved" || s == "matched" || s == "coded" || s == "posted"
    }

    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        let navy  = Color(red: 0.05, green: 0.15, blue: 0.42)
        switch (live.status ?? "").lowercased() {
        case "approved", "matched", "coded": return (teal, teal.opacity(0.12))
        case "posted": return (teal, teal.opacity(0.12))
        case "pending", "pending_receipt": return (orange, orange.opacity(0.12))
        case "pending_coding", "pending_code", "pending code": return (navy, navy.opacity(0.12))
        case "awaiting_approval": return (.goldDark, Color.gold.opacity(0.15))
        case "queried": return (.purple, Color.purple.opacity(0.12))
        case "under_review": return (.blue, Color.blue.opacity(0.12))
        case "escalated": return (.red, Color.red.opacity(0.12))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private var dateText: String {
        let ts = (live.transactionDate ?? 0) > 0 ? (live.transactionDate ?? 0) : (live.createdAt ?? 0)
        return ts > 0 ? FormatUtils.formatTimestamp(ts) : "—"
    }

    /// Shortcut for the "—" fallback pattern on Optional strings — used
    /// in SwiftUI view builders where inlining the ternary chain was
    /// tripping the type-check timeout.
    private func dashIfEmpty(_ s: String?) -> String {
        let v = s ?? ""
        return v.isEmpty ? "—" : v
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    summaryCard
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 90)
            }

            // Bottom bar
            if isInApprovalQueue {
                // Override button for approval queue context
                VStack(spacing: 0) {
                    Rectangle().fill(Color.borderColor).frame(height: 1)
                    HStack {
                        Button(action: { overrideReason = ""; showOverrideSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.badge.shield.checkmark.fill").font(.system(size: 13, weight: .bold))
                                Text("Override").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.95, green: 0.55, blue: 0.15))
                            .cornerRadius(10)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color(UIColor.systemGroupedBackground))
                }
            } else if allowEdit && !isLocked {
                // Edit Receipt for regular user context
                VStack(spacing: 0) {
                    Rectangle().fill(Color.borderColor).frame(height: 1)
                    HStack {
                        Button(action: { navigateToEdit = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil").font(.system(size: 13, weight: .bold))
                                Text("Edit Receipt").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.gold)
                            .cornerRadius(10)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color(UIColor.systemGroupedBackground))
                }
            }
        }
        .navigationBarTitle(Text("Receipt Details"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            },
            // Trailing: native SwiftUI Menu on iOS 14+, appDropdownMenu fallback on iOS 13.
            // Both options (Query + History) mirror the pattern used on InvoiceDetailPage.
            trailing: trailingMenu
        )
        .background(DisableSwipeBack())
        .background(
            NavigationLink(destination: EditCardTransactionPage(transaction: live).environmentObject(appState),
                           isActive: $navigateToEdit) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            NavigationLink(
                destination: TransactionHistoryPage(
                    transaction: live,
                    entries: historyEntries,
                    isLoading: isLoadingHistory
                ),
                isActive: $showHistory
            ) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            NavigationLink(
                destination: TransactionQueriesPage(
                    receiptId: resolvedReceiptId,
                    label: headerLabel
                ).environmentObject(appState),
                isActive: $showQueries
            ) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            // iOS 13 fallback dropdown — driven by the same `showActionsMenu`
            // flag the iOS 13 trigger toggles. iOS 14+ uses `Menu {}` directly.
            Group {
                if #available(iOS 14.0, *) { EmptyView() }
                else {
                    Color.clear
                        .appDropdownMenu(
                            isPresented: $showActionsMenu,
                            items: [
                                .action("Query", systemImage: "text.bubble") { openQueries() },
                                .action("History", systemImage: "clock.arrow.circlepath") { openHistory() }
                            ]
                        )
                        .frame(width: 0, height: 0)
                }
            }
        )
        .sheet(isPresented: $showOverrideSheet) {
            NavigationView {
                VStack(alignment: .leading, spacing: 20) {
                    // Item summary
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            let merchantText: String = {
                                let m = live.merchant ?? ""
                                return m.isEmpty ? (live.description ?? "") : m
                            }()
                            let holderText: String = {
                                let h = live.holderName ?? ""
                                return h.isEmpty ? "—" : h
                            }()
                            Text(merchantText).font(.system(size: 14, weight: .semibold))
                            Text(holderText).font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(FormatUtils.formatGBP(live.amount ?? 0))
                            .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                    .padding(14).background(Color(.systemGray6)).cornerRadius(10)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("REASON FOR OVERRIDE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                        TextField("e.g. Approver unavailable, deadline critical…", text: $overrideReason)
                            .font(.system(size: 13))
                            .padding(12)
                            .background(Color.bgSurface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    Spacer()

                    Button(action: {
                        guard !overrideReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        isOverriding = true
                        appState.overrideApprovalItem(live.id ?? "", reason: overrideReason) { success in
                            isOverriding = false
                            if success { showOverrideSheet = false; presentationMode.wrappedValue.dismiss() }
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isOverriding { ActivityIndicator(isAnimating: true) }
                            Text(isOverriding ? "Overriding…" : "Confirm Override")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding
                                    ? Color.gray.opacity(0.3) : Color(red: 0.95, green: 0.55, blue: 0.15))
                        .foregroundColor(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding
                                         ? .gray : .white)
                        .cornerRadius(12)
                    }
                    .disabled(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding)
                }
                .padding(20)
                .background(Color.bgBase.edgesIgnoringSafeArea(.all))
                .navigationBarTitle("Override Approval", displayMode: .inline)
                .navigationBarItems(leading: Button("Cancel") {
                    showOverrideSheet = false
                }.foregroundColor(.goldDark))
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.trailing).lineLimit(2)
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func infoCell(label: String, value: String, valueColor: Color = .primary, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value)
                .font(mono ? .system(size: 14, weight: .bold, design: .monospaced) : .system(size: 13))
                .foregroundColor(valueColor)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func costCodeLabel(_ code: String) -> String {
        if code.isEmpty { return "—" }
        if let m = costCodeOptions.first(where: { $0.0 == code }) { return m.1 }
        return code.uppercased()
    }

    private func approverRow(userId: String, tierNumber: Int, override: Bool) -> some View {
        let user = UsersData.byId[userId]
        return HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.15)).frame(width: 20, height: 20)
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.purple)
            }
            Text(user?.fullName ?? userId).font(.system(size: 13, weight: .semibold))
            if let d = user?.displayDesignation, !d.isEmpty {
                Text("(\(d))").font(.system(size: 11)).foregroundColor(.secondary)
            }
            if tierNumber > 0 {
                Text("Level \(tierNumber)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(red: 0.7, green: 0.55, blue: 0.0))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(red: 1.0, green: 0.85, blue: 0.2).opacity(0.18))
                    .cornerRadius(3)
            }
            if override {
                Text("Override").font(.system(size: 9, weight: .bold)).foregroundColor(.purple)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.purple.opacity(0.12)).cornerRadius(4)
            }
            Spacer()
        }
    }

    private var lineItemHeader: some View {
        HStack(spacing: 8) {
            Text("CODE").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(width: 60, alignment: .leading)
            Text("DESCRIPTION").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(maxWidth: .infinity, alignment: .leading)
            Text("NET").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(width: 54, alignment: .trailing)
            Text("TAX").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(width: 48, alignment: .trailing)
            Text("GROSS").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).frame(width: 58, alignment: .trailing)
        }.padding(.horizontal, 8).padding(.vertical, 6)
    }

    private func lineItemRow(code: String, description: String, net: Double, tax: Double, gross: Double, isDeduction: Bool) -> some View {
        HStack(spacing: 8) {
            Text(code).font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isDeduction ? .orange : .goldDark)
                .frame(width: 60, alignment: .leading).lineLimit(1)
            Text(description).font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
            Text(FormatUtils.formatGBP(net)).font(.system(size: 10, design: .monospaced)).foregroundColor(.goldDark).frame(width: 54, alignment: .trailing)
            Text(FormatUtils.formatGBP(tax)).font(.system(size: 10, design: .monospaced)).foregroundColor(.goldDark).frame(width: 48, alignment: .trailing)
            Text(FormatUtils.formatGBP(gross)).font(.system(size: 10, weight: .semibold, design: .monospaced)).frame(width: 58, alignment: .trailing)
        }.padding(.horizontal, 8).padding(.vertical, 8)
    }

    /// Opens the history page and loads entries via
    /// GET /api/v2/card-expenses/receipts/{id}/history.
    ///
    /// In this app the "My Transactions" list surfaces receipts as CardTransaction
    /// rows, so the transaction's own `id` IS the receipt id on the backend.
    /// Prefer `receiptId` when it's explicitly set (linked-transaction case), and
    /// fall back to `id` otherwise.
    private var resolvedReceiptId: String {
        if let linked = live.receiptId, !linked.isEmpty { return linked }
        return live.id ?? ""
    }

    /// Extracted summary card — the whole block between the ScrollView
    /// and the bottom action bar. Split into sub-sections below because
    /// inlining the full layout hit SwiftUI's type-check timeout.
    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            receiptPreviewSection
            Divider()
            infoSection
            Divider()
            descriptionSection
            Divider()
            approvalProgressSection.padding(14)
            Divider()
            submittedSection
            Divider()
            lineItemsSection
        }
        .background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 8) {
            Text("Receipt Details").font(.system(size: 15, weight: .bold))
            Spacer()
            if live.isUrgent ?? false {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").font(.system(size: 9))
                    Text("Urgent").font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(Color.red.opacity(0.1)).cornerRadius(4)
            }
            let (fg, bg) = statusColors
            Text(live.statusDisplay).font(.system(size: 10, weight: .bold)).foregroundColor(fg)
                .padding(.horizontal, 8).padding(.vertical, 4).background(bg).cornerRadius(4)
        }
        .padding(14)
    }

    @ViewBuilder
    private var receiptPreviewSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text").font(.system(size: 30)).foregroundColor(.gray.opacity(0.4))
            Text(live.hasReceipt ? "Receipt attached" : "No receipt uploaded")
                .font(.system(size: 11)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 28)
        .overlay(Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundColor(Color.borderColor))
        .padding(14)
    }

    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                infoCell(label: "MERCHANT", value: dashIfEmpty(live.merchant))
                infoCell(label: "AMOUNT", value: FormatUtils.formatGBP(live.amount ?? 0), valueColor: .goldDark, mono: true)
            }
            HStack(alignment: .top, spacing: 14) {
                infoCell(label: "DATE", value: dateText)
                cardHolderCell
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var cardHolderCell: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CARD HOLDER").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(dashIfEmpty(live.holderName)).font(.system(size: 13))
            if let u = UsersData.byId[live.holderId ?? ""], !u.displayDesignation.isEmpty {
                Text(u.displayDesignation).font(.system(size: 11)).foregroundColor(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var descriptionSection: some View {
        HStack(alignment: .top, spacing: 14) {
            infoCell(label: "DESCRIPTION", value: dashIfEmpty(live.codeDescription))
            infoCell(label: "COST CODE",
                     value: costCodeLabel(live.nominalCode ?? ""),
                     valueColor: .goldDark, mono: true)
            infoCell(label: "EPISODE", value: dashIfEmpty(live.episode))
        }
        .padding(14)
    }

    @ViewBuilder
    private var submittedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SUBMITTED").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            let ts = live.createdAt ?? 0
            Text(ts > 0 ? FormatUtils.formatTimestamp(ts) : "—").font(.system(size: 13))
        }.padding(14)
    }

    @ViewBuilder
    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LINE ITEMS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            VStack(spacing: 0) {
                lineItemHeader
                Divider()
                let amount = live.amount ?? 0
                let net   = (live.netAmount ?? 0) > 0 ? (live.netAmount ?? 0) : amount
                let tax   = live.taxAmount ?? 0
                let gross = (live.grossAmount ?? 0) > 0 ? (live.grossAmount ?? 0) : amount
                let code: String = {
                    let n = (live.nominalCode ?? "")
                    return n.isEmpty ? "—" : n.uppercased()
                }()
                let desc: String = {
                    let m = live.merchant ?? ""
                    return m.isEmpty ? dashIfEmpty(live.codeDescription) : m
                }()
                lineItemRow(code: code, description: desc, net: net, tax: tax, gross: gross, isDeduction: false)
            }
            .background(Color.bgRaised).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }.padding(14)
    }

    /// Extracted approval-progress block. Inlining this into the parent
    /// VStack tripped SwiftUI's "unable to type-check" timeout because
    /// of the nested `if / else-if / else` + ForEach branches.
    @ViewBuilder
    private var approvalProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("APPROVAL PROGRESS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            let approvals = live.approvals ?? []
            if !approvals.isEmpty {
                ForEach(Array(approvals.enumerated()), id: \.offset) { _, a in
                    approverRow(userId: a.userId ?? "", tierNumber: a.tierNumber ?? 0, override: a.isOverride ?? false)
                }
            } else if let by = live.approvedBy, !by.isEmpty {
                approverRow(userId: by, tierNumber: 1, override: false)
            } else {
                Text("No approvals yet").font(.system(size: 11)).foregroundColor(.gray)
            }
        }
    }

    /// Short label used in the header of the pushed Query / History pages.
    private var headerLabel: String {
        if !(live.merchant ?? "").isEmpty { return live.merchant ?? "" }
        if !(live.description ?? "").isEmpty { return live.description ?? "" }
        return "Transaction"
    }

    private func openHistory() {
        historyEntries = []
        showHistory = true
        let rid = resolvedReceiptId
        guard !rid.isEmpty else {
            isLoadingHistory = false
            return
        }
        isLoadingHistory = true
        appState.loadReceiptHistory(rid) { entries in
            historyEntries = entries.sorted { ($0.timestamp ?? 0) > ($1.timestamp ?? 0) }
            isLoadingHistory = false
        }
    }

    private func openQueries() {
        showQueries = true
    }

    /// Trailing nav-bar dropdown matching InvoiceDetailPage: iOS 14+ uses the
    /// native SwiftUI `Menu`, iOS 13 falls back to `appDropdownMenu` via the
    /// `showActionsMenu` flag (wired in the body's background group).
    @ViewBuilder
    private var trailingMenu: some View {
        if #available(iOS 14.0, *) {
            Menu {
                Button { openQueries() } label: {
                    Label("Query", systemImage: "text.bubble")
                }
                Button { openHistory() } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.goldDark)
            }
            .accessibility(label: Text("More actions"))
        } else {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showActionsMenu.toggle()
                }
            }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.goldDark)
            }
            .accessibility(label: Text("More actions"))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Transaction History Page (pushed on nav stack)
// ═══════════════════════════════════════════════════════════════════

private struct TransactionHistoryPage: View {
    let transaction: CardTransaction
    let entries: [CardHistoryEntry]
    let isLoading: Bool

    /// Header label for the transaction — merchant or description.
    private var headerTitle: String {
        if !(transaction.merchant ?? "").isEmpty { return transaction.merchant ?? "" }
        if !(transaction.description ?? "").isEmpty { return transaction.description ?? "" }
        return "Transaction"
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            if isLoading {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                    Text("No history yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                    Text("Changes to this receipt will appear here.")
                        .font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header card — transaction summary
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 12)).foregroundColor(.goldDark)
                            Text(headerTitle)
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                                .lineLimit(1)
                            if !(transaction.cardLastFour ?? "").isEmpty {
                                Text("•••• \(transaction.cardLastFour ?? "")")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(entries.count) event\(entries.count == 1 ? "" : "s")")
                                .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        .padding(12).background(Color.bgSurface).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

                        ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                            historyRow(entry, isLast: idx == entries.count - 1)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarTitle(Text("History"), displayMode: .inline)
    }

    // MARK: - Label / color / icon helpers

    /// Server returns human-readable actions for receipts ("Uploaded", "Approved",
    /// "Coded & submitted", etc.), plus card-lifecycle events prefixed with `"Card: "`.
    /// Any snake_case / UPPER_SNAKE values are normalised to Title Case; the
    /// `Card: Card X` redundancy is collapsed to just `Card X`.
    private func humanizeAction(_ action: String) -> String {
        var s = action.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "Update" }
        // Collapse "Card: Card requested" → "Card Requested"
        if s.hasPrefix("Card: Card ") {
            s = String(s.dropFirst("Card: ".count))
        }
        if s.contains("_") || s == s.uppercased() {
            return s
                .replacingOccurrences(of: "_", with: " ")
                .lowercased()
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
        return s
    }

    private func actionColor(_ action: String) -> Color {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return .green }
        if a.contains("reject") { return .red }
        if a.contains("override") { return .orange }
        if a.contains("submit") || a.contains("request") || a.contains("upload") { return .goldDark }
        if a.contains("escalat") { return .red }
        if a.contains("post") { return Color(red: 0.1, green: 0.6, blue: 0.3) }
        if a.contains("delete") || a.contains("remov") { return .red }
        if a.contains("match") { return Color(red: 0, green: 0.6, blue: 0.5) }
        if a.contains("duplicate") || a.contains("personal") { return .purple }
        if a.contains("assign") { return .blue }
        if a.contains("code") { return .blue }
        return .goldDark
    }

    private func actionIcon(_ action: String) -> String {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return "checkmark.circle.fill" }
        if a.contains("reject") { return "xmark.circle.fill" }
        if a.contains("override") { return "bolt.fill" }
        if a.contains("upload") { return "arrow.up.circle.fill" }
        if a.contains("submit") || a.contains("request") { return "paperplane.fill" }
        if a.contains("escalat") { return "exclamationmark.triangle.fill" }
        if a.contains("post") { return "tray.and.arrow.down.fill" }
        if a.contains("match") { return "link.circle.fill" }
        if a.contains("duplicate") { return "doc.on.doc.fill" }
        if a.contains("personal") { return "person.crop.circle.badge.exclamationmark" }
        if a.contains("assign") { return "arrow.right.circle.fill" }
        if a.contains("code") { return "number.circle.fill" }
        if a.contains("top-up") || a.contains("top up") { return "arrow.up.circle.fill" }
        if a.contains("delete") || a.contains("remov") { return "trash.fill" }
        if a.contains("amend") || a.contains("update") || a.contains("edit") { return "pencil.circle.fill" }
        return "circle.fill"
    }

    private func resolvedUser(_ entry: CardHistoryEntry) -> (String, String?) {
        if !(entry.actionBy ?? "").isEmpty, let u = UsersData.byId[entry.actionBy ?? ""] {
            return (u.fullName ?? "", u.displayDesignation.isEmpty ? nil : u.displayDesignation)
        }
        if !(entry.actionByName ?? "").isEmpty { return (entry.actionByName ?? "", nil) }
        if !(entry.actionBy ?? "").isEmpty { return (entry.actionBy ?? "", nil) }
        return ("System", nil)
    }

    // MARK: - Row

    private func historyRow(_ entry: CardHistoryEntry, isLast: Bool) -> some View {
        let color = actionColor(entry.action ?? "")
        let label = humanizeAction(entry.action ?? "")
        let (name, role) = resolvedUser(entry)
        return HStack(alignment: .top, spacing: 12) {
            // Timeline rail: icon circle + connector line to the next row
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: actionIcon(entry.action ?? ""))
                        .font(.system(size: 11, weight: .bold)).foregroundColor(color)
                }
                if !isLast {
                    Rectangle().fill(Color.borderColor).frame(width: 2)
                        .frame(maxHeight: .infinity).padding(.top, 2)
                }
            }
            .frame(width: 28)

            // Event card
            VStack(alignment: .leading, spacing: 6) {
                // Action title + optional tier badge
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let tier = entry.tierNumber, tier > 0 {
                        Text("Tier \(tier)")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(color.opacity(0.12)).cornerRadius(4)
                    }
                    Spacer()
                }

                // "by Name (Role)"
                if !name.isEmpty && name != "System" {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9)).foregroundColor(.secondary)
                            .padding(.trailing, 4)
                        (
                            Text("by ").foregroundColor(.secondary)
                            + Text(name).fontWeight(.semibold).foregroundColor(.primary)
                            + Text({ if let r = role { return " (\(r))" } else { return "" } }())
                                .foregroundColor(.secondary)
                        )
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }

                // Details / description
                if !(entry.details ?? "").isEmpty {
                    Text(entry.details ?? "")
                        .font(.system(size: 12)).foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Field change (old → new)
                if !(entry.oldValue ?? "").isEmpty || !(entry.newValue ?? "").isEmpty {
                    HStack(spacing: 6) {
                        if !(entry.field ?? "").isEmpty {
                            Text((entry.field ?? "").uppercased())
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        }
                        if !(entry.oldValue ?? "").isEmpty {
                            Text(entry.oldValue ?? "")
                                .font(.system(size: 11, design: .monospaced)).foregroundColor(.red)
                                .strikethrough()
                        }
                        if !(entry.oldValue ?? "").isEmpty && !(entry.newValue ?? "").isEmpty {
                            Image(systemName: "arrow.right").font(.system(size: 9)).foregroundColor(.gray)
                        }
                        if !(entry.newValue ?? "").isEmpty {
                            Text(entry.newValue ?? "")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.green)
                        }
                    }
                }

                // Reason
                if !(entry.reason ?? "").isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "quote.bubble").font(.system(size: 9)).foregroundColor(.secondary)
                        Text("Reason: \(entry.reason ?? "")")
                            .font(.system(size: 11)).foregroundColor(.secondary).italic()
                    }
                }

                // Timestamp
                if (entry.timestamp ?? 0) > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.gray)
                        Text(FormatUtils.formatDateTime(entry.timestamp ?? 0))
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgSurface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            .padding(.bottom, isLast ? 0 : 10)
        }
        .padding(.horizontal, 16).padding(.top, 4)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Transaction Queries Page (chat thread)
// ═══════════════════════════════════════════════════════════════════
//
// Mirrors InvoiceQueriesPage but hits
//   GET /api/v2/account-hub/queries/entity/receipt/{receiptId}
// via `appState.loadReceiptQueries` and reads from `appState.receiptQueries`.
// Messages appear as right-aligned orange chat bubbles; the composer is a
// text field + paperplane send button. Sending currently appends locally —
// hooking up a POST endpoint would replace `sendMessage` with a server call.

private struct TransactionQueryMessage: Identifiable {
    let id: String
    let userId: String?
    let userName: String?
    let text: String
    let timestamp: Int64?
    let isLocal: Bool
}

private struct TransactionQueriesPage: View {
    @EnvironmentObject var appState: POViewModel
    let receiptId: String
    let label: String

    @State private var draft: String = ""
    @State private var localMessages: [TransactionQueryMessage] = []

    private var thread: InvoiceQueryThread? { appState.receiptQueries[receiptId] }

    private var messages: [TransactionQueryMessage] {
        var list: [TransactionQueryMessage] = []
        if let t = thread {
            for m in (t.messages ?? []) {
                guard let body = m.query, !body.isEmpty else { continue }
                list.append(TransactionQueryMessage(
                    id: m.id,
                    userId: m.queriedBy,
                    userName: nil,
                    text: body,
                    timestamp: m.queriedAt,
                    isLocal: false
                ))
            }
        }
        list.append(contentsOf: localMessages)
        return list.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        VStack(spacing: 0) {
            // Header — merchant / description as a centered title
            Text(label.isEmpty ? "—" : label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 10)

            Divider()

            Group {
                if appState.receiptQueriesLoading && messages.isEmpty {
                    VStack { Spacer(); LoaderView(); Spacer() }
                } else if messages.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "text.bubble")
                            .font(.system(size: 32)).foregroundColor(.gray.opacity(0.4))
                        Text("No messages yet")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                        Text("Type a message to start the conversation.")
                            .font(.system(size: 11)).foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .trailing, spacing: 16) {
                            ForEach(messages) { m in messageBubble(m) }
                        }
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 16)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Composer — same style as InvoiceQueriesPage
            Divider()
            HStack(spacing: 10) {
                TextField("Type a message…", text: $draft)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Capsule().fill(Color.bgSurface))
                    .overlay(Capsule().stroke(Color.borderColor, lineWidth: 1))
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(draft.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.gold.opacity(0.5)
                            : Color(red: 0.95, green: 0.55, blue: 0.15)))
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.bgSurface)
        }
        .background(Color.bgSurface.edgesIgnoringSafeArea(.all))
        .navigationBarTitle(Text("Query"), displayMode: .inline)
        .onAppear { appState.loadReceiptQueries(receiptId) }
    }

    private func messageBubble(_ m: TransactionQueryMessage) -> some View {
        let resolvedName: String = {
            if let n = m.userName, !n.isEmpty { return n }
            if let uid = m.userId { return UsersData.byId[uid]?.fullName ?? "Unknown" }
            return "Unknown"
        }()
        let role: String = {
            if let uid = m.userId, let u = UsersData.byId[uid] {
                return u.displayDesignation
            }
            return ""
        }()
        let stamp: String = {
            guard let ts = m.timestamp, ts > 0 else { return "" }
            return FormatUtils.formatHistoryDateTime(ts)
        }()
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        return HStack {
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text(resolvedName).font(.system(size: 13, weight: .bold))
                    if !role.isEmpty {
                        Text(role).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                }

                Text(m.text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(orange)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)

                if !stamp.isEmpty {
                    Text(stamp)
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
            }
        }
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let me = appState.currentUser
        localMessages.append(TransactionQueryMessage(
            id: UUID().uuidString,
            userId: me?.id,
            userName: me?.fullName,
            text: text,
            timestamp: now,
            isLocal: true
        ))
        draft = ""
        debugPrint("⚠️ sendReceiptQueryMessage: no POST endpoint wired yet. Message added locally.")
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Edit Card Transaction Page (with Upload section)
// ═══════════════════════════════════════════════════════════════════

struct DisableSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Controller() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Controller: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            parent?.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            parent?.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
