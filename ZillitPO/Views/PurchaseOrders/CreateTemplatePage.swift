import SwiftUI

struct CreateTemplatePage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            CreateTemplateFormView(
                onBack: { presentationMode.wrappedValue.dismiss() }
            )
        }
        .navigationBarTitle(Text("Create Template"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
    }
}

// MARK: - Create Template Form View

struct CreateTemplateFormView: View {
    @EnvironmentObject var appState: POViewModel
    var onBack: () -> Void

    @State private var templateName = ""
    @State private var vendorId = ""
    @State private var departmentId = ""
    @State private var nominalCode = ""
    @State private var showLineItemsPage = false
    @State private var desc = ""
    @State private var currency = "GBP"
    @State private var vatTreatment = "pending"
    @State private var effectiveDate = Date()
    @State private var hasEffDate = false
    @State private var deliveryDate = Date()
    @State private var hasDelDate = false
    @State private var notes = ""
    @State private var lineItems: [LineItem] = [LineItem()]
    @State private var customFieldValues: [String: String] = [:]
    @State private var lineItemCustomValues: [String: [String: String]] = [:]

    // Delivery address states
    @State private var daName = ""
    @State private var daEmail = ""
    @State private var daPhoneCode = ""
    @State private var daPhone = ""
    @State private var daLine1 = ""
    @State private var daLine2 = ""
    @State private var daCity = ""
    @State private var daState = ""
    @State private var daPostal = ""
    @State private var daCountry = ""

    // Action sheet state
    @State private var showAttachSheet = false
    @State private var showCtValidationAlert = false
    @State private var ctValidationMessage = ""
    @State private var showTemplateNameSheet = false

    private var sortedSections: [FormSection]? {
        appState.formTemplate?.template?.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }

    private var ctLineItemFields: [FormField] {
        if let sections = sortedSections,
           let liSection = sections.first(where: { ($0.key ?? "") == "line_items" }) {
            return liSection.visibleFields
        }
        return []
    }

    private var ctLineItemsSummaryCard: some View {
        Button(action: { showLineItemsPage = true }) {
            VStack(spacing: 10) {
                ForEach(Array(lineItems.enumerated()), id: \.element.id) { idx, item in
                    HStack {
                        Text("\(idx + 1).").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                        Text((item.description ?? "").isEmpty ? "Untitled Item" : item.description ?? "")
                            .font(.system(size: 13, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                        Spacer()
                        Text("×\(Int(item.quantity ?? 0))").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                        Text(FormatUtils.formatCurrency((item.quantity ?? 0) * (item.unitPrice ?? 0), code: currency))
                            .font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundColor(.primary)
                    }
                }
                Divider()
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.system(size: 10))
                        Text("Tap to edit line items").font(.system(size: 11))
                    }.foregroundColor(.goldDark)
                    Spacer()
                    Text("\(lineItems.count) item\(lineItems.count == 1 ? "" : "s")").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    Text(FormatUtils.formatCurrency(ctNetTotal, code: currency)).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                }
            }
            .padding(12).background(Color.bgBase).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldDark.opacity(0.3), lineWidth: 1))
        }.buttonStyle(BorderlessButtonStyle())
    }

    var body: some View {
        ZStack {
            List {
                Section(header: ctSectionHeader(icon: "doc.on.doc", title: "TEMPLATE INFO")) {
                    VStack(spacing: 14) {
                        FieldGroup(label: "TEMPLATE NAME") {
                            InputField(text: $templateName, placeholder: "e.g. Weekly Catering Order")
                        }
                    }
                }

                if let sections = sortedSections {
                    ForEach(sections, id: \.id) { section in
                        self.ctSection(for: section)
                    }
                    if !sections.contains(where: { ($0.key ?? "") == "terms_of_engagement" }) {
                        Section(header: ctSectionHeader(icon: "sum", title: "SUMMARY")) {
                            HStack {
                                Text("Net Total").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                                Spacer()
                                Text(FormatUtils.formatCurrency(ctNetTotal, code: currency)).font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                            }
                        }
                    }
                } else {
                    Section(header: ctSectionHeader(icon: "doc.text", title: "PO DETAILS")) { ctFallbackPODetails }
                    Section(header: ctSectionHeader(icon: "shippingbox", title: "DELIVERY ADDRESS")) { ctFallbackDeliveryAddress }
                    Section(header: ctSectionHeader(icon: "list.bullet.rectangle", title: "LINE ITEMS")) { ctLineItemsSummaryCard }
                    Section(header: ctSectionHeader(icon: "note.text", title: "NOTES")) {
                        FieldGroup(label: "NOTES", optional: true) { InputField(text: $notes, placeholder: "Internal notes...") }
                    }
                    Section(header: ctSectionHeader(icon: "sum", title: "SUMMARY")) {
                        HStack {
                            Text("Net Total").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                            Spacer()
                            Text(FormatUtils.formatCurrency(ctNetTotal, code: currency)).font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        }
                    }
                }

                // MARK: - Action Buttons
                Section {
                    HStack(spacing: 10) {
                        // Attach button
                        Button(action: { showAttachSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "paperclip").font(.system(size: 13, weight: .semibold))
                                Text("Attach").font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.bgSurface).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }.buttonStyle(BorderlessButtonStyle())

                        // Save Template button — opens name sheet if name is empty
                        Button(action: {
                            if templateName.trimmingCharacters(in: .whitespaces).isEmpty {
                                showTemplateNameSheet = true
                            } else {
                                createTemplate()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.badge.plus").font(.system(size: 13, weight: .bold))
                                Text("Save Template").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.gold).cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .dismissKeyboardOnTap()
            .onAppear { ctLoadDefaults() }
            .appActionSheet(title: "Attach", isPresented: $showAttachSheet, items: [
                .action("Quote") { /* TODO: attach quote */ },
                .action("Email") { /* TODO: attach email */ },
                .action("Attachment") { /* TODO: attach file */ }
            ])
            .overlay(
                Group {
                    if showTemplateNameSheet {
                        ZStack {
                            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                                .onTapGesture { showTemplateNameSheet = false }
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Template Name").font(.system(size: 16, weight: .bold))
                                    Spacer()
                                    Button(action: { showTemplateNameSheet = false }) {
                                        Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundColor(.gray)
                                    }
                                }
                                Text("Give your template a name so you can reuse it later.")
                                    .font(.system(size: 12)).foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                TextField("e.g. Weekly Catering Order", text: $templateName)
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                                    .background(Color.bgSurface).cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                                Button(action: {
                                    guard !templateName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                    showTemplateNameSheet = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { createTemplate() }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                                        Text("Save Template").font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(templateName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gold.opacity(0.4) : Color.gold)
                                    .cornerRadius(8)
                                }
                                .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .padding(20)
                            .background(Color.bgBase)
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
                            .padding(.horizontal, 30)
                        }
                    }
                }
            )

            NavigationLink(
                destination: LineItemsPage(
                    lineItems: $lineItems,
                    lineItemCustomValues: $lineItemCustomValues,
                    formFields: ctLineItemFields,
                    currency: currency
                ).environmentObject(appState),
                isActive: $showLineItemsPage
            ) { EmptyView() }
            .hidden()
        }
    }

    // MARK: - Dynamic Section Router

    @ViewBuilder
    private func ctSection(for section: FormSection) -> some View {
        let sectionKey = section.key ?? ""
        if sectionKey == "po_details" {
            Section(header: ctSectionHeader(icon: "doc.text", title: (section.label ?? "").uppercased())) {
                VStack(spacing: 14) {
                    ForEach(section.visibleFields, id: \.id) { field in
                        self.ctPOField(field)
                    }
                }
            }
        } else if sectionKey == "delivery_address" {
            Section(header: ctSectionHeader(icon: "shippingbox", title: (section.label ?? "").uppercased())) {
                VStack(spacing: 14) {
                    ForEach(section.visibleFields, id: \.id) { field in
                        self.ctDeliveryField(field)
                    }
                }
            }
        } else if sectionKey == "line_items" {
            Section(header: ctSectionHeader(icon: "list.bullet.rectangle", title: (section.label ?? "").uppercased())) {
                ctLineItemsSummaryCard
            }
        } else if sectionKey == "terms_of_engagement" {
            Section(header: ctSectionHeader(icon: "sum", title: "SUMMARY")) {
                HStack {
                    Text("Net Total").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                    Spacer()
                    Text(FormatUtils.formatCurrency(ctNetTotal, code: currency)).font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                }
            }
            Section(header: ctSectionHeader(icon: "doc.plaintext", title: (section.label ?? "").uppercased())) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(section.values ?? [], id: \.self) { term in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                            Text(term).font(.system(size: 13))
                        }
                    }
                }
            }
        } else {
            Section(header: ctSectionHeader(icon: "square.grid.2x2", title: (section.label ?? "").uppercased())) {
                VStack(spacing: 14) {
                    ForEach(section.visibleFields, id: \.id) { field in
                        self.ctCustomFieldView(sectionKey: sectionKey, field: field)
                    }
                }
            }
        }
    }

    // MARK: - PO Details Fields

    @ViewBuilder
    private func ctPOField(_ field: FormField) -> some View {
        if field.label == "vendor" {
            FieldGroup(label: (field.name ?? "").uppercased()) { VendorSearchField(vendorId: $vendorId, vendors: appState.vendors) }
        } else if field.label == "vendor_address" {
            FieldGroup(label: (field.name ?? "").uppercased()) {
                Text(ctVendorAddressText)
                    .font(.system(size: 13))
                    .foregroundColor(vendorId.isEmpty ? .gray : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        } else if field.label == "department" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                PickerField(selection: ctDepartmentBinding, placeholder: "Select department...",
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier ?? "", $0.displayName) })
            }
        } else if field.label == "account_code" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                PickerField(selection: ctNominalCodeBinding, placeholder: "Select nominal code...",
                    options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
            }
        } else if field.label == "description" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                InputField(text: $desc, placeholder: "e.g. Studio hire — Stage G, 12 weeks")
            }
        } else if field.label == "currency" {
            FieldGroup(label: (field.name ?? "").uppercased()) {
                PickerField(selection: $currency, placeholder: "Select currency...",
                    options: [DropdownOption("GBP", "GBP — British Pound"), DropdownOption("USD", "USD — US Dollar"), DropdownOption("EUR", "EUR — Euro")])
            }
        } else if field.label == "vat" {
            FieldGroup(label: (field.name ?? "").uppercased()) {
                PickerField(selection: $vatTreatment, placeholder: "Select VAT...",
                    options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
            }
        } else if field.label == "delivery_date" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                ctDateFieldContent(hasDate: $hasDelDate, date: $deliveryDate)
            }
        } else if field.label == "effective_date" {
            // Effective date is hidden from users
            EmptyView()
        } else if field.label == "notes" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                InputField(text: $notes, placeholder: "Internal notes...")
            }
        } else if !ctPOSystemLabels.contains(field.label ?? "") {
            ctCustomFieldView(sectionKey: "po_details", field: field)
        }
    }

    // MARK: - Auto-select defaults from current user
    private func ctLoadDefaults() {
        if let u = appState.currentUser {
            if departmentId.isEmpty { departmentId = u.departmentIdentifier ?? "" }
            if nominalCode.isEmpty { nominalCode = NominalCodes.deptToNominal[departmentId] ?? "" }
            for i in lineItems.indices {
                if (lineItems[i].department ?? "").isEmpty { lineItems[i].department = departmentId }
                if (lineItems[i].account ?? "").isEmpty { lineItems[i].account = nominalCode }
            }
        }
    }

    // MARK: - Nominal Code → Department auto-sync binding
    private var ctNominalCodeBinding: Binding<String> {
        Binding<String>(
            get: { nominalCode },
            set: { newValue in
                nominalCode = newValue
                if let dept = NominalCodes.nominalToDept[newValue] {
                    departmentId = dept
                }
            }
        )
    }

    // MARK: - Department → Nominal Code auto-sync binding
    private var ctDepartmentBinding: Binding<String> {
        Binding<String>(
            get: { departmentId },
            set: { newValue in
                departmentId = newValue
                nominalCode = NominalCodes.deptToNominal[newValue] ?? nominalCode
                for i in lineItems.indices {
                    if (lineItems[i].department ?? "").isEmpty || lineItems[i].department != newValue {
                        lineItems[i].department = newValue
                    }
                    let newNominal = NominalCodes.deptToNominal[newValue] ?? ""
                    if (lineItems[i].account ?? "").isEmpty || lineItems[i].account != newNominal {
                        lineItems[i].account = newNominal
                    }
                }
            }
        )
    }

    private let ctPOSystemLabels: Set<String> = [
        "vendor", "vendor_address", "department", "account_code", "description",
        "currency", "vat", "delivery_date", "effective_date", "notes"
    ]
    private let ctDeliverySystemLabels: Set<String> = [
        "delivery_name", "delivery_email", "delivery_phone_code", "delivery_phone",
        "delivery_line1", "delivery_line2", "delivery_city", "delivery_state",
        "delivery_postal_code", "country"
    ]

    // MARK: - Delivery Address Fields

    @ViewBuilder
    private func ctDeliveryField(_ field: FormField) -> some View {
        if field.label == "delivery_name" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) { InputField(text: $daName, placeholder: "Recipient name...") }
        } else if field.label == "delivery_email" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) { InputField(text: $daEmail, placeholder: "email@example.com", keyboard: .emailAddress) }
        } else if field.label == "delivery_phone_code" {
            EmptyView()
        } else if field.label == "delivery_phone" {
            FieldGroup(label: "PHONE", optional: !field.isRequired) { PhoneField(phoneCode: $daPhoneCode, phone: $daPhone) }
        } else if field.label == "delivery_line1" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) { InputField(text: $daLine1, placeholder: "Street address...") }
        } else if field.label == "delivery_line2" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) { InputField(text: $daLine2, placeholder: "Suite, unit, building...") }
        } else if field.label == "delivery_city" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) { InputField(text: $daCity, placeholder: "City...") }
        } else if field.label == "delivery_state" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) { InputField(text: $daState, placeholder: "State / County...") }
        } else if field.label == "delivery_postal_code" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) { InputField(text: $daPostal, placeholder: "Postal code...") }
        } else if field.label == "country" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) { InputField(text: $daCountry, placeholder: "Country") }
        } else if !ctDeliverySystemLabels.contains(field.label ?? "") {
            ctCustomFieldView(sectionKey: "delivery_address", field: field)
        }
    }

    // MARK: - Date Field Helper

    @ViewBuilder
    private func ctDateFieldContent(hasDate: Binding<Bool>, date: Binding<Date>) -> some View {
        DateFieldView(hasDate: hasDate, date: date)
    }

    // MARK: - Custom Field

    @ViewBuilder
    private func ctCustomFieldView(sectionKey: String, field: FormField) -> some View {
        let key = "\(sectionKey)_\(field.name ?? "")"
        let binding = Binding<String>(
            get: { self.customFieldValues[key] ?? "" },
            set: { self.customFieldValues[key] = $0 }
        )
        if field.type == "select" {
            if field.selectionType == "vendor" {
                FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select...",
                        options: appState.vendors.map { DropdownOption($0.id, $0.name ?? "") })
                }
            } else if field.selectionType == "department" {
                FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select department...",
                        options: DepartmentsData.sorted.map { DropdownOption($0.identifier ?? "", $0.displayName) })
                }
            } else if field.selectionType == "currency" {
                FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select currency...",
                        options: [DropdownOption("GBP", "GBP — British Pound"),
                                  DropdownOption("USD", "USD — US Dollar"),
                                  DropdownOption("EUR", "EUR — Euro")])
                }
            } else if field.selectionType == "vat" {
                FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select VAT...",
                        options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
                }
            } else if field.selectionType == "account_code" {
                FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select account...",
                        options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
                }
            } else if field.selectionType == "exp_type" {
                FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select type...",
                        options: expenditureTypes.map { DropdownOption($0, $0) })
                }
            } else {
                FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                    InputField(text: binding, placeholder: "Enter \((field.name ?? "").lowercased())...")
                }
            }
        } else if field.type == "date" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                InputField(text: binding, placeholder: "dd/mm/yyyy")
            }
        } else if field.type == "number" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                InputField(text: binding, placeholder: "0", keyboard: .decimalPad)
            }
        } else if field.type == "email" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                InputField(text: binding, placeholder: "email@example.com", keyboard: .emailAddress)
            }
        } else if field.type == "phone" {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                InputField(text: binding, placeholder: "Phone number", keyboard: .phonePad)
            }
        } else {
            FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                InputField(text: binding, placeholder: "Enter \((field.name ?? "").lowercased())...")
            }
        }
    }

    // MARK: - Helpers

    private var ctVendorAddressText: String {
        guard !vendorId.isEmpty, let v = appState.vendors.first(where: { $0.id == vendorId }) else { return "Select a vendor first" }
        let addr = v.address?.formatted ?? ""
        return addr.isEmpty ? "No address on file" : addr
    }

    private func ctSectionHeader(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(.goldDark)
            Text(title).font(.system(size: 11, weight: .bold)).tracking(1).lineLimit(1)
            Spacer()
        }
    }

    private var ctNetTotal: Double {
        lineItems.reduce(0) { $0 + (($1.quantity ?? 0) * ($1.unitPrice ?? 0)) }
    }

    private var ctDecimalFormatter: NumberFormatter {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.minimumFractionDigits = 2; f.maximumFractionDigits = 2; return f
    }

    // MARK: - Fallback views

    private var ctFallbackPODetails: some View {
        VStack(spacing: 14) {
            FieldGroup(label: "VENDOR") { VendorSearchField(vendorId: $vendorId, vendors: appState.vendors) }
            FieldGroup(label: "DEPARTMENT") {
                PickerField(selection: ctDepartmentBinding, placeholder: "Select department...",
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier ?? "", $0.displayName) })
            }
            FieldGroup(label: "NOMINAL CODE") {
                PickerField(selection: ctNominalCodeBinding, placeholder: "Select nominal code...",
                    options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
            }
            FieldGroup(label: "DESCRIPTION", optional: true) { InputField(text: $desc, placeholder: "e.g. Studio hire — Stage G, 12 weeks") }
            HStack(spacing: 10) {
                FieldGroup(label: "CURRENCY") {
                    PickerField(selection: $currency, placeholder: "Select currency...",
                        options: [DropdownOption("GBP", "GBP — British Pound"), DropdownOption("USD", "USD — US Dollar"), DropdownOption("EUR", "EUR — Euro")])
                }
                FieldGroup(label: "VAT TREATMENT") {
                    PickerField(selection: $vatTreatment, placeholder: "Select VAT...",
                        options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
                }
            }
            FieldGroup(label: "NOTES", optional: true) { InputField(text: $notes, placeholder: "Internal notes...") }
        }
    }

    private var ctFallbackDeliveryAddress: some View {
        VStack(spacing: 14) {
            FieldGroup(label: "RECIPIENT NAME") { InputField(text: $daName, placeholder: "Recipient name...") }
            FieldGroup(label: "EMAIL") { InputField(text: $daEmail, placeholder: "email@example.com", keyboard: .emailAddress) }
            FieldGroup(label: "PHONE") { PhoneField(phoneCode: $daPhoneCode, phone: $daPhone) }
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

    // MARK: - Create Template

    private func createTemplate() {
        for i in lineItems.indices { lineItems[i].total = (lineItems[i].quantity ?? 0) * (lineItems[i].unitPrice ?? 0) }
        let da = DeliveryAddress(name: daName, email: daEmail, phoneCode: daPhoneCode, phone: daPhone,
                                  line1: daLine1, line2: daLine2, city: daCity,
                                  state: daState, postalCode: daPostal, country: daCountry)
        let hasDA = ![daName, daEmail, daPhone, daLine1, daCity].allSatisfy { $0.isEmpty }
        let fd = POFormData(vendorId: vendorId, departmentId: departmentId, nominalCode: nominalCode,
                            description: desc, currency: currency, vatTreatment: vatTreatment,
                            effectiveDate: hasEffDate ? effectiveDate : nil,
                            deliveryDate: hasDelDate ? deliveryDate : nil,
                            notes: notes, lineItems: lineItems,
                            deliveryAddress: hasDA ? da : nil,
                            customFieldValues: customFieldValues,
                            lineItemCustomValues: lineItemCustomValues)
        appState.saveTemplate(fd, templateName: templateName, onComplete: onBack)
    }
}

// MARK: - PO Form Page (Navigation destination)
