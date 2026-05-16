//
//  DMDealsPage.swift
//  ZillitPO
//
//  Port of `DMDealsPage.jsx` — list of all deal memos with status filter
//  + search. The React file has fancier filtering / column ordering;
//  this is a tight first cut that uses the same API + visuals.
//

import SwiftUI

struct DMDealsPage: View {
    @EnvironmentObject var dm: DealMemoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchBar
            filterChips
            if dm.isLoadingDeals {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            } else if filtered.isEmpty {
                emptyState
            } else {
                ForEach(filtered) { deal in
                    DMDealRow(deal: deal)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .onAppear { if dm.deals.isEmpty { dm.loadDeals() } }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            TextField("Search by reference, crew name…", text: $dm.searchText)
                .font(.system(size: 13))
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.bgSurface)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(label: "All", isActive: dm.statusFilter == nil) { dm.statusFilter = nil }
                ForEach(DealMemoStatus.allCases, id: \.self) { st in
                    chip(label: st.label, isActive: dm.statusFilter == st) { dm.statusFilter = st }
                }
            }
        }
    }

    private func chip(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(isActive ? Color.gold.opacity(0.18) : Color.bgSurface)
                .foregroundColor(isActive ? .goldDark : .secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.goldDark.opacity(0.4) : Color.borderColor, lineWidth: 1)
                )
                .cornerRadius(12)
        }.buttonStyle(BorderlessButtonStyle())
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
                if !ref.contains(q) && !crew.contains(q) { return false }
            }
            return true
        }
    }
}

private struct DMDealRow: View {
    @EnvironmentObject var dm: DealMemoViewModel
    let deal: DealMemo

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(deal.dealReference ?? "—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(dm.crewName(for: deal))
                    .font(.system(size: 13, weight: .semibold))
                Text(dm.position(for: deal))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(dm.formattedDailyRate(deal))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                StatusBadge(deal.poStatus.label, color: statusColor(deal.poStatus))
            }
        }
        .padding(12)
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func statusColor(_ s: DealMemoStatus) -> Color {
        switch s.tokenColor {
        case "amber": return Color(red: 0.96, green: 0.62, blue: 0.20)
        case "green": return Color(red: 0.21, green: 0.64, blue: 0.37)
        case "red":   return .red
        case "blue":  return Color(red: 0.20, green: 0.50, blue: 0.86)
        default:      return .gray
        }
    }
}
