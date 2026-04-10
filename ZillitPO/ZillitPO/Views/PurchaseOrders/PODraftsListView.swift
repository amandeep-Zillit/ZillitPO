import SwiftUI

struct PODraftsListView: View {
    @EnvironmentObject var appState: POViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                StatCard(title: "Drafts", value: "\(appState.drafts.count)")
                StatCard(title: "Draft Value", value: FormatUtils.formatGBP(appState.drafts.reduce(0) { $0 + $1.netAmount }), color: .goldDark)
            }
            if appState.drafts.isEmpty {
                VStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                    Text("No drafts yet").font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, minHeight: 480)
            } else {
                ForEach(appState.drafts, id: \.id) { draft in
                    HStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.poNumber.isEmpty ? "—" : draft.poNumber).font(.system(size: 11, design: .monospaced)).foregroundColor(.goldDark)
                                Text(draft.vendor.isEmpty ? "—" : draft.vendor).font(.system(size: 13, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                            }
                            Spacer()
                            Text(FormatUtils.formatCurrency(draft.netAmount, code: draft.currency)).font(.system(size: 13, design: .monospaced)).foregroundColor(.primary)
                            Text("Draft").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.gold.opacity(0.15)).cornerRadius(4)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { appState.resumeDraft = draft }

                        Image(systemName: "trash").font(.system(size: 11)).foregroundColor(.red.opacity(0.6))
                            .padding(10)
                            .contentShape(Rectangle())
                            .onTapGesture { appState.deleteDraftId = draft.id }
                    }.padding(12)
                    .background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }
            }
        }
    }
}
