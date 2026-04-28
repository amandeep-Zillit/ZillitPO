import SwiftUI
import UIKit

struct LineItemsPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @Binding var lineItems: [LineItem]
    @Binding var lineItemCustomValues: [String: [String: String]]
    var formFields: [FormField]
    var currency: String = "GBP"
    var defaultDepartment: String = ""
    var defaultAccount: String = ""

    @State private var priceText: [String: String] = [:]
    @State private var qtyText: [String: String] = [:]

    private var decimalFormatter: NumberFormatter {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.minimumFractionDigits = 2; f.maximumFractionDigits = 2; return f
    }

    private var netTotal: Double {
        lineItems.reduce(0) { $0 + (($1.quantity ?? 0) * ($1.unitPrice ?? 0)) }
    }

    /// Aggregate VAT across all line items based on per-item vatTreatment
    private var vatSummary: (totalVat: Double, grossTotal: Double, hasVat: Bool) {
        var totalVat = 0.0
        var grossTotal = 0.0
        for item in lineItems {
            let itemNet = (item.quantity ?? 0) * (item.unitPrice ?? 0)
            let treatment = lineItemCustomValues[item.id ?? ""]?["vat"] ?? "pending"
            let result = VATHelpers.calcVat(itemNet, treatment: treatment)
            totalVat += result.vatAmount
            grossTotal += result.gross
        }
        let hasVat = lineItems.contains { (lineItemCustomValues[$0.id ?? ""]?["vat"] ?? "pending") != "pending" }
        return (totalVat, grossTotal, hasVat)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(lineItems.enumerated()), id: \.element.id) { idx, item in
                        liCard(idx: idx, item: item)
                    }

                    // Add Line Item button
                    Button(action: { lineItems.append(LineItem(account: defaultAccount, department: defaultDepartment)) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 14))
                            Text("Add Line Item").font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.goldDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gold.opacity(0.08))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 3])).foregroundColor(Color.goldDark.opacity(0.3)))
                    }.buttonStyle(BorderlessButtonStyle())
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
            }

            // Bottom summary bar
            VStack(spacing: 4) {
                Divider()
                HStack {
                    Text("\(lineItems.count) item\(lineItems.count == 1 ? "" : "s")").font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    Text("Net Total").font(.system(size: 13)).foregroundColor(.secondary)
                    Text(FormatUtils.formatCurrency(netTotal, code: currency)).font(.system(size: 15, weight: .semibold, design: .monospaced))
                }
                if vatSummary.hasVat {
                    HStack {
                        Text("VAT").font(.system(size: 12)).foregroundColor(.secondary)
                        Spacer()
                        Text(FormatUtils.formatCurrency(vatSummary.totalVat, code: currency)).font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary)
                    }
                    Divider()
                    HStack {
                        Text("Gross Total").font(.system(size: 14, weight: .bold))
                        Spacer()
                        Text(FormatUtils.formatCurrency(vatSummary.grossTotal, code: currency)).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                } else {
                    HStack {
                        Spacer()
                        Text(FormatUtils.formatCurrency(netTotal, code: currency)).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.bgBase)
        }
        .background(Color.bgBase.edgesIgnoringSafeArea(.all))
        .navigationBarTitle(Text("Line Items"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {
                // Dismiss keyboard first so TextFields commit their values
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Done").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
    }

    @ViewBuilder
    private func liCard(idx: Int, item: LineItem) -> some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(Color.gold.opacity(0.2)).frame(width: 24, height: 24)
                        Text("\(idx + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(.goldDark)
                    }
                    Text("Line Item").font(.system(size: 13, weight: .semibold))
                }
                Spacer()
                if lineItems.count > 1 {
                    Button(action: { withAnimation { lineItems.removeAll(where: { $0.id == item.id }) } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash").font(.system(size: 11))
                            Text("Delete").font(.system(size: 11, weight: .medium))
                        }.foregroundColor(.red.opacity(0.7))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.red.opacity(0.06)).cornerRadius(6)
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }

            Divider()

            // Dynamic fields from form template
            if !formFields.isEmpty {
                ForEach(formFields, id: \.id) { field in
                    self.liFieldView(field, itemId: item.id ?? "", item: item)
                }
                // Amount row always shown after dynamic fields
                liAmountRow(item)
            } else {
                // Fallback fields (includes amount row)
                liFallbackFields(item: item)
            }
        }
        .padding(14)
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private let liSystemLabels: Set<String> = ["line_description", "line_quantity", "line_unit_price", "account_code", "department", "exp_type", "vat", "vat_treatment", "line_vat", "tax_type", "tax_rate"]

    @ViewBuilder
    private func liFieldView(_ field: FormField, itemId: String, item: LineItem) -> some View {
        if field.label == "line_description" {
            FieldGroup(label: (field.name ?? "").uppercased()) {
                InputField(text: liBindDesc(itemId), placeholder: "Item description")
            }
        } else if field.label == "line_quantity" {
            FieldGroup(label: (field.name ?? "").uppercased()) {
                TextField("1", text: liBindQty(itemId))
                    .font(.system(size: 14)).keyboardType(.numberPad).padding(10)
                    .background(Color.bgSurface).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        } else if field.label == "line_unit_price" {
            FieldGroup(label: (field.name ?? "").uppercased()) {
                TextField("0.00", text: liBindPrice(itemId))
                    .font(.system(size: 14, design: .monospaced)).keyboardType(.decimalPad).padding(10)
                    .background(Color.bgSurface).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        } else if field.label == "account_code" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                InputField(text: liBindAccount(itemId), placeholder: "e.g. 2100")
            }
        } else if field.label == "department" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                PickerField(selection: liBindDept(itemId), placeholder: "Select department...",
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier ?? "", $0.displayName) })
            }
        } else if field.label == "exp_type" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                PickerField(selection: liBindExpType(itemId), placeholder: "Select type...",
                    options: expenditureTypes.map { DropdownOption($0, $0) })
            }
        } else if field.label == "vat" || field.label == "vat_treatment" || field.label == "tax_type"
                    || field.selectionType == "vat" || field.selectionType == "tax_type" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                PickerField(selection: liBindVat(itemId), placeholder: "Select VAT...",
                    options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
            }
        } else if field.label == "tax_rate" {
            // Tax rate is auto-derived from VAT treatment — hide or show read-only
            EmptyView()
        } else if !liSystemLabels.contains(field.label ?? "") {
            // Custom field — render if label is not a known system label
            liCustomFieldView(itemId: itemId, field: field)
        }
    }

    // Amount row — always shown at the bottom of every line item card
    private func liAmountRow(_ item: LineItem) -> some View {
        let itemNet = (item.quantity ?? 0) * (item.unitPrice ?? 0)
        let treatment = lineItemCustomValues[item.id ?? ""]?["vat"] ?? "pending"
        let vatResult = VATHelpers.calcVat(itemNet, treatment: treatment)
        return VStack(spacing: 4) {
            HStack {
                Text("Net").font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                Text(FormatUtils.formatCurrency(itemNet, code: currency))
                    .font(.system(size: 13, design: .monospaced)).foregroundColor(.primary)
            }
            if treatment != "pending" {
                HStack {
                    HStack(spacing: 4) {
                        Text("VAT (\(VATHelpers.vatLabel(treatment)))").font(.system(size: 11)).foregroundColor(.secondary)
                        if vatResult.reverseCharged {
                            Text("RC").font(.system(size: 8, weight: .bold)).foregroundColor(.orange)
                                .padding(.horizontal, 3).padding(.vertical, 1)
                                .background(Color.orange.opacity(0.1)).cornerRadius(3)
                        }
                    }
                    Spacer()
                    Text(FormatUtils.formatCurrency(vatResult.vatAmount, code: currency))
                        .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                }
            }
            HStack {
                Text("Total").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                Spacer()
                Text(FormatUtils.formatCurrency(vatResult.gross, code: currency))
                    .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func liFallbackFields(item: LineItem) -> some View {
        FieldGroup(label: "DESCRIPTION") { InputField(text: liBindDesc(item.id ?? ""), placeholder: "Item description") }
        HStack(spacing: 10) {
            FieldGroup(label: "QTY") {
                TextField("1", text: liBindQty(item.id ?? ""))
                    .font(.system(size: 14)).keyboardType(.numberPad).padding(10).background(Color.bgSurface).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
            FieldGroup(label: "UNIT PRICE") {
                TextField("0.00", text: liBindPrice(item.id ?? ""))
                    .font(.system(size: 14, design: .monospaced)).keyboardType(.decimalPad).padding(10).background(Color.bgSurface).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        }
        FieldGroup(label: "ACCOUNT CODE", optional: true) {
            InputField(text: liBindAccount(item.id ?? ""), placeholder: "e.g. 2100")
        }
        FieldGroup(label: "DEPARTMENT", optional: true) {
            PickerField(selection: liBindDept(item.id ?? ""), placeholder: "Select department...",
                options: DepartmentsData.sorted.map { DropdownOption($0.identifier ?? "", $0.displayName) })
        }
        FieldGroup(label: "EXPENDITURE TYPE", optional: true) {
            PickerField(selection: liBindExpType(item.id ?? ""), placeholder: "Select type...",
                options: expenditureTypes.map { DropdownOption($0, $0) })
        }
        liAmountRow(item)
    }

    @ViewBuilder
    private func liCustomFieldView(itemId: String, field: FormField) -> some View {
        let fieldName = field.name ?? ""
        let binding = Binding<String>(
            get: { self.lineItemCustomValues[itemId]?[fieldName] ?? "" },
            set: { val in
                if self.lineItemCustomValues[itemId] == nil { self.lineItemCustomValues[itemId] = [:] }
                self.lineItemCustomValues[itemId]?[fieldName] = val
            }
        )
        FieldGroup(label: fieldName.uppercased(), optional: !field.isRequired) {
            if field.selectionType == "vat" || field.selectionType == "tax_type" {
                PickerField(selection: binding, placeholder: "Select VAT...",
                    options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
            } else {
                InputField(text: binding, placeholder: "Enter \(fieldName.lowercased())...")
            }
        }
    }

    // MARK: - Bindings

    private func liBindDesc(_ id: String) -> Binding<String> {
        Binding<String>(get: { lineItems.first { $0.id == id }?.description ?? "" },
                        set: { v in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].description = v } })
    }
    private func liBindQty(_ id: String) -> Binding<String> {
        Binding<String>(
            get: {
                if let raw = qtyText[id] { return raw }
                // Default to 0 for brand-new line items — previously `?? 1`
                // pre-filled "1" which users frequently missed overriding
                // and ended up submitting with the wrong quantity.
                let q = lineItems.first { $0.id == id }?.quantity ?? 0
                return q == Double(Int(q)) ? "\(Int(q))" : "\(q)"
            },
            set: { v in
                qtyText[id] = v
                if let i = lineItems.firstIndex(where: { $0.id == id }) {
                    lineItems[i].quantity = Double(v) ?? 0
                }
            })
    }
    private func liBindPrice(_ id: String) -> Binding<String> {
        Binding<String>(
            get: {
                if let raw = priceText[id] { return raw }
                let p = lineItems.first { $0.id == id }?.unitPrice ?? 0
                return p == 0 ? "" : String(format: "%.2f", p)
            },
            set: { v in
                priceText[id] = v
                if let i = lineItems.firstIndex(where: { $0.id == id }) {
                    lineItems[i].unitPrice = Double(v) ?? 0
                }
            })
    }

    private func liBindAccount(_ id: String) -> Binding<String> {
        Binding<String>(get: { lineItems.first { $0.id == id }?.account ?? "" },
                        set: { v in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].account = v } })
    }
    private func liBindDept(_ id: String) -> Binding<String> {
        Binding<String>(get: { lineItems.first { $0.id == id }?.department ?? "" },
                        set: { v in if let i = lineItems.firstIndex(where: { $0.id == id }) {
                            lineItems[i].department = v
                            lineItems[i].account = NominalCodes.deptToNominal[v] ?? lineItems[i].account
                        } })
    }
    private func liBindExpType(_ id: String) -> Binding<String> {
        Binding<String>(get: { lineItems.first { $0.id == id }?.expenditureType ?? "" },
                        set: { v in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].expenditureType = v } })
    }
    private func liBindVat(_ id: String) -> Binding<String> {
        Binding<String>(
            get: { self.lineItemCustomValues[id]?["vat"] ?? "pending" },
            set: { val in
                if self.lineItemCustomValues[id] == nil { self.lineItemCustomValues[id] = [:] }
                self.lineItemCustomValues[id]?["vat"] = val
            }
        )
    }
}

// MARK: - Template Name Sheet
