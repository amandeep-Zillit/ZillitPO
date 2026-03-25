import SwiftUI

enum DeleteAlertType: Identifiable {
    case po(PurchaseOrder)
    case template(String)
    case draft(String)
    case vendor(String)
    var id: String {
        switch self {
        case .po(let p): return "po-\(p.id)"
        case .template(let id): return "tpl-\(id)"
        case .draft(let id): return "dft-\(id)"
        case .vendor(let id): return "vnd-\(id)"
        }
    }
}

struct DepartmentPOModule: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToForm = false
    @State private var navigateToDraftsTemplates = false
    @State private var activeDeleteAlert: DeleteAlertType?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Pinned tab bar
                tabBar.padding(.horizontal, 16).padding(.top, 12)
                    .background(Color.bgBase)

                // Pinned filters & search bar (above scroll)
                pinnedContent
                    .padding(.horizontal, 16).padding(.top, 10)
                    .background(Color.bgBase)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        scrollableContent
                    }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 80)
                }
            }

            // Floating Create PO button
            Button(action: {
                appState.editingPO = nil
                appState.resumeDraft = nil
                navigateToForm = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Create PO").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.gold)
                .cornerRadius(28)
                .shadow(color: Color.gold.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)

        }
        .background(
            VStack {
                NavigationLink(
                    destination: POFormPage().environmentObject(appState),
                    isActive: $navigateToForm
                ) { EmptyView() }

                NavigationLink(
                    destination: DraftsTemplatesPage().environmentObject(appState),
                    isActive: $navigateToDraftsTemplates
                ) { EmptyView() }
            }.frame(width: 0, height: 0).hidden()
        )
        .navigationBarTitle(Text("Purchase Orders"), displayMode: .inline)
        .sheet(isPresented: $appState.showRejectSheet) { RejectSheetView().environmentObject(appState) }
        .alert(isPresented: .init(get: { activeDeleteAlert != nil }, set: { if !$0 { activeDeleteAlert = nil } })) {
            switch activeDeleteAlert {
            case .po(let po):
                return Alert(title: Text("Delete PO?"), message: Text("This cannot be undone."),
                      primaryButton: .destructive(Text("Delete")) { appState.deletePO(po) },
                      secondaryButton: .cancel())
            case .template(let id):
                return Alert(title: Text("Delete Template?"), message: Text("This cannot be undone."),
                      primaryButton: .destructive(Text("Delete")) { appState.deleteTemplate(id) },
                      secondaryButton: .cancel())
            case .draft(let id):
                return Alert(title: Text("Delete Draft?"), message: Text("This cannot be undone."),
                      primaryButton: .destructive(Text("Delete")) { appState.deleteDraft(id) },
                      secondaryButton: .cancel())
            case .vendor(let id):
                return Alert(title: Text("Delete Vendor?"), message: Text("This cannot be undone."),
                      primaryButton: .destructive(Text("Delete")) { appState.deleteVendor(id) },
                      secondaryButton: .cancel())
            case .none:
                return Alert(title: Text("Delete?"))
            }
        }
        .onReceive(appState.$deleteTarget) { po in
            if let po = po { activeDeleteAlert = .po(po); appState.deleteTarget = nil }
        }
        .onReceive(appState.$deleteTemplateId) { id in
            if let id = id { activeDeleteAlert = .template(id); appState.deleteTemplateId = nil }
        }
        .onReceive(appState.$deleteDraftId) { id in
            if let id = id { activeDeleteAlert = .draft(id); appState.deleteDraftId = nil }
        }
        .onReceive(appState.$deleteVendorId) { id in
            if let id = id { activeDeleteAlert = .vendor(id); appState.deleteVendorId = nil }
        }
        .onReceive(appState.$editingPO) { po in
            if po != nil { navigateToForm = true }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TRANSACTIONS").font(.system(size: 10, weight: .semibold)).foregroundColor(.goldDark)
            Text("Purchase Orders").font(.system(size: 26, weight: .bold))
            Text("Create, track, and manage purchase orders for your department.").font(.system(size: 13)).foregroundColor(.secondary)
        }
    }

    private var userInfo: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.gold.opacity(0.2)).frame(width: 30, height: 30)
                Text(appState.currentUser?.initials ?? "?").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(appState.currentUser?.fullName ?? "").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(appState.currentUser?.displayDesignation ?? "").font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Text(appState.currentUser?.displayDepartment ?? "").font(.system(size: 9, weight: .bold)).lineLimit(1)
                .foregroundColor(.blue).padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1)).cornerRadius(4)
        }.padding(10).background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach([DeptTab.all, .my, .department, .vendors], id: \.self) { tabButton($0) }
        }.overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)
    }

    private func tabButton(_ tab: DeptTab) -> some View {
        Button(action: { appState.activeTab = tab; appState.activeFilter = .all }) {
            HStack(spacing: 4) {
                Text(tab.rawValue).font(.system(size: 12, weight: appState.activeTab == tab ? .semibold : .regular)).lineLimit(1)
                if let count = appState.tabCounts[tab] {
                    Text("\(count)").font(.system(size: 9, design: .monospaced)).padding(.horizontal, 5).padding(.vertical, 2)
                        .background(appState.activeTab == tab ? Color.gold.opacity(0.2) : Color.bgRaised).cornerRadius(10)
                }
            }.foregroundColor(appState.activeTab == tab ? .goldDark : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .overlay(appState.activeTab == tab ? Rectangle().fill(Color.goldDark).frame(height: 2) : nil, alignment: .bottom)
        }.buttonStyle(BorderlessButtonStyle())
    }

    @ViewBuilder
    private var pinnedContent: some View {
        if appState.activeTab == .vendors {
            VendorsPinnedHeader()
        } else {
            QuickFiltersBar(onDraftsTemplatesTap: { navigateToDraftsTemplates = true })
        }
    }

    @ViewBuilder
    private var scrollableContent: some View {
        if appState.activeTab == .vendors {
            VendorsScrollableList()
        } else {
            if appState.isLoading && appState.purchaseOrders.isEmpty { LoaderView() }
            else { POStatsCards(); POTableView() }
        }
    }
}

// MARK: - Drafts / Templates Page (Navigation destination)

enum DraftsTemplatesTab: String, CaseIterable {
    case drafts = "Drafts"
    case templates = "Templates"
}

struct DraftsTemplatesPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var activeTab: DraftsTemplatesTab = .drafts
    @State private var navigateToForm = false
    @State private var navigateToEditTemplate = false
    @State private var navigateToCreateDraft = false
    @State private var navigateToCreateTemplate = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Tab bar
                HStack(spacing: 0) {
                    ForEach(DraftsTemplatesTab.allCases, id: \.self) { tab in
                        Button(action: { activeTab = tab }) {
                            VStack(spacing: 6) {
                                Text(tab.rawValue)
                                    .font(.system(size: 14, weight: activeTab == tab ? .semibold : .regular))
                                    .foregroundColor(activeTab == tab ? .goldDark : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .overlay(
                                activeTab == tab
                                    ? Rectangle().fill(Color.goldDark).frame(height: 2)
                                    : nil,
                                alignment: .bottom
                            )
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
                .background(Color.bgBase)
                .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if activeTab == .drafts {
                            PODraftsListView()
                        } else {
                            POTemplatesListView()
                        }
                    }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 80)
                }
            }

            // Floating Create button (only for Templates tab)
            if activeTab == .templates {
                Button(action: {
                    navigateToCreateTemplate = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text("Create Template").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.gold)
                    .cornerRadius(28)
                    .shadow(color: Color.gold.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }

        }
        .background(
            VStack {
                NavigationLink(
                    destination: POFormPage().environmentObject(appState),
                    isActive: $navigateToForm
                ) { EmptyView() }

                NavigationLink(
                    destination: POFormPage().environmentObject(appState),
                    isActive: $navigateToCreateDraft
                ) { EmptyView() }

                NavigationLink(
                    destination: EditTemplatePage(
                        template: appState.editingTemplate
                    ).environmentObject(appState),
                    isActive: $navigateToEditTemplate
                ) { EmptyView() }

                NavigationLink(
                    destination: CreateTemplatePage().environmentObject(appState),
                    isActive: $navigateToCreateTemplate
                ) { EmptyView() }
            }.frame(width: 0, height: 0).hidden()
        )
        .navigationBarTitle(Text("Drafts & Templates"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .onAppear {
            appState.loadDrafts()
            appState.loadTemplates()
        }
        .onReceive(appState.$resumeDraft) { draft in
            if draft != nil { navigateToForm = true }
        }
        .onReceive(appState.$editingTemplate) { tpl in
            if tpl != nil { navigateToEditTemplate = true }
        }
    }
}

// MARK: - Edit Template Page (Navigation destination)

struct EditTemplatePage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    var template: POTemplate?

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            EditTemplateFormView(
                template: template,
                onBack: { presentationMode.wrappedValue.dismiss() }
            )
        }
        .navigationBarTitle(Text("Edit Template"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .onDisappear {
            appState.editingTemplate = nil
        }
    }
}

// MARK: - Edit Template Form View

struct EditTemplateFormView: View {
    @EnvironmentObject var appState: POViewModel
    var template: POTemplate?
    var onBack: () -> Void

    @State private var templateName = ""
    @State private var vendorId = ""
    @State private var departmentId = ""
    @State private var nominalCode = ""
    @State private var desc = ""
    @State private var currency = "GBP"
    @State private var showLineItemsPage = false
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

    // Action sheet states
    @State private var showAttachSheet = false
    @State private var showSaveSheet = false
    @State private var showSaveAsNameSheet = false
    @State private var saveAsTemplateName = ""
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showErrors = false

    private func tplFieldHasError(_ value: String) -> Bool {
        showErrors && value.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private func tplPickerHasError(_ value: String) -> Bool {
        showErrors && value.isEmpty
    }
    private func tplCustomFieldHasError(sectionKey: String, fieldName: String) -> Bool {
        showErrors && (customFieldValues["\(sectionKey)_\(fieldName)"] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private func tplErrorWrappedInput(label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default, required: Bool) -> some View {
        let hasErr = required && tplFieldHasError(text.wrappedValue)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .bold)).tracking(0.3)
                    .foregroundColor(hasErr ? .red : Color(red: 0.45, green: 0.47, blue: 0.5))
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                if !required {
                    Text("(optional)").font(.system(size: 8)).foregroundColor(.gray).italic().lineLimit(1)
                }
            }
            TextField(placeholder, text: text)
                .font(.system(size: 13)).keyboardType(keyboard)
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Color.white).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(hasErr ? Color.red : Color.borderColor, lineWidth: 1))
            if hasErr {
                Text("\(label.lowercased().capitalizingFirst()) is required").font(.system(size: 10)).foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private func tplErrorWrappedPicker<Content: View>(label: String, value: String, required: Bool, @ViewBuilder content: @escaping () -> Content) -> some View {
        let hasErr = required && tplPickerHasError(value)
        VStack(alignment: .leading, spacing: 4) {
            FieldGroup(label: label, optional: !required) {
                content()
            }
            if hasErr {
                Text("\(label.lowercased().capitalizingFirst()) is required").font(.system(size: 10)).foregroundColor(.red)
            }
        }
    }

    private var hasValidLineItem: Bool {
        lineItems.contains { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty && $0.quantity > 0 && $0.unitPrice > 0 }
    }

    // ── Template-driven validation (matches web client) ──
    private func tplGetVisibleFields(_ sectionKey: String) -> [FormField] {
        guard let sections = sortedSections,
              let sec = sections.first(where: { $0.key == sectionKey }) else { return [] }
        return sec.visibleFields
    }

    private let tplPOValLabels: Set<String> = ["vendor", "vendor_address", "department", "account_code", "currency", "vat", "description", "delivery_date", "effective_date", "notes"]
    private let tplDeliveryValLabels: Set<String> = ["delivery_name", "delivery_email", "delivery_phone", "delivery_phone_code", "delivery_line1", "delivery_line2", "delivery_city", "delivery_state", "delivery_postal_code", "country"]
    private let tplLineValLabels: Set<String> = ["line_description", "line_quantity", "line_unit_price", "account_code", "department", "exp_type"]

    private func tplValidate() -> [String] {
        var errors: [String] = []

        let poFields = tplGetVisibleFields("po_details")
        for field in poFields {
            guard field.isRequired else { continue }
            let label = field.label ?? ""
            if tplPOValLabels.contains(label) {
                switch label {
                case "vendor": if vendorId.isEmpty { errors.append("Vendor is required") }
                case "department": if departmentId.isEmpty { errors.append("Department is required") }
                case "currency": if currency.isEmpty { errors.append("Currency is required") }
                case "vat": if vatTreatment.isEmpty { errors.append("VAT Treatment is required") }
                case "description": if desc.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Description is required") }
                case "delivery_date": if !hasDelDate { errors.append("Delivery Date is required") }
                case "effective_date": break // hidden from users
                case "notes": if notes.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Notes is required") }
                case "account_code": if nominalCode.isEmpty { errors.append("Nominal Code is required") }
                default: break
                }
            } else {
                // Custom field — key matches tplCustomFieldView: "sectionKey_fieldName"
                let key = "po_details_\(field.name)"
                let val = customFieldValues[key] ?? ""
                if val.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("\(field.name) is required") }
            }
        }

        let deliveryFields = tplGetVisibleFields("delivery_address")
        for field in deliveryFields {
            guard field.isRequired else { continue }
            let label = field.label ?? ""
            if tplDeliveryValLabels.contains(label) {
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
                let key = "delivery_address_\(field.name)"
                let val = customFieldValues[key] ?? ""
                if val.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("\(field.name) is required") }
            }
        }

        // Custom sections
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

        if lineItems.allSatisfy({ $0.description.trimmingCharacters(in: .whitespaces).isEmpty }) {
            errors.append("At least one line item with a description is required")
        }

        let lineFields = tplGetVisibleFields("line_items")
        for (idx, li) in lineItems.enumerated() {
            guard !li.description.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            for field in lineFields {
                guard field.isRequired else { continue }
                let label = field.label ?? ""
                if tplLineValLabels.contains(label) {
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

        // Always enforce vendor + at least one valid line item
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

    private var tplLineItemFields: [FormField] {
        if let sections = sortedSections,
           let liSection = sections.first(where: { $0.key == "line_items" }) {
            return liSection.visibleFields
        }
        return []
    }

    @ViewBuilder
    private var tplLineItemsSummaryCard: some View {
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
                    Text(FormatUtils.formatCurrency(templateNetTotal, code: currency)).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                }
            }
            .padding(12).background(Color.bgBase).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                showErrors && !hasValidLineItem ? Color.red : Color.goldDark.opacity(0.3), lineWidth: 1))
        }.buttonStyle(BorderlessButtonStyle())
        if showErrors && !hasValidLineItem {
            Text("At least one line item with description, quantity, and unit price is required")
                .font(.system(size: 10)).foregroundColor(.red)
        }
    }

    var body: some View {
        ZStack {
            List {
                // Template Name (always shown first)
                Section(header: tplSectionHeader(icon: "doc.on.doc", title: "TEMPLATE INFO")) {
                    VStack(spacing: 14) {
                        FieldGroup(label: "TEMPLATE NAME") {
                            InputField(text: $templateName, placeholder: "e.g. Weekly Catering Order")
                        }
                    }
                }

                if let sections = sortedSections {
                    ForEach(sections, id: \.key) { section in
                        self.editTplSection(for: section)
                    }
                    // If template has no terms_of_engagement, show Summary after all sections
                    if !sections.contains(where: { $0.key == "terms_of_engagement" }) {
                        Section(header: tplSectionHeader(icon: "sum", title: "SUMMARY")) {
                            HStack {
                                Text("Net Total").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                                Spacer()
                                Text(FormatUtils.formatCurrency(templateNetTotal, code: currency)).font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                            }
                        }
                    }
                } else {
                    // Fallback
                    Section(header: tplSectionHeader(icon: "doc.text", title: "PO DETAILS")) {
                        tplFallbackPODetails
                    }
                    Section(header: tplSectionHeader(icon: "shippingbox", title: "DELIVERY ADDRESS")) {
                        tplFallbackDeliveryAddress
                    }
                    Section(header: tplSectionHeader(icon: "list.bullet.rectangle", title: "LINE ITEMS")) {
                        tplLineItemsSummaryCard
                    }
                    Section(header: tplSectionHeader(icon: "note.text", title: "NOTES")) {
                        FieldGroup(label: "NOTES", optional: true) { InputField(text: $notes, placeholder: "Internal notes...") }
                    }
                    Section(header: tplSectionHeader(icon: "sum", title: "SUMMARY")) {
                        HStack {
                            Text("Net Total").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                            Spacer()
                            Text(FormatUtils.formatCurrency(templateNetTotal, code: currency)).font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        }
                    }
                }

                // MARK: - Action Buttons
                Section {
                    VStack(spacing: 10) {
                        // Row 1: Attach + Save
                        HStack(spacing: 10) {
                            // Attach button
                            Button(action: { showAttachSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "paperclip").font(.system(size: 13, weight: .semibold))
                                    Text("Attach").font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.white).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            }.buttonStyle(BorderlessButtonStyle())

                            // Save button (dropdown)
                            Button(action: { showSaveSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.down").font(.system(size: 13, weight: .semibold))
                                    Text("Save").font(.system(size: 13, weight: .semibold))
                                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.gold).cornerRadius(8)
                            }.buttonStyle(BorderlessButtonStyle())
                        }

                        // Row 2: Create & Submit PO
                        Button(action: { validateAndSubmitFromTemplate() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "paperplane.fill").font(.system(size: 13, weight: .bold))
                                Text("Create & Submit PO").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background((!vendorId.isEmpty && hasValidLineItem) ? Color.goldDark : Color.goldDark.opacity(0.4)).cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                        .alert(isPresented: $showValidationAlert) {
                            Alert(title: Text("Missing Required Fields"), message: Text(validationMessage), dismissButton: .default(Text("OK")))
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .dismissKeyboardOnTap()
            .onAppear { loadTemplateData() }
            .compatActionSheet(title: "Attach", isPresented: $showAttachSheet, buttons: [
                CompatActionSheetButton.default("Quote") { /* TODO: attach quote */ },
                CompatActionSheetButton.default("Email") { /* TODO: attach email */ },
                CompatActionSheetButton.default("Attachment") { /* TODO: attach file */ },
                CompatActionSheetButton.cancel()
            ])
            .sheet(isPresented: $showSaveAsNameSheet) {
                TemplateNameSheet(templateName: $saveAsTemplateName, isPresented: $showSaveAsNameSheet) {
                    saveAsNewTemplate()
                }
            }

            NavigationLink(
                destination: LineItemsPage(
                    lineItems: $lineItems,
                    lineItemCustomValues: $lineItemCustomValues,
                    formFields: tplLineItemFields,
                    currency: currency
                ).environmentObject(appState),
                isActive: $showLineItemsPage
            ) { EmptyView() }
            .hidden()
            .compatActionSheet(title: "Save Options", isPresented: $showSaveSheet, buttons: [
                CompatActionSheetButton.default("Save") { updateTemplate() },
                CompatActionSheetButton.default("Save As") { saveAsTemplateName = templateName; showSaveAsNameSheet = true },
                CompatActionSheetButton.default("Save as Draft") { saveAsDraft() },
                CompatActionSheetButton.cancel()
            ])
        }
    }

    // MARK: - Dynamic Section Router

    @ViewBuilder
    private func editTplSection(for section: FormSection) -> some View {
        if section.key == "po_details" {
            Section(header: tplSectionHeader(icon: "doc.text", title: section.label.uppercased())) {
                VStack(spacing: 14) {
                    ForEach(section.visibleFields, id: \.id) { field in
                        self.editTplPOField(field)
                    }
                }
            }
        } else if section.key == "delivery_address" {
            Section(header: tplSectionHeader(icon: "shippingbox", title: section.label.uppercased())) {
                VStack(spacing: 14) {
                    ForEach(section.visibleFields, id: \.id) { field in
                        self.editTplDeliveryField(field)
                    }
                }
            }
        } else if section.key == "line_items" {
            Section(header: tplSectionHeader(icon: "list.bullet.rectangle", title: section.label.uppercased())) {
                tplLineItemsSummaryCard
            }
        } else if section.key == "terms_of_engagement" {
            Section(header: tplSectionHeader(icon: "sum", title: "SUMMARY")) {
                HStack {
                    Text("Net Total").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                    Spacer()
                    Text(FormatUtils.formatCurrency(templateNetTotal, code: currency)).font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                }
            }
            Section(header: tplSectionHeader(icon: "doc.plaintext", title: section.label.uppercased())) {
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
            Section(header: tplSectionHeader(icon: "square.grid.2x2", title: section.label.uppercased())) {
                VStack(spacing: 14) {
                    ForEach(section.visibleFields, id: \.id) { field in
                        self.tplCustomFieldView(sectionKey: section.key, field: field)
                    }
                }
            }
        }
    }

    // MARK: - PO Details Fields

    @ViewBuilder
    private func editTplPOField(_ field: FormField) -> some View {
        if field.label == "vendor" {
            let hasErr = field.isRequired && tplPickerHasError(vendorId)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    Text(field.name.uppercased())
                        .font(.system(size: 9, weight: .bold)).tracking(0.3)
                        .foregroundColor(hasErr ? .red : Color(red: 0.45, green: 0.47, blue: 0.5))
                        .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                }
                VendorSearchField(vendorId: $vendorId, vendors: appState.vendors, hasError: hasErr)
                if hasErr { Text("Vendor is required").font(.system(size: 10)).foregroundColor(.red) }
            }
        } else if field.label == "vendor_address" {
            FieldGroup(label: field.name.uppercased()) {
                Text(tplVendorAddressText)
                    .font(.system(size: 13))
                    .foregroundColor(vendorId.isEmpty ? .gray : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
        } else if field.label == "department" {
            tplErrorWrappedPicker(label: field.name.uppercased(), value: departmentId, required: field.isRequired) {
                PickerField(selection: tplDepartmentBinding, placeholder: "Select department...",
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
            }
        } else if field.label == "account_code" {
            tplErrorWrappedPicker(label: field.name.uppercased(), value: nominalCode, required: field.isRequired) {
                PickerField(selection: tplNominalCodeBinding, placeholder: "Select nominal code...",
                    options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
            }
        } else if field.label == "description" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: $desc, placeholder: "e.g. Studio hire — Stage G, 12 weeks", required: field.isRequired)
        } else if field.label == "currency" {
            tplErrorWrappedPicker(label: field.name.uppercased(), value: currency, required: field.isRequired) {
                PickerField(selection: $currency, placeholder: "Select currency...",
                    options: [DropdownOption("GBP", "GBP — British Pound"), DropdownOption("USD", "USD — US Dollar"), DropdownOption("EUR", "EUR — Euro")])
            }
        } else if field.label == "vat" {
            tplErrorWrappedPicker(label: field.name.uppercased(), value: vatTreatment, required: field.isRequired) {
                PickerField(selection: $vatTreatment, placeholder: "Select VAT...",
                    options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
            }
        } else if field.label == "delivery_date" {
            let hasErr = field.isRequired && showErrors && !hasDelDate
            VStack(alignment: .leading, spacing: 4) {
                FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                    tplDateFieldContent(hasDate: $hasDelDate, date: $deliveryDate)
                }
                if hasErr { Text("\(field.name) is required").font(.system(size: 10)).foregroundColor(.red) }
            }
        } else if field.label == "effective_date" {
            // Effective date is hidden from users
            EmptyView()
        } else if field.label == "notes" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: $notes, placeholder: "Internal notes...", required: field.isRequired)
        } else if !tplPOSystemLabels.contains(field.label ?? "") {
            tplCustomFieldView(sectionKey: "po_details", field: field)
        }
    }

    // MARK: - Nominal Code → Department auto-sync binding
    private var tplNominalCodeBinding: Binding<String> {
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
    private var tplDepartmentBinding: Binding<String> {
        Binding<String>(
            get: { departmentId },
            set: { newValue in
                departmentId = newValue
                nominalCode = NominalCodes.deptToNominal[newValue] ?? nominalCode
                for i in lineItems.indices {
                    if lineItems[i].department.isEmpty || lineItems[i].department != newValue {
                        lineItems[i].department = newValue
                    }
                    let newNominal = NominalCodes.deptToNominal[newValue] ?? ""
                    if lineItems[i].account.isEmpty || lineItems[i].account != newNominal {
                        lineItems[i].account = newNominal
                    }
                }
            }
        )
    }

    private let tplPOSystemLabels: Set<String> = [
        "vendor", "vendor_address", "department", "account_code", "description",
        "currency", "vat", "delivery_date", "effective_date", "notes"
    ]
    private let tplDeliverySystemLabels: Set<String> = [
        "delivery_name", "delivery_email", "delivery_phone_code", "delivery_phone",
        "delivery_line1", "delivery_line2", "delivery_city", "delivery_state",
        "delivery_postal_code", "country"
    ]

    // MARK: - Delivery Address Fields

    @ViewBuilder
    private func editTplDeliveryField(_ field: FormField) -> some View {
        if field.label == "delivery_name" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: $daName, placeholder: "Recipient name...", required: field.isRequired)
        } else if field.label == "delivery_email" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: $daEmail, placeholder: "email@example.com", keyboard: .emailAddress, required: field.isRequired)
        } else if field.label == "delivery_phone_code" {
            EmptyView()
        } else if field.label == "delivery_phone" {
            let hasErr = field.isRequired && tplFieldHasError(daPhone)
            VStack(alignment: .leading, spacing: 4) {
                FieldGroup(label: "PHONE", optional: !field.isRequired) {
                    PhoneField(phoneCode: $daPhoneCode, phone: $daPhone)
                }
                if hasErr { Text("Phone is required").font(.system(size: 10)).foregroundColor(.red) }
            }
        } else if field.label == "delivery_line1" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: $daLine1, placeholder: "Street address...", required: field.isRequired)
        } else if field.label == "delivery_line2" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: $daLine2, placeholder: "Suite, unit, building...", required: field.isRequired)
        } else if field.label == "delivery_city" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: $daCity, placeholder: "City...", required: field.isRequired)
        } else if field.label == "delivery_state" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: $daState, placeholder: "State / County...", required: field.isRequired)
        } else if field.label == "delivery_postal_code" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: $daPostal, placeholder: "Postal code...", required: field.isRequired)
        } else if field.label == "country" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: $daCountry, placeholder: "Country", required: field.isRequired)
        } else if !tplDeliverySystemLabels.contains(field.label ?? "") {
            tplCustomFieldView(sectionKey: "delivery_address", field: field)
        }
    }

    // MARK: - Date Field Helper

    @ViewBuilder
    private func tplDateFieldContent(hasDate: Binding<Bool>, date: Binding<Date>) -> some View {
        DateFieldView(hasDate: hasDate, date: date)
    }

    // MARK: - Custom Field

    @ViewBuilder
    private func tplCustomFieldView(sectionKey: String, field: FormField) -> some View {
        let key = "\(sectionKey)_\(field.name)"
        let binding = Binding<String>(
            get: { self.customFieldValues[key] ?? "" },
            set: { self.customFieldValues[key] = $0 }
        )
        if field.type == "select" {
            if field.selectionType == "vendor" {
                tplErrorWrappedPicker(label: field.name.uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select...",
                        options: appState.vendors.map { DropdownOption($0.id, $0.name) })
                }
            } else if field.selectionType == "department" {
                tplErrorWrappedPicker(label: field.name.uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select department...",
                        options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
                }
            } else if field.selectionType == "currency" {
                tplErrorWrappedPicker(label: field.name.uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select currency...",
                        options: [DropdownOption("GBP", "GBP — British Pound"),
                                  DropdownOption("USD", "USD — US Dollar"),
                                  DropdownOption("EUR", "EUR — Euro")])
                }
            } else if field.selectionType == "vat" {
                tplErrorWrappedPicker(label: field.name.uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select VAT...",
                        options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
                }
            } else if field.selectionType == "account_code" {
                tplErrorWrappedPicker(label: field.name.uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select account...",
                        options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
                }
            } else if field.selectionType == "exp_type" {
                tplErrorWrappedPicker(label: field.name.uppercased(), value: binding.wrappedValue, required: field.isRequired) {
                    PickerField(selection: binding, placeholder: "Select type...",
                        options: expenditureTypes.map { DropdownOption($0, $0) })
                }
            } else {
                tplErrorWrappedInput(label: field.name.uppercased(), text: binding, placeholder: "Enter \(field.name.lowercased())...", required: field.isRequired)
            }
        } else if field.type == "date" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: binding, placeholder: "dd/mm/yyyy", required: field.isRequired)
        } else if field.type == "number" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: binding, placeholder: "0", keyboard: .decimalPad, required: field.isRequired)
        } else if field.type == "email" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: binding, placeholder: "email@example.com", keyboard: .emailAddress, required: field.isRequired)
        } else if field.type == "phone" {
            tplErrorWrappedInput(label: field.name.uppercased(), text: binding, placeholder: "Phone number", keyboard: .phonePad, required: field.isRequired)
        } else {
            tplErrorWrappedInput(label: field.name.uppercased(), text: binding, placeholder: "Enter \(field.name.lowercased())...", required: field.isRequired)
        }
    }

    // MARK: - Line Item Custom Field

    @ViewBuilder
    private func tplLineItemCustomFieldView(itemId: String, field: FormField) -> some View {
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

    // MARK: - Helpers

    private var tplVendorAddressText: String {
        guard !vendorId.isEmpty, let v = appState.vendors.first(where: { $0.id == vendorId }) else { return "Select a vendor first" }
        let addr = v.address.formatted
        return addr.isEmpty ? "No address on file" : addr
    }

    private func tplSectionHeader(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(.goldDark)
            Text(title).font(.system(size: 11, weight: .bold)).tracking(1).lineLimit(1)
            Spacer()
        }
    }

    // (Line item bindings removed — now uses LineItemsPage)

    // MARK: - Fallback views (when form template not loaded)

    private var tplFallbackPODetails: some View {
        VStack(spacing: 14) {
            FieldGroup(label: "VENDOR") { VendorSearchField(vendorId: $vendorId, vendors: appState.vendors) }
            FieldGroup(label: "VENDOR ADDRESS") {
                Text(tplVendorAddressText).font(.system(size: 13)).foregroundColor(vendorId.isEmpty ? .gray : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color(red: 0.97, green: 0.97, blue: 0.98)).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
            FieldGroup(label: "DEPARTMENT") {
                PickerField(selection: tplDepartmentBinding, placeholder: "Select department...",
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
            }
            FieldGroup(label: "NOMINAL CODE") {
                PickerField(selection: tplNominalCodeBinding, placeholder: "Select nominal code...",
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
            FieldGroup(label: "DELIVERY DATE", optional: true) { tplDateFieldContent(hasDate: $hasDelDate, date: $deliveryDate) }
            FieldGroup(label: "NOTES", optional: true) { InputField(text: $notes, placeholder: "Internal notes...") }
        }
    }

    private var tplFallbackDeliveryAddress: some View {
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

    private var templateNetTotal: Double {
        lineItems.reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
    }

    private var tplDecimalFormatter: NumberFormatter {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.minimumFractionDigits = 2; f.maximumFractionDigits = 2; return f
    }

    // MARK: - Load Template Data

    private func loadTemplateData() {
        // Auto-select from current user first
        if let u = appState.currentUser {
            departmentId = u.departmentIdentifier
            nominalCode = NominalCodes.deptToNominal[u.departmentIdentifier] ?? ""
        }

        guard let tpl = template else { return }
        templateName = tpl.templateName ?? ""
        vendorId = tpl.vendorId ?? ""
        // Override with template values if present
        if let d = tpl.departmentId, !d.isEmpty { departmentId = d }
        if let n = tpl.nominalCode, !n.isEmpty { nominalCode = n }
        desc = tpl.description ?? ""
        currency = tpl.currency ?? "GBP"
        vatTreatment = tpl.vatTreatment ?? "pending"
        notes = tpl.notes ?? ""

        if !departmentId.isEmpty {
            if let dept = DepartmentsData.all.first(where: { $0.id == departmentId }) {
                departmentId = dept.identifier
            }
            // Auto-set nominal code if not already set from template
            if nominalCode.isEmpty {
                nominalCode = NominalCodes.deptToNominal[departmentId] ?? ""
            }
        }

        if let ms = tpl.effectiveDate, ms > 0 { effectiveDate = Date(timeIntervalSince1970: Double(ms)/1000); hasEffDate = true }
        if let ms = tpl.deliveryDate, ms > 0 { deliveryDate = Date(timeIntervalSince1970: Double(ms)/1000); hasDelDate = true }

        if let da = tpl.deliveryAddress?.address {
            daName = da.name ?? ""; daEmail = da.email ?? ""; daPhone = da.phone ?? ""
            daLine1 = da.line1 ?? ""; daLine2 = da.line2 ?? ""; daCity = da.city ?? ""
            daState = da.state ?? ""; daPostal = da.postalCode ?? ""; daCountry = da.country ?? ""
        }

        if let flexItems = tpl.lineItems {
            let items = flexItems.items.map {
                LineItem(id: $0.id ?? UUID().uuidString, description: $0.description ?? "",
                         quantity: Double($0.quantity ?? 1), unitPrice: Double($0.unit_price ?? 0),
                         total: Double($0.total ?? 0), account: $0.account ?? "",
                         department: $0.department ?? "", expenditureType: $0.expenditure_type ?? "Purchase")
            }
            if !items.isEmpty { lineItems = items }
        }
    }

    // MARK: - Build Form Data

    private func buildFormData() -> POFormData {
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
                          deliveryAddress: hasDA ? da : nil,
                          customFieldValues: customFieldValues,
                          lineItemCustomValues: lineItemCustomValues)
    }

    // MARK: - Actions

    private func updateTemplate() {
        guard let tpl = template else { return }
        appState.updateTemplate(tpl.id, buildFormData(), templateName: templateName, onComplete: onBack)
    }

    private func saveAsNewTemplate() {
        let name = saveAsTemplateName.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : saveAsTemplateName
        appState.saveTemplate(buildFormData(), templateName: name, onComplete: onBack)
    }

    private func saveAsDraft() {
        appState.saveDraft(buildFormData(), onComplete: onBack)
    }

    private func validateAndSubmitFromTemplate() {
        let errors = tplValidate()
        if !errors.isEmpty {
            showErrors = true
            validationMessage = errors.map { "• \($0)" }.joined(separator: "\n")
            showValidationAlert = true
            return
        }
        submitPOFromTemplate()
    }

    private func submitPOFromTemplate() {
        appState.submitPO(buildFormData(), onComplete: onBack)
    }
}

// MARK: - Create Template Page (Navigation destination)

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
        appState.formTemplate?.template.sorted { $0.order < $1.order }
    }

    private var ctLineItemFields: [FormField] {
        if let sections = sortedSections,
           let liSection = sections.first(where: { $0.key == "line_items" }) {
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
                    ForEach(sections, id: \.key) { section in
                        self.ctSection(for: section)
                    }
                    if !sections.contains(where: { $0.key == "terms_of_engagement" }) {
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
                            .background(Color.white).cornerRadius(8)
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
            .compatActionSheet(title: "Attach", isPresented: $showAttachSheet, buttons: [
                CompatActionSheetButton.default("Quote") { /* TODO: attach quote */ },
                CompatActionSheetButton.default("Email") { /* TODO: attach email */ },
                CompatActionSheetButton.default("Attachment") { /* TODO: attach file */ },
                CompatActionSheetButton.cancel()
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
                                    .background(Color.white).cornerRadius(8)
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
        if section.key == "po_details" {
            Section(header: ctSectionHeader(icon: "doc.text", title: section.label.uppercased())) {
                VStack(spacing: 14) {
                    ForEach(section.visibleFields, id: \.id) { field in
                        self.ctPOField(field)
                    }
                }
            }
        } else if section.key == "delivery_address" {
            Section(header: ctSectionHeader(icon: "shippingbox", title: section.label.uppercased())) {
                VStack(spacing: 14) {
                    ForEach(section.visibleFields, id: \.id) { field in
                        self.ctDeliveryField(field)
                    }
                }
            }
        } else if section.key == "line_items" {
            Section(header: ctSectionHeader(icon: "list.bullet.rectangle", title: section.label.uppercased())) {
                ctLineItemsSummaryCard
            }
        } else if section.key == "terms_of_engagement" {
            Section(header: ctSectionHeader(icon: "sum", title: "SUMMARY")) {
                HStack {
                    Text("Net Total").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                    Spacer()
                    Text(FormatUtils.formatCurrency(ctNetTotal, code: currency)).font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                }
            }
            Section(header: ctSectionHeader(icon: "doc.plaintext", title: section.label.uppercased())) {
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
            Section(header: ctSectionHeader(icon: "square.grid.2x2", title: section.label.uppercased())) {
                VStack(spacing: 14) {
                    ForEach(section.visibleFields, id: \.id) { field in
                        self.ctCustomFieldView(sectionKey: section.key, field: field)
                    }
                }
            }
        }
    }

    // MARK: - PO Details Fields

    @ViewBuilder
    private func ctPOField(_ field: FormField) -> some View {
        if field.label == "vendor" {
            FieldGroup(label: field.name.uppercased()) { VendorSearchField(vendorId: $vendorId, vendors: appState.vendors) }
        } else if field.label == "vendor_address" {
            FieldGroup(label: field.name.uppercased()) {
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
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                PickerField(selection: ctDepartmentBinding, placeholder: "Select department...",
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
            }
        } else if field.label == "account_code" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                PickerField(selection: ctNominalCodeBinding, placeholder: "Select nominal code...",
                    options: NominalCodes.all.map { DropdownOption($0.code, "\($0.code) — \($0.label)") })
            }
        } else if field.label == "description" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $desc, placeholder: "e.g. Studio hire — Stage G, 12 weeks")
            }
        } else if field.label == "currency" {
            FieldGroup(label: field.name.uppercased()) {
                PickerField(selection: $currency, placeholder: "Select currency...",
                    options: [DropdownOption("GBP", "GBP — British Pound"), DropdownOption("USD", "USD — US Dollar"), DropdownOption("EUR", "EUR — Euro")])
            }
        } else if field.label == "vat" {
            FieldGroup(label: field.name.uppercased()) {
                PickerField(selection: $vatTreatment, placeholder: "Select VAT...",
                    options: VATHelpers.options.map { DropdownOption($0.value, $0.label) })
            }
        } else if field.label == "delivery_date" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                ctDateFieldContent(hasDate: $hasDelDate, date: $deliveryDate)
            }
        } else if field.label == "effective_date" {
            // Effective date is hidden from users
            EmptyView()
        } else if field.label == "notes" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) {
                InputField(text: $notes, placeholder: "Internal notes...")
            }
        } else if !ctPOSystemLabels.contains(field.label ?? "") {
            ctCustomFieldView(sectionKey: "po_details", field: field)
        }
    }

    // MARK: - Auto-select defaults from current user
    private func ctLoadDefaults() {
        if let u = appState.currentUser {
            if departmentId.isEmpty { departmentId = u.departmentIdentifier }
            if nominalCode.isEmpty { nominalCode = NominalCodes.deptToNominal[departmentId] ?? "" }
            for i in lineItems.indices {
                if lineItems[i].department.isEmpty { lineItems[i].department = departmentId }
                if lineItems[i].account.isEmpty { lineItems[i].account = nominalCode }
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
                    if lineItems[i].department.isEmpty || lineItems[i].department != newValue {
                        lineItems[i].department = newValue
                    }
                    let newNominal = NominalCodes.deptToNominal[newValue] ?? ""
                    if lineItems[i].account.isEmpty || lineItems[i].account != newNominal {
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
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) { InputField(text: $daName, placeholder: "Recipient name...") }
        } else if field.label == "delivery_email" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) { InputField(text: $daEmail, placeholder: "email@example.com", keyboard: .emailAddress) }
        } else if field.label == "delivery_phone_code" {
            EmptyView()
        } else if field.label == "delivery_phone" {
            FieldGroup(label: "PHONE", optional: !field.isRequired) { PhoneField(phoneCode: $daPhoneCode, phone: $daPhone) }
        } else if field.label == "delivery_line1" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) { InputField(text: $daLine1, placeholder: "Street address...") }
        } else if field.label == "delivery_line2" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) { InputField(text: $daLine2, placeholder: "Suite, unit, building...") }
        } else if field.label == "delivery_city" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) { InputField(text: $daCity, placeholder: "City...") }
        } else if field.label == "delivery_state" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) { InputField(text: $daState, placeholder: "State / County...") }
        } else if field.label == "delivery_postal_code" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) { InputField(text: $daPostal, placeholder: "Postal code...") }
        } else if field.label == "country" {
            FieldGroup(label: field.name.uppercased(), optional: !field.isRequired) { InputField(text: $daCountry, placeholder: "Country") }
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
        let key = "\(sectionKey)_\(field.name)"
        let binding = Binding<String>(
            get: { self.customFieldValues[key] ?? "" },
            set: { self.customFieldValues[key] = $0 }
        )
        if field.type == "select" {
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

    // MARK: - Helpers

    private var ctVendorAddressText: String {
        guard !vendorId.isEmpty, let v = appState.vendors.first(where: { $0.id == vendorId }) else { return "Select a vendor first" }
        let addr = v.address.formatted
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
        lineItems.reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
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
                    options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
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
        for i in lineItems.indices { lineItems[i].total = lineItems[i].quantity * lineItems[i].unitPrice }
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

struct POFormPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    private var editingPO: PurchaseOrder? { appState.editingPO }
    private var resumeDraft: PurchaseOrder? { appState.resumeDraft }
    private var prefilledVendorId: String? { appState.prefilledVendorId }

    private var title: String {
        if editingPO != nil { return "Edit PO" }
        if resumeDraft != nil { return "Resume Draft" }
        return "Create PO"
    }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            POFormView(
                editingPO: editingPO,
                resumeDraft: resumeDraft,
                prefilledVendorId: prefilledVendorId,
                onBack: {
                    appState.editingPO = nil
                    appState.resumeDraft = nil
                    appState.showCreatePO = false
                    appState.prefilledVendorId = nil
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .navigationBarTitle(Text(title), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: {
                appState.editingPO = nil
                appState.resumeDraft = nil
                appState.showCreatePO = false
                appState.prefilledVendorId = nil
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
    }
}
