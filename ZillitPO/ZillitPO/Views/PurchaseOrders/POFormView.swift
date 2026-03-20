import SwiftUI
import Combine

struct POFormView: View {
    @EnvironmentObject var appState: AppState
    var editingPO: PurchaseOrder?
    var resumeDraft: PurchaseOrder?
    var prefilledVendorId: String?
    var onBack: () -> Void

    // System field states
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

    // Custom field values: keyed by "sectionKey_fieldName"
    @State private var customFieldValues: [String: String] = [:]
    // Line item custom field values: keyed by lineItem.id -> fieldName -> value
    @State private var lineItemCustomValues: [String: [String: String]] = [:]

    @State private var cancellables = Set<AnyCancellable>()
    @State private var showTemplateNameSheet = false
    @State private var templateName = ""
    @State private var showLineItemsPage = false
    @State private var showAttachSheet = false
    @State private var showSaveSheet = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    var isEdit: Bool { editingPO != nil }

    private var hasValidLineItem: Bool {
        lineItems.contains { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty && $0.quantity > 0 && $0.unitPrice > 0 }
    }

    private var canSubmit: Bool {
        !vendorId.isEmpty && hasValidLineItem && !appState.formSubmitting
    }

    // ── Template-driven validation (matches web client) ──
    private func getVisibleFields(_ sectionKey: String) -> [FormField] {
        guard let sections = sortedSections,
              let sec = sections.first(where: { $0.key == sectionKey }) else { return [] }
        return sec.visibleFields
    }

    private func validate() -> [String] {
        var errors: [String] = []

        // PO Details — check required system + custom fields
        let poFields = getVisibleFields("po_details")
        for field in poFields {
            guard field.isRequired else { continue }
            let label = field.label ?? ""
            if poSystemLabels.contains(label) {
                switch label {
                case "vendor": if vendorId.isEmpty { errors.append("Vendor is required") }
                case "department": if departmentId.isEmpty { errors.append("Department is required") }
                case "currency": if currency.isEmpty { errors.append("Currency is required") }
                case "vat": if vatTreatment.isEmpty { errors.append("VAT Treatment is required") }
                case "description": if desc.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Description is required") }
                case "delivery_date": if !hasDelDate { errors.append("Delivery Date is required") }
                case "effective_date": if !hasEffDate { errors.append("Effective Date is required") }
                case "notes": if notes.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Notes is required") }
                case "account_code": if nominalCode.isEmpty { errors.append("Nominal Code is required") }
                default: break
                }
            } else {
                // Custom field — key matches customFieldView: "sectionKey_fieldName"
                let key = "po_details_\(field.name)"
                let val = customFieldValues[key] ?? ""
                if val.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append("\(field.name) is required")
                }
            }
        }

        // Delivery Address — check required fields
        let deliveryFields = getVisibleFields("delivery_address")
        for field in deliveryFields {
            guard field.isRequired else { continue }
            let label = field.label ?? ""
            if deliverySystemLabels.contains(label) {
                let addrMap: [String: String] = [
                    "delivery_name": daName, "delivery_email": daEmail,
                    "delivery_phone": daPhone, "delivery_phone_code": daPhoneCode,
                    "delivery_line1": daLine1, "delivery_line2": daLine2,
                    "delivery_city": daCity, "delivery_state": daState,
                    "delivery_postal_code": daPostal, "country": daCountry
                ]
                if let val = addrMap[label], val.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append("\(field.name) is required")
                }
            } else {
                // Custom field — key matches customFieldView: "sectionKey_fieldName"
                let key = "delivery_address_\(field.name)"
                let val = customFieldValues[key] ?? ""
                if val.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append("\(field.name) is required")
                }
            }
        }

        // Custom sections — check required custom fields
        if let sections = sortedSections {
            let knownSections: Set<String> = ["po_details", "delivery_address", "line_items", "terms_of_engagement"]
            for section in sections where !knownSections.contains(section.key) {
                for field in section.visibleFields {
                    guard field.isRequired else { continue }
                    let key = "\(section.key)_\(field.name)"
                    let val = customFieldValues[key] ?? ""
                    if val.trimmingCharacters(in: .whitespaces).isEmpty {
                        errors.append("\(field.name) is required")
                    }
                }
            }
        }

        // Line items — at least one with description
        if lineItems.allSatisfy({ $0.description.trimmingCharacters(in: .whitespaces).isEmpty }) {
            errors.append("At least one line item with a description is required")
        }

        // Line item field validation
        let lineFields = getVisibleFields("line_items")
        let liSysLabels: Set<String> = ["line_description", "line_quantity", "line_unit_price", "account_code", "department", "exp_type"]
        for (idx, li) in lineItems.enumerated() {
            guard !li.description.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            for field in lineFields {
                guard field.isRequired else { continue }
                let label = field.label ?? ""
                if liSysLabels.contains(label) {
                    switch label {
                    case "line_description":
                        if li.description.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Line \(idx + 1): Description is required") }
                    case "line_quantity":
                        if li.quantity <= 0 { errors.append("Line \(idx + 1): Quantity must be > 0") }
                    case "line_unit_price":
                        if li.unitPrice < 0 { errors.append("Line \(idx + 1): Unit Price is required") }
                    case "exp_type":
                        if li.expenditureType.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Line \(idx + 1): Expenditure Type is required") }
                    default: break
                    }
                } else {
                    let key = label.isEmpty ? field.name : label
                    let val = (lineItemCustomValues[li.id]?[key]) ?? ""
                    if val.trimmingCharacters(in: .whitespaces).isEmpty {
                        errors.append("Line \(idx + 1): \(field.name) is required")
                    }
                }
            }
        }

        // Always enforce vendor + at least one valid line item (even if template loaded)
        if vendorId.isEmpty && !errors.contains("Vendor is required") {
            errors.insert("Vendor is required", at: 0)
        }
        if !hasValidLineItem && !errors.contains(where: { $0.contains("line item") }) {
            errors.append("At least one line item (with description, quantity, and unit price) is required")
        }

        return errors
    }

    private var sortedSections: [FormSection]? {
        appState.formTemplate?.template.sorted { $0.order < $1.order }
    }

    var body: some View {
        ZStack {
            List {
                if let sections = sortedSections {
                    ForEach(sections, id: \.key) { section in
                        self.formSection(for: section)
                    }
                    // If template has no terms_of_engagement section, show Summary after all sections
                    if !sections.contains(where: { $0.key == "terms_of_engagement" }) {
                        Section(header: sectionHeader(icon: "sum", title: "SUMMARY")) { summaryContent }
                    }
                } else {
                    // Fallback: original hardcoded sections when template not loaded
                    Section(header: sectionHeader(icon: "person.crop.square", title: "VENDOR INFORMATION")) {
                        fallbackVendorInfoContent
                    }
                    Section(header: sectionHeader(icon: "doc.text", title: "PO DETAILS", trailing: "All fields required unless noted")) {
                        fallbackPODetailsContent
                    }
                    Section(header: sectionHeader(icon: "shippingbox", title: "DELIVERY ADDRESS")) {
                        fallbackDeliveryAddressContent
                    }
                    Section(header: sectionHeader(icon: "list.bullet.rectangle", title: "LINE ITEMS")) {
                        lineItemsSummaryCard
                    }
                    Section(header: sectionHeader(icon: "note.text", title: "ADDITIONAL NOTES")) {
                        FieldGroup(label: "NOTES", optional: true) { InputField(text: $notes, placeholder: "Internal notes...") }
                    }
                    Section(header: sectionHeader(icon: "sum", title: "SUMMARY")) { summaryContent }
                }
                Section { actionsContent }
            }
            .listStyle(GroupedListStyle())
            .dismissKeyboardOnTap()
            .onAppear { loadData() }
            .sheet(isPresented: $showTemplateNameSheet) {
                TemplateNameSheet(templateName: $templateName, isPresented: $showTemplateNameSheet) { saveTemplate() }
            }

            // Hidden NavigationLink for Line Items page
            NavigationLink(
                destination: LineItemsPage(
                    lineItems: $lineItems,
                    lineItemCustomValues: $lineItemCustomValues,
                    formFields: lineItemFields,
                    currency: currency,
                    vatTreatment: vatTreatment
                ).environmentObject(appState),
                isActive: $showLineItemsPage
            ) { EmptyView() }
            .hidden()
        }
    }

    private var lineItemFields: [FormField] {
        if let sections = sortedSections,
           let liSection = sections.first(where: { $0.key == "line_items" }) {
            return liSection.visibleFields
        }
        return []
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Dynamic Section Router
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    private func formSection(for section: FormSection) -> some View {
        if section.key == "po_details" {
            poDetailsSection(section)
        } else if section.key == "delivery_address" {
            deliveryAddressSection(section)
        } else if section.key == "line_items" {
            lineItemsSection(section)
        } else if section.key == "terms_of_engagement" {
            Section(header: sectionHeader(icon: "sum", title: "SUMMARY")) { summaryContent }
            termsSection(section)
        } else {
            customSection(section)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - PO Details Section (dynamic)
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    private func poDetailsSection(_ section: FormSection) -> some View {
        Section(header: sectionHeader(icon: "doc.text", title: section.label.uppercased())) {
            VStack(spacing: 14) {
                ForEach(section.visibleFields, id: \.id) { field in
                    self.poDetailFieldView(field)
                }
            }
        }
    }

    @ViewBuilder
    private func poDetailFieldView(_ field: FormField) -> some View {
        if field.label == "vendor" {
            FieldGroup(label: field.name.uppercased()) {
                VendorSearchField(vendorId: $vendorId, vendors: appState.vendors)
            }
        } else if field.label == "vendor_address" {
            FieldGroup(label: field.name.uppercased()) {
                Text(vendorAddressText)
                    .font(.system(size: 13))
                    .foregroundColor(vendorId.isEmpty ? .gray : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        } else if field.label == "department" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                PickerField(selection: $departmentId, placeholder: "Select department...",
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
            }
        } else if field.label == "account_code" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                PickerField(selection: $nominalCode, placeholder: "Select nominal code...",
                    options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
            }
        } else if field.label == "description" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $desc, placeholder: "e.g. Studio hire — Stage G, 12 weeks")
            }
        } else if field.label == "currency" {
            FieldGroup(label: field.name.uppercased()) {
                PickerField(selection: $currency, placeholder: "Select currency...",
                    options: [DropdownOption("GBP", "GBP — British Pound"),
                              DropdownOption("USD", "USD — US Dollar"),
                              DropdownOption("EUR", "EUR — Euro")])
            }
        } else if field.label == "vat" {
            FieldGroup(label: field.name.uppercased()) {
                PickerField(selection: $vatTreatment, placeholder: "Select VAT...",
                    options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
            }
        } else if field.label == "delivery_date" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                dateFieldContent(hasDate: $hasDelDate, date: $deliveryDate)
            }
        } else if field.label == "effective_date" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                dateFieldContent(hasDate: $hasEffDate, date: $effectiveDate)
            }
        } else if field.label == "notes" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $notes, placeholder: "Internal notes...")
            }
        } else if !poSystemLabels.contains(field.label ?? "") {
            customFieldView(sectionKey: "po_details", field: field)
        }
    }

    private let poSystemLabels: Set<String> = [
        "vendor", "vendor_address", "department", "account_code", "description",
        "currency", "vat", "delivery_date", "effective_date", "notes"
    ]
    private let deliverySystemLabels: Set<String> = [
        "delivery_name", "delivery_email", "delivery_phone_code", "delivery_phone",
        "delivery_line1", "delivery_line2", "delivery_city", "delivery_state",
        "delivery_postal_code", "country"
    ]

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Delivery Address Section (dynamic)
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    private func deliveryAddressSection(_ section: FormSection) -> some View {
        Section(header: sectionHeader(icon: "shippingbox", title: section.label.uppercased())) {
            VStack(spacing: 14) {
                ForEach(section.visibleFields, id: \.id) { field in
                    self.deliveryFieldView(field)
                }
            }
        }
    }

    @ViewBuilder
    private func deliveryFieldView(_ field: FormField) -> some View {
        if field.label == "delivery_name" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $daName, placeholder: "Recipient name...")
            }
        } else if field.label == "delivery_email" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $daEmail, placeholder: "email@example.com", keyboard: .emailAddress)
            }
        } else if field.label == "delivery_phone_code" {
            EmptyView()
        } else if field.label == "delivery_phone" {
            FieldGroup(label: "PHONE", optional: !field.isRequired) {
                PhoneField(phoneCode: $daPhoneCode, phone: $daPhone)
            }
        } else if field.label == "delivery_line1" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $daLine1, placeholder: "Street address...")
            }
        } else if field.label == "delivery_line2" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $daLine2, placeholder: "Suite, unit, building...")
            }
        } else if field.label == "delivery_city" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $daCity, placeholder: "City...")
            }
        } else if field.label == "delivery_state" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $daState, placeholder: "State / County...")
            }
        } else if field.label == "delivery_postal_code" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $daPostal, placeholder: "Postal code...")
            }
        } else if field.label == "country" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $daCountry, placeholder: "Country")
            }
        } else if !deliverySystemLabels.contains(field.label ?? "") {
            customFieldView(sectionKey: "delivery_address", field: field)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Line Items Section (dynamic)
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    private func lineItemsSection(_ section: FormSection) -> some View {
        Section(header: sectionHeader(icon: "list.bullet.rectangle", title: section.label.uppercased())) {
            lineItemsSummaryCard
        }
    }

    private var lineItemsSummaryCard: some View {
        Button(action: { showLineItemsPage = true }) {
            VStack(spacing: 10) {
                ForEach(Array(lineItems.enumerated()), id: \.element.id) { idx, item in
                    HStack {
                        Text("\(idx + 1).").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                        Text(item.description.isEmpty ? "Untitled Item" : item.description)
                            .font(.system(size: 13, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                        Spacer()
                        Text("×\(Int(item.quantity))").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                        Text(FormatUtils.formatCurrency(item.quantity * item.unitPrice, code: currency))
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
                    Text(FormatUtils.formatCurrency(netTotal, code: currency)).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                }
            }
            .padding(12)
            .background(Color.bgBase)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldDark.opacity(0.3), lineWidth: 1))
        }.buttonStyle(BorderlessButtonStyle())
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Terms of Engagement Section
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    private func termsSection(_ section: FormSection) -> some View {
        if let values = section.values, !values.isEmpty {
            Section(header: sectionHeader(icon: "doc.plaintext", title: section.label.uppercased())) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(values, id: \.self) { term in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.goldDark)
                            Text(term)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Custom Section (dynamic)
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    private func customSection(_ section: FormSection) -> some View {
        Section(header: sectionHeader(icon: "square.grid.2x2", title: section.label.uppercased())) {
            VStack(spacing: 14) {
                ForEach(section.visibleFields, id: \.id) { field in
                    self.customFieldView(sectionKey: section.key, field: field)
                }
            }
        }
    }

    @ViewBuilder
    private func customFieldView(sectionKey: String, field: FormField) -> some View {
        let key = "\(sectionKey)_\(field.name)"
        let binding = Binding<String>(
            get: { self.customFieldValues[key] ?? "" },
            set: { self.customFieldValues[key] = $0 }
        )
        if field.type == "select" {
            // Handle selection_type for known option sets (matches web client)
            if field.selectionType == "vendor" {
                FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select...",
                        options: appState.vendors.map { DropdownOption($0.id, $0.name) })
                }
            } else if field.selectionType == "department" {
                FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select department...",
                        options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
                }
            } else if field.selectionType == "currency" {
                FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select currency...",
                        options: [DropdownOption("GBP", "GBP — British Pound"),
                                  DropdownOption("USD", "USD — US Dollar"),
                                  DropdownOption("EUR", "EUR — Euro")])
                }
            } else if field.selectionType == "vat" {
                FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select VAT...",
                        options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
                }
            } else if field.selectionType == "account_code" {
                FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select account...",
                        options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
                }
            } else if field.selectionType == "exp_type" {
                FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select type...",
                        options: expenditureTypes.map { DropdownOption($0, $0) })
                }
            } else {
                FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                    InputField(text: binding, placeholder: "Enter \(field.name.lowercased())...")
                }
            }
        } else if field.type == "date" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: binding, placeholder: "dd/mm/yyyy")
            }
        } else if field.type == "number" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: binding, placeholder: "0", keyboard: .decimalPad)
            }
        } else if field.type == "email" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: binding, placeholder: "email@example.com", keyboard: .emailAddress)
            }
        } else if field.type == "phone" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: binding, placeholder: "Phone number", keyboard: .phonePad)
            }
        } else {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: binding, placeholder: "Enter \(field.name.lowercased())...")
            }
        }
    }

    // Line item custom field
    @ViewBuilder
    private func lineItemCustomFieldView(itemId: String, field: FormField) -> some View {
        let binding = Binding<String>(
            get: { self.lineItemCustomValues[itemId]?[field.name] ?? "" },
            set: { val in
                if self.lineItemCustomValues[itemId] == nil { self.lineItemCustomValues[itemId] = [:] }
                self.lineItemCustomValues[itemId]?[field.name] = val
            }
        )
        FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
            InputField(text: binding, placeholder: "Enter \(field.name.lowercased())...")
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Date Field Helper
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    private func dateFieldContent(hasDate: Binding<Bool>, date: Binding<Date>) -> some View {
        DateFieldView(hasDate: hasDate, date: date)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Section Headers
    // ═══════════════════════════════════════════════════════════════════════

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

    // ═══════════════════════════════════════════════════════════════════════
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Summary & Actions
    // ═══════════════════════════════════════════════════════════════════════

    private var summaryContent: some View {
        let vat = VATHelpers.calcVat(netTotal, treatment: vatTreatment)
        return VStack(spacing: 8) {
            HStack {
                Text("Net Amount").font(.system(size: 14)).foregroundColor(.secondary)
                Spacer()
                Text(FormatUtils.formatCurrency(netTotal, code: currency)).font(.system(size: 15, design: .monospaced))
            }
            if vatTreatment != "pending" {
                HStack {
                    Text("VAT (\(VATHelpers.vatLabel(vatTreatment)))").font(.system(size: 14)).foregroundColor(.secondary)
                    if vat.reverseCharged {
                        Text("RC").font(.system(size: 8, weight: .bold)).foregroundColor(.orange)
                            .padding(.horizontal, 4).padding(.vertical, 1).background(Color.orange.opacity(0.1)).cornerRadius(3)
                    }
                    Spacer()
                    Text(FormatUtils.formatCurrency(vat.vatAmount, code: currency)).font(.system(size: 14, design: .monospaced)).foregroundColor(.secondary)
                }
            }
            Divider()
            HStack {
                Text("Gross Total").font(.system(size: 16, weight: .bold))
                Spacer()
                Text(FormatUtils.formatCurrency(vat.gross, code: currency)).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }
        }
    }

    private var actionsContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Attach button (outlined)
                Button(action: { showAttachSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "paperclip").font(.system(size: 13))
                        Text("Attach").font(.system(size: 13, weight: .semibold))
                    }.foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())
                .actionSheet(isPresented: $showAttachSheet) {
                    ActionSheet(title: Text("Attach"), buttons: [
                        .default(Text("Quote")) { /* TODO: attach quote */ },
                        .default(Text("Email")) { /* TODO: attach email */ },
                        .default(Text("Attachment")) { /* TODO: attach file */ },
                        .cancel()
                    ])
                }

                // Save button (gold, dropdown)
                Button(action: { showSaveSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 13))
                        Text("Save").font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }.foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.gold).cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle())
                .actionSheet(isPresented: $showSaveSheet) {
                    if resumeDraft != nil {
                        return ActionSheet(title: Text("Save Options"), buttons: [
                            .default(Text("Save")) { saveCurrentDraft() },
                            .default(Text("Save as Draft")) { saveAsNewDraft() },
                            .default(Text("Save as Template")) { templateName = desc; showTemplateNameSheet = true },
                            .cancel()
                        ])
                    } else {
                        return ActionSheet(title: Text("Save Options"), buttons: [
                            .default(Text("Save as Draft")) { saveAsNewDraft() },
                            .default(Text("Save as Template")) { templateName = desc; showTemplateNameSheet = true },
                            .cancel()
                        ])
                    }
                }
            }

            // Submit PO button (full width, dark gold)
            Button(action: { validateAndSubmit() }) {
                HStack(spacing: 6) {
                    Text(isEdit ? "Update PO" : "Submit PO").font(.system(size: 14, weight: .bold))
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                }.foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(canSubmit ? Color.gold : Color.gold.opacity(0.4)).cornerRadius(8)
            }.disabled(appState.formSubmitting)
            .alert(isPresented: $showValidationAlert) {
                Alert(title: Text("Missing Required Fields"), message: Text(validationMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Computed
    // ═══════════════════════════════════════════════════════════════════════

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

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Load Data
    // ═══════════════════════════════════════════════════════════════════════

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
            if let ms = po.deliveryDate, ms > 0 { deliveryDate = Date(timeIntervalSince1970: Double(ms)/1000); hasDelDate = true }
            if let da = po.deliveryAddress {
                daName = da.name ?? ""; daEmail = da.email ?? ""; daPhone = da.phone ?? ""
                daLine1 = da.line1 ?? ""; daLine2 = da.line2 ?? ""; daCity = da.city ?? ""
                daState = da.state ?? ""; daPostal = da.postalCode ?? ""; daCountry = da.country ?? ""
            }
            // Load custom field values from PO
            for section in po.customFields {
                let secKey = section.section ?? "custom"
                for field in section.fields ?? [] {
                    customFieldValues["\(secKey)_\(field.name)"] = field.value
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Form Actions
    // ═══════════════════════════════════════════════════════════════════════

    private func buildForm() -> POFormData {
        for i in lineItems.indices { lineItems[i].total = lineItems[i].quantity * lineItems[i].unitPrice }
        let da = DeliveryAddress(name: daName, email: daEmail, phoneCode: daPhoneCode, phone: daPhone,
                                  line1: daLine1, line2: daLine2, city: daCity,
                                  state: daState, postalCode: daPostal, country: daCountry)
        let hasDA = ![daName, daEmail, daPhone, daLine1, daCity].allSatisfy { $0.isEmpty }
        return POFormData(vendorId: vendorId, departmentId: departmentId, nominalCode: nominalCode,
                          description: desc, currency: currency, vatTreatment: vatTreatment,
                          effectiveDate: hasEffDate ? effectiveDate : nil,
                          deliveryDate: hasDelDate ? deliveryDate : nil,
                          notes: notes, lineItems: lineItems,
                          existingDraftId: (editingPO ?? resumeDraft)?.id,
                          deliveryAddress: hasDA ? da : nil,
                          customFieldValues: customFieldValues,
                          lineItemCustomValues: lineItemCustomValues)
    }

    private func validateAndSubmit() {
        let errors = validate()
        if !errors.isEmpty {
            validationMessage = errors.map { "• \($0)" }.joined(separator: "\n")
            showValidationAlert = true
            return
        }
        submitPO()
    }

    private func submitPO() { appState.submitPO(buildForm(), onComplete: onBack) }

    /// Save (update) current draft — uses existingDraftId
    private func saveCurrentDraft() { appState.saveDraft(buildForm(), onComplete: onBack) }

    /// Save as new draft — no existingDraftId, creates a brand new draft
    private func saveAsNewDraft() {
        print("📝 saveAsNewDraft called")
        var fd = buildForm()
        fd.existingDraftId = nil
        appState.saveDraft(fd, onComplete: onBack)
    }

    private func saveTemplate() { appState.saveTemplate(buildForm(), templateName: templateName, onComplete: onBack) }


    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Fallback (original hardcoded layout when template not loaded)
    // ═══════════════════════════════════════════════════════════════════════

    private var fallbackVendorInfoContent: some View {
        VStack(spacing: 14) {
            FieldGroup(label: "VENDOR") { VendorSearchField(vendorId: $vendorId, vendors: appState.vendors) }
            FieldGroup(label: "VENDOR ADDRESS") {
                Text(vendorAddressText).font(.system(size: 13)).foregroundColor(vendorId.isEmpty ? .gray : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color(red: 0.97, green: 0.97, blue: 0.98)).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        }
    }

    private var fallbackPODetailsContent: some View {
        VStack(spacing: 14) {
            FieldGroup(label: "DEPARTMENT") {
                PickerField(selection: $departmentId, placeholder: "Select department...",
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
            }
            FieldGroup(label: "NOMINAL CODE") {
                PickerField(selection: $nominalCode, placeholder: "Select nominal code...",
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
            FieldGroup(label: "DELIVERY DATE") { dateFieldContent(hasDate: $hasDelDate, date: $deliveryDate) }
        }
    }

    private var fallbackDeliveryAddressContent: some View {
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

}

// MARK: - Line Items Page

struct LineItemsPage: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    @Binding var lineItems: [LineItem]
    @Binding var lineItemCustomValues: [String: [String: String]]
    var formFields: [FormField]
    var currency: String = "GBP"
    var vatTreatment: String = "pending"

    private var decimalFormatter: NumberFormatter {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.minimumFractionDigits = 2; f.maximumFractionDigits = 2; return f
    }

    private var netTotal: Double {
        lineItems.reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
    }

    private var vat: VATResult {
        VATHelpers.calcVat(netTotal, treatment: vatTreatment)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(lineItems.enumerated()), id: \.element.id) { idx, item in
                        liCard(idx: idx, item: item)
                    }

                    // Add Line Item button
                    Button(action: { lineItems.append(LineItem()) }) {
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
                if vatTreatment != "pending" {
                    HStack {
                        HStack(spacing: 4) {
                            Text("VAT (\(VATHelpers.vatLabel(vatTreatment)))").font(.system(size: 12)).foregroundColor(.secondary)
                            if vat.reverseCharged {
                                Text("RC").font(.system(size: 8, weight: .bold)).foregroundColor(.orange)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.1)).cornerRadius(3)
                            }
                        }
                        Spacer()
                        Text(FormatUtils.formatCurrency(vat.vatAmount, code: currency)).font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary)
                    }
                    Divider()
                    HStack {
                        Text("Gross Total").font(.system(size: 14, weight: .bold))
                        Spacer()
                        Text(FormatUtils.formatCurrency(vat.gross, code: currency)).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
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
            leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
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
                    self.liFieldView(field, itemId: item.id, item: item)
                }
                // Amount row always shown after dynamic fields
                liAmountRow(item)
            } else {
                // Fallback fields (includes amount row)
                liFallbackFields(item: item)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private let liSystemLabels: Set<String> = ["line_description", "line_quantity", "line_unit_price", "account_code", "department", "exp_type"]

    @ViewBuilder
    private func liFieldView(_ field: FormField, itemId: String, item: LineItem) -> some View {
        if field.label == "line_description" {
            FieldGroup(label: field.name.uppercased()) {
                InputField(text: liBindDesc(itemId), placeholder: "Item description")
            }
        } else if field.label == "line_quantity" {
            FieldGroup(label: field.name.uppercased()) {
                TextField("1", value: liBindQty(itemId), formatter: NumberFormatter())
                    .font(.system(size: 14)).keyboardType(.numberPad).padding(10)
                    .background(Color.white).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        } else if field.label == "line_unit_price" {
            FieldGroup(label: field.name.uppercased()) {
                TextField("0.00", value: liBindPrice(itemId), formatter: decimalFormatter)
                    .font(.system(size: 14, design: .monospaced)).keyboardType(.decimalPad).padding(10)
                    .background(Color.white).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        } else if field.label == "account_code" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                PickerField(selection: liBindAccount(itemId), placeholder: "Select account...",
                    options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
            }
        } else if field.label == "department" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                PickerField(selection: liBindDept(itemId), placeholder: "Select department...",
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
            }
        } else if field.label == "exp_type" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                PickerField(selection: liBindExpType(itemId), placeholder: "Select type...",
                    options: expenditureTypes.map { DropdownOption($0, $0) })
            }
        } else if !liSystemLabels.contains(field.label ?? "") {
            // Custom field — render if label is not a known system label
            liCustomFieldView(itemId: itemId, field: field)
        }
    }

    // Amount row — always shown at the bottom of every line item card
    private func liAmountRow(_ item: LineItem) -> some View {
        HStack {
            Text("Amount").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
            Spacer()
            Text(FormatUtils.formatCurrency(item.quantity * item.unitPrice, code: currency))
                .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func liFallbackFields(item: LineItem) -> some View {
        FieldGroup(label: "DESCRIPTION") { InputField(text: liBindDesc(item.id), placeholder: "Item description") }
        HStack(spacing: 10) {
            FieldGroup(label: "QTY") {
                TextField("1", value: liBindQty(item.id), formatter: NumberFormatter())
                    .font(.system(size: 14)).keyboardType(.numberPad).padding(10).background(Color.white).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
            FieldGroup(label: "UNIT PRICE") {
                TextField("0.00", value: liBindPrice(item.id), formatter: decimalFormatter)
                    .font(.system(size: 14, design: .monospaced)).keyboardType(.decimalPad).padding(10).background(Color.white).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        }
        FieldGroup(label: "ACCOUNT CODE", optional: true) {
            PickerField(selection: liBindAccount(item.id), placeholder: "Select account...",
                options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
        }
        FieldGroup(label: "DEPARTMENT", optional: true) {
            PickerField(selection: liBindDept(item.id), placeholder: "Select department...",
                options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
        }
        FieldGroup(label: "EXPENDITURE TYPE", optional: true) {
            PickerField(selection: liBindExpType(item.id), placeholder: "Select type...",
                options: expenditureTypes.map { DropdownOption($0, $0) })
        }
        liAmountRow(item)
    }

    @ViewBuilder
    private func liCustomFieldView(itemId: String, field: FormField) -> some View {
        let binding = Binding<String>(
            get: { self.lineItemCustomValues[itemId]?[field.name] ?? "" },
            set: { val in
                if self.lineItemCustomValues[itemId] == nil { self.lineItemCustomValues[itemId] = [:] }
                self.lineItemCustomValues[itemId]?[field.name] = val
            }
        )
        FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
            InputField(text: binding, placeholder: "Enter \(field.name.lowercased())...")
        }
    }

    // MARK: - Bindings

    private func liBindDesc(_ id: String) -> Binding<String> {
        Binding<String>(get: { lineItems.first { $0.id == id }?.description ?? "" },
                        set: { v in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].description = v } })
    }
    private func liBindQty(_ id: String) -> Binding<Double> {
        Binding<Double>(get: { lineItems.first { $0.id == id }?.quantity ?? 1 },
                        set: { v in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].quantity = v } })
    }
    private func liBindPrice(_ id: String) -> Binding<Double> {
        Binding<Double>(get: { lineItems.first { $0.id == id }?.unitPrice ?? 0 },
                        set: { v in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].unitPrice = v } })
    }
    private func liBindAccount(_ id: String) -> Binding<String> {
        Binding<String>(get: { lineItems.first { $0.id == id }?.account ?? "" },
                        set: { v in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].account = v } })
    }
    private func liBindDept(_ id: String) -> Binding<String> {
        Binding<String>(get: { lineItems.first { $0.id == id }?.department ?? "" },
                        set: { v in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].department = v } })
    }
    private func liBindExpType(_ id: String) -> Binding<String> {
        Binding<String>(get: { lineItems.first { $0.id == id }?.expenditureType ?? "" },
                        set: { v in if let i = lineItems.firstIndex(where: { $0.id == id }) { lineItems[i].expenditureType = v } })
    }
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
    var keyboard: UIKeyboardType = .default
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 13))
            .keyboardType(keyboard)
            .autocapitalization(keyboard == .emailAddress ? .none : .sentences)
            .disableAutocorrection(keyboard == .emailAddress || keyboard == .phonePad || keyboard == .decimalPad || keyboard == .numberPad)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.white)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
    }
}

// MARK: - Dismiss Keyboard Helper

extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
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
        .buttonStyle(BorderlessButtonStyle())
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
                        Button(action: { selection = option.id; isPresented = false }) {
                            HStack {
                                Text(option.label).font(.system(size: 14)).foregroundColor(.primary)
                                Spacer()
                                if option.id == selection {
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundColor(.goldDark)
                                }
                            }.padding(.vertical, 2)
                        }
                    }
                }.listStyle(GroupedListStyle())
            }
            .navigationBarTitle(Text("Select Option"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { isPresented = false }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark))
        }
    }
}

// MARK: - Country Code Data

struct CountryCode: Identifiable {
    let code: String  // e.g. "+44"
    let name: String  // e.g. "United Kingdom"
    let flag: String  // e.g. "🇬🇧"
    var id: String { "\(code)_\(name)" }
    var displayLabel: String { "\(flag) \(name) (\(code))" }
    var shortLabel: String { "\(flag) \(code)" }
}

let countryCodes: [CountryCode] = [
    CountryCode(code: "+44", name: "United Kingdom", flag: "🇬🇧"),
    CountryCode(code: "+1", name: "United States", flag: "🇺🇸"),
    CountryCode(code: "+1", name: "Canada", flag: "🇨🇦"),
    CountryCode(code: "+91", name: "India", flag: "🇮🇳"),
    CountryCode(code: "+61", name: "Australia", flag: "🇦🇺"),
    CountryCode(code: "+353", name: "Ireland", flag: "🇮🇪"),
    CountryCode(code: "+33", name: "France", flag: "🇫🇷"),
    CountryCode(code: "+49", name: "Germany", flag: "🇩🇪"),
    CountryCode(code: "+39", name: "Italy", flag: "🇮🇹"),
    CountryCode(code: "+34", name: "Spain", flag: "🇪🇸"),
    CountryCode(code: "+351", name: "Portugal", flag: "🇵🇹"),
    CountryCode(code: "+31", name: "Netherlands", flag: "🇳🇱"),
    CountryCode(code: "+32", name: "Belgium", flag: "🇧🇪"),
    CountryCode(code: "+41", name: "Switzerland", flag: "🇨🇭"),
    CountryCode(code: "+43", name: "Austria", flag: "🇦🇹"),
    CountryCode(code: "+46", name: "Sweden", flag: "🇸🇪"),
    CountryCode(code: "+47", name: "Norway", flag: "🇳🇴"),
    CountryCode(code: "+45", name: "Denmark", flag: "🇩🇰"),
    CountryCode(code: "+358", name: "Finland", flag: "🇫🇮"),
    CountryCode(code: "+48", name: "Poland", flag: "🇵🇱"),
    CountryCode(code: "+420", name: "Czech Republic", flag: "🇨🇿"),
    CountryCode(code: "+36", name: "Hungary", flag: "🇭🇺"),
    CountryCode(code: "+40", name: "Romania", flag: "🇷🇴"),
    CountryCode(code: "+30", name: "Greece", flag: "🇬🇷"),
    CountryCode(code: "+90", name: "Turkey", flag: "🇹🇷"),
    CountryCode(code: "+7", name: "Russia", flag: "🇷🇺"),
    CountryCode(code: "+380", name: "Ukraine", flag: "🇺🇦"),
    CountryCode(code: "+972", name: "Israel", flag: "🇮🇱"),
    CountryCode(code: "+971", name: "UAE", flag: "🇦🇪"),
    CountryCode(code: "+966", name: "Saudi Arabia", flag: "🇸🇦"),
    CountryCode(code: "+974", name: "Qatar", flag: "🇶🇦"),
    CountryCode(code: "+965", name: "Kuwait", flag: "🇰🇼"),
    CountryCode(code: "+968", name: "Oman", flag: "🇴🇲"),
    CountryCode(code: "+973", name: "Bahrain", flag: "🇧🇭"),
    CountryCode(code: "+27", name: "South Africa", flag: "🇿🇦"),
    CountryCode(code: "+234", name: "Nigeria", flag: "🇳🇬"),
    CountryCode(code: "+254", name: "Kenya", flag: "🇰🇪"),
    CountryCode(code: "+20", name: "Egypt", flag: "🇪🇬"),
    CountryCode(code: "+212", name: "Morocco", flag: "🇲🇦"),
    CountryCode(code: "+86", name: "China", flag: "🇨🇳"),
    CountryCode(code: "+81", name: "Japan", flag: "🇯🇵"),
    CountryCode(code: "+82", name: "South Korea", flag: "🇰🇷"),
    CountryCode(code: "+65", name: "Singapore", flag: "🇸🇬"),
    CountryCode(code: "+60", name: "Malaysia", flag: "🇲🇾"),
    CountryCode(code: "+66", name: "Thailand", flag: "🇹🇭"),
    CountryCode(code: "+62", name: "Indonesia", flag: "🇮🇩"),
    CountryCode(code: "+63", name: "Philippines", flag: "🇵🇭"),
    CountryCode(code: "+84", name: "Vietnam", flag: "🇻🇳"),
    CountryCode(code: "+880", name: "Bangladesh", flag: "🇧🇩"),
    CountryCode(code: "+92", name: "Pakistan", flag: "🇵🇰"),
    CountryCode(code: "+94", name: "Sri Lanka", flag: "🇱🇰"),
    CountryCode(code: "+64", name: "New Zealand", flag: "🇳🇿"),
    CountryCode(code: "+55", name: "Brazil", flag: "🇧🇷"),
    CountryCode(code: "+52", name: "Mexico", flag: "🇲🇽"),
    CountryCode(code: "+54", name: "Argentina", flag: "🇦🇷"),
    CountryCode(code: "+57", name: "Colombia", flag: "🇨🇴"),
    CountryCode(code: "+56", name: "Chile", flag: "🇨🇱"),
    CountryCode(code: "+51", name: "Peru", flag: "🇵🇪"),
    CountryCode(code: "+852", name: "Hong Kong", flag: "🇭🇰"),
    CountryCode(code: "+886", name: "Taiwan", flag: "🇹🇼"),
    CountryCode(code: "+370", name: "Lithuania", flag: "🇱🇹"),
    CountryCode(code: "+371", name: "Latvia", flag: "🇱🇻"),
    CountryCode(code: "+372", name: "Estonia", flag: "🇪🇪"),
    CountryCode(code: "+385", name: "Croatia", flag: "🇭🇷"),
    CountryCode(code: "+381", name: "Serbia", flag: "🇷🇸"),
    CountryCode(code: "+359", name: "Bulgaria", flag: "🇧🇬"),
    CountryCode(code: "+386", name: "Slovenia", flag: "🇸🇮"),
    CountryCode(code: "+421", name: "Slovakia", flag: "🇸🇰"),
    CountryCode(code: "+352", name: "Luxembourg", flag: "🇱🇺"),
    CountryCode(code: "+356", name: "Malta", flag: "🇲🇹"),
    CountryCode(code: "+357", name: "Cyprus", flag: "🇨🇾"),
    CountryCode(code: "+354", name: "Iceland", flag: "🇮🇸"),
]

// MARK: - Phone Input Field (country code picker + phone number on one line)

struct PhoneField: View {
    @Binding var phoneCode: String
    @Binding var phone: String
    @State private var showCodePicker = false
    @State private var searchText = ""

    private var selectedCountry: CountryCode? {
        countryCodes.first { $0.code == phoneCode }
    }

    private var codeButtonLabel: String {
        if let c = selectedCountry { return c.shortLabel }
        return phoneCode.isEmpty ? "🌐 Code" : "🌐 \(phoneCode)"
    }

    var body: some View {
        HStack(spacing: 6) {
            // Country code picker button
            Button(action: { showCodePicker = true }) {
                HStack(spacing: 4) {
                    Text(codeButtonLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
            .buttonStyle(BorderlessButtonStyle())
            .fixedSize()

            // Phone number input
            TextField("Phone number", text: $phone)
                .font(.system(size: 13))
                .keyboardType(.phonePad)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
        .sheet(isPresented: $showCodePicker) {
            CountryCodePickerSheet(selectedCode: $phoneCode, isPresented: $showCodePicker)
        }
    }
}

struct CountryCodePickerSheet: View {
    @Binding var selectedCode: String
    @Binding var isPresented: Bool
    @State private var searchText = ""

    private var filteredCodes: [CountryCode] {
        if searchText.isEmpty { return countryCodes }
        let q = searchText.lowercased()
        return countryCodes.filter { $0.name.lowercased().contains(q) || $0.code.contains(q) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                    TextField("Search country or code...", text: $searchText).font(.system(size: 13))
                }
                .padding(10).background(Color.white).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

                List {
                    ForEach(filteredCodes) { code in
                        Button(action: { selectedCode = code.code; isPresented = false }) {
                            HStack {
                                Text(code.flag).font(.system(size: 18))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(code.name).font(.system(size: 14)).foregroundColor(.primary)
                                    Text(code.code).font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                if code.code == selectedCode {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.goldDark)
                                }
                            }.padding(.vertical, 2)
                        }
                    }
                }.listStyle(GroupedListStyle())
            }
            .navigationBarTitle(Text("Country Code"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { isPresented = false }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark))
        }
    }
}

// MARK: - Vendor Search Field (text field with inline vendor list)

struct VendorSearchField: View {
    @Binding var vendorId: String
    let vendors: [Vendor]

    @State private var searchText = ""
    @State private var isEditing = false

    private var selectedVendor: Vendor? { vendors.first { $0.id == vendorId } }

    private var filteredVendors: [Vendor] {
        guard isEditing else { return [] }
        if searchText.isEmpty { return vendors }
        let q = searchText.lowercased()
        return vendors.filter {
            $0.name.lowercased().contains(q) || $0.email.lowercased().contains(q) || $0.contactPerson.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundColor(.gray)
                if isEditing || vendorId.isEmpty {
                    TextField("Search by name, email, or contact...", text: $searchText, onEditingChanged: { editing in
                        isEditing = editing
                    })
                    .font(.system(size: 13))
                } else {
                    Text(selectedVendor?.name ?? "").font(.system(size: 13)).foregroundColor(.primary).lineLimit(1)
                    Spacer()
                    Button(action: { vendorId = ""; searchText = ""; isEditing = true }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundColor(.gray.opacity(0.5))
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(Color.white).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isEditing ? Color.goldDark : Color.borderColor, lineWidth: isEditing ? 1.5 : 1))
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditing && !vendorId.isEmpty {
                    vendorId = ""; searchText = ""; isEditing = true
                }
            }

            // Inline vendor list (shows all when empty, filtered when typing)
            if !filteredVendors.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredVendors, id: \.id) { vendor in
                            Button(action: {
                                vendorId = vendor.id; searchText = ""; isEditing = false
                                #if canImport(UIKit)
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                #endif
                            }) {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(vendor.name).font(.system(size: 13, weight: .medium)).foregroundColor(.primary).lineLimit(1)
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
                                    Spacer()
                                    if vendor.id == vendorId {
                                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.goldDark)
                                    }
                                }
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            if vendor.id != filteredVendors.last?.id { Divider().padding(.horizontal, 8) }
                        }
                    }
                }
                .frame(maxHeight: 220)
                .background(Color.white).cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .padding(.top, 4)
            }
        }
    }
}
