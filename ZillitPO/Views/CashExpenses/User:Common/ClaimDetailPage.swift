import SwiftUI

struct ClaimDetailPage: View {
    let claim: ClaimBatch
    @EnvironmentObject var appState: POViewModel

    @State private var showHistory = false
    @State private var showQueries = false
    @State private var showActionsMenu = false
    @State private var historyEntries: [FloatHistoryEntry] = []
    @State private var isLoadingHistory = false

    private var currentStep: Int {
        switch (claim.status ?? "").uppercased() {
        case "CODING": return 0
        case "CODED": return 1
        case "IN_AUDIT": return 2
        case "AWAITING_APPROVAL", "ACCT_OVERRIDE", "APPROVED": return 3
        case "READY_TO_POST", "ESCALATED": return 3
        case "POSTED": return 4
        case "REJECTED": return -1
        default: return 0
        }
    }

    private var statusColors: (Color, Color) {
        switch (claim.status ?? "").uppercased() {
        case "CODING", "CODED": return (.blue, Color.blue.opacity(0.12))
        case "IN_AUDIT": return (.purple, Color.purple.opacity(0.12))
        case "AWAITING_APPROVAL": return (.goldDark, Color.gold.opacity(0.15))
        case "APPROVED", "ACCT_OVERRIDE": return (.green, Color.green.opacity(0.12))
        case "READY_TO_POST": return (.blue, Color.blue.opacity(0.12))
        case "POSTED": return (.green, Color.green.opacity(0.12))
        case "REJECTED": return (.red, Color.red.opacity(0.12))
        case "ESCALATED": return (.orange, Color.orange.opacity(0.12))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private func settlementDisplay(_ s: String) -> String {
        switch s.uppercased() {
        case "REIMBURSE": return "Reimburse"
        case "PAYROLL": return "Payroll"
        case "FLOAT": return "Float"
        default: return s.isEmpty ? "—" : s.capitalized
        }
    }

    private func categoryDisplay(_ c: String) -> String {
        if c.isEmpty { return "—" }
        if let match = claimCategories.first(where: { $0.0 == c }) { return match.1 }
        return c.capitalized
    }

    private func costCodeLabel(_ c: String) -> String {
        if c.isEmpty { return "—" }
        if let match = costCodeOptions.first(where: { $0.0 == c }) { return match.1 }
        return c.uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header: "Receipt Details" + status badge ──────────
                HStack {
                    Text("Receipt Details").font(.system(size: 16, weight: .bold))
                    Spacer()
                    let (fg, bg) = statusColors
                    Text(claim.statusDisplay)
                        .font(.system(size: 11, weight: .bold)).foregroundColor(fg)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(bg).cornerRadius(6)
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

                Divider()

                // ── Progress flow (5 steps) ───────────────────────────
                HStack(spacing: 0) {
                    stepDot(index: 0, label: "Submitted", sub: "Receipts sent")
                    stepDot(index: 1, label: "Coordinator", sub: "Budget coding")
                    stepDot(index: 2, label: "Accounts", sub: "Audit & verify")
                    stepDot(index: 3, label: "Approval", sub: "Sign-off")
                    stepDot(index: 4, label: "Posted", sub: "Ledger / payment")
                }
                .padding(.horizontal, 10).padding(.top, 14).padding(.bottom, 16)

                Divider()

                // ── Summary row: title + amount ───────────────────────
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 16)).foregroundColor(.goldDark)
                        .frame(width: 32, height: 32).background(Color.gold.opacity(0.15)).cornerRadius(6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text((claim.notes ?? "").isEmpty ? ((claim.batchReference ?? "").isEmpty ? "—" : "#\(claim.batchReference!)") : claim.notes!)
                            .font(.system(size: 15, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Text(FormatUtils.formatTimestamp(claim.createdAt ?? 0)).font(.system(size: 11)).foregroundColor(.secondary)
                            Text("·").foregroundColor(.secondary)
                            Text(claim.isPettyCash ? "Petty Cash" : "Out of Pocket")
                                .font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text(FormatUtils.formatGBP(claim.totalGross ?? 0))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.goldDark)
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                Divider()

                // ── 2-column details grid (2 per row) ─────────────────
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        infoCell(label: "BATCH", value: (claim.batchReference ?? "").isEmpty ? "—" : "#\(claim.batchReference!)", mono: true)
                        infoCell(label: "CATEGORY", value: categoryDisplay(claim.category ?? ""))
                    }
                    HStack(alignment: .top, spacing: 16) {
                        infoCell(label: "SETTLEMENT", value: settlementDisplay(claim.settlementType ?? ""))
                        infoCell(label: "COST CODE", value: costCodeLabel(claim.costCode ?? ""))
                    }
                    HStack(alignment: .top, spacing: 16) {
                        infoCell(label: "TYPE", value: claim.isPettyCash ? "Petty Cash" : (claim.isOutOfPocket ? "Out of Pocket" : ((claim.expenseType ?? "").isEmpty ? "—" : claim.expenseType!.uppercased())))
                        infoCell(label: "RECEIPTS", value: "\(claim.claimCount ?? 0)")
                    }
                    HStack(alignment: .top, spacing: 16) {
                        infoCell(label: "TOTAL NET", value: FormatUtils.formatGBP(claim.totalNet ?? 0), mono: true)
                        infoCell(label: "VAT", value: FormatUtils.formatGBP(claim.totalVat ?? 0), mono: true)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                // ── Notes / coding description ────────────────────────
                let desc = (claim.codingDescription ?? "").isEmpty ? (claim.notes ?? "") : claim.codingDescription!
                if !desc.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CODING DESCRIPTION")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        Text(desc).font(.system(size: 13)).foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.bgRaised)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                }

                // ── Rejection banner (tinted callout) ─────────────────
                if let reason = claim.rejectionReason, !reason.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REJECTION REASON")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.red).tracking(0.6)
                        Text(reason).font(.system(size: 12)).foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.red.opacity(0.06))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bgSurface)
        .navigationBarTitle(Text("Receipt Details"), displayMode: .inline)
        .navigationBarItems(trailing: trailingMenu)
        .background(
            NavigationLink(
                destination: ClaimHistoryPage(
                    batchId: resolvedBatchId,
                    label: (claim.batchReference ?? "").isEmpty ? "Claim" : claim.batchReference!,
                    entries: historyEntries,
                    isLoading: isLoadingHistory
                ),
                isActive: $showHistory
            ) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            NavigationLink(
                destination: ClaimQueriesPage(
                    batchId: resolvedBatchId,
                    label: (claim.batchReference ?? "").isEmpty ? "Claim" : claim.batchReference!
                ).environmentObject(appState),
                isActive: $showQueries
            ) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            // iOS 13 dropdown fallback — toggled by the same button as iOS 14+.
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
    }

    // MARK: - Nav bar ellipsis menu (Query / History) — matches InvoiceDetailPage

    /// The list page feeds claim items, so `claim.id` can be an item id.
    /// History/query endpoints operate on the parent batch — prefer `batchId`
    /// when populated, fall back to `id` (already-batch rows).
    private var resolvedBatchId: String {
        (claim.batchId ?? "").isEmpty ? claim.id : claim.batchId!
    }

    private func openHistory() {
        historyEntries = []
        showHistory = true
        isLoadingHistory = true
        appState.loadClaimHistory(resolvedBatchId) { entries in
            historyEntries = entries.sorted { ($0.actionAt ?? 0) > ($1.actionAt ?? 0) }
            isLoadingHistory = false
        }
    }

    private func openQueries() {
        showQueries = true
    }

    @ViewBuilder
    private var trailingMenu: some View {
        if #available(iOS 14.0, *) {
            Menu {
                Button { openQueries() } label: { Label("Query", systemImage: "text.bubble") }
                Button { openHistory() } label: { Label("History", systemImage: "clock.arrow.circlepath") }
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
        }
    }

    private func stepDot(index: Int, label: String, sub: String) -> some View {
        let isDone = index < currentStep
        let isActive = index == currentStep
        let color: Color = isDone ? .green : isActive ? .goldDark : Color.gray.opacity(0.4)
        let labelColor: Color = isDone ? .green : isActive ? .goldDark : .secondary
        return VStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 11, weight: isActive ? .bold : .semibold)).foregroundColor(labelColor).lineLimit(1).minimumScaleFactor(0.7)
            Text(sub).font(.system(size: 9)).foregroundColor(.gray).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func infoCell(label: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(mono ? .system(size: 13, weight: .semibold, design: .monospaced) : .system(size: 13))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Claim History Page (pushed timeline)
// ═══════════════════════════════════════════════════════════════════
//
// Mirrors FloatHistoryPage: colored-icon timeline rail + content card
// per entry. Actions arrive as UPPER_SNAKE_CASE codes from the cash server
// (SUBMITTED, CODING, CODED, IN_AUDIT, APPROVED, REJECTED, POSTED, OVERRIDE,
// ESCALATED, QUERIED, …) and are humanised before display.

struct ClaimHistoryPage: View {
    let batchId: String
    let label: String
    let entries: [FloatHistoryEntry]
    let isLoading: Bool

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            if isLoading {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                    Text("No history yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                    Text("Actions on this claim will appear here.")
                        .font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                            Text(label.isEmpty ? "Claim" : label)
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                                .lineLimit(1)
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

    // MARK: - label / color / icon helpers

    private func actionLabel(_ action: String) -> String {
        let trimmed = action.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "—" }
        switch trimmed.uppercased() {
        case "SUBMITTED":         return "Submitted"
        case "CODING":            return "Coding"
        case "CODED":             return "Coded"
        case "IN_AUDIT":          return "In Audit"
        case "AWAITING_APPROVAL": return "Awaiting Approval"
        case "APPROVED":          return "Approved"
        case "ACCT_OVERRIDE",
             "OVERRIDE":          return "Override Approved"
        case "READY_TO_POST":     return "Ready to Post"
        case "POSTED":            return "Posted"
        case "REJECTED":          return "Rejected"
        case "ESCALATED":         return "Escalated"
        case "QUERIED":           return "Queried"
        default:
            if trimmed.contains("_") || trimmed == trimmed.uppercased() {
                return trimmed
                    .replacingOccurrences(of: "_", with: " ")
                    .lowercased()
                    .split(separator: " ")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                    .joined(separator: " ")
            }
            return trimmed
        }
    }

    private func actionColor(_ action: String) -> Color {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return .green }
        if a.contains("reject") || a.contains("cancel") { return .red }
        if a.contains("override") { return .orange }
        if a.contains("posted") { return .green }
        if a.contains("escalat") { return .red }
        if a.contains("queried") { return .purple }
        if a.contains("code") { return .blue }
        if a.contains("audit") { return Color(red: 0.5, green: 0.3, blue: 0.7) }
        if a.contains("submit") { return .goldDark }
        return .goldDark
    }

    private func actionIcon(_ action: String) -> String {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return "checkmark.circle.fill" }
        if a.contains("reject") { return "xmark.circle.fill" }
        if a.contains("override") { return "bolt.fill" }
        if a.contains("posted") { return "tray.and.arrow.down.fill" }
        if a.contains("escalat") { return "exclamationmark.triangle.fill" }
        if a.contains("queried") { return "text.bubble.fill" }
        if a.contains("audit") { return "magnifyingglass.circle.fill" }
        if a.contains("code") { return "number.circle.fill" }
        if a.contains("submit") { return "paperplane.fill" }
        if a.contains("ready") { return "checkmark.seal.fill" }
        return "circle.fill"
    }

    private func resolvedActor(_ entry: FloatHistoryEntry) -> (String, String?) {
        if let uid = entry.actionBy, !uid.isEmpty, let u = UsersData.byId[uid] {
            return (u.fullName ?? "", u.displayDesignation.isEmpty ? nil : u.displayDesignation)
        }
        if let uid = entry.actionBy, !uid.isEmpty { return (uid, nil) }
        return ("System", nil)
    }

    private func historyRow(_ entry: FloatHistoryEntry, isLast: Bool) -> some View {
        let raw = entry.action ?? ""
        let color = actionColor(raw)
        let (name, role) = resolvedActor(entry)
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: actionIcon(raw))
                        .font(.system(size: 11, weight: .bold)).foregroundColor(color)
                }
                if !isLast {
                    Rectangle().fill(Color.borderColor).frame(width: 2)
                        .frame(maxHeight: .infinity).padding(.top, 2)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(actionLabel(raw))
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if name != "System" {
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

                if let n = entry.note, !n.isEmpty {
                    Text(n).font(.system(size: 12)).foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let ts = entry.actionAt, ts > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.gray)
                        Text(FormatUtils.formatDateTime(ts))
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
// MARK: - Claim Queries Page (chat thread)
// ═══════════════════════════════════════════════════════════════════
//
// Mirrors InvoiceQueriesPage + TransactionQueriesPage. Hits
//   GET /api/v2/account-hub/queries/entity/claim_batch/{batchId}
// via appState.loadClaimQueries and reads from appState.claimQueries.

struct ClaimQueryMessage: Identifiable {
    let id: String
    let userId: String?
    let userName: String?
    let text: String
    let timestamp: Int64?
    let isLocal: Bool
}

struct ClaimQueriesPage: View {
    @EnvironmentObject var appState: POViewModel
    let batchId: String
    let label: String

    @State private var draft: String = ""
    @State private var localMessages: [ClaimQueryMessage] = []

    private var thread: InvoiceQueryThread? { appState.claimQueries[batchId] }

    private var messages: [ClaimQueryMessage] {
        var list: [ClaimQueryMessage] = []
        if let t = thread {
            for m in t.messages ?? [] {
                guard let body = m.query, !body.isEmpty else { continue }
                list.append(ClaimQueryMessage(
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

    var body: some View {
        VStack(spacing: 0) {
            Text(label.isEmpty ? "—" : label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 10)

            Divider()

            Group {
                if appState.claimQueriesLoading && messages.isEmpty {
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
        .onAppear { appState.loadClaimQueries(batchId) }
    }

    private func messageBubble(_ m: ClaimQueryMessage) -> some View {
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
                    Text(stamp).font(.system(size: 10)).foregroundColor(.gray)
                }
            }
        }
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let me = appState.currentUser
        localMessages.append(ClaimQueryMessage(
            id: UUID().uuidString,
            userId: me?.id,
            userName: me?.fullName,
            text: text,
            timestamp: now,
            isLocal: true
        ))
        draft = ""
        print("⚠️ sendClaimQueryMessage: no POST endpoint wired yet. Message added locally.")
    }
}
