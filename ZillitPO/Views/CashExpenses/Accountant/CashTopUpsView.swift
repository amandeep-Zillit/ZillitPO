import SwiftUI

struct CashTopUpsView: View {
    @EnvironmentObject var appState: POViewModel

    enum TopUpFilter: String, CaseIterable {
        case all = "All", pending = "Pending", completed = "Completed", skipped = "Skipped"
    }
    @State private var activeFilter: TopUpFilter = .all
    @State private var showFilterSheet = false

    private var pending: [TopUpItem] {
        appState.cashTopUpQueue
            .filter { ($0.status ?? "").lowercased() == "pending" }
            .sorted { ($0.createdAt ?? 0) < ($1.createdAt ?? 0) }
    }

    private var history: [TopUpItem] {
        appState.cashTopUpQueue
            .filter { ["completed", "partial", "skipped"].contains(($0.status ?? "").lowercased()) }
            .sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }
    }

    private var filteredPending: [TopUpItem] {
        switch activeFilter {
        case .all, .pending: return pending
        default: return []
        }
    }

    private var filteredHistory: [TopUpItem] {
        switch activeFilter {
        case .all: return history
        case .pending: return []
        case .completed: return history.filter { ["completed", "partial"].contains(($0.status ?? "").lowercased()) }
        case .skipped: return history.filter { ($0.status ?? "").lowercased() == "skipped" }
        }
    }

    var body: some View {
        Group {
            if appState.isLoadingTopUps && appState.cashTopUpQueue.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
                    .background(Color.bgBase)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        infoBanner
                        filterBar
                        if !filteredPending.isEmpty { pendingSection }
                        if !filteredHistory.isEmpty { historySection }
                        if filteredPending.isEmpty && filteredHistory.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
                }
                .background(Color.bgBase)
            }
        }
        .onAppear { appState.loadTopUpQueue() }
    }

    // ── Orange info banner ────────────────────────────────────────
    private var infoBanner: some View {
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "chart.bar.fill").font(.system(size: 12)).foregroundColor(orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Petty Cash Top-Ups")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(orange)
                Text("Cash float top-up requests created from crew claim submissions. Mark as topped-up when you hand over the cash.")
                    .font(.system(size: 11)).foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(orange.opacity(0.08)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(orange.opacity(0.25), lineWidth: 1))
    }

    // ── Filter dropdown (compact action sheet) ────────────────────
    private var filterBar: some View {
        HStack(spacing: 6) {
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
                .background(Color.bgSurface).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
            .selectionActionSheet(
                title: "Filter by Status",
                isPresented: $showFilterSheet,
                options: TopUpFilter.allCases,
                isSelected: { $0 == activeFilter },
                label: { $0.rawValue },
                onSelect: { activeFilter = $0 }
            )
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle").font(.system(size: 28)).foregroundColor(.gray.opacity(0.35))
            Text("No top-ups match this filter").font(.system(size: 13)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private var summaryCards: some View {
        let pendingTotal = pending.reduce(0.0) { $0 + ($1.amount ?? 0) }
        let completedTotal = history.filter { ($0.status ?? "").lowercased() == "completed" }.reduce(0.0) { $0 + ($1.amount ?? 0) }
        return HStack(spacing: 8) {
            statCard(label: "PENDING", value: FormatUtils.formatGBP(pendingTotal),
                     sub: "\(pending.count) request\(pending.count == 1 ? "" : "s")",
                     color: Color(red: 0.95, green: 0.55, blue: 0.15))
            statCard(label: "COMPLETED", value: FormatUtils.formatGBP(completedTotal),
                     sub: "\(history.filter { ($0.status ?? "").lowercased() == "completed" }.count) completed",
                     color: Color(red: 0.0, green: 0.6, blue: 0.5))
        }
        .frame(height: 80)
    }

    private func statCard(label: String, value: String, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            Text(value).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(color)
            Text(sub).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(Color.bgSurface).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
    }

    private var pendingSection: some View {
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").font(.system(size: 12)).foregroundColor(orange)
                Text("PENDING TOP-UPS").font(.system(size: 11, weight: .bold)).tracking(0.4)
                Text("\(filteredPending.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(orange).cornerRadius(8)
                Spacer()
            }
            .padding(12).background(orange.opacity(0.06))

            ForEach(filteredPending) { item in
                Divider()
                cashTopUpRow(item, isPending: true)
            }
        }
        .background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private var historySection: some View {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let title: String = {
            switch activeFilter {
            case .completed: return "COMPLETED"
            case .skipped:   return "SKIPPED"
            default:         return "COMPLETED & SKIPPED"
            }
        }()
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundColor(teal)
                Text(title).font(.system(size: 11, weight: .bold)).tracking(0.4)
                Text("\(filteredHistory.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2)).cornerRadius(8)
                Spacer()
            }
            .padding(12).background(Color.gray.opacity(0.06))

            ForEach(filteredHistory) { item in
                Divider()
                cashTopUpRow(item, isPending: false)
            }
        }
        .background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private func cashTopUpRow(_ item: TopUpItem, isPending: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Info section — wrapped in NavigationLink so tapping opens the
            // full-page Top-Up Details view. Action buttons stay outside
            // the link so they don't trigger navigation.
            NavigationLink(destination: CashTopUpDetailPage(item: item)) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text((item.holderName ?? "").isEmpty ? "—" : (item.holderName ?? ""))
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                        if !(item.department ?? "").isEmpty {
                            Text(item.department ?? "").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        if !(item.floatReqNumber ?? "").isEmpty {
                            Text(item.floatReqNumber ?? "").font(.system(size: 10, design: .monospaced)).foregroundColor(.goldDark)
                        }
                        // Date/time line — "Requested DD MMM YYYY | h:mm a"
                        // for pending items, "Completed …" / "Skipped …" for
                        // history items (uses updatedAt when available).
                        if let dateLine = topUpDateLine(item, isPending: isPending), !dateLine.isEmpty {
                            Text(dateLine)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(FormatUtils.formatGBP(item.amount ?? 0))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
                        statusBadge(item.status ?? "")
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10)).foregroundColor(.gray.opacity(0.6))
                        .padding(.leading, 2).padding(.top, 4)
                }
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if isPending {
                HStack(spacing: 8) {
                    Button(action: { appState.markTopUpCompleted(item.id ?? "", amount: item.amount ?? 0) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 11))
                            Text("Mark Topped Up").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color(red: 0.0, green: 0.6, blue: 0.5)).cornerRadius(6)
                    }.buttonStyle(BorderlessButtonStyle())
                    Button(action: { appState.skipTopUp(item.id ?? "") }) {
                        Text("Skip").font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                    Spacer()
                }
            }
        }
        .padding(12)
    }

    /// Builds the date/time line shown under each top-up row.
    ///   • Pending → "Requested 14 Apr 2026 | 10:42 AM"
    ///   • History → "Completed 14 Apr 2026 | 11:03 AM" (uses updatedAt),
    ///     or "Skipped …" for skipped items.
    /// Falls back to createdAt if updatedAt isn't set.
    private func topUpDateLine(_ item: TopUpItem, isPending: Bool) -> String? {
        let ts: Int64 = isPending ? (item.createdAt ?? 0) : ((item.updatedAt ?? 0) > 0 ? (item.updatedAt ?? 0) : (item.createdAt ?? 0))
        guard ts > 0 else { return nil }
        let stamp = FormatUtils.formatDateTime(ts)
        if isPending { return "Requested \(stamp)" }
        switch (item.status ?? "").lowercased() {
        case "completed": return "Completed \(stamp)"
        case "partial":   return "Partial top-up \(stamp)"
        case "skipped":   return "Skipped \(stamp)"
        default:          return stamp
        }
    }

    private func statusBadge(_ s: String) -> some View {
        let (fg, bg, label): (Color, Color, String) = {
            switch s.lowercased() {
            case "pending":   return (Color(red: 0.95, green: 0.55, blue: 0.15), Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.12), "Pending")
            case "completed": return (Color(red: 0.0, green: 0.6, blue: 0.5), Color(red: 0.0, green: 0.6, blue: 0.5).opacity(0.12), "Completed")
            case "partial":   return (.blue, Color.blue.opacity(0.12), "Partial")
            case "skipped":   return (.gray, Color.gray.opacity(0.12), "Skipped")
            default:          return (.secondary, Color.gray.opacity(0.12), s.capitalized)
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(bg).cornerRadius(4)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Cash Top-Up Detail Page
// Full-page layout matching the "Top-Up Details" screenshot:
// header with icon, then a 2x2 grid of details (HOLDER / FLOAT,
// AMOUNT / STATUS, FLOAT BALANCE / FLOAT ISSUED, CREATED / UPDATED).
// ═══════════════════════════════════════════════════════════════════

struct CashTopUpDetailPage: View {
    let item: TopUpItem

    private var user: AppUser? { UsersData.byId[item.userId ?? ""] }

    private var subtitleLine: String {
        let role = user?.displayDesignation ?? ""
        let dept = (item.department ?? "").isEmpty ? (user?.displayDepartment ?? "") : (item.department ?? "")
        switch (role.isEmpty, dept.isEmpty) {
        case (false, false): return "\(role) · \(dept)"
        case (false, true):  return role
        case (true, false):  return dept
        default:             return ""
        }
    }

    private var statusDisplay: String { item.statusDisplay }

    private var statusColor: Color {
        switch (item.status ?? "").lowercased() {
        case "pending":   return Color(red: 0.95, green: 0.55, blue: 0.15)
        case "completed": return Color(red: 0.0,  green: 0.6,  blue: 0.5)
        case "partial":   return .blue
        case "skipped":   return .gray
        default:          return .secondary
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header: icon + "Top-Up Details" ─────────────────────
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18)).foregroundColor(.goldDark)
                        .frame(width: 34, height: 34)
                        .background(Color.gold.opacity(0.15)).cornerRadius(8)
                    Text("Top-Up Details").font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

                Divider()

                // ── 2-column grid of details ────────────────────────────
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        detailCell(
                            label: "HOLDER",
                            primary: (item.holderName ?? "").isEmpty ? "—" : (item.holderName ?? ""),
                            secondary: subtitleLine
                        )
                        detailCell(
                            label: "FLOAT",
                            primary: (item.floatReqNumber ?? "").isEmpty ? "—" : "#\(item.floatReqNumber ?? "")",
                            mono: true
                        )
                    }
                    HStack(alignment: .top, spacing: 16) {
                        detailCell(
                            label: "AMOUNT",
                            primary: FormatUtils.formatGBP(item.amount ?? 0),
                            primaryColor: Color(red: 0.95, green: 0.55, blue: 0.15),
                            mono: true
                        )
                        detailCell(
                            label: "STATUS",
                            primary: statusDisplay,
                            primaryColor: statusColor
                        )
                    }
                    HStack(alignment: .top, spacing: 16) {
                        detailCell(
                            label: "FLOAT BALANCE",
                            primary: FormatUtils.formatGBP(item.floatBalance ?? 0),
                            mono: true
                        )
                        detailCell(
                            label: "FLOAT ISSUED",
                            primary: FormatUtils.formatGBP(item.floatIssued ?? 0),
                            mono: true
                        )
                    }
                    HStack(alignment: .top, spacing: 16) {
                        detailCell(
                            label: "CREATED",
                            primary: (item.createdAt ?? 0) > 0 ? FormatUtils.formatDateTime(item.createdAt ?? 0) : "—",
                            mono: true
                        )
                        detailCell(
                            label: "UPDATED",
                            primary: (item.updatedAt ?? 0) > 0 ? FormatUtils.formatDateTime(item.updatedAt ?? 0) : "—",
                            mono: true
                        )
                    }
                }
                .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 18)

                // ── Optional note ───────────────────────────────────────
                if !(item.note ?? "").isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTE")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        Text(item.note ?? "").font(.system(size: 13)).foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).background(Color.bgRaised).cornerRadius(8)
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bgSurface)
        .navigationBarTitle(Text("Top-Up Details"), displayMode: .inline)
    }

    /// Two-line cell: uppercase grey label on top, bold value below,
    /// optional secondary line under the primary (used by HOLDER which
    /// shows the role · department under the name).
    private func detailCell(label: String,
                            primary: String,
                            secondary: String? = nil,
                            primaryColor: Color = .primary,
                            mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            Text(primary)
                .font(mono
                      ? .system(size: 15, weight: .bold, design: .monospaced)
                      : .system(size: 15, weight: .semibold))
                .foregroundColor(primaryColor)
                .fixedSize(horizontal: false, vertical: true)
            if let s = secondary, !s.isEmpty {
                Text(s).font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
