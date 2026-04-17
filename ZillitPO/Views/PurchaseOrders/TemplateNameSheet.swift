import SwiftUI

struct TemplateNameSheet: View {
    @Binding var templateName: String
    @Binding var isPresented: Bool
    var onSave: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc").font(.system(size: 14)).foregroundColor(.goldDark)
                        Text("Save as Template").font(.system(size: 18, weight: .bold))
                    }
                    Text("Give your template a name so you can reuse it later.")
                        .font(.system(size: 13)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("TEMPLATE NAME").font(.system(size: 9, weight: .bold)).tracking(0.3)
                        .foregroundColor(Color.secondary)
                    TextField("e.g. Weekly Catering Order", text: $templateName)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }

                Button(action: {
                    guard !templateName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSave() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                        Text("Save Template").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(templateName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gold.opacity(0.4) : Color.gold).cornerRadius(8)
                }
                .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(.horizontal, 20)
            .background(Color.bgBase.edgesIgnoringSafeArea(.all))
            .navigationBarTitle(Text("Template Name"), displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Cancel") { isPresented = false }
                    .font(.system(size: 16)).foregroundColor(.goldDark)
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Reusable Form Components
// ═══════════════════════════════════════════════════════════════════════════════
