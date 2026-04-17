import SwiftUI

struct POFormView: View {
    @EnvironmentObject var appState: POViewModel
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
    // Start with NO line items. The summary card shows an "Add Line Items"
    // button until the user adds their first item on the Line Items page.
    // Previously initialised with `[LineItem()]`, which surfaced as an
    // "Untitled Item" row on a fresh create-PO form.
    @State private var lineItems: [LineItem] = []

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

    @State private var showTemplateNameSheet = false
    @State private var templateName = ""
    @State private var showLineItemsPage = false
    @State private var showAttachSheet = false
    @State private var showCountryPicker = false  // delivery address country picker
    @State private var showSaveSheet = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var didLoad = false
    @State private var showErrors = false

    var isEdit: Bool { editingPO != nil }

    private var hasValidLineItem: Bool {
        lineItems.contains { !($0.description ?? "").trimmingCharacters(in: .whitespaces).isEmpty && ($0.quantity ?? 0) > 0 && ($0.unitPrice ?? 0) > 0 }
    }

    private var canSubmit: Bool {
        !vendorId.isEmpty && hasValidLineItem && !appState.formSubmitting
    }

    // ── Template-driven validation (matches web client) ──
    private func getVisibleFields(_ sectionKey: String) -> [FormField] {
        guard let sections = sortedSections,
              let sec = sections.first(where: { ($0.key ?? "") == sectionKey }) else { return [] }
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
                case "vat": break // VAT is now per line item
                case "description": if desc.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Description is required") }
                case "delivery_date": if !hasDelDate { errors.append("Delivery Date is required") }
                case "effective_date": break // hidden from users
                case "notes": if notes.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Notes is required") }
                case "account_code": if nominalCode.isEmpty { errors.append("Nominal Code is required") }
                default: break
                }
            } else {
                // Custom field — key matches customFieldView: "sectionKey_fieldName"
                let key = "po_details_\(field.name ?? "")"
                let val = customFieldValues[key] ?? ""
                if val.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append("\(field.name ?? "") is required")
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
                    errors.append("\(field.name ?? "") is required")
                }
            } else {
                // Custom field — key matches customFieldView: "sectionKey_fieldName"
                let key = "delivery_address_\(field.name ?? "")"
                let val = customFieldValues[key] ?? ""
                if val.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append("\(field.name ?? "") is required")
                }
            }
        }

        // Custom sections — check required custom fields
        if let sections = sortedSections {
            let knownSections: Set<String> = ["po_details", "delivery_address", "line_items", "terms_of_engagement"]
            for section in sections where !knownSections.contains(section.key ?? "") {
                for field in section.visibleFields {
                    guard field.isRequired else { continue }
                    let key = "\(section.key ?? "")_\(field.name ?? "")"
                    let val = customFieldValues[key] ?? ""
                    if val.trimmingCharacters(in: .whitespaces).isEmpty {
                        errors.append("\(field.name ?? "") is required")
                    }
                }
            }
        }

        // Line items — at least one with description
        if lineItems.allSatisfy({ ($0.description ?? "").trimmingCharacters(in: .whitespaces).isEmpty }) {
            errors.append("At least one line item with a description is required")
        }

        // Line item field validation
        let lineFields = getVisibleFields("line_items")
        let liSysLabels: Set<String> = ["line_description", "line_quantity", "line_unit_price", "account_code", "department", "exp_type", "vat", "tax_type", "tax_rate"]
        for (idx, li) in lineItems.enumerated() {
            guard !( li.description ?? "").trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            for field in lineFields {
                guard field.isRequired else { continue }
                let label = field.label ?? ""
                if liSysLabels.contains(label) {
                    switch label {
                    case "line_description":
                        if (li.description ?? "").trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Line \(idx + 1): Description is required") }
                    case "line_quantity":
                        if (li.quantity ?? 0) <= 0 { errors.append("Line \(idx + 1): Quantity must be > 0") }
                    case "line_unit_price":
                        if (li.unitPrice ?? 0) < 0 { errors.append("Line \(idx + 1): Unit Price is required") }
                    case "exp_type":
                        if (li.expenditureType ?? "").trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Line \(idx + 1): Expenditure Type is required") }
                    case "vat", "tax_type":
                        let vatVal = lineItemCustomValues[li.id]?["vat"] ?? ""
                        if vatVal.isEmpty { errors.append("Line \(idx + 1): VAT Treatment is required") }
                    case "tax_rate": break // auto-derived from VAT treatment
                    default: break
                    }
                } else {
                    let key = label.isEmpty ? (field.name ?? "") : label
                    let val = (lineItemCustomValues[li.id]?[key]) ?? ""
                    if val.trimmingCharacters(in: .whitespaces).isEmpty {
                        errors.append("Line \(idx + 1): \(field.name ?? "") is required")
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
        appState.formTemplate?.template?.sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }

    var body: some View {
        ZStack {
            List {
                if let sections = sortedSections {
                    ForEach(sections, id: \.id) { section in
                        self.formSection(for: section)
                    }
                    // If template has no terms_of_engagement section, show Summary after all sections
                    if !sections.contains(where: { ($0.key ?? "") == "terms_of_engagement" }) {
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
            .onAppear {
                if !didLoad {
                    loadData()
                    didLoad = true
                }
            }
            .sheet(isPresented: $showTemplateNameSheet) {
                TemplateNameSheet(templateName: $templateName, isPresented: $showTemplateNameSheet) { saveTemplate() }
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryNamePickerSheet(selectedName: $daCountry, isPresented: $showCountryPicker)
            }

            // Hidden NavigationLink for Line Items page
            NavigationLink(
                destination: LineItemsPage(
                    lineItems: $lineItems,
                    lineItemCustomValues: $lineItemCustomValues,
                    formFields: lineItemFields,
                    currency: currency,
                    defaultDepartment: departmentId,
                    defaultAccount: nominalCode
                ).environmentObject(appState),
                isActive: $showLineItemsPage
            ) { EmptyView() }
            .hidden()

            // Full-screen blocking loader while the submit request is in
            // flight. Semi-opaque backdrop + centred spinner makes it
            // clear the app is working and prevents any stray taps on
            // the form fields behind it. Only shown for the Submit path;
            // Save as Draft / Save as Template rely on the inline Save
            // button spinner since they're lightweight and stay on the
            // same page on success.
            if appState.formSubmitting {
                Color.black.opacity(0.35)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                VStack(spacing: 12) {
                    ActivityIndicator(isAnimating: true).frame(width: 28, height: 28)
                    Text(isEdit ? "Updating & Submitting…" : "Submitting PO…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 22).padding(.vertical, 18)
                .background(Color.bgSurface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: appState.formSubmitting)
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
        let sectionKey = section.key ?? ""
        if sectionKey == "po_details" {
            poDetailsSection(section)
        } else if sectionKey == "delivery_address" {
            deliveryAddressSection(section)
        } else if sectionKey == "line_items" {
            lineItemsSection(section)
        } else if sectionKey == "terms_of_engagement" {
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
        Section(header: sectionHeader(icon: "doc.text", title: (section.label ?? "").uppercased())) {
            VStack(spacing: 14) {
                // Group fields so `currency` + `delivery_date` render
                // together on one row (50/50). Every other field keeps
                // its own row.
                let rows = poDetailRows(from: section.visibleFields)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    if row.count == 2 {
                        HStack(alignment: .top, spacing: 10) {
                            self.poDetailFieldView(row[0]).frame(maxWidth: .infinity)
                            self.poDetailFieldView(row[1]).frame(maxWidth: .infinity)
                        }
                    } else {
                        self.poDetailFieldView(row[0])
                    }
                }
            }
        }
    }

    /// Pairs the `currency` and `delivery_date` fields into the same
    /// row (currency on the left, delivery date on the right) so the
    /// two narrow inputs sit side-by-side instead of taking a full row
    /// each. If one of them is missing from the template, the other
    /// falls back to rendering solo on its own row.
    private func poDetailRows(from fields: [FormField]) -> [[FormField]] {
        let currencyField = fields.first { $0.label == "currency" }
        let deliveryField = fields.first { $0.label == "delivery_date" }

        // No pairing needed unless both fields are present.
        guard let c = currencyField, let d = deliveryField else {
            return fields.map { [$0] }
        }

        var rows: [[FormField]] = []
        var skipDeliveryOnce = false
        for field in fields {
            if field.id == c.id {
                rows.append([c, d])         // paired row
                skipDeliveryOnce = true
            } else if field.id == d.id && skipDeliveryOnce {
                continue                     // already paired above
            } else {
                rows.append([field])
            }
        }
        return rows
    }

    @ViewBuilder
    private func poDetailFieldView(_ field: FormField) -> some View {
        if field.label == "vendor" {
            let hasErr = field.isRequired && pickerHasError(vendorId)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    Text((field.name ?? "").uppercased())
                        .font(.system(size: 9, weight: .bold)).tracking(0.3)
                        .foregroundColor(hasErr ? .red : Color.secondary)
                        .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                }
                VendorSearchField(vendorId: $vendorId, vendors: appState.vendors, hasError: hasErr)
                if hasErr { Text("Vendor is required").font(.system(size: 10)).foregroundColor(.red) }
            }
        } else if field.label == "vendor_address" {
            FieldGroup(label: (field.name ?? "").uppercased()) {
                Text(vendorAddressText)
                    .font(.system(size: 13))
                    .foregroundColor(vendorId.isEmpty ? .gray : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color.bgRaised)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        } else if field.label == "department" {
            errorWrappedPicker(label: (field.name ?? "").uppercased(), value: departmentId, required: field.isRequired) {
                PickerField(selection: departmentBinding, placeholder: "Select department...",
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier ?? "", $0.displayName) })
            }
        } else if field.label == "account_code" {
            errorWrappedPicker(label: (field.name ?? "").uppercased(), value: nominalCode, required: field.isRequired) {
                PickerField(selection: nominalCodeBinding, placeholder: "Select nominal code...",
                    options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
            }
        } else if field.label == "description" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: $desc, placeholder: "e.g. Studio hire — Stage G, 12 weeks", required: field.isRequired)
        } else if field.label == "currency" {
            errorWrappedPicker(label: (field.name ?? "").uppercased(), value: currency, required: field.isRequired) {
                PickerField(selection: $currency, placeholder: "Select currency...",
                    options: [DropdownOption("GBP", "GBP — British Pound"),
                              DropdownOption("USD", "USD — US Dollar"),
                              DropdownOption("EUR", "EUR — Euro")])
            }
        } else if field.label == "vat" {
            // VAT is now per line item — skip in PO details
            EmptyView()
        } else if field.label == "delivery_date" {
            let hasErr = field.isRequired && showErrors && !hasDelDate
            VStack(alignment: .leading, spacing: 4) {
                FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
                    dateFieldContent(hasDate: $hasDelDate, date: $deliveryDate)
                }
                if hasErr { Text("\(field.name ?? "") is required").font(.system(size: 10)).foregroundColor(.red) }
            }
        } else if field.label == "effective_date" {
            // Effective date is hidden from users
            EmptyView()
        } else if field.label == "notes" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: $notes, placeholder: "Internal notes...", required: field.isRequired)
        } else if !poSystemLabels.contains(field.label ?? "") {
            customFieldView(sectionKey: "po_details", field: field)
        }
    }

    // MARK: - Error-wrapped field helpers

    @ViewBuilder
    private func errorWrappedInput(label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default, required: Bool) -> some View {
        let hasErr = required && fieldHasError(text.wrappedValue)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .bold)).tracking(0.3)
                    .foregroundColor(hasErr ? .red : Color.secondary)
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                if !required {
                    Text("(optional)").font(.system(size: 8)).foregroundColor(.gray).italic().lineLimit(1)
                }
            }
            TextField(placeholder, text: text)
                .font(.system(size: 13)).keyboardType(keyboard)
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Color.bgSurface).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(hasErr ? Color.red : Color.borderColor, lineWidth: 1))
            if hasErr {
                Text("\(label.lowercased().capitalizingFirst()) is required").font(.system(size: 10)).foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private func errorWrappedPicker<Content: View>(label: String, value: String, required: Bool, @ViewBuilder content: @escaping () -> Content) -> some View {
        let hasErr = required && pickerHasError(value)
        VStack(alignment: .leading, spacing: 4) {
            FieldGroup(label: label, optional: !required) {
                content()
            }
            if hasErr {
                Text("\(label.lowercased().capitalizingFirst()) is required").font(.system(size: 10)).foregroundColor(.red)
            }
        }
    }

    /// Country picker field — visually matches `errorWrappedInput` but
    /// taps open the `CountryNamePickerSheet` instead of a keyboard. The
    /// selected name is shown inline with a flag when possible.
    @ViewBuilder
    private func countryPickerField(label: String, required: Bool) -> some View {
        let hasErr = required && fieldHasError(daCountry)
        let flag: String = {
            countryCodes.first { $0.name.lowercased() == daCountry.lowercased() }?.flag ?? ""
        }()
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .bold)).tracking(0.3)
                    .foregroundColor(hasErr ? .red : Color.secondary)
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                if !required {
                    Text("(optional)").font(.system(size: 8)).foregroundColor(.gray).italic().lineLimit(1)
                }
            }
            Button(action: { showCountryPicker = true }) {
                HStack(spacing: 6) {
                    if !flag.isEmpty { Text(flag).font(.system(size: 14)) }
                    Text(daCountry.isEmpty ? "Select country" : daCountry)
                        .font(.system(size: 13))
                        .foregroundColor(daCountry.isEmpty ? .gray : .primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Color.bgSurface).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(hasErr ? Color.red : Color.borderColor, lineWidth: 1))
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())
            if hasErr {
                Text("\(label.lowercased().capitalizingFirst()) is required").font(.system(size: 10)).foregroundColor(.red)
            }
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
        Section(header: sectionHeader(icon: "shippingbox", title: (section.label ?? "").uppercased())) {
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
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: $daName, placeholder: "Recipient name...", required: field.isRequired)
        } else if field.label == "delivery_email" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: $daEmail, placeholder: "email@example.com", keyboard: .emailAddress, required: field.isRequired)
        } else if field.label == "delivery_phone_code" {
            EmptyView()
        } else if field.label == "delivery_phone" {
            let hasErr = field.isRequired && fieldHasError(daPhone)
            VStack(alignment: .leading, spacing: 4) {
                FieldGroup(label: "PHONE", optional: !field.isRequired) {
                    PhoneField(phoneCode: $daPhoneCode, phone: $daPhone)
                }
                if hasErr { Text("Phone is required").font(.system(size: 10)).foregroundColor(.red) }
            }
        } else if field.label == "delivery_line1" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: $daLine1, placeholder: "Street address...", required: field.isRequired)
        } else if field.label == "delivery_line2" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: $daLine2, placeholder: "Suite, unit, building...", required: field.isRequired)
        } else if field.label == "delivery_city" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: $daCity, placeholder: "City...", required: field.isRequired)
        } else if field.label == "delivery_state" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: $daState, placeholder: "State / County...", required: field.isRequired)
        } else if field.label == "delivery_postal_code" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: $daPostal, placeholder: "Postal code...", required: field.isRequired)
        } else if field.label == "country" {
            // Tap-to-open picker instead of a free-text input. Uses the
            // same `countryCodes` catalogue the phone-code picker reads
            // from; presents `CountryNamePickerSheet` as a searchable
            // modal.
            countryPickerField(label: (field.name ?? "").uppercased(), required: field.isRequired)
        } else if !deliverySystemLabels.contains(field.label ?? "") {
            customFieldView(sectionKey: "delivery_address", field: field)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Line Items Section (dynamic)
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    private func lineItemsSection(_ section: FormSection) -> some View {
        Section(header: sectionHeader(icon: "list.bullet.rectangle", title: (section.label ?? "").uppercased())) {
            lineItemsSummaryCard
        }
    }

    @ViewBuilder
    private var lineItemsSummaryCard: some View {
        // Empty state — show just an "Add Line Items" button that pushes
        // the Line Items page. Avoids the previous behaviour of rendering
        // an "Untitled Item" placeholder card before the user has added
        // anything. The red border still surfaces the validation error
        // on submit if no items have been added.
        if lineItems.isEmpty {
            Button(action: {
                // Seed the first line item with the form-level defaults
                // (account / department) so the destination Line Items
                // page opens with one row ready to edit — saves the user
                // a tap on "+ Add Line Item" after landing there.
                lineItems.append(LineItem(account: nominalCode, department: departmentId))
                showLineItemsPage = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 14))
                    Text("Add Line Items").font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.goldDark)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.gold.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                    showErrors && !hasValidLineItem ? Color.red : Color.goldDark.opacity(0.3),
                    lineWidth: 1))
                .cornerRadius(8)
            }.buttonStyle(BorderlessButtonStyle())
            if showErrors && !hasValidLineItem {
                Text("At least one line item with description, quantity, and unit price is required")
                    .font(.system(size: 10)).foregroundColor(.red)
            }
        } else {
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
                        Text(FormatUtils.formatCurrency(netTotal, code: currency)).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }
                .padding(12)
                .background(Color.bgBase)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                    showErrors && !hasValidLineItem ? Color.red : Color.goldDark.opacity(0.3), lineWidth: 1))
            }.buttonStyle(BorderlessButtonStyle())
            if showErrors && !hasValidLineItem {
                Text("At least one line item with description, quantity, and unit price is required")
                    .font(.system(size: 10)).foregroundColor(.red)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Terms of Engagement Section
    // ═══════════════════════════════════════════════════════════════════════

    @ViewBuilder
    private func termsSection(_ section: FormSection) -> some View {
        if let values = section.values, !values.isEmpty {
            Section(header: sectionHeader(icon: "doc.plaintext", title: (section.label ?? "").uppercased())) {
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
        Section(header: sectionHeader(icon: "square.grid.2x2", title: (section.label ?? "").uppercased())) {
            VStack(spacing: 14) {
                ForEach(section.visibleFields, id: \.id) { field in
                    self.customFieldView(sectionKey: section.key ?? "", field: field)
                }
            }
        }
    }

    @ViewBuilder
    private func customFieldView(sectionKey: String, field: FormField) -> some View {
        let key = "\(sectionKey)_\(field.name ?? "")"
        let binding = Binding<String>(
            get: { self.customFieldValues[key] ?? "" },
            set: { self.customFieldValues[key] = $0 }
        )
        let _ = field.isRequired && customFieldHasError(sectionKey: sectionKey, fieldName: field.name ?? "")
        if field.type == "select" {
            // Handle selection_type for known option sets (matches web client)
            if field.selectionType == "vendor" {
                errorWrappedPicker(label: (field.name ?? "").uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select...",
                        options: appState.vendors.map { DropdownOption($0.id, $0.name ?? "") })
                }
            } else if field.selectionType == "department" {
                errorWrappedPicker(label: (field.name ?? "").uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select department...",
                        options: DepartmentsData.sorted.map { DropdownOption($0.identifier ?? "", $0.displayName) })
                }
            } else if field.selectionType == "currency" {
                errorWrappedPicker(label: (field.name ?? "").uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select currency...",
                        options: [DropdownOption("GBP", "GBP — British Pound"),
                                  DropdownOption("USD", "USD — US Dollar"),
                                  DropdownOption("EUR", "EUR — Euro")])
                }
            } else if field.selectionType == "vat" {
                errorWrappedPicker(label: (field.name ?? "").uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select VAT...",
                        options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
                }
            } else if field.selectionType == "account_code" {
                errorWrappedPicker(label: (field.name ?? "").uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select account...",
                        options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
                }
            } else if field.selectionType == "exp_type" {
                errorWrappedPicker(label: (field.name ?? "").uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select type...",
                        options: expenditureTypes.map { DropdownOption($0, $0) })
                }
            } else {
                errorWrappedInput(label: (field.name ?? "").uppercased(), text: binding, placeholder: "Enter \((field.name ?? "").lowercased())...", required: field.isRequired)
            }
        } else if field.type == "date" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: binding, placeholder: "dd/mm/yyyy", required: field.isRequired)
        } else if field.type == "number" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: binding, placeholder: "0", keyboard: .decimalPad, required: field.isRequired)
        } else if field.type == "email" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: binding, placeholder: "email@example.com", keyboard: .emailAddress, required: field.isRequired)
        } else if field.type == "phone" {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: binding, placeholder: "Phone number", keyboard: .phonePad, required: field.isRequired)
        } else {
            errorWrappedInput(label: (field.name ?? "").uppercased(), text: binding, placeholder: "Enter \((field.name ?? "").lowercased())...", required: field.isRequired)
        }
    }

    // Line item custom field
    @ViewBuilder
    private func lineItemCustomFieldView(itemId: String, field: FormField) -> some View {
        let binding = Binding<String>(
            get: { self.lineItemCustomValues[itemId]?[field.name ?? ""] ?? "" },
            set: { val in
                if self.lineItemCustomValues[itemId] == nil { self.lineItemCustomValues[itemId] = [:] }
                self.lineItemCustomValues[itemId]?[field.name ?? ""] = val
            }
        )
        FieldGroup(label: (field.name ?? "").uppercased(), optional: !field.isRequired) {
            InputField(text: binding, placeholder: "Enter \((field.name ?? "").lowercased())...")
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

    /// Aggregate VAT across all line items based on per-item vatTreatment
    private var lineItemVATSummary: (totalVat: Double, grossTotal: Double, hasVat: Bool) {
        var totalVat = 0.0
        var grossTotal = 0.0
        for item in lineItems {
            let itemNet = (item.quantity ?? 0) * (item.unitPrice ?? 0)
            let treatment = lineItemCustomValues[item.id]?["vat"] ?? "pending"
            let result = VATHelpers.calcVat(itemNet, treatment: treatment)
            totalVat += result.vatAmount
            grossTotal += result.gross
        }
        let hasVat = lineItems.contains { (lineItemCustomValues[$0.id]?["vat"] ?? "pending") != "pending" }
        return (totalVat, grossTotal, hasVat)
    }

    private var summaryContent: some View {
        let vatSummary = lineItemVATSummary
        return VStack(spacing: 8) {
            HStack {
                Text("Net Amount").font(.system(size: 14)).foregroundColor(.secondary)
                Spacer()
                Text(FormatUtils.formatCurrency(netTotal, code: currency)).font(.system(size: 15, design: .monospaced))
            }
            if vatSummary.hasVat {
                HStack {
                    Text("VAT").font(.system(size: 14)).foregroundColor(.secondary)
                    Spacer()
                    Text(FormatUtils.formatCurrency(vatSummary.totalVat, code: currency)).font(.system(size: 14, design: .monospaced)).foregroundColor(.secondary)
                }
            }
            Divider()
            HStack {
                Text("Gross Total").font(.system(size: 16, weight: .bold))
                Spacer()
                Text(FormatUtils.formatCurrency(vatSummary.grossTotal, code: currency)).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
            }
        }
    }

    private var actionsContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Attach button (outlined)
                HStack(spacing: 6) {
                    Image(systemName: "paperclip").font(.system(size: 13))
                    Text("Attach").font(.system(size: 13, weight: .semibold))
                }.foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.bgSurface).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture { showAttachSheet = true }
                .appActionSheet(title: "Attach", isPresented: $showAttachSheet, items: [
                    .action("Quote") { /* TODO: attach quote */ },
                    .action("Email") { /* TODO: attach email */ },
                    .action("Attachment") { /* TODO: attach file */ }
                ])

                // Save button (gold, dropdown) — reads the save-specific
                // `formSaving` flag so tapping Submit doesn't spin this
                // button too. Disabled + swapped for a spinner while a
                // Save as Draft / Save as Template round-trip is in
                // flight.
                HStack(spacing: 6) {
                    if appState.formSaving {
                        ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                        Text("Saving…").font(.system(size: 13, weight: .semibold))
                    } else {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 13))
                        Text("Save").font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                }.foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(appState.formSaving ? Color.gold.opacity(0.6) : Color.gold)
                .cornerRadius(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Block opening the save sheet mid-flight — prevents
                    // double taps that would fire a second request. Also
                    // block while the main Submit is in flight.
                    guard !appState.formSaving && !appState.formSubmitting else { return }
                    showSaveSheet = true
                }
                .appActionSheet(title: "Save Options", isPresented: $showSaveSheet, items: saveSheetItems)
            }

            // Submit PO button (full width, dark gold)
            HStack(spacing: 6) {
                Text(isEdit ? "Update & Submit PO" : "Submit PO").font(.system(size: 14, weight: .bold))
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
            }.foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(canSubmit ? Color.gold : Color.gold.opacity(0.4)).cornerRadius(8)
            .contentShape(Rectangle())
            .onTapGesture { if !appState.formSubmitting { validateAndSubmit() } }
            .opacity(appState.formSubmitting ? 0.5 : 1.0)
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
        let addr = v.address?.formatted ?? ""
        return addr.isEmpty ? "No address on file" : addr
    }

    private var netTotal: Double {
        lineItems.reduce(0) { $0 + (($1.quantity ?? 0) * ($1.unitPrice ?? 0)) }
    }

    private var decimalFormatter: NumberFormatter {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.minimumFractionDigits = 2; f.maximumFractionDigits = 2; return f
    }

    // MARK: - Save sheet buttons
    private var saveSheetItems: [AppActionSheetItem] {
        if resumeDraft != nil {
            // Resuming a draft — Save updates existing, Save as Draft creates new
            return [
                .action("Save") { self.saveCurrentDraft() },
                .action("Save as New Draft") { self.saveAsNewDraft() },
                .action("Save as Template") { self.templateName = self.desc; self.showTemplateNameSheet = true }
            ]
        } else if editingPO != nil {
            // Editing an existing PO — Save as Draft creates a copy as draft
            return [
                .action("Save as Draft") { self.saveAsNewDraft() },
                .action("Save as Template") { self.templateName = self.desc; self.showTemplateNameSheet = true }
            ]
        } else {
            // New PO — Save as Draft creates new
            return [
                .action("Save as Draft") { self.saveAsNewDraft() },
                .action("Save as Template") { self.templateName = self.desc; self.showTemplateNameSheet = true }
            ]
        }
    }

    // MARK: - Nominal Code → Department auto-sync binding
    private var nominalCodeBinding: Binding<String> {
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
    private var departmentBinding: Binding<String> {
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

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Load Data
    // ═══════════════════════════════════════════════════════════════════════

    private func loadData() {
        if let u = appState.currentUser {
            departmentId = u.departmentIdentifier ?? ""
            nominalCode = NominalCodes.deptToNominal[u.departmentIdentifier ?? ""] ?? ""
            // Auto-populate initial line item with user's department and nominal code
            for i in lineItems.indices {
                if (lineItems[i].department ?? "").isEmpty { lineItems[i].department = departmentId }
                if (lineItems[i].account ?? "").isEmpty { lineItems[i].account = nominalCode }
            }
        }
        if let vid = prefilledVendorId ?? appState.prefilledVendorId, !vid.isEmpty {
            vendorId = vid
            appState.prefilledVendorId = nil
        }
        if let po = editingPO ?? resumeDraft {
            vendorId = po.vendorId ?? ""
            // Resolve department ID to identifier for picker matching
            let rawDeptId = po.departmentId ?? ""
            if let dept = DepartmentsData.all.first(where: { $0.id == rawDeptId || $0.identifier == rawDeptId }) {
                departmentId = dept.identifier ?? ""
            } else if !rawDeptId.isEmpty {
                departmentId = rawDeptId
            }
            nominalCode = po.nominalCode ?? ""
            // Auto-set nominal code from department if not set
            if nominalCode.isEmpty { nominalCode = NominalCodes.deptToNominal[departmentId] ?? "" }
            desc = po.description ?? ""
            currency = po.currency ?? "GBP"; notes = po.notes ?? ""
            var items = (po.lineItems ?? []).isEmpty ? [LineItem(account: nominalCode, department: departmentId)] : po.lineItems ?? []
            // Resolve line item department IDs to identifiers and auto-set account codes
            for i in items.indices {
                let rawDept = items[i].department ?? ""
                if let dept = DepartmentsData.all.first(where: { $0.id == rawDept || $0.identifier == rawDept }) {
                    items[i].department = dept.identifier
                }
                if (items[i].account ?? "").isEmpty {
                    items[i].account = NominalCodes.deptToNominal[items[i].department ?? ""] ?? nominalCode
                }
            }
            lineItems = items
            // Populate per-line-item custom fields and VAT
            for item in items {
                if lineItemCustomValues[item.id] == nil { lineItemCustomValues[item.id] = [:] }
                // Load custom fields from line item
                for cf in item.customFields ?? [] {
                    lineItemCustomValues[item.id]?[cf.name ?? ""] = cf.value
                }
                // Set VAT: prefer line item's own vatTreatment, then PO-level, then "pending"
                let vatValue: String
                if (item.vatTreatment ?? "pending") != "pending" {
                    vatValue = item.vatTreatment ?? "pending"
                } else if (po.vatTreatment ?? "pending") != "pending" {
                    vatValue = po.vatTreatment ?? "pending"
                } else {
                    vatValue = "pending"
                }
                lineItemCustomValues[item.id]?["vat"] = vatValue
            }
            if let ms = po.effectiveDate, ms > 0 { effectiveDate = Date(timeIntervalSince1970: Double(ms)/1000); hasEffDate = true }
            if let ms = po.deliveryDate, ms > 0 { deliveryDate = Date(timeIntervalSince1970: Double(ms)/1000); hasDelDate = true }
            if let da = po.deliveryAddress {
                daName = da.name ?? ""; daEmail = da.email ?? ""; daPhone = da.phone ?? ""
                daLine1 = da.line1 ?? ""; daLine2 = da.line2 ?? ""; daCity = da.city ?? ""
                daState = da.state ?? ""; daPostal = da.postalCode ?? ""; daCountry = da.country ?? ""
            }
            // Load custom field values from PO
            for section in po.customFields ?? [] {
                let secKey = section.section ?? "custom"
                for field in section.fields ?? [] {
                    customFieldValues["\(secKey)_\(field.name ?? "")"] = field.value
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Form Actions
    // ═══════════════════════════════════════════════════════════════════════

    private func buildForm() -> POFormData {
        // Debug: log lineItemCustomValues before building
        print("🔧 buildForm: lineItemCustomValues keys=\(lineItemCustomValues.keys.map { String($0.prefix(8)) })")
        for (id, vals) in lineItemCustomValues {
            print("  🔧 LI \(id.prefix(8)): \(vals)")
        }
        for i in lineItems.indices {
            lineItems[i].total = (lineItems[i].quantity ?? 0) * (lineItems[i].unitPrice ?? 0)
            let vatFromCustom = lineItemCustomValues[lineItems[i].id]?["vat"]
            lineItems[i].vatTreatment = vatFromCustom ?? lineItems[i].vatTreatment
            print("  🔧 LI[\(i)] id=\(lineItems[i].id.prefix(8)) vatFromCustom=\(vatFromCustom ?? "nil") final=\(lineItems[i].vatTreatment ?? "nil")")
        }
        let da = DeliveryAddress(name: daName, email: daEmail, phoneCode: daPhoneCode, phone: daPhone,
                                  line1: daLine1, line2: daLine2, city: daCity,
                                  state: daState, postalCode: daPostal, country: daCountry)
        let hasDA = ![daName, daEmail, daPhone, daLine1, daCity].allSatisfy { $0.isEmpty }
        // Derive PO-level vatTreatment from line items (use first non-pending, or "pending")
        let derivedVat = lineItems.compactMap { lineItemCustomValues[$0.id]?["vat"] ?? ((($0.vatTreatment ?? "pending") != "pending") ? $0.vatTreatment : nil) }.first(where: { $0 != "pending" }) ?? "pending"
        return POFormData(vendorId: vendorId, departmentId: departmentId, nominalCode: nominalCode,
                          description: desc, currency: currency, vatTreatment: derivedVat,
                          effectiveDate: hasEffDate ? effectiveDate : nil,
                          deliveryDate: hasDelDate ? deliveryDate : nil,
                          notes: notes, lineItems: lineItems,
                          existingDraftId: (editingPO ?? resumeDraft)?.id,
                          deliveryAddress: hasDA ? da : nil,
                          customFieldValues: customFieldValues,
                          lineItemCustomValues: lineItemCustomValues)
    }

    /// Returns true when showErrors is active and the given value is empty
    private func fieldHasError(_ value: String) -> Bool {
        showErrors && value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Returns true when showErrors is active and the given picker/selection value is empty
    private func pickerHasError(_ value: String) -> Bool {
        showErrors && value.isEmpty
    }

    /// Returns true when showErrors is active and a custom field value is empty
    private func customFieldHasError(sectionKey: String, fieldName: String) -> Bool {
        showErrors && (customFieldValues["\(sectionKey)_\(fieldName)"] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func validateAndSubmit() {
        let errors = validate()
        if !errors.isEmpty {
            showErrors = true
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
                PickerField(selection: departmentBinding, placeholder: "Select department...",

                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier ?? "", $0.displayName) })
            }
            FieldGroup(label: "NOMINAL CODE") {
                PickerField(selection: nominalCodeBinding, placeholder: "Select nominal code...",
                    options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
            }
            FieldGroup(label: "DESCRIPTION", optional: true) { InputField(text: $desc, placeholder: "e.g. Studio hire — Stage G, 12 weeks") }
            // Currency + Delivery Date on one row (50/50 split) so
            // two narrow fields don't each take a full line.
            HStack(alignment: .top, spacing: 10) {
                FieldGroup(label: "CURRENCY") {
                    PickerField(selection: $currency, placeholder: "Select currency...",
                        options: [DropdownOption("GBP", "GBP — British Pound"),
                                  DropdownOption("USD", "USD — US Dollar"),
                                  DropdownOption("EUR", "EUR — Euro")])
                }
                .frame(maxWidth: .infinity)
                FieldGroup(label: "DELIVERY DATE") {
                    dateFieldContent(hasDate: $hasDelDate, date: $deliveryDate)
                }
                .frame(maxWidth: .infinity)
            }
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

// MARK: - String Extension

extension String {
    func capitalizingFirst() -> String {
        prefix(1).uppercased() + dropFirst()
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
