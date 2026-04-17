import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Add Code & Line Items Page
// ═══════════════════════════════════════════════════════════════════

struct AddCodeLineItemsPage: View {
    let receipt: Receipt
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var nominalCode: String = ""
    @State private var lineItems: [CodingLineItem] = [CodingLineItem()]
    @State private var isSaving = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Receipt info card
                    receiptInfoCard

                    // Receipt Code
                    receiptCodeSection

                    // Extracted Items
                    lineItemsSection
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 80)
            }

            // Bottom bar: Cancel + Save Coding
            HStack(spacing: 12) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel").font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())

                Button(action: saveCoding) {
                    HStack(spacing: 6) {
                        if isSaving { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(isSaving ? "Saving..." : "Save Coding")
                    }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(!isSaving && !nominalCode.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gold : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isSaving || nominalCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Add Code & Line Items"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .onAppear { prefillFromReceipt() }
    }

    // MARK: - Receipt Info

    private var receiptInfoCard: some View {
        VStack(spacing: 0) {
            Text((receipt.originalName ?? "").isEmpty ? "Receipt" : (receipt.originalName ?? ""))
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            Divider()

            infoRow("Merchant", receipt.merchantDetected ?? "—")
            Divider().padding(.leading, 14)
            infoRow("Amount", receipt.amountDetected.map { "£\($0)" } ?? "—")
            Divider().padding(.leading, 14)
            infoRow("Date", receipt.dateDetected ?? FormatUtils.formatTimestamp(receipt.createdAt ?? 0))
            Divider().padding(.leading, 14)
            infoRow("File", "\((receipt.fileType ?? "").uppercased()) · \(receipt.fileSizeDisplay)")
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(.primary).lineLimit(1)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: - Receipt Code

    private var receiptCodeSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Receipt Code").font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                if let existing = receipt.nominalCode, !existing.isEmpty {
                    Text("Extracted: \(existing)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 0.6, blue: 0.5))
                }
                TextField("e.g. 5010", text: $nominalCode)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.goldDark)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(6).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("EXTRACTED ITEMS (\(lineItems.count))")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                Spacer()
                Button(action: { lineItems.append(CodingLineItem()) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Add Line").font(.system(size: 11, weight: .semibold))
                    }.foregroundColor(.goldDark)
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            // Column headers
            HStack(spacing: 0) {
                Text("ITEM NAME").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("TOTAL").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                    .frame(width: 70, alignment: .trailing)
                Text("CODE").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                    .frame(width: 60, alignment: .leading).padding(.leading, 8)
                if lineItems.count > 1 { Spacer().frame(width: 28) }
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Color.bgRaised)

            Divider()

            // Editable rows
            ForEach(lineItems) { item in
                let isLast = item.id == lineItems.last?.id
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        TextField("Item name", text: bindingForField(item.id, \.description))
                            .font(.system(size: 12)).foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                        TextField("0.00", text: bindingForField(item.id, \.amount))
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(.primary)
                            .multilineTextAlignment(.trailing).keyboardType(.decimalPad)
                            .frame(width: 70)
                        TextField("Code", text: bindingForField(item.id, \.code))
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(.goldDark)
                            .frame(width: 60).padding(.leading, 8)
                        if lineItems.count > 1 {
                            Button(action: { removeLine(item.id) }) {
                                Image(systemName: "minus.circle.fill").font(.system(size: 14)).foregroundColor(.red.opacity(0.6))
                            }.buttonStyle(BorderlessButtonStyle()).frame(width: 28)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    if !isLast { Divider().padding(.horizontal, 14) }
                }
            }

            // Total row
            Divider()
            HStack {
                Text("Total").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                Spacer()
                let total = lineItems.reduce(0.0) { $0 + (Double($1.amount) ?? 0) }
                Text(FormatUtils.formatGBP(total))
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Actions

    private func bindingForField(_ id: UUID, _ keyPath: WritableKeyPath<CodingLineItem, String>) -> Binding<String> {
        Binding<String>(
            get: { lineItems.first(where: { $0.id == id })?[keyPath: keyPath] ?? "" },
            set: { newValue in
                if let idx = lineItems.firstIndex(where: { $0.id == id }) {
                    lineItems[idx][keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func removeLine(_ id: UUID) {
        lineItems.removeAll { $0.id == id }
    }

    private func prefillFromReceipt() {
        nominalCode = receipt.nominalCode ?? ""
        if !(receipt.lineItems ?? []).isEmpty {
            lineItems = (receipt.lineItems ?? []).map { li in
                CodingLineItem(
                    description: li.description ?? "",
                    amount: li.amountValue > 0 ? String(format: "%.2f", li.amountValue) : "",
                    code: li.code ?? ""
                )
            }
        } else {
            lineItems = [CodingLineItem()]
        }
    }

    private func saveCoding() {
        guard !nominalCode.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true
        let items: [[String: Any]] = lineItems.filter { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty }.map {
            ["description": $0.description, "amount": Double($0.amount) ?? 0, "code": $0.code] as [String: Any]
        }
        appState.submitReceiptCoding(receipt, nominalCode: nominalCode.trimmingCharacters(in: .whitespaces), lineItems: items) { success in
            isSaving = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Upload Receipt Page
// ═══════════════════════════════════════════════════════════════════

struct CodingLineItem: Identifiable {
    let id = UUID()
    var description: String = ""
    var amount: String = ""
    var code: String = ""
}
