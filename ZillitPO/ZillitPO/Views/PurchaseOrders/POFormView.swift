import SwiftUI
import Combine

struct POFormView: View {
    @EnvironmentObject var appState: AppState
    var editingPO: PurchaseOrder?
    var resumeDraft: PurchaseOrder?
    var prefilledVendorId: String?
    var onBack: () -> Void

    @State private var vendorId = ""
    @State private var departmentId = ""
    @State private var nominalCode = ""
    @State private var desc = ""
    @State private var currency = "GBP"
    @State private var vatTreatment = "pending"
    @State private var effectiveDate = Date()
    @State private var hasEffDate = false
    @State private var deliveryDate = Date()
    @State private var hasDelDate = false
    @State private var notes = ""
    @State private var lineItems: [LineItem] = [LineItem()]

    @State private var daName = ""
    @State private var daEmail = ""
    @State private var daPhone = ""
    @State private var daLine1 = ""
    @State private var daLine2 = ""
    @State private var daCity = ""
    @State private var daState = ""
    @State private var daPostal = ""
    @State private var daCountry = ""
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showTemplateNameSheet = false
    @State private var templateName = ""

    var isEdit: Bool { editingPO != nil }

    var body: some View {
        List {
            // Vendor Info
            Section(header: sectionHeader(icon: "person.crop.square", title: "VENDOR INFORMATION")) {
                vendorInfoContent
            }

            // PO Details
            Section(header: sectionHeader(icon: "doc.text", title: "PO DETAILS", trailing: "All fields required unless noted")) {
                poDetailsContent
            }

            // Delivery Address
            Section(header: sectionHeader(icon: "shippingbox", title: "DELIVERY ADDRESS")) {
                deliveryAddressContent
            }

            // Line Items
            Section(header: lineItemsHeader) {
                lineItemsContent
            }

            // Notes
            Section(header: sectionHeader(icon: "note.text", title: "ADDITIONAL NOTES")) {
                notesContent
            }

            // Summary
            Section(header: sectionHeader(icon: "sum", title: "SUMMARY")) {
                summaryContent
            }

            // Actions
            Section {
                actionsContent
            }
        }
        .listStyle(GroupedListStyle())
        .onAppear { loadData() }
        .sheet(isPresented: $showTemplateNameSheet) {
            TemplateNameSheet(templateName: $templateName, isPresented: $showTemplateNameSheet) {
                saveTemplate()
            }
        }
    }

    // MARK: - Section Headers

    private func sectionHeader(icon: String, title: String, trailing: String? = nil) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(.goldDark)
            Text(title).font(.system(size: 11, weight: .bold)).tracking(1).lineLimit(1)
            Spacer()
            if let t = trailing {
                Text(t).font(.system(size: 9)).foregroundColor(.gray).italic().lineLimit(1)
            }
        }
    }

    // MARK: - Vendor Information

    private var vendorInfoContent: some View {
        VStack(spacing: 14) {
            FieldGroup(label: "VENDOR") {
                VendorSearchField(
                    vendorId: $vendorId,
                    vendors: appState.vendors
                )
            }
            FieldGroup(label: "VENDOR ADDRESS") {
                Text(vendorAddressText)
                    .font(.system(size: 13))
                    .foregroundColor(vendorId.isEmpty ? .gray : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        }
    }

    // MARK: - PO Details

    private var poDetailsContent: some View {
        VStack(spacing: 14) {
            FieldGroup(label: "DEPARTMENT") {
                PickerField(selection: $departmentId, placeholder: "Select department...",
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
            }
            FieldGroup(label: "NOMINAL CODE") {
                PickerField(selection: $nominalCode, placeholder: "Select nominal code...",
                    options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
            }
            FieldGroup(label: "DESCRIPTION", optional: true) {
                InputField(text: $desc, placeholder: "e.g. Studio hire — Stage G, 12 weeks")
            }
            HStack(spacing: 10) {
                FieldGroup(label: "CURRENCY") {
                    PickerField(selection: $currency, placeholder: "Select currency...",
                        options: [DropdownOption("GBP", "GBP — British Pound"),
                                  DropdownOption("USD", "USD — US Dollar"),
                                  DropdownOption("EUR", "EUR — Euro")])
                }
                FieldGroup(label: "VAT TREATMENT") {
                    PickerField(selection: $vatTreatment, placeholder: "Select VAT...",
                        options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
                }
            }
            FieldGroup(label: "DELIVERY DATE") {
                if hasDelDate {
                    HStack {
                        DatePicker("", selection: $deliveryDate, displayedComponents: .date).labelsHidden()
                        Spacer()
                        Button(action: { hasDelDate = false }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray.opacity(0.4)).font(.system(size: 14))
                        }.buttonStyle(PlainButtonStyle())
                    }
                } else {
                    Button(action: { hasDelDate = true }) {
                        HStack {
                            Text("dd/mm/yyyy").foregroundColor(.gray).font(.system(size: 14))
                            Spacer()
                            Image(systemName: "calendar").foregroundColor(.gray).font(.system(size: 13))
                        }
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Delivery Address

    private var deliveryAddressContent: some View {
        VStack(spacing: 14) {
            FieldGroup(label: "RECIPIENT NAME") { InputField(text: $daName, placeholder: "Recipient name...") }
            HStack(spacing: 10) {
                FieldGroup(label: "EMAIL") { InputField(text: $daEmail, placeholder: "email@example.com") }
                FieldGroup(label: "PHONE") { InputField(text: $daPhone, placeholder: "Phone number") }
            }
            FieldGroup(label: "ADDRESS LINE 1") { InputField(text: $daLine1, placeholder: "Street address...") }
            FieldGroup(label: "ADDRESS LINE 2") { InputField(text: $daLine2, placeholder: "Suite, unit, building...") }
            HStack(spacing: 10) {
                FieldGroup(label: "CITY") { InputField(text: $daCity, placeholder: "City...") }
                FieldGroup(label: "STATE") { InputField(text: $daState, placeholder: "State / County...") }
            }
            HStack(spacing: 10) {
                FieldGroup(label: "POSTAL CODE") { InputField(text: $daPostal, placeholder: "Postal code...") }
                FieldGroup(label: "COUNTRY") { InputField(text: $daCountry, placeholder: "Country") }
            }
        }
    }

    // MARK: - Line Items

    private var lineItemsHeader: some View {
        HStack {
            Image(systemName: "list.bullet.rectangle").font(.system(size: 11)).foregroundColor(.goldDark)
            Text("LINE ITEMS").font(.system(size: 11, weight: .bold)).tracking(1)
            Spacer()
            Button(action: { lineItems.append(LineItem()) }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    Text("Add Line").font(.system(size: 11, weight: .semibold))
                }.foregroundColor(.goldDark)
            }
        }
    }

    private func bindingForItem(_ id: String) -> (desc: Binding<String>, qty: Binding<Double>, price: Binding<Double>) {
        let descBinding = Binding<String>(
            get: { lineItems.first(where: { $0.id == id })?.description ?? "" },
            set: { val in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].description = val } }
        )
        let qtyBinding = Binding<Double>(
            get: { lineItems.first(where: { $0.id == id })?.quantity ?? 1 },
            set: { val in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].quantity = val } }
        )
        let priceBinding = Binding<Double>(
            get: { lineItems.first(where: { $0.id == id })?.unitPrice ?? 0 },
            set: { val in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].unitPrice = val } }
        )
        return (descBinding, qtyBinding, priceBinding)
    }

    private var lineItemsContent: some View {
        Group {
            VStack(spacing: 12) {
                ForEach(Array(lineItems.enumerated()), id: \.element.id) { idx, item in
                    VStack(spacing: 10) {
                        HStack {
                            Text("Item \(idx + 1)").font(.system(size: 11, weight: .semibold)).foregroundColor(.goldDark)
                            Spacer()
                            if lineItems.count > 1 {
                                Button(action: { lineItems.removeAll(where: { $0.id == item.id }) }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "trash").font(.system(size: 10))
                                        Text("Remove").font(.system(size: 10))
                                    }.foregroundColor(.red.opacity(0.6))
                                }.buttonStyle(PlainButtonStyle())
                            }
                        }
                        FieldGroup(label: "DESCRIPTION") {
                            InputField(text: bindingForItem(item.id).desc, placeholder: "Item description")
                        }
                        HStack(spacing: 10) {
                            FieldGroup(label: "QTY") {
                                TextField("1", value: bindingForItem(item.id).qty, formatter: NumberFormatter())
                                    .font(.system(size: 14)).padding(10)
                                    .background(Color.white).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            FieldGroup(label: "UNIT PRICE") {
                                TextField("0.00", value: bindingForItem(item.id).price, formatter: decimalFormatter)
                                    .font(.system(size: 14, design: .monospaced)).padding(10)
                                    .background(Color.white).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            FieldGroup(label: "TOTAL") {
                                Text(FormatUtils.formatGBP(item.quantity * item.unitPrice))
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.goldDark)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10).padding(.vertical, 9)
                                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.bgBase)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }
            }

            // Net total
            HStack {
                Spacer()
                Text("Net Total").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                Text(FormatUtils.formatGBP(netTotal)).font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }.padding(.top, 4)
        }
    }

    // MARK: - Notes

    private var notesContent: some View {
        FieldGroup(label: "NOTES", optional: true) {
            InputField(text: $notes, placeholder: "Internal notes...")
        }
    }

    // MARK: - Summary

    private var summaryContent: some View {
        let vat = VATHelpers.calcVat(netTotal, treatment: vatTreatment)
        return VStack(spacing: 8) {
            HStack {
                Text("Net Amount").font(.system(size: 14)).foregroundColor(.secondary)
                Spacer()
                Text(FormatUtils.formatGBP(netTotal)).font(.system(size: 15, design: .monospaced))
            }
            if vatTreatment != "pending" {
                HStack {
                    Text("VAT (\(VATHelpers.vatLabel(vatTreatment)))").font(.system(size: 14)).foregroundColor(.secondary)
                    if vat.reverseCharged {
                        Text("RC").font(.system(size: 8, weight: .bold)).foregroundColor(.orange)
                            .padding(.horizontal, 4).padding(.vertical, 1).background(Color.orange.opacity(0.1)).cornerRadius(3)
                    }
                    Spacer()
                    Text(FormatUtils.formatGBP(vat.vatAmount)).font(.system(size: 14, design: .monospaced)).foregroundColor(.secondary)
                }
            }
            Divider()
            HStack {
                Text("Gross Total").font(.system(size: 16, weight: .bold))
                Spacer()
                Text(FormatUtils.formatGBP(vat.gross)).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }
        }
    }

    // MARK: - Actions

    private var actionsContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: { saveDraft() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 13))
                        Text("Save Draft").font(.system(size: 13, weight: .semibold))
                    }.foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())

                Button(action: { templateName = desc; showTemplateNameSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc").font(.system(size: 13))
                        Text("Save Template").font(.system(size: 13, weight: .semibold))
                    }.foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())
            }

            Button(action: { submitPO() }) {
                HStack(spacing: 6) {
                    Text(isEdit ? "Update PO" : "Submit PO").font(.system(size: 14, weight: .bold))
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                }.foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(vendorId.isEmpty ? Color.gold.opacity(0.4) : Color.gold).cornerRadius(8)
            }.disabled(vendorId.isEmpty || appState.formSubmitting)
        }
    }

    // MARK: - Computed

    private var vendorAddressText: String {
        guard !vendorId.isEmpty, let v = appState.vendors.first(where: { $0.id == vendorId }) else { return "Select a vendor first" }
        let addr = v.address.formatted
        return addr.isEmpty ? "No address on file" : addr
    }

    private var netTotal: Double {
        lineItems.reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
    }

    private var decimalFormatter: NumberFormatter {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.minimumFractionDigits = 2; f.maximumFractionDigits = 2; return f
    }

    // MARK: - Load

    private func loadData() {
        if let u = appState.currentUser {
            departmentId = u.departmentIdentifier
            nominalCode = NominalCodes.deptToNominal[u.departmentIdentifier] ?? ""
        }
        if let vid = prefilledVendorId ?? appState.prefilledVendorId, !vid.isEmpty {
            vendorId = vid
            appState.prefilledVendorId = nil
        }
        if let po = editingPO ?? resumeDraft {
            vendorId = po.vendorId ?? ""; departmentId = po.departmentId ?? ""
            nominalCode = po.nominalCode ?? ""; desc = po.description ?? ""
            currency = po.currency; vatTreatment = po.vatTreatment; notes = po.notes ?? ""
            lineItems = po.lineItems.isEmpty ? [LineItem()] : po.lineItems
            if let ms = po.effectiveDate, ms > 0 { effectiveDate = Date(timeIntervalSince1970: Double(ms)/1000); hasEffDate = true }
            if let da = po.deliveryAddress {
                daName = da.name ?? ""; daEmail = da.email ?? ""; daPhone = da.phone ?? ""
                daLine1 = da.line1 ?? ""; daLine2 = da.line2 ?? ""; daCity = da.city ?? ""
                daState = da.state ?? ""; daPostal = da.postalCode ?? ""; daCountry = da.country ?? ""
            }
        }
    }

    // MARK: - Actions

    private func buildForm() -> POFormData {
        for i in lineItems.indices { lineItems[i].total = lineItems[i].quantity * lineItems[i].unitPrice }
        return POFormData(vendorId: vendorId, departmentId: departmentId, nominalCode: nominalCode,
                          description: desc, currency: currency, vatTreatment: vatTreatment,
                          effectiveDate: hasEffDate ? effectiveDate : nil, notes: notes,
                          lineItems: lineItems, existingDraftId: (editingPO ?? resumeDraft)?.id)
    }

    private func submitPO() { appState.submitPO(buildForm(), onComplete: onBack) }
    private func saveDraft() { appState.saveDraft(buildForm(), onComplete: onBack) }

    private func saveTemplate() { appState.saveTemplate(buildForm(), templateName: templateName, onComplete: onBack) }
}

// MARK: - Template Name Sheet

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
                        .foregroundColor(Color(red: 0.45, green: 0.47, blue: 0.5))
                    TextField("e.g. Weekly Catering Order", text: $templateName)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.white).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }

                Button(action: {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSave() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                        Text("Save Template").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Color.gold).cornerRadius(8)
                }

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

struct CardView<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }
}

struct CardHeader: View {
    var icon: String
    var title: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(.goldDark)
            Text(title).font(.system(size: 11, weight: .bold)).tracking(1).lineLimit(1)
            Spacer()
            if let t = trailing {
                Text(t).font(.system(size: 9)).foregroundColor(.gray).italic().lineLimit(1)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.bgRaised)
        .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)
    }
}

struct FieldGroup<Content: View>: View {
    var label: String
    var optional: Bool = false
    let content: () -> Content
    init(label: String, optional: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.label = label; self.optional = optional; self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                HStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.3)
                        .foregroundColor(Color(red: 0.45, green: 0.47, blue: 0.5))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    if optional {
                        Text("(optional)")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                            .italic()
                            .lineLimit(1)
                    }
                }
            }
            content()
        }
    }
}

struct InputField: View {
    @Binding var text: String
    var placeholder: String
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.white)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
    }
}

struct DropdownOption: Identifiable {
    let id: String
    let label: String
    init(_ id: String, _ label: String) { self.id = id; self.label = label }
}

struct PickerField: View {
    @Binding var selection: String
    var placeholder: String
    var options: [DropdownOption]
    @State private var showSheet = false

    private var selectedLabel: String {
        options.first { $0.id == selection }?.label ?? ""
    }

    var body: some View {
        Button(action: { showSheet = true }) {
            HStack {
                Text(selection.isEmpty ? placeholder : selectedLabel)
                    .font(.system(size: 13))
                    .foregroundColor(selection.isEmpty ? .gray : .primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.white)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showSheet) {
            PickerSheetView(selection: $selection, options: options, isPresented: $showSheet)
        }
    }
}

struct PickerSheetView: View {
    @Binding var selection: String
    let options: [DropdownOption]
    @Binding var isPresented: Bool
    @State private var searchText = ""

    private var filteredOptions: [DropdownOption] {
        if searchText.isEmpty { return options }
        let q = searchText.lowercased()
        return options.filter { $0.label.lowercased().contains(q) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                if options.count > 5 {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                        TextField("Search...", text: $searchText).font(.system(size: 13))
                    }
                    .padding(10).background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
                }

                List {
                    ForEach(filteredOptions) { option in
                        Button(action: {
                            selection = option.id
                            isPresented = false
                        }) {
                            HStack {
                                Text(option.label)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                Spacer()
                                if option.id == selection {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.goldDark)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .listStyle(GroupedListStyle())
            }
            .navigationBarTitle(Text("Select Option"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { isPresented = false }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark))
        }
    }
}

// MARK: - Vendor Search Field with Suggestions

struct VendorSearchField: View {
    @Binding var vendorId: String
    let vendors: [Vendor]

    @State private var searchText = ""
    @State private var isEditing = false

    private var selectedVendor: Vendor? {
        vendors.first { $0.id == vendorId }
    }

    private var suggestions: [Vendor] {
        guard isEditing, !searchText.isEmpty else { return [] }
        let q = searchText.lowercased()
        return vendors.filter {
            $0.name.lowercased().contains(q) ||
            $0.email.lowercased().contains(q) ||
            $0.contactPerson.lowercased().contains(q)
        }.prefix(6).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Input field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                if isEditing || vendorId.isEmpty {
                    TextField("Search by name, email, or contact...", text: $searchText, onEditingChanged: { editing in
                        isEditing = editing
                    })
                    .font(.system(size: 13))
                } else {
                    // Show selected vendor name
                    Text(selectedVendor?.name ?? "")
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Spacer()
                    // Clear button
                    Button(action: {
                        vendorId = ""
                        searchText = ""
                        isEditing = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.5))
                    }.buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.white)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                isEditing ? Color.goldDark : Color.borderColor, lineWidth: isEditing ? 1.5 : 1
            ))

            // Suggestions dropdown
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.id) { vendor in
                        Button(action: {
                            vendorId = vendor.id
                            searchText = ""
                            isEditing = false
                            // Dismiss keyboard
                            #if canImport(UIKit)
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            #endif
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vendor.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                HStack(spacing: 8) {
                                    if !vendor.email.isEmpty {
                                        HStack(spacing: 3) {
                                            Image(systemName: "envelope").font(.system(size: 8)).foregroundColor(.gray)
                                            Text(vendor.email).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                                        }
                                    }
                                    if !vendor.contactPerson.isEmpty {
                                        HStack(spacing: 3) {
                                            Image(systemName: "person").font(.system(size: 8)).foregroundColor(.gray)
                                            Text(vendor.contactPerson).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                        }
                        .buttonStyle(PlainButtonStyle())

                        if vendor.id != suggestions.last?.id {
                            Divider().padding(.horizontal, 8)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .padding(.top, 4)
                .zIndex(10)
            }
        }
    }
}
