//
//  DMDealsPage.swift
//  ZillitPO
//
//  Deal Memos list — matches the iOS design (rich card per deal with
//  department pill, status dot, PER DAY rate, term/total/structure row,
//  start→end progress bar, plus a floating "+" action that pushes the
//  wizard host).
//

import SwiftUI

struct DMDealsPage: View {
    @EnvironmentObject var dm: DealMemoViewModel
    @State private var showCreate = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                searchAndFilterRow

                if dm.isLoadingDeals {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if filtered.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filtered) { deal in
                            DMDealCard(deal: deal).environmentObject(dm)
                        }
                    }
                }
                // Bottom padding so the FAB never sits on top of the last card
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 16)

            // Floating "+" — pushes the wizard host
            NavigationLink(destination: DMCreatePage(), isActive: $showCreate) { EmptyView() }.hidden()
            Button(action: { showCreate = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.goldDark)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.trailing, 18)
            .padding(.bottom, 18)
        }
        .onAppear { if dm.deals.isEmpty { dm.loadDeals() } }
    }

    // MARK: - Search + filter

    private var searchAndFilterRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("Search crew, reference, role", text: $dm.searchText)
                    .font(.system(size: 13))
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.bgRaised)
            .cornerRadius(12)

            Button(action: { /* TODO: filter sheet */ }) {
                HStack(spacing: 6) {
                    Text("Filter").font(.system(size: 13, weight: .semibold))
                    Text("\(dm.deals.count)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.bgSurface)
                        .cornerRadius(6)
                    Image(systemName: "chevron.down").font(.system(size: 10))
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.bgRaised)
                .cornerRadius(12)
                .foregroundColor(.primary)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "tray").font(.system(size: 28)).foregroundColor(.secondary.opacity(0.5))
            Text("No deals match these filters.").font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var filtered: [DealMemo] {
        let q = dm.searchText.lowercased()
        return dm.deals.filter { deal in
            if let s = dm.statusFilter, deal.poStatus != s { return false }
            if !q.isEmpty {
                let ref = (deal.dealReference ?? "").lowercased()
                let crew = dm.crewName(for: deal).lowercased()
                let pos = dm.position(for: deal).lowercased()
                if !ref.contains(q) && !crew.contains(q) && !pos.contains(q) { return false }
            }
            return true
        }
    }
}

// MARK: - Deal card

struct DMDealCard: View {
    @EnvironmentObject var dm: DealMemoViewModel
    let deal: DealMemo

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top row: dept pill + status pill
            HStack {
                DMDeptPill(department: deal.departmentId)
                Spacer()
                DMStatusPill(status: deal.poStatus)
            }

            // Crew name + position/ref + per-day rate
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dm.crewName(for: deal))
                        .font(.system(size: 22, weight: .bold))
                    HStack(spacing: 4) {
                        Text(dm.position(for: deal))
                        Text("·").foregroundColor(.secondary.opacity(0.6))
                        Text(deal.dealReference ?? "—")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("PER DAY")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(dm.formattedDailyRate(deal))
                        .font(.system(size: 22, weight: .bold))
                }
            }

            // 3-column metadata row
            HStack(alignment: .top, spacing: 18) {
                metaColumn(label: "TERM",       value: termLabel,        valueColor: .primary)
                metaColumn(label: "DEAL TOTAL", value: dealTotalLabel,   valueColor: .goldDark)
                metaColumn(label: "STRUCTURE",  value: structureLabel,   valueColor: .primary)
                Spacer(minLength: 0)
            }

            // Progress bar with start / % complete / end
            progressSection
        }
        .padding(16)
        .background(Color.bgSurface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderSubtle, lineWidth: 1))
    }

    private func metaColumn(label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }

    private var progressSection: some View {
        let pct = max(0, min(1, progressFraction))
        return VStack(spacing: 6) {
            HStack {
                Text(startDateLabel).font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(pct * 100))% complete")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.21, green: 0.64, blue: 0.37))
                Spacer()
                Text(endDateLabel).font(.system(size: 11)).foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.bgRaised).frame(height: 4)
                    Capsule()
                        .fill(Color(red: 0.21, green: 0.64, blue: 0.37))
                        .frame(width: max(2, geo.size.width * CGFloat(pct)), height: 4)
                }
            }.frame(height: 4)
        }
    }

    // MARK: - Derived display fields
    //
    // Pulled inline because the demo `DealMemo` model doesn't yet model
    // term/structure/progress as first-class fields. When the full live
    // model lands (with `contract_term`, `structure_type`, lifecycle
    // dates) these computeds get replaced by direct property reads.

    private var termLabel: String {
        // Live carries `term_weeks` on the deal. Demo computes a stub
        // from createdAt → updatedAt if both present, otherwise "—".
        if let start = deal.createdAt, let end = deal.activatedAt ?? deal.approvedAt {
            let secs = max(0, (end - start) / 1000)
            let weeks = Int(secs / (7 * 24 * 60 * 60))
            if weeks > 0 { return "\(weeks) wks" }
        }
        return "—"
    }

    private var dealTotalLabel: String {
        guard let daily = deal.rates?.daily?.rate, daily > 0 else { return "—" }
        // Term in weeks × 5 days × daily — rough stub.
        let weeks: Double = {
            if let start = deal.createdAt, let end = deal.activatedAt ?? deal.approvedAt {
                let secs = max(0, Double(end - start) / 1000)
                return secs / (7 * 24 * 60 * 60)
            }
            return 0
        }()
        let total = daily * weeks * 5
        if total >= 1000 {
            return "\(DealMemoViewModel.currencySymbol(deal.rates?.contractCurrency))\(Int(total / 1000))k"
        }
        return "\(DealMemoViewModel.currencySymbol(deal.rates?.contractCurrency))\(Int(total))"
    }

    private var structureLabel: String {
        // Live exposes `rate_structure` (weekly / daily / hourly / fixed).
        // Demo infers from which rate row is populated.
        if (deal.rates?.weekly?.rate ?? 0) > 0 { return "Weekly" }
        if (deal.rates?.hourly?.rate ?? 0) > 0 { return "Hourly" }
        if (deal.rates?.daily?.rate ?? 0) > 0  { return "Daily" }
        return "Fixed"
    }

    private var progressFraction: Double {
        guard let start = deal.createdAt, let end = deal.activatedAt ?? deal.approvedAt, end > start else { return 0 }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let clamped = max(start, min(end, now))
        return Double(clamped - start) / Double(end - start)
    }

    private static let monthDayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private var startDateLabel: String {
        guard let ms = deal.createdAt else { return "—" }
        return Self.monthDayFmt.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }

    private var endDateLabel: String {
        guard let ms = deal.activatedAt ?? deal.approvedAt else { return "—" }
        return Self.monthDayFmt.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }
}

// MARK: - Department pill

private struct DMDeptPill: View {
    let department: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(label).font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(tint.opacity(0.15))
        .foregroundColor(tint)
        .clipShape(Capsule())
    }

    private var label: String {
        guard let d = department, !d.isEmpty else { return "—" }
        return FormatUtils.formatLabel(d)
    }

    private var tint: Color {
        let key = (department ?? "").lowercased()
        if key.contains("camera")        { return Color(red: 0.20, green: 0.50, blue: 0.86) } // blue
        if key.contains("art")           { return Color(red: 0.62, green: 0.40, blue: 0.85) } // purple
        if key.contains("costume") ||
           key.contains("wardrobe")      { return Color(red: 0.91, green: 0.51, blue: 0.62) } // pink
        if key.contains("electric") ||
           key.contains("lighting")      { return Color(red: 0.96, green: 0.62, blue: 0.20) } // amber
        if key.contains("sound")         { return Color(red: 0.20, green: 0.74, blue: 0.69) } // teal
        if key.contains("production")    { return Color(red: 0.35, green: 0.72, blue: 0.36) } // green
        return Color.gray
    }
}

// MARK: - Status pill

private struct DMStatusPill: View {
    let status: DealMemoStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(displayLabel).font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(tint)
    }

    /// Display matches the design's "In Production" copy for `.active`.
    private var displayLabel: String {
        switch status {
        case .active:            return "In Production"
        case .awaitingApproval:  return "Awaiting Approval"
        case .approved:          return "Approved"
        case .draft:             return "Draft"
        case .rejected:          return "Rejected"
        case .completed:         return "Completed"
        case .cancelled:         return "Cancelled"
        }
    }

    private var tint: Color {
        switch status.tokenColor {
        case "green": return Color(red: 0.21, green: 0.64, blue: 0.37)
        case "amber": return Color(red: 0.96, green: 0.62, blue: 0.20)
        case "red":   return .red
        case "blue":  return Color(red: 0.20, green: 0.50, blue: 0.86)
        default:      return .gray
        }
    }
}
