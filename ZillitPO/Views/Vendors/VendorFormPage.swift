import SwiftUI
import UIKit

// MARK: - Vendor Form Page (Navigation destination)

struct VendorFormPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    /// Non-nil when opening in edit mode. `VendorFormView` pre-fills
    /// its state from this vendor and switches its submit action from
    /// create → update.
    var vendor: Vendor? = nil

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            VendorFormView(
                existingVendor: vendor,
                onBack: { presentationMode.wrappedValue.dismiss() }
            )
        }
        .navigationBarTitle(Text(vendor == nil ? "New Vendor" : "Edit Vendor"), displayMode: .inline)
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
            appState.loadVendors()
        }
    }
}

// Local form-state row for "Additional Bank Details". Kept separate
// from the codable `VendorBankAdditionalDetail` so we can attach a
// stable identity for ForEach without leaking UI-only state into the
// model payload.
struct AdditionalBankDetailRow: Identifiable, Equatable {
    let id: UUID
    var title: String
    var description: String
    init(id: UUID = UUID(), title: String = "", description: String = "") {
        self.id = id; self.title = title; self.description = description
    }
}

struct VendorFormView: View {
    @EnvironmentObject var appState: POViewModel
    /// When set, the form runs in edit mode: fields are pre-populated
    /// from this vendor on first appear and submit calls
    /// `updateVendor` instead of `createVendor`.
    var existingVendor: Vendor? = nil
    var onBack: () -> Void
    @State private var name = ""; @State private var contact = ""; @State private var email = ""
    @State private var phoneCode = "+44"; @State private var phone = ""
    @State private var vat = ""; @State private var departmentId = ""
    @State private var companyType = ""          // e.g. "Limited", "Sole Trader"
    @State private var terms = ""                // payment terms key
    @State private var addr1 = ""; @State private var addr2 = ""
    @State private var city = ""; @State private var state = ""
    @State private var postal = ""; @State private var country = ""
    // Bank details (web-parity block)
    @State private var bankName = ""
    @State private var accountHolderName = ""
    @State private var accountNumber = ""
    @State private var sortCode = ""
    @State private var ibanCode = ""
    @State private var swiftCode = ""
    @State private var additionalBankDetails: [AdditionalBankDetailRow] = []
    @State private var isSubmitting = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showErrors = false
    @State private var didPrefill = false
    @State private var showCountryPicker = false
    private var isEditing: Bool { existingVendor != nil }

    /// Payment-terms options (dropdown). Keys match a typical backend
    /// enum — if the server uses a different key set, remap only the
    /// `id` values here.
    private let termsOptions: [DropdownOption] = [
        DropdownOption("due_on_receipt", "Due on Receipt"),
        DropdownOption("net_7",          "Net 7"),
        DropdownOption("net_15",         "Net 15"),
        DropdownOption("net_30",         "Net 30"),
        DropdownOption("net_45",         "Net 45"),
        DropdownOption("net_60",         "Net 60"),
        DropdownOption("net_90",         "Net 90"),
        DropdownOption("cod",            "Cash on Delivery"),
        DropdownOption("prepaid",        "Prepaid")
    ]

    private func validate() -> [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Vendor name is required") }
        if contact.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Contact person is required") }
        if email.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Email is required") }
        if phone.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Phone number is required") }
        if addr1.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Address line 1 is required") }
        if city.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("City is required") }
        if postal.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Postal code is required") }
        if country.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Country is required") }
        return errors
    }

    private func isFieldEmpty(_ value: String) -> Bool {
        showErrors && value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        List {
            // Vendor Details
            Section(header: vendorSectionHeader(icon: "person.crop.square", title: "VENDOR DETAILS", trailing: "All fields required unless noted")) {
                VStack(spacing: 14) {
                    vendorField(label: "VENDOR / COMPANY NAME", text: $name, placeholder: "e.g. Pinewood Studios Ltd", required: true)
                    vendorField(label: "CONTACT PERSON", text: $contact, placeholder: "e.g. Margaret Thornton", required: true)
                    vendorField(label: "EMAIL", text: $email, placeholder: "e.g. bookings@studio.co.uk", keyboard: .emailAddress, required: true)
                    VStack(alignment: .leading, spacing: 4) {
                        FieldGroup(label: "PHONE") {
                            PhoneField(phoneCode: $phoneCode, phone: $phone)
                        }
                        if isFieldEmpty(phone) {
                            Text("Phone number is required").font(.system(size: 10)).foregroundColor(.red)
                        }
                    }
                    FieldGroup(label: "VAT NUMBER", optional: true) {
                        InputField(text: $vat, placeholder: "e.g. GB 123 4567 89")
                    }
                    FieldGroup(label: "DEPARTMENT") {
                        PickerField(selection: $departmentId, placeholder: "Select department...",
                            options: DepartmentsData.sorted.map { DropdownOption($0.identifier ?? "", $0.displayName) })
                    }
                    FieldGroup(label: "COMPANY TYPE", optional: true) {
                        InputField(text: $companyType, placeholder: "e.g. Limited, Sole Trader")
                    }
                    FieldGroup(label: "TERMS", optional: true) {
                        PickerField(selection: $terms, placeholder: "Select terms...",
                                    options: termsOptions)
                    }
                }
            }

            // Address
            Section(header: vendorSectionHeader(icon: "mappin.and.ellipse", title: "ADDRESS")) {
                VStack(spacing: 14) {
                    vendorField(label: "ADDRESS LINE 1", text: $addr1, placeholder: "Street address", required: true)
                    FieldGroup(label: "ADDRESS LINE 2", optional: true) {
                        InputField(text: $addr2, placeholder: "Suite, unit, building...")
                    }
                    vendorField(label: "CITY", text: $city, placeholder: "e.g. London", required: true)
                    FieldGroup(label: "STATE / COUNTY", optional: true) {
                        InputField(text: $state, placeholder: "e.g. Middlesex")
                    }
                    vendorField(label: "POSTAL / ZIP CODE", text: $postal, placeholder: "e.g. SL0 0NH", required: true)
                    countryPickerField(required: true)
                }
            }

            // Bank Details (all optional) — mirrors the web vendor form.
            // Primary six fields plus a dynamic list of key/value rows
            // for region-specific identifiers (IFSC, routing number,
            // BSB, etc.).
            Section(header: vendorSectionHeader(icon: "building.columns", title: "BANK DETAILS", trailing: "All optional")) {
                VStack(spacing: 14) {
                    FieldGroup(label: "BANK NAME", optional: true) {
                        InputField(text: $bankName, placeholder: "e.g. Barclays Bank")
                    }
                    FieldGroup(label: "ACCOUNT HOLDER NAME", optional: true) {
                        InputField(text: $accountHolderName, placeholder: "e.g. Pinewood Studios Ltd")
                    }
                    FieldGroup(label: "ACCOUNT NUMBER", optional: true) {
                        InputField(text: $accountNumber, placeholder: "e.g. 12345678")
                    }
                    FieldGroup(label: "SORT CODE", optional: true) {
                        InputField(text: $sortCode, placeholder: "e.g. 20-00-00")
                    }
                    FieldGroup(label: "IBAN CODE", optional: true) {
                        InputField(text: $ibanCode, placeholder: "e.g. GB29 NWBK 6016 1331 9268 19")
                    }
                    FieldGroup(label: "SWIFT CODE", optional: true) {
                        InputField(text: $swiftCode, placeholder: "e.g. BARCGB22")
                    }

                    // Dynamic "Additional Bank Details" rows (title + description)
                    ForEach(additionalBankDetails.indices, id: \.self) { idx in
                        additionalBankRow(at: idx)
                    }

                    // + Add Additional Bank Details — same pattern as the
                    // other action buttons in this form (plain HStack +
                    // onTapGesture, so it plays nicely with iOS 26 List
                    // hit-testing inside a Section).
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add Additional Bank Details")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.goldDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        additionalBankDetails.append(AdditionalBankDetailRow())
                    }
                }
            }

            // Actions
            Section {
                // Plain HStack + onTapGesture pattern (same as
                // POFormView) so the button reliably responds on
                // iOS 26 List cells.
                HStack(spacing: 6) {
                    if isSubmitting { ActivityIndicatorView() }
                    Text(saveButtonLabel).font(.system(size: 14, weight: .bold))
                    if !isSubmitting {
                        Image(systemName: isEditing ? "checkmark" : "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(name.isEmpty || isSubmitting ? Color.gold.opacity(0.4) : Color.gold)
                .cornerRadius(8)
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture { submitVendor() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(GroupedListStyle())
        .dismissKeyboardOnTap()
        .alert(isPresented: $showValidationAlert) {
            Alert(title: Text("Missing Fields"), message: Text(validationMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryNamePickerSheet(selectedName: $country, isPresented: $showCountryPicker)
        }
        .onAppear(perform: prefillIfEditing)
    }

    /// Tap-to-open country picker — replaces the plain text input so
    /// users pick from a searchable list of countries (same picker
    /// used on PO/Template delivery-address blocks). Validation still
    /// works: `isFieldEmpty(country)` yields the same red border /
    /// error row as the other required fields.
    @ViewBuilder
    private func countryPickerField(required: Bool) -> some View {
        let hasError = required && isFieldEmpty(country)
        let flag: String = {
            countryCodes.first { $0.name.lowercased() == country.lowercased() }?.flag ?? ""
        }()
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text("COUNTRY")
                    .font(.system(size: 9, weight: .bold)).tracking(0.3)
                    .foregroundColor(hasError ? .red : Color(red: 0.45, green: 0.47, blue: 0.5))
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            Button(action: { showCountryPicker = true }) {
                HStack(spacing: 6) {
                    if !flag.isEmpty { Text(flag).font(.system(size: 14)) }
                    Text(country.isEmpty ? "Select country" : country)
                        .font(.system(size: 13))
                        .foregroundColor(country.isEmpty ? .gray : .primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Color.bgSurface).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(hasError ? Color.red : Color.borderColor, lineWidth: 1))
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())
            if hasError {
                Text("Country is required").font(.system(size: 10)).foregroundColor(.red)
            }
        }
    }

    private var saveButtonLabel: String {
        if isSubmitting { return isEditing ? "Updating..." : "Saving..." }
        return isEditing ? "Update Vendor" : "Save Vendor"
    }

    /// Copy the existing vendor's fields into local @State on first
    /// appear. Guarded by `didPrefill` so user edits don't get
    /// overwritten if the view re-appears (e.g. returning from a
    /// pushed subview).
    private func prefillIfEditing() {
        guard !didPrefill, let v = existingVendor else { return }
        didPrefill = true
        name       = v.name ?? ""
        contact    = v.contactPerson ?? ""
        email      = v.email ?? ""
        phoneCode  = v.phone?.countryCode ?? "+44"
        phone      = v.phone?.number ?? ""
        vat        = v.vatNumber ?? ""
        departmentId = v.departmentId ?? ""
        companyType = v.companyType ?? ""
        terms       = v.terms ?? ""
        addr1      = v.address?.line1 ?? ""
        addr2      = v.address?.line2 ?? ""
        city       = v.address?.city ?? ""
        state      = v.address?.state ?? ""
        postal     = v.address?.postalCode ?? ""
        country    = v.address?.country ?? ""
        // Bank details — unpack each primary field + the additional
        // details list into editable rows.
        if let b = v.bankDetails {
            bankName          = b.bankName ?? ""
            accountHolderName = b.accountHolderName ?? ""
            accountNumber     = b.accountNumber ?? ""
            sortCode          = b.sortCode ?? ""
            ibanCode          = b.ibanCode ?? ""
            swiftCode         = b.swiftCode ?? ""
            additionalBankDetails = (b.additionalDetails ?? []).map {
                AdditionalBankDetailRow(title: $0.title ?? "", description: $0.description ?? "")
            }
        }
    }

    /// One editable row in the "Additional Bank Details" list. Each row
    /// has a 2-column layout (TITLE, DESCRIPTION) with a trailing
    /// delete button so users can remove entries added in error.
    @ViewBuilder
    private func additionalBankRow(at idx: Int) -> some View {
        let titleBinding = Binding<String>(
            get: { additionalBankDetails.indices.contains(idx) ? additionalBankDetails[idx].title : "" },
            set: { if additionalBankDetails.indices.contains(idx) { additionalBankDetails[idx].title = $0 } }
        )
        let descBinding = Binding<String>(
            get: { additionalBankDetails.indices.contains(idx) ? additionalBankDetails[idx].description : "" },
            set: { if additionalBankDetails.indices.contains(idx) { additionalBankDetails[idx].description = $0 } }
        )
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 10) {
                FieldGroup(label: "TITLE", optional: true) {
                    InputField(text: titleBinding, placeholder: "e.g. IFSC Code")
                }
                FieldGroup(label: "DESCRIPTION", optional: true) {
                    InputField(text: descBinding, placeholder: "e.g. INDB0001234")
                }
            }
            Button(action: {
                if additionalBankDetails.indices.contains(idx) {
                    additionalBankDetails.remove(at: idx)
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.top, 22)
        }
        .padding(10)
        .background(Color.bgRaised)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor.opacity(0.6), lineWidth: 1))
    }

    @ViewBuilder
    private func vendorField(label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default, required: Bool = false) -> some View {
        let hasError = required && isFieldEmpty(text.wrappedValue)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.3)
                    .foregroundColor(hasError ? .red : Color(red: 0.45, green: 0.47, blue: 0.5))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            TextField(placeholder, text: text)
                .font(.system(size: 13))
                .keyboardType(keyboard)
                .autocapitalization(keyboard == .emailAddress ? .none : .sentences)
                .disableAutocorrection(keyboard == .emailAddress || keyboard == .phonePad)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.bgSurface)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(hasError ? Color.red : Color.borderColor, lineWidth: 1))
            if hasError {
                Text("\(label.capitalized.lowercased().replacingOccurrences(of: " / ", with: "/")) is required")
                    .font(.system(size: 10)).foregroundColor(.red)
            }
        }
    }

    private func vendorSectionHeader(icon: String, title: String, trailing: String? = nil) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(.goldDark)
            Text(title).font(.system(size: 11, weight: .bold)).tracking(1).lineLimit(1)
            Spacer()
            if let t = trailing {
                Text(t).font(.system(size: 9)).foregroundColor(.gray).italic().lineLimit(1)
            }
        }
    }

    /// Dispatches to either `updateVendor` or `createVendor` based on
    /// whether the form was opened with an existing vendor. Body shape
    /// is identical in both cases so the backend can patch individual
    /// fields on an existing record or create a fresh one.
    private func submitVendor() {
        guard !isSubmitting else { return }
        let errors = validate()
        if !errors.isEmpty {
            showErrors = true
            validationMessage = errors.map { "• \($0)" }.joined(separator: "\n")
            showValidationAlert = true
            return
        }
        isSubmitting = true
        var body: [String: Any] = [
            "name": name, "contact_person": contact, "email": email,
            "phone": ["country_code": phoneCode, "number": phone],
            "address": ["line1": addr1, "line2": addr2, "city": city, "state": state, "postal_code": postal, "country": country],
            "vat_number": vat, "department_id": departmentId,
            "company_type": companyType, "terms": terms
        ]

        // Bank details — only send the block when the user filled in
        // at least one field (primary or an additional row). The server
        // treats an absent block as "no banking info" which preserves
        // the previous state on updates.
        let additionalPayload: [[String: Any]] = additionalBankDetails
            .filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty
                   || !$0.description.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { ["title": $0.title, "description": $0.description] }
        let hasAnyBank = ![bankName, accountHolderName, accountNumber, sortCode, ibanCode, swiftCode]
            .allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            || !additionalPayload.isEmpty
        if hasAnyBank {
            var bd: [String: Any] = [
                "bank_name": bankName,
                "account_holder_name": accountHolderName,
                "account_number": accountNumber,
                "sort_code": sortCode,
                "iban_code": ibanCode,
                "swift_code": swiftCode
            ]
            if !additionalPayload.isEmpty { bd["additional_details"] = additionalPayload }
            body["bank_details"] = bd
        }

        if let editing = existingVendor {
            appState.updateVendor(id: editing.id, body: body) { ok in
                if ok {
                    onBack()
                } else {
                    isSubmitting = false
                }
            }
        } else {
            POCodableTask.createVendor(body) { [self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Vendor created successfully")
                        appState.loadVendors()
                        onBack()
                    case .failure(let error):
                        print("❌ Create vendor failed: \(error)")
                        isSubmitting = false
                    }
                }
            }.urlDataTask?.resume()
        }
    }
}
