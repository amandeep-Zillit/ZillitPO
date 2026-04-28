import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - All Transactions Page
// ═══════════════════════════════════════════════════════════════════

struct AllTransactionsPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var searchText = ""
    @State private var activeFilter: String = "All"
    @State private var activeCard: String = "All Cards"
    @State private var activeDept: String = "All Dept"
    @State private var showFilterSheet = false
    @State private var showCardSheet = false
    @State private var showDeptSheet = false

    private let filters = ["All", "New", "Pending Receipt", "Pending Code", "Awaiting Approval", "Approved", "Rejected", "Queried", "Under Review", "Escalated", "Posted"]

    private var cardOptions: [String] {
        let cards = Set(appState.cardTransactions.compactMap { (($0.cardLastFour ?? "").isEmpty) ? nil : "•••• \($0.cardLastFour ?? "")" })
        return ["All Cards"] + cards.sorted()
    }
    private var deptOptions: [String] {
        let depts = Set(appState.cardTransactions.compactMap { (($0.department ?? "").isEmpty) ? nil : $0.department })
        return ["All Dept"] + depts.sorted()
    }

    private var filtered: [CardTransaction] {
        var list = appState.cardTransactions
        switch activeFilter {
        case "New":              list = list.filter { ["new", "imported"].contains(($0.status ?? "").lowercased()) }
        case "Pending Receipt":  list = list.filter { ["pending", "pending_receipt"].contains(($0.status ?? "").lowercased()) }
        case "Pending Code":     list = list.filter { ["pending_coding", "pending_code"].contains(($0.status ?? "").lowercased()) }
        case "Awaiting Approval":list = list.filter { ($0.status ?? "").lowercased() == "awaiting_approval" }
        case "Approved":         list = list.filter { ["approved", "matched", "coded"].contains(($0.status ?? "").lowercased()) }
        case "Rejected":         list = list.filter { ($0.status ?? "").lowercased() == "rejected" }
        case "Queried":          list = list.filter { ($0.status ?? "").lowercased() == "queried" }
        case "Under Review":     list = list.filter { ($0.status ?? "").lowercased() == "under_review" }
        case "Escalated":        list = list.filter { ($0.status ?? "").lowercased() == "escalated" }
        case "Posted":           list = list.filter { ($0.status ?? "").lowercased() == "posted" }
        default: break
        }
        if activeCard != "All Cards" {
            let trimmed = activeCard.replacingOccurrences(of: "•••• ", with: "")
            list = list.filter { ($0.cardLastFour ?? "") == trimmed }
        }
        if activeDept != "All Dept" {
            list = list.filter { ($0.department ?? "") == activeDept }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter { ($0.merchant ?? "").lowercased().contains(q) || ($0.holderName ?? "").lowercased().contains(q) || ($0.nominalCode ?? "").lowercased().contains(q) }
        }
        return list.sorted { (($0.transactionDate ?? 0) > 0 ? ($0.transactionDate ?? 0) : ($0.createdAt ?? 0)) > (($1.transactionDate ?? 0) > 0 ? ($1.transactionDate ?? 0) : ($1.createdAt ?? 0)) }
    }

    private var totalGross: Double { filtered.reduce(0) { $0 + ($1.amount ?? 0) } }

    var body: some View {
        VStack(spacing: 8) {
            // ── Row 1: Filter chips ──
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    dropdown(label: activeFilter, icon: "line.3.horizontal.decrease", action: { showFilterSheet = true })
                        .selectionActionSheet(
                            title: "Status",
                            isPresented: $showFilterSheet,
                            options: filters,
                            isSelected: { $0 == activeFilter },
                            label: { $0 },
                            onSelect: { activeFilter = $0 }
                        )
                    dropdown(label: activeCard, icon: "creditcard", action: { showCardSheet = true })
                        .selectionActionSheet(
                            title: "Card",
                            isPresented: $showCardSheet,
                            options: cardOptions,
                            isSelected: { $0 == activeCard },
                            label: { $0 },
                            onSelect: { activeCard = $0 }
                        )
                    dropdown(label: activeDept, icon: "building.2", action: { showDeptSheet = true })
                        .selectionActionSheet(
                            title: "Department",
                            isPresented: $showDeptSheet,
                            options: deptOptions,
                            isSelected: { $0 == activeDept },
                            label: { $0 },
                            onSelect: { activeDept = $0 }
                        )
                }
            }

            // ── Row 2: Search bar (always visible below filters) ──
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13)).foregroundColor(.gray)
                TextField("Search merchant, holder, code…", text: $searchText)
                    .font(.system(size: 13))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15)).foregroundColor(Color(.systemGray3))
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.bgSurface).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                searchText.isEmpty ? Color.borderColor : Color.goldDark,
                lineWidth: searchText.isEmpty ? 1 : 1.5
            ))

            // Scrollable rows section
            ScrollView {
                if appState.isLoadingCardTxns && appState.cardTransactions.isEmpty {
                    LoaderView()
                } else if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "tray").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No transactions").font(.system(size: 13)).foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: 480)
                } else {
                    VStack(spacing: 10) {
                        ForEach(filtered) { tx in
                            // Wrap each row in a NavigationLink so tapping
                            // pushes the detail page (matches the pattern
                            // used by `CardListPage`, `AccountantApprovalQueuePage`,
                            // and `CoordinatorApprovalQueueView`).
                            //
                            // `allowEdit: false` — the All Transactions page is
                            // an accountant read-only view; the Edit Receipt
                            // button on the detail page is hidden here.
                            NavigationLink(destination: CardTransactionDetailPage(transaction: tx, allowEdit: false).environmentObject(appState)) {
                                AllTransactionsRow(tx: tx)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 14)
        .background(Color.bgBase)
        .navigationBarTitle(Text("All Transactions"), displayMode: .inline)
        .onAppear {
            // Reset search on re-appear (e.g. after returning from a tapped row)
            searchText = ""
            appState.loadCardTransactions()
        }
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.4).lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.primary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(10)
        .background(Color.bgSurface).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
    }

    private func dropdown(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.bgSurface).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }.buttonStyle(BorderlessButtonStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Top-Up Detail Page (summary card)
// ═══════════════════════════════════════════════════════════════════

struct AllTransactionsRow: View {
    let tx: CardTransaction

    private var date: String {
        let ts = (tx.transactionDate ?? 0) > 0 ? (tx.transactionDate ?? 0) : (tx.createdAt ?? 0)
        return ts > 0 ? FormatUtils.formatTimestamp(ts) : "—"
    }
    private var codeLabel: String {
        if (tx.nominalCode ?? "").isEmpty { return "—" }
        if let m = costCodeOptions.first(where: { $0.0 == tx.nominalCode }) { return m.1 }
        return (tx.nominalCode ?? "").uppercased()
    }
    private var holder: AppUser? { UsersData.byId[tx.holderId ?? ""] }
    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        let navy  = Color(red: 0.05, green: 0.15, blue: 0.42)
        switch (tx.status ?? "").lowercased() {
        case "approved", "matched", "coded": return (teal, teal.opacity(0.12))
        case "posted": return (teal, teal.opacity(0.12))
        case "pending", "pending_receipt": return (orange, orange.opacity(0.12))
        case "pending_coding", "pending_code", "pending code": return (navy, navy.opacity(0.12))
        case "escalated": return (.red, Color.red.opacity(0.12))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private var deptText: String {
        if !(tx.department ?? "").isEmpty { return tx.department ?? "" }
        if let h = holder, !h.displayDepartment.isEmpty { return h.displayDepartment }
        return "—"
    }
    private var cardText: String {
        if !(tx.cardLastFour ?? "").isEmpty { return "•••• \(tx.cardLastFour ?? "")" }
        return "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1 — merchant + amount + status
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text((tx.merchant ?? "").isEmpty ? "—" : (tx.merchant ?? ""))
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.primary).lineLimit(2)
                    Text(date).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(FormatUtils.formatGBP(tx.amount ?? 0))
                        .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    let (fg, bg) = statusColors
                    Text(tx.statusDisplay).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
                }
            }

            Divider()

            // Row 2 — holder + dept + receipt
            HStack(spacing: 10) {
                if let h = holder {
                    ZStack {
                        Circle().fill(Color.gold.opacity(0.18)).frame(width: 24, height: 24)
                        Text(h.initials).font(.system(size: 9, weight: .bold)).foregroundColor(.goldDark)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(holder?.fullName ?? ((tx.holderName ?? "").isEmpty ? "—" : (tx.holderName ?? "")))
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(deptText).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
            }

            // Row 3 — card + code chips
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "creditcard").font(.system(size: 9)).foregroundColor(.blue)
                    Text(cardText).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.blue)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.blue.opacity(0.1)).cornerRadius(4)

                HStack(spacing: 4) {
                    Image(systemName: "tag.fill").font(.system(size: 9)).foregroundColor(.goldDark)
                    Text(codeLabel).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.gold.opacity(0.1)).cornerRadius(4)
                Spacer()
            }
        }
        .padding(14)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
        .contentShape(Rectangle())
    }
}
