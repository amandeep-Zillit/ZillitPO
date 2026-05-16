//
//  MyTimecardsModule.swift
//  ZillitPO
//
//  Scaffold for `MyTimecardsModule.jsx` (1,545 LOC). Lists the current
//  user's weekly summaries with status badges + hours + gross pay.
//

import SwiftUI

struct MyTimecardsModule: View {
    @EnvironmentObject var tc: TimecardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if tc.isLoadingMySummary {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if tc.mySummary.isEmpty {
                    emptyState
                } else {
                    ForEach(tc.mySummary) { row in
                        summaryRow(row)
                    }
                }
            }
            .padding(16)
        }
        .navigationBarTitle("My Time Cards", displayMode: .inline)
        .background(Color.bgBase.edgesIgnoringSafeArea(.all))
        .onAppear { if tc.mySummary.isEmpty { tc.loadMySummary() } }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No timecards yet").font(.system(size: 13)).foregroundColor(.secondary)
            Text("Your weekly summaries will appear here once you start logging.")
                .font(.system(size: 11)).foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func summaryRow(_ row: TimecardSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(TimecardViewModel.weekOfLabel(row.weekStarting))
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 6) {
                    Text(row.timecardNumber ?? "—")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("·").foregroundColor(.secondary.opacity(0.5))
                    Text("\(row.daysWorked ?? 0) days")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(TimecardViewModel.grossLabel(row.grossPay, currency: row.currency))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                StatusBadge(row.tcStatus.label, color: statusColor(row.tcStatus))
            }
        }
        .padding(12)
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func statusColor(_ s: TimecardStatus) -> Color {
        switch s.tokenColor {
        case "amber": return Color(red: 0.96, green: 0.62, blue: 0.20)
        case "green": return Color(red: 0.21, green: 0.64, blue: 0.37)
        case "red":   return .red
        case "blue":  return Color(red: 0.20, green: 0.50, blue: 0.86)
        default:      return .gray
        }
    }
}
