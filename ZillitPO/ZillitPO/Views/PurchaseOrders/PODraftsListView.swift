import SwiftUI

struct PODraftsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteAlert = false
    @State private var deleteId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                StatCard(title: "Drafts", value: "\(appState.drafts.count)")
                StatCard(title: "Draft Value", value: FormatUtils.formatGBP(appState.drafts.reduce(0) { $0 + $1.netAmount }), color: .goldDark)
            }
            if appState.drafts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                    Text("No drafts yet").font(.system(size: 13)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.white).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            } else {
                ForEach(appState.drafts, id: \.id) { draft in
                    Button(action: { appState.resumeDraft = draft; appState.showCreatePO = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.poNumber.isEmpty ? "—" : draft.poNumber).font(.system(size: 11, design: .monospaced)).foregroundColor(.goldDark)
                                Text(draft.vendor.isEmpty ? "—" : draft.vendor).font(.system(size: 13, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                            }
                            Spacer()
                            Text(FormatUtils.formatGBP(draft.netAmount)).font(.system(size: 13, design: .monospaced)).foregroundColor(.primary)
                            Text("Draft").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.gold.opacity(0.15)).cornerRadius(4)
                            Button(action: { deleteId = draft.id; showDeleteAlert = true }) {
                                Image(systemName: "trash").font(.system(size: 11)).foregroundColor(.red.opacity(0.4))
                            }.buttonStyle(PlainButtonStyle())
                        }.padding(12)
                    }.buttonStyle(PlainButtonStyle()).background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(title: Text("Delete Draft?"), message: Text("This cannot be undone."),
                  primaryButton: .destructive(Text("Delete")) { if let id = deleteId { appState.deleteDraft(id) } },
                  secondaryButton: .cancel())
        }
    }
}
