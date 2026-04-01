import SwiftUI

struct POTemplatesListView: View {
    @EnvironmentObject var appState: POViewModel

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
                    HStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tpl.displayName).font(.system(size: 14, weight: .medium))
                                Text(tpl.templateNumber ?? "—").font(.system(size: 11, design: .monospaced)).foregroundColor(.goldDark)
                            }
                            Spacer()
                            Text(FormatUtils.formatCurrency(tpl.netAmount ?? 0, code: tpl.currency ?? "GBP")).font(.system(size: 13, design: .monospaced))
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium)).foregroundColor(.gray.opacity(0.5)).padding(.leading, 6)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { appState.editingTemplate = tpl }

                        Image(systemName: "trash").font(.system(size: 11)).foregroundColor(.red.opacity(0.6))
                            .padding(10)
                            .contentShape(Rectangle())
                            .onTapGesture { appState.deleteTemplateId = tpl.id }
                    }.padding(12).background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }
            }
        }
    }
}
