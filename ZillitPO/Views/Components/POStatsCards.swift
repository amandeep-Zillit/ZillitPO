import SwiftUI

struct POStatsCards: View {
    @EnvironmentObject var appState: POViewModel
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatCard(title: "Total POs", value: "\(appState.filteredPOs.count)")
                StatCard(title: "Pending", value: "\(appState.pendingCount)", color: .goldDark)
            }
            HStack(spacing: 10) {
                StatCard(title: "Approved", value: "\(appState.approvedCount)", color: .green)
                StatCard(title: "Total Value", value: FormatUtils.formatGBP(appState.totalValue), color: .goldDark)
            }
        }
    }
}

struct StatCard: View {
    let title: String; let value: String; var color: Color = .primary
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary)
            Text(value).font(.system(size: 22, design: .monospaced)).foregroundColor(color).lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}
