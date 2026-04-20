import SwiftUI
import UIKit

// ═══════════════════════════════════════════════════════════════════
// MARK: - Top-Up To Do Page
// ═══════════════════════════════════════════════════════════════════

struct TopUpToDoPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var pendingExpanded = true
    @State private var historyExpanded = true
    @State private var partialGroup: TopUpGroup? = nil
    @State private var skippingGroupKey: String? = nil
    @State private var markingGroupKey: String? = nil
    @State private var errorMessage: String? = nil
    /// Drives the hidden NavigationLink used for detail navigation.
    /// Set when the user taps any non-button area of a pending card
    /// (or a history row) → cleared automatically on back-nav.
    @State private var detailItem: TopUpItem? = nil
    @State private var detailActive: Bool = false

    // MARK: - Filter to card-only top-ups
    // Cash float top-ups live on a separate page; treat missing entityType as "card" for
    // backward compatibility with older API rows.
    private var cardTopUps: [TopUpItem] {
        appState.topUpQueue.filter { t in
            let et = (t.entityType ?? "").lowercased()
            return et.isEmpty || et == "card"
        }
    }

    private var pendingItems: [TopUpItem] {
        cardTopUps.filter { ($0.status ?? "").lowercased() == "pending" }
    }
    private var history: [TopUpItem] {
        // Include partials alongside completed/skipped (partial renders with Skipped label)
        cardTopUps.filter { ["completed", "skipped", "partial"].contains(($0.status ?? "").lowercased()) }
            .sorted { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }
    }

    // MARK: - Grouping
    /// Aggregates pending top-ups by cardholder. Sort order: urgent groups first,
    /// then oldest `createdAt` first, matching the React reference.
    private var pendingGroups: [TopUpGroup] {
        var map: [String: TopUpGroup] = [:]
        for item in pendingItems {
            let key = !(item.entityId ?? "").isEmpty ? (item.entityId ?? "")
                    : !(item.cardId ?? "").isEmpty   ? (item.cardId ?? "")
                    : !(item.userId ?? "").isEmpty   ? (item.userId ?? "")
                    : item.id
            if var g = map[key] {
                g.topups.append(item)
                if item.isUrgent { g.hasUrgent = true }
                map[key] = g
            } else {
                var g = TopUpGroup(key: key, primary: item)
                if item.isUrgent { g.hasUrgent = true }
                map[key] = g
            }
        }
        return Array(map.values).sorted { a, b in
            if a.hasUrgent != b.hasUrgent { return a.hasUrgent }
            return a.oldestCreatedAt < b.oldestCreatedAt
        }
    }

    // MARK: - Helpers
    /// Builds the "From: Merchant £X + Merchant2 £Y + N more + N other expenses" line.
    private func buildSourceLine(_ topups: [TopUpItem]) -> String? {
        let named = topups.filter { !($0.receiptMerchant ?? "").isEmpty }
        let rest = topups.count - named.count
        var parts: [String] = named.prefix(2).map { t in
            let amt = (t.receiptAmount ?? 0) > 0 ? " \(FormatUtils.formatGBP(t.receiptAmount ?? 0))" : ""
            return "\(t.receiptMerchant ?? "")\(amt)"
        }
        if named.count > 2 { parts.append("\(named.count - 2) more") }
        if rest > 0 { parts.append("\(rest) other expense\(rest > 1 ? "s" : "")") }
        return parts.isEmpty ? nil : "From: \(parts.joined(separator: " + "))"
    }

    /// Returns `nil` if the top-up passes the card-limit check; otherwise the error string.
    private func cardLimitError(for group: TopUpGroup, attemptedAmount: Double) -> String? {
        guard group.cardLimit > 0 else { return nil }
        if group.cardBalance + attemptedAmount > group.cardLimit {
            let maxAllowed = max(0, group.cardLimit - group.cardBalance)
            return "Top-up exceeds card limit. Max allowed: \(FormatUtils.formatGBP(maxAllowed))"
        }
        return nil
    }

    var body: some View {
        Group {
            if appState.isLoadingTopUps && appState.topUpQueue.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
                    .background(Color.bgBase)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        pendingSection
                        historySection
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
                }
                .background(Color.bgBase)
            }
        }
        // Hidden NavigationLink that the whole-card tap gestures
        // trigger via `detailActive`. One link serves every card —
        // `detailItem` is swapped immediately before `detailActive`
        // flips, so the destination sees the right top-up item.
        .background(
            NavigationLink(
                destination: Group {
                    if let item = detailItem {
                        TopUpDetailPage(item: item).environmentObject(appState)
                    } else {
                        EmptyView()
                    }
                },
                isActive: $detailActive
            ) { EmptyView() }.hidden()
        )
        .navigationBarTitle(Text("Top-Up To Do"), displayMode: .inline)
        .onAppear { appState.loadTopUpQueue() }
        .sheet(item: $partialGroup) { group in
            PartialTopUpSheet(group: group) { amount, note, done in
                applyPartial(to: group, amount: amount, note: note, done: done)
            }
            .environmentObject(appState)
        }
        .alert(isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Alert(
                title: Text("Cannot top up"),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Batch actions
    /// Runs the given per-item action over all pending items in the group, waits for every
    /// call to complete, then invokes `done(allOK)` on the main thread. Mirrors React's
    /// `await Promise.all(...)` pattern.
    private func runBatch(_ group: TopUpGroup,
                          action: (TopUpItem, @escaping (Bool) -> Void) -> Void,
                          done: @escaping (Bool) -> Void) {
        let pending = group.topups.filter { ($0.status ?? "").lowercased() == "pending" }
        guard !pending.isEmpty else { done(true); return }
        let dgroup = DispatchGroup()
        var allOK = true
        for t in pending {
            dgroup.enter()
            action(t) { ok in
                if !ok { allOK = false }
                dgroup.leave()
            }
        }
        dgroup.notify(queue: .main) { done(allOK) }
    }

    private func markGroupCompleted(_ group: TopUpGroup) {
        if let err = cardLimitError(for: group, attemptedAmount: group.totalAmount) {
            errorMessage = err
            return
        }
        markingGroupKey = group.key
        runBatch(group,
                 action: { item, cb in appState.markTopUpCompleted(item.id, completion: cb) },
                 done: { allOK in
                    markingGroupKey = nil
                    appState.loadTopUpQueue()
                    if !allOK { errorMessage = "Failed to complete some top-ups. Please try again." }
                 })
    }

    private func skipGroup(_ group: TopUpGroup) {
        skippingGroupKey = group.key
        runBatch(group,
                 action: { item, cb in appState.skipTopUp(item.id, completion: cb) },
                 done: { allOK in
                    skippingGroupKey = nil
                    appState.loadTopUpQueue()
                    if !allOK { errorMessage = "Failed to skip some top-ups. Please try again." }
                 })
    }

    private func applyPartial(to group: TopUpGroup,
                              amount: Double?,
                              note: String,
                              done: @escaping (Bool) -> Void) {
        // Card-limit check when a specific amount is provided
        if let amt = amount, let err = cardLimitError(for: group, attemptedAmount: amt) {
            errorMessage = err
            done(false)
            return
        }
        runBatch(group,
                 action: { item, cb in
                    // Hits /topups/{id}/partial; amount=nil tells server to use stored amount
                    appState.partialTopUp(item.id, amount: amount, note: note, completion: cb)
                 },
                 done: { allOK in
                    appState.loadTopUpQueue()
                    if !allOK { errorMessage = "Failed to record partial top-up. Please try again." }
                    done(allOK)
                 })
    }

    private var pendingSection: some View {
        VStack(spacing: 0) {
            Button(action: { pendingExpanded.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill").font(.system(size: 12)).foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
                    Text("PENDING TOP-UPS").font(.system(size: 11, weight: .bold)).tracking(0.4)
                    Text("\(pendingItems.count)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(red: 0.95, green: 0.55, blue: 0.15)).cornerRadius(8)
                    Spacer()
                    Text("Oldest first · Urgent prioritised").font(.system(size: 9)).foregroundColor(.gray)
                    Image(systemName: pendingExpanded ? "chevron.up" : "chevron.down").font(.system(size: 9)).foregroundColor(.gray)
                }
                .padding(12).background(Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.06))
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if pendingExpanded {
                if pendingGroups.isEmpty {
                    Text("No pending top-ups").font(.system(size: 11)).foregroundColor(.gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                } else {
                    ForEach(pendingGroups) { group in
                        Divider()
                        pendingCard(group)
                    }
                }
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.3), lineWidth: 1))
    }

    private func pendingCard(_ group: TopUpGroup) -> some View {
        let item = group.primary
        let user = UsersData.byId[item.userId ?? ""]
        let initials = (user?.initials ?? String((item.holderName ?? "").prefix(2))).uppercased()
        let spentPct = group.cardLimit > 0 ? min(1.0, group.cardBalance / group.cardLimit) : 0.0
        let totalAmount = group.totalAmount
        let sourceLine = buildSourceLine(group.topups)
        let noteText = group.topups.first(where: { !($0.note ?? "").isEmpty })?.note
        let isSkipping = skippingGroupKey == group.key
        let isMarking = markingGroupKey == group.key
        let groupBusy = isSkipping || isMarking
        // Whole card wrapped in a Button for rock-solid hit testing —
        // `.contentShape + .onTapGesture` on a VStack was only catching
        // taps on non-empty areas in practice. A Button with
        // PlainButtonStyle fills its entire rendered frame as the
        // touch target, and SwiftUI correctly routes taps to inner
        // Buttons (Mark / Partial / Skip) before this outer one fires.
        return Button(action: {
            detailItem = item
            detailActive = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
            // Informational content.
            VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack(spacing: 10) {
                        if group.hasUrgent {
                            Image(systemName: "flame.fill").font(.system(size: 11)).foregroundColor(.orange)
                        }
                        ZStack {
                            Circle().fill(Color(red: 0.95, green: 0.55, blue: 0.15)).frame(width: 30, height: 30)
                            Text(initials).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(user?.fullName ?? (item.holderName ?? "")).font(.system(size: 14, weight: .bold))
                                if !(item.cardLastFour ?? "").isEmpty {
                                    Text("—").font(.system(size: 11)).foregroundColor(.gray)
                                    Text("•••• \(item.cardLastFour ?? "")").font(.system(size: 11, design: .monospaced)).foregroundColor(.primary)
                                }
                            }
                            HStack(spacing: 4) {
                                if !(item.cardLastFour ?? "").isEmpty {
                                    Text("Card •••• \(item.cardLastFour ?? "")").font(.system(size: 9)).foregroundColor(.gray)
                                }
                                if !(item.bsControlCode ?? "").isEmpty {
                                    Text("· BS: \(item.bsControlCode ?? "")").font(.system(size: 9)).foregroundColor(.gray)
                                }
                            }
                        }
                        Spacer()
                        if group.hasUrgent {
                            Text("URGENT")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.red)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Color.red.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red.opacity(0.4), lineWidth: 1))
                                .cornerRadius(4)
                        }
                    }

                    // Details grid 2x2
                    VStack(spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            detailCell(label: "CURRENT BAL", value: FormatUtils.formatGBP(group.cardBalance), color: Color(red: 0.0, green: 0.6, blue: 0.5), mono: true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CARD LIMIT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                                Text(FormatUtils.formatGBP(group.cardLimit)).font(.system(size: 14, weight: .bold, design: .monospaced))
                                // Progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 4).cornerRadius(2)
                                        Rectangle().fill(Color(red: 0.95, green: 0.55, blue: 0.15)).frame(width: geo.size.width * CGFloat(spentPct), height: 4).cornerRadius(2)
                                    }
                                }.frame(height: 4)
                                Text("Spent \(FormatUtils.formatGBP(item.cardSpent ?? 0))").font(.system(size: 9)).foregroundColor(.gray)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            detailCell(label: "TOP-UP METHOD", value: (item.method ?? "").lowercased() == "restore" ? "Restore float" : item.methodDisplay, color: .primary, mono: false)
                            detailCell(label: "TOP-UP AMOUNT", value: FormatUtils.formatGBP(totalAmount), color: Color(red: 0.95, green: 0.55, blue: 0.15), mono: true)
                        }
                    }

                    // Source line (aggregated across all receipts in the group)
                    if let sourceLine = sourceLine {
                        Text(sourceLine)
                            .font(.system(size: 10)).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                // Note (if any group item has a partial-topup note attached)
                if let note = noteText {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "pencil").font(.system(size: 9)).foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Note:").font(.system(size: 10, weight: .bold)).foregroundColor(.orange)
                            Text(note).font(.system(size: 10)).foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.25), lineWidth: 1))
                    .cornerRadius(6)
                }
            }

            // Action buttons — batch over all pending items in the group.
            // Kept OUTSIDE the NavigationLink so each button captures its
            // own tap without navigating.
            HStack(spacing: 8) {
                Button(action: { markGroupCompleted(group) }) {
                    HStack(spacing: 4) {
                        if isMarking {
                            ActivityIndicator(isAnimating: true).frame(width: 10, height: 10)
                        } else {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 11))
                        }
                        Text(isMarking ? "Marking..." : "Mark Topped Up")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(red: 0.0, green: 0.6, blue: 0.5).opacity(groupBusy ? 0.6 : 1))
                    .cornerRadius(6)
                }
                .disabled(groupBusy)
                .buttonStyle(BorderlessButtonStyle())

                Button(action: { partialGroup = group }) {
                    Text("Partial Top-Up").font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.bgSurface)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        .opacity(groupBusy ? 0.5 : 1)
                }
                .disabled(groupBusy)
                .buttonStyle(BorderlessButtonStyle())

                Button(action: { skipGroup(group) }) {
                    HStack(spacing: 4) {
                        if isSkipping {
                            ActivityIndicator(isAnimating: true).frame(width: 10, height: 10)
                        }
                        Text(isSkipping ? "Skipping..." : "Skip")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.bgSurface)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    .opacity(groupBusy ? 0.5 : 1)
                }
                .disabled(groupBusy)
                .buttonStyle(BorderlessButtonStyle())

                Spacer()
            }
            } // inner VStack close
            .padding(14)
            .contentShape(Rectangle())
        } // Button closure close
        .buttonStyle(PlainButtonStyle())
    }

    private func detailCell(label: String, value: String, color: Color, mono: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(mono ? .system(size: 14, weight: .bold, design: .monospaced) : .system(size: 13, weight: .semibold)).foregroundColor(color)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historySection: some View {
        VStack(spacing: 0) {
            Button(action: { historyExpanded.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundColor(Color(red: 0.0, green: 0.6, blue: 0.5))
                    Text("COMPLETED & SKIPPED").font(.system(size: 11, weight: .bold)).tracking(0.4)
                    Text("\(history.count)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gray).cornerRadius(8)
                    Spacer()
                    Image(systemName: historyExpanded ? "chevron.up" : "chevron.down").font(.system(size: 9)).foregroundColor(.gray)
                }
                .padding(12).background(Color.bgRaised)
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if historyExpanded {
                if history.isEmpty {
                    Text("Nothing completed yet").font(.system(size: 11)).foregroundColor(.gray)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                } else {
                    ForEach(history) { item in
                        Divider()
                        NavigationLink(destination: TopUpDetailPage(item: item).environmentObject(appState)) {
                            historyRow(item)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func historyRow(_ item: TopUpItem) -> some View {
        let user = UsersData.byId[item.userId ?? ""]
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let s = (item.status ?? "").lowercased()
        let statusColor: Color = s == "completed" ? teal : .gray
        let statusLabel: String = s == "completed" ? "Completed" : "Skipped"
        let dateText = (item.updatedAt ?? 0) > 0 ? FormatUtils.formatTimestamp(item.updatedAt ?? 0)
                      : ((item.createdAt ?? 0) > 0 ? FormatUtils.formatTimestamp(item.createdAt ?? 0) : "—")
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(user?.fullName ?? (item.holderName ?? "")).font(.system(size: 12, weight: .semibold))
                    if let d = user?.displayDesignation, !d.isEmpty {
                        Text(d).font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(FormatUtils.formatGBP(item.amount ?? 0))
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }
            HStack(spacing: 8) {
                if !(item.cardLastFour ?? "").isEmpty {
                    Text("•••• \(item.cardLastFour ?? "")").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Text((item.method ?? "").lowercased() == "restore" ? "Restore Float"
                     : (item.method ?? "").lowercased() == "expense" ? "Expense Amount"
                     : item.methodDisplay)
                    .font(.system(size: 10)).foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 3) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(statusLabel).font(.system(size: 10, weight: .semibold)).foregroundColor(statusColor)
                }
                Text(dateText).font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Manual Match Sheet
// ═══════════════════════════════════════════════════════════════════

// MARK: - Top-Up Group (aggregates pending top-ups per cardholder)

struct TopUpGroup: Identifiable, Equatable {
    let key: String
    var primary: TopUpItem        // representative item for card meta (holder, card, balance, limit, …)
    var topups: [TopUpItem]
    var hasUrgent: Bool

    var id: String { key }
    var totalAmount: Double {
        topups.filter { ($0.status ?? "").lowercased() == "pending" }
              .reduce(0) { $0 + ($1.amount ?? 0) }
    }
    var oldestCreatedAt: Int64 { topups.compactMap { $0.createdAt }.min() ?? 0 }
    var cardBalance: Double { primary.cardBalance ?? 0 }
    var cardLimit: Double   { primary.cardLimit ?? 0 }

    init(key: String, primary: TopUpItem) {
        self.key = key
        self.primary = primary
        self.topups = [primary]
        self.hasUrgent = primary.isUrgent
    }

    static func == (lhs: TopUpGroup, rhs: TopUpGroup) -> Bool { lhs.key == rhs.key }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Partial Top-Up Sheet (note required; applies to group)
// ═══════════════════════════════════════════════════════════════════

struct PartialTopUpSheet: View {
    let group: TopUpGroup
    /// Called with amount, note, and a completion that signals when the server has replied.
    /// The sheet will only dismiss when that completion returns `true`.
    let onConfirm: (Double?, String, @escaping (Bool) -> Void) -> Void

    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var amount: String = ""
    @State private var note: String = ""
    @State private var submitting: Bool = false

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var canSubmit: Bool { !trimmedNote.isEmpty && !submitting }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Group summary
                VStack(alignment: .leading, spacing: 4) {
                    Text((group.primary.holderName ?? "").isEmpty ? "Top-up" : (group.primary.holderName ?? ""))
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                    Text("Total pending: \(FormatUtils.formatGBP(group.totalAmount)) across \(group.topups.count) item\(group.topups.count == 1 ? "" : "s")")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 6) {
                    Text("PARTIAL AMOUNT (OPTIONAL)")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                    HStack(spacing: 2) {
                        Text("£").font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark)
                        TextField("0.00", text: $amount)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.goldDark)
                            .keyboardType(.decimalPad)
                    }
                    .padding(10).background(Color.bgRaised).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 2) {
                        Text("NOTE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        Text("*").font(.system(size: 9, weight: .bold)).foregroundColor(.red)
                    }
                    TextField("Reason for partial top-up...", text: $note)
                        .font(.system(size: 13))
                        .padding(10).background(Color.bgRaised).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }

                Button(action: submit) {
                    HStack(spacing: 6) {
                        if submitting {
                            ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                        }
                        Text(submitting ? "Submitting..." : "Submit Partial Top-Up")
                            .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(canSubmit ? Color.gold : Color.gold.opacity(0.4))
                    .cornerRadius(10)
                }
                .disabled(!canSubmit)

                Spacer()
            }
            .padding(20)
            .background(Color.bgBase.edgesIgnoringSafeArea(.all))
            .navigationBarTitle(Text("Partial Top-Up"), displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark)
                    .disabled(submitting)
            )
        }
    }

    private func submit() {
        guard canSubmit else { return }
        submitting = true
        let amt = Double(amount.trimmingCharacters(in: .whitespaces))
        onConfirm(amt.flatMap { $0 > 0 ? $0 : nil }, trimmedNote) { ok in
            submitting = false
            // Only dismiss on success; on failure keep the sheet open so the user can retry
            if ok { presentationMode.wrappedValue.dismiss() }
        }
    }
}
