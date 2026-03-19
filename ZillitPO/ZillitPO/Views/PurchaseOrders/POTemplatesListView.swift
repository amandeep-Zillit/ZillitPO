import SwiftUI

struct POTemplatesListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteAlert = false
    @State private var deleteId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appState.templates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.doc").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                    Text("No templates yet").font(.system(size: 13)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.white).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            } else {
                ForEach(appState.templates, id: \.id) { tpl in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tpl.templateName).font(.system(size: 14, weight: .medium))
                            Text(tpl.templateNumber ?? "—").font(.system(size: 11, design: .monospaced)).foregroundColor(.goldDark)
                        }
                        Spacer()
                        Text(FormatUtils.formatGBP(tpl.netAmount ?? 0)).font(.system(size: 13, design: .monospaced))
                        Button(action: { deleteId = tpl.id; showDeleteAlert = true }) {
                            Image(systemName: "trash").font(.system(size: 11)).foregroundColor(.red.opacity(0.4))
                        }.buttonStyle(PlainButtonStyle())
                    }.padding(12).background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(title: Text("Delete Template?"), message: Text("This cannot be undone."),
                  primaryButton: .destructive(Text("Delete")) { if let id = deleteId { appState.deleteTemplate(id) } },
                  secondaryButton: .cancel())
        }
    }
}
