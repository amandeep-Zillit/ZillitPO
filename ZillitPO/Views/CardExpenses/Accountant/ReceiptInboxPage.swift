import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt Inbox Page (4 sections — System Matched, No Match, Duplicate, Personal)
// ═══════════════════════════════════════════════════════════════════

struct ReceiptInboxPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var systemMatchedExpanded = true
    @State private var noMatchExpanded = true
    @State private var duplicateExpanded = true
    @State private var personalExpanded = true
    @State private var selectedReceipt: Receipt? = nil
    @State private var navigateToDetail = false
    @State private var showManualMatch = false
    @State private var matchingReceiptId = ""

    private var inboxItems: [Receipt] { appState.inboxReceipts }

    // System Matched = status explicitly indicates a system-found match awaiting confirmation.
    // "matched" is included: the web treats it as auto-matched pending user confirmation.
    // linkedMerchant/linkedAmt on "unmatched" receipts is just transaction metadata — not a suggestion.
    private static let suggestedStatuses: Set<String> = [
        "suggested_match", "matched", "auto_matched", "system_matched",
        "match_suggested", "pending_match", "pending_confirmation",
        "auto_match", "suggestion"
    ]

    private func isSystemMatch(_ r: Receipt) -> Bool {
        ReceiptInboxPage.suggestedStatuses.contains((r.matchStatus ?? "").lowercased())
    }

    /// A confirmed receipt has history entries indicating the match was already acted on.
    private func isAlreadyConfirmed(_ r: Receipt) -> Bool {
        (r.history ?? []).contains { entry in
            let a = (entry.action ?? "").lowercased()
            return a.contains("confirmed") || a.contains("match confirmed")
        }
    }

    private var systemMatched: [Receipt] {
        inboxItems.filter { isSystemMatch($0) }
    }
    // No Match — unmatched receipts with no transaction link (user-uploaded, no match found).
    private var noMatch: [Receipt] {
        inboxItems.filter { r in
            (r.matchStatus ?? "").lowercased() == "unmatched" &&
            (r.transactionId == nil || r.transactionId!.isEmpty)
        }
    }
    private var duplicates: [Receipt] {
        inboxItems.filter { $0.duplicateScore != nil && !($0.duplicateDismissed ?? false) }
    }
    private var personals: [Receipt] {
        inboxItems.filter { $0.personalScore != nil && !($0.personalDismissed ?? false) }
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        Group {
            if appState.isLoadingInboxReceipts && inboxItems.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        section(
                            icon: "sparkles",
                            title: "System Matched",
                            subtitle: "Confirm & Attach",
                            color: Color(red: 0.1, green: 0.6, blue: 0.3),
                            items: systemMatched,
                            expanded: $systemMatchedExpanded,
                            emptyText: "No system-matched receipts.",
                            trailing: AnyView(rerunButton),
                            sectionKind: .systemMatched,
                            onTap: { r in selectedReceipt = r; navigateToDetail = true }
                        )
                        section(
                            icon: "questionmark.circle",
                            title: "No Match",
                            subtitle: "Manual matching required",
                            color: Color(red: 0.95, green: 0.55, blue: 0.15),
                            items: noMatch,
                            expanded: $noMatchExpanded,
                            emptyText: "No unmatched receipts.",
                            trailing: AnyView(EmptyView()),
                            sectionKind: .noMatch,
                            onTap: { r in selectedReceipt = r; navigateToDetail = true }
                        )
                        section(
                            icon: "doc.on.doc.fill",
                            title: "Duplicate",
                            subtitle: "Review before posting",
                            color: .purple,
                            items: duplicates,
                            expanded: $duplicateExpanded,
                            emptyText: "No duplicate receipts detected.",
                            trailing: AnyView(EmptyView()),
                            sectionKind: .duplicate,
                            onTap: { r in selectedReceipt = r; navigateToDetail = true }
                        )
                        section(
                            icon: "person.crop.circle.fill",
                            title: "Personal",
                            subtitle: "Flagged as personal expense",
                            color: .blue,
                            items: personals,
                            expanded: $personalExpanded,
                            emptyText: "No personal receipts flagged.",
                            trailing: AnyView(EmptyView()),
                            sectionKind: .personal,
                            onTap: { r in selectedReceipt = r; navigateToDetail = true }
                        )
                    }
                    .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 28)
                }
                .background(Color.bgBase)
                .background(
                    NavigationLink(
                        destination: Group {
                            if let r = selectedReceipt {
                                ReceiptDetailPage(receipt: r).environmentObject(appState)
                            } else { EmptyView() }
                        },
                        isActive: $navigateToDetail
                    ) { EmptyView() }.frame(width: 0, height: 0).hidden()
                )
            }
        }
        .navigationBarTitle(Text("Receipt Inbox"), displayMode: .inline)
        .onAppear { appState.loadInboxReceipts(); appState.loadCardTransactions() }
        .sheet(isPresented: $showManualMatch) {
            ManualMatchSheet(receiptId: matchingReceiptId, isPresented: $showManualMatch)
                .environmentObject(appState)
        }
    }

    private var rerunButton: some View {
        Button(action: { appState.loadInboxReceipts() }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10, weight: .semibold))
                Text("Re-run").font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.goldDark)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.gold.opacity(0.12)).cornerRadius(6)
        }.buttonStyle(BorderlessButtonStyle())
    }

    private enum InboxSectionKind { case systemMatched, noMatch, duplicate, personal }

    @ViewBuilder
    private func section(icon: String, title: String, subtitle: String, color: Color, items: [Receipt], expanded: Binding<Bool>, emptyText: String, trailing: AnyView, sectionKind: InboxSectionKind, onTap: @escaping (Receipt) -> Void) -> some View {
        VStack(spacing: 0) {
            // ── Section heading ──────────────────────────────────
            Button(action: { expanded.wrappedValue.toggle() }) {
                HStack(spacing: 0) {
                    // Colored left accent bar
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: 4).padding(.vertical, 14)

                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(color)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.primary)
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        trailing

                        Text("\(items.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(color)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(color.opacity(0.1)).cornerRadius(10)

                        Image(systemName: expanded.wrappedValue ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 14)
                }
                .background(Color.bgSurface)
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if expanded.wrappedValue {
                Divider()
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: icon).font(.system(size: 24)).foregroundColor(.gray.opacity(0.25))
                        Text(emptyText).font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 32).padding(.horizontal, 20)
                } else {
                    ForEach(items) { r in
                        inboxRow(r, sectionKind: sectionKind)
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(r) }
                    }
                }
            }
        }
        .background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private func inboxRow(_ r: Receipt, sectionKind: InboxSectionKind) -> some View {
        let receiptDate = (r.transactionDate ?? 0) > 0 ? FormatUtils.formatTimestamp(r.transactionDate ?? 0)
            : ((r.createdAt ?? 0) > 0 ? FormatUtils.formatTimestamp(r.createdAt ?? 0) : "—")
        let user = UsersData.byId[r.uploaderId ?? ""]
        let holderName = user?.fullName ?? ((r.uploaderName ?? "").isEmpty ? "—" : r.uploaderName!)
        let designation = user?.displayDesignation ?? ""
        let nominalCode = r.nominalCode ?? ""
        let codeLabel: String = {
            if nominalCode.isEmpty { return "" }
            if let m = costCodeOptions.first(where: { $0.0 == nominalCode }) {
                return "\(nominalCode.uppercased().replacingOccurrences(of: "_", with: "-")) — \(m.1)"
            }
            return nominalCode.uppercased().replacingOccurrences(of: "_", with: "-")
        }()
        let isSystemMatched = sectionKind == .systemMatched
        let isNoMatch = sectionKind == .noMatch
        let isDuplicate = sectionKind == .duplicate
        let isPersonal = sectionKind == .personal
        let hasLinkedTxn = !(r.linkedMerchant ?? "").isEmpty || r.linkedAmount != nil
        let wfLower = (r.workflowStatus ?? "").lowercased()
        let isPosted = wfLower == "posted" || wfLower == "approved" || wfLower == "confirmed"
        let isConfirmed = isAlreadyConfirmed(r)
        let showAttach = isSystemMatched && !isPosted && !isConfirmed

        return VStack(alignment: .leading, spacing: 0) {

            // ── Main row ──────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                // Left: avatar
                ZStack {
                    Circle().fill(Color.gold.opacity(0.15)).frame(width: 36, height: 36)
                    Text((user?.initials ?? String(holderName.prefix(2))).uppercased())
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.goldDark)
                }

                // Centre: merchant + date + holder
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(r.displayMerchant.isEmpty ? "Receipt" : r.displayMerchant)
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.primary).lineLimit(1)
                        if let score = r.matchScore {
                            Text("\(Int(score * 100))%")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(red: 0.0, green: 0.55, blue: 0.35))
                                .padding(.horizontal, 4).padding(.vertical, 2)
                                .background(Color.green.opacity(0.1)).cornerRadius(3)
                        }
                        if r.isUrgent ?? false {
                            Text("URGENT")
                                .font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.red).cornerRadius(3)
                        }
                    }
                    Text(receiptDate)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text(holderName).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary).lineLimit(1)
                        if !designation.isEmpty {
                            Text("· \(designation)").font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 4)

                // Right: amount + status
                VStack(alignment: .trailing, spacing: 5) {
                    Text(FormatUtils.formatGBP(r.displayAmount))
                        .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    inboxStatusBadge(r)
                }
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, hasLinkedTxn || !codeLabel.isEmpty ? 6 : 10)

            // ── Code pill ─────────────────────────────────────────
            if !codeLabel.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill").font(.system(size: 9)).foregroundColor(.goldDark)
                    Text(codeLabel).font(.system(size: 10, weight: .semibold)).foregroundColor(.goldDark).lineLimit(1)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.gold.opacity(0.1)).cornerRadius(5)
                .padding(.horizontal, 14).padding(.bottom, hasLinkedTxn ? 6 : 10)
            }

            // ── Linked transaction strip ──────────────────────────
            if hasLinkedTxn {
                HStack(spacing: 6) {
                    Image(systemName: "link").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        if !(r.linkedMerchant ?? "").isEmpty {
                            Text(r.linkedMerchant ?? "").font(.system(size: 11, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                        }
                        HStack(spacing: 6) {
                            if let amt = r.linkedAmount {
                                Text(FormatUtils.formatGBP(amt))
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.secondary)
                            }
                            if !(r.linkedCardLast4 ?? "").isEmpty {
                                Text("···· \(r.linkedCardLast4 ?? "")").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                            }
                            if let ld = r.linkedDate, ld > 0 {
                                Text(FormatUtils.formatTimestamp(ld)).font(.system(size: 10)).foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.gray.opacity(0.04))
                .padding(.horizontal, 14).padding(.bottom, 8)
            }

            // ── Action buttons ────────────────────────────────────
            Divider()
            HStack(spacing: 10) {
                if isSystemMatched {
                    if showAttach {
                        Button(action: { appState.attachInboxReceipt(r.id ?? "") }) {
                            HStack(spacing: 5) {
                                Image(systemName: "paperclip").font(.system(size: 11, weight: .semibold))
                                Text("Attach").font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(Color.orange).cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }

                if isNoMatch {
                    Button(action: { matchingReceiptId = r.id ?? ""; showManualMatch = true }) {
                        Text("Manual Match")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                }

                if isDuplicate {
                    Button(action: { appState.confirmReceipt(r) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                            Text("Keep").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(Color(red: 0.0, green: 0.6, blue: 0.5)).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())

                    Button(action: { appState.deleteReceipt(r) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash").font(.system(size: 11, weight: .semibold))
                            Text("Remove").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(Color.red).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())
                }

                if isPersonal {
                    Button(action: { appState.confirmReceipt(r) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "briefcase").font(.system(size: 11, weight: .semibold))
                            Text("Mark Business").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(Color(red: 0.0, green: 0.6, blue: 0.5)).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())

                    Button(action: { appState.flagReceiptPersonal(r) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "person.fill").font(.system(size: 11, weight: .semibold))
                            Text("Confirm Personal").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
    }

    private func inboxStatusBadge(_ r: Receipt) -> some View {
        let teal   = Color(red: 0.0,  green: 0.6,  blue: 0.5)
        let navy   = Color(red: 0.05, green: 0.15, blue: 0.42)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        // Use workflowStatus for display; fall back to matchStatus
        let s = (r.workflowStatus ?? "").isEmpty ? (r.matchStatus ?? "") : (r.workflowStatus ?? "")
        let (label, fg, bg): (String, Color, Color) = {
            switch s.lowercased() {
            case "pending_coding", "pending_code", "pending code": return ("Pending Code",      navy, navy.opacity(0.12))
            case "coded":                                       return ("Coded",             teal,   teal.opacity(0.12))
            case "posted":                                      return ("Posted",            Color(red: 0.1, green: 0.6, blue: 0.3), Color.green.opacity(0.1))
            case "approved":                                    return ("Approved",          teal,   teal.opacity(0.12))
            case "awaiting_approval", "pending_approval",
                 "submitted", "under_review":                   return ("Awaiting Approval", orange, orange.opacity(0.12))
            case "matched", "suggested_match":                  return ("Matched",           teal,   teal.opacity(0.12))
            case "unmatched":                                   return ("No Match",          orange, orange.opacity(0.12))
            case "duplicate":                                   return ("Duplicate",         Color.purple, Color.purple.opacity(0.12))
            case "personal":                                    return ("Personal",          Color.blue,   Color.blue.opacity(0.12))
            case "pending", "pending_receipt", "":              return ("Pending",           orange, orange.opacity(0.12))
            default:                                            return (s.replacingOccurrences(of: "_", with: " ").capitalized, Color.gray, Color.gray.opacity(0.1))
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(bg).cornerRadius(5)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Smart Alerts Page
// ═══════════════════════════════════════════════════════════════════

struct ManualMatchSheet: View {
    @EnvironmentObject var appState: POViewModel
    let receiptId: String
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var matching = false

    private var transactions: [CardTransaction] {
        let q = searchText.lowercased()
        let all = appState.cardTransactions
        guard !q.isEmpty else { return all }
        return all.filter {
            ($0.merchant ?? "").lowercased().contains(q) ||
            ($0.description ?? "").lowercased().contains(q) ||
            ($0.cardLastFour ?? "").contains(q)
        }
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                    TextField("Search transactions...", text: $searchText).font(.system(size: 13))
                }
                .padding(10).background(Color.bgSurface).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

                if appState.isLoadingCardTxns {
                    VStack { Spacer(); LoaderView(); Spacer() }
                } else if transactions.isEmpty {
                    VStack { Spacer(); Text("No transactions found").font(.system(size: 13)).foregroundColor(.secondary); Spacer() }
                } else {
                    List {
                        ForEach(transactions) { tx in
                            Button(action: { matchTransaction(tx) }) {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text((tx.merchant ?? "").isEmpty ? (tx.description ?? "") : (tx.merchant ?? ""))
                                            .font(.system(size: 14, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                                        HStack(spacing: 6) {
                                            if !(tx.cardLastFour ?? "").isEmpty {
                                                Text("•••• \(tx.cardLastFour ?? "")").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                                            }
                                            if (tx.transactionDate ?? 0) > 0 {
                                                Text(FormatUtils.formatTimestamp(tx.transactionDate ?? 0)).font(.system(size: 10)).foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Text(FormatUtils.formatGBP(tx.amount ?? 0))
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }.listStyle(GroupedListStyle())
                }
            }
            .background(Color.bgBase)
            .navigationBarTitle(Text("Match to Transaction"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") { isPresented = false }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark))
        }
    }

    private func matchTransaction(_ tx: CardTransaction) {
        matching = true
        appState.matchReceipt(receiptId, transactionId: tx.id ?? "") { _ in
            matching = false
            isPresented = false
        }
    }
}
