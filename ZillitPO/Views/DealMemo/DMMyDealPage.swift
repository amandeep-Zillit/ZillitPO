//
//  DMMyDealPage.swift
//  ZillitPO
//
//  Port of `DMMyDealPage.jsx` — singular preview of the current user's
//  deal memo. The React file delegates straight to `DMDealPreviewPage`
//  once the deal id is resolved; we mirror that by showing a compact
//  summary card plus a "View full deal" CTA (full preview port lands
//  alongside `DMDealPreviewPage` in a follow-up turn).
//

import SwiftUI

struct DMMyDealPage: View {
    @EnvironmentObject var dm: DealMemoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dm.isLoadingMyDeal {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            } else if let deal = dm.myDeal {
                summaryCard(for: deal)
                // TODO: route into DMDealPreviewPage(dealId:) once that
                // file is ported in the follow-up turn.
            } else {
                emptyState
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .onAppear { if dm.myDeal == nil && !dm.isLoadingMyDeal { dm.loadMyDeal() } }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.secondary.opacity(0.5))
            Text("No deal memo on file for you yet.")
                .font(.system(size: 12)).foregroundColor(.secondary)
            Text("Once Production raises one, it'll show up here.")
                .font(.system(size: 11)).foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func summaryCard(for deal: DealMemo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(deal.dealReference ?? "—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                StatusBadge(deal.poStatus.label, color: statusColor(deal.poStatus))
            }
            Text(dm.crewName(for: deal)).font(.system(size: 16, weight: .bold))
            Text(dm.position(for: deal)).font(.system(size: 12)).foregroundColor(.secondary)

            Divider().background(Color.borderSubtle)

            HStack(alignment: .top, spacing: 16) {
                infoCol("Daily Rate", value: dm.formattedDailyRate(deal))
                infoCol("Currency",    value: deal.rates?.contractCurrency ?? "GBP")
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private func infoCol(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
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
