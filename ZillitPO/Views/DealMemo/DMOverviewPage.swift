//
//  DMOverviewPage.swift
//  ZillitPO
//
//  Faithful port of `DMOverviewPage.jsx`. Renders:
//    1. Info banner
//    2. 4 stat cards (Total / Active / Awaiting Approval / Total Daily Value)
//    3. Recent deals table (5 cols: Reference, Crew, Position, Rate/Day, Status)
//    4. Department breakdown bar chart
//    5. Status summary
//

import SwiftUI

struct DMOverviewPage: View {
    @EnvironmentObject var dm: DealMemoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if dm.isLoadingOverview {
                loading
            } else if let error = dm.overviewError {
                errorState(error)
            } else {
                content
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .onAppear {
            if dm.overview == nil && !dm.isLoadingOverview { dm.loadOverview() }
        }
    }

    private var loading: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Loading...").font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 6) {
            Text(message).font(.system(size: 13)).foregroundColor(.red)
            Text("Refresh the page once the deal-memo server is reachable.")
                .font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    @ViewBuilder
    private var content: some View {
        infoBanner
        statsRow
        recentDealsCard
        departmentBreakdownCard
        statusSummaryCard
    }

    // MARK: - Info banner

    private var infoBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 14))
                .foregroundColor(.goldDark)
            VStack(alignment: .leading, spacing: 1) {
                Text("Deal Memo Overview")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.goldDark)
                Text("Track crew contracts, rates, and deal statuses across all departments.")
                    .font(.system(size: 11))
                    .foregroundColor(.goldDark.opacity(0.8))
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.gold.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Stat cards

    private var statsRow: some View {
        let s = dm.overview?.stats
        let totalValue = s?.totalValue ?? 0
        let valueLabel = "£\(NumberFormatter.localizedString(from: NSNumber(value: totalValue), number: .decimal))"
        let items: [(String, String, Color)] = [
            ("Total Deals",       "\(s?.total ?? 0)",            .primary),
            ("Active",            "\(s?.active ?? 0)",           Color(red: 0.21, green: 0.64, blue: 0.37)),
            ("Awaiting Approval", "\(s?.awaitingApproval ?? 0)", Color(red: 0.96, green: 0.62, blue: 0.20)),
            ("Total Daily Value", valueLabel,                    .goldDark),
        ]
        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(items, id: \.0) { item in
                statCard(label: item.0, value: item.1, color: item.2)
            }
        }
    }

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Recent deals

    private var recentDealsCard: some View {
        let recent = dm.overview?.recent ?? []
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent Deal Memos")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Button(action: { dm.activeTab = .deals }) {
                    HStack(spacing: 3) {
                        Text("View all")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.goldDark)
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            Divider().background(Color.borderColor)

            if recent.isEmpty {
                Text("No deal memos yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                ForEach(recent) { deal in
                    DMOverviewRecentRow(deal: deal)
                        .environmentObject(dm)
                    if deal.id != recent.last?.id {
                        Divider().background(Color.borderSubtle).padding(.leading, 12)
                    }
                }
            }
        }
        .background(Color.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Department breakdown

    private var departmentBreakdownCard: some View {
        let breakdown = dm.overview?.departmentBreakdown ?? []
        let total = max(1, breakdown.reduce(0) { $0 + ($1.count ?? 0) })
        return VStack(alignment: .leading, spacing: 10) {
            Text("By Department")
                .font(.system(size: 12, weight: .bold))
            if breakdown.isEmpty {
                Text("No departments yet.")
                    .font(.system(size: 11)).italic()
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(breakdown.enumerated()), id: \.offset) { idx, row in
                    deptBar(row: row, total: total, paletteIndex: idx)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    /// Same rotating palette as `DEPT_COLOR_PALETTE` in the React file.
    private static let palette: [Color] = [
        Color(red: 0.38, green: 0.65, blue: 0.96), // blue
        Color(red: 0.96, green: 0.74, blue: 0.27), // amber
        Color(red: 0.66, green: 0.45, blue: 0.91), // purple
        Color(red: 0.20, green: 0.74, blue: 0.69), // teal
        Color(red: 0.97, green: 0.55, blue: 0.25), // orange
        Color(red: 0.96, green: 0.42, blue: 0.62), // pink
    ]

    private func deptBar(row: DealMemoDeptBreakdown, total: Int, paletteIndex: Int) -> some View {
        let count = row.count ?? 0
        let fraction = Double(count) / Double(total)
        let name: String = {
            guard let d = row.department, !d.isEmpty else { return "—" }
            return FormatUtils.formatLabel(d)
        }()
        return HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.bgRaised).frame(height: 6)
                    Capsule()
                        .fill(Self.palette[paletteIndex % Self.palette.count])
                        .frame(width: max(2, geo.size.width * CGFloat(fraction)), height: 6)
                }
            }.frame(height: 6)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 22, alignment: .trailing)
        }
    }

    // MARK: - Status summary

    private var statusSummaryCard: some View {
        let s = dm.overview?.stats
        let rows: [(String, Int, Color)] = [
            ("Active",            s?.active ?? 0,           Color(red: 0.30, green: 0.78, blue: 0.45)),
            ("Awaiting Approval", s?.awaitingApproval ?? 0, Color(red: 0.96, green: 0.62, blue: 0.20)),
            ("Draft",             s?.draft ?? 0,            Color.gray.opacity(0.6)),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            Text("Status Summary")
                .font(.system(size: 12, weight: .bold))
            ForEach(rows, id: \.0) { row in
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(row.2).frame(width: 8, height: 8)
                        Text(row.0)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(row.1)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }
}

// MARK: - Row

private struct DMOverviewRecentRow: View {
    @EnvironmentObject var dm: DealMemoViewModel
    let deal: DealMemo

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(deal.dealReference ?? "—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(dm.crewName(for: deal))
                    .font(.system(size: 12, weight: .semibold))
                Text(dm.position(for: deal))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(dm.formattedDailyRate(deal))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                StatusBadge(deal.poStatus.label, color: tokenColor(deal.poStatus.tokenColor))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func tokenColor(_ token: String) -> Color {
        switch token {
        case "gray":  return .gray
        case "amber": return Color(red: 0.96, green: 0.62, blue: 0.20)
        case "green": return Color(red: 0.21, green: 0.64, blue: 0.37)
        case "red":   return .red
        case "blue":  return Color(red: 0.20, green: 0.50, blue: 0.86)
        default:      return .gray
        }
    }
}
