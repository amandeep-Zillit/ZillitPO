import SwiftUI
import UIKit

// MARK: - Vendor Form Page (Navigation destination)

struct VendorFormPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            VendorFormView(onBack: { presentationMode.wrappedValue.dismiss() })
        }
        .navigationBarTitle(Text("New Vendor"), displayMode: .inline)
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

struct VendorFormView: View {
    @EnvironmentObject var appState: POViewModel
    var onBack: () -> Void
    @State private var name = ""; @State private var contact = ""; @State private var email = ""
    @State private var phoneCode = "+44"; @State private var phone = ""
    @State private var vat = ""; @State private var departmentId = ""
    @State private var addr1 = ""; @State private var addr2 = ""
    @State private var city = ""; @State private var state = ""
    @State private var postal = ""; @State private var country = ""
    @State private var isSubmitting = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showErrors = false

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
                    vendorField(label: "COUNTRY", text: $country, placeholder: "United Kingdom", required: true)
                }
            }

            // Actions
            Section {
                Button(action: { createVendor() }) {
                    HStack(spacing: 6) {
                        if isSubmitting {
                            ActivityIndicatorView()
                        }
                        Text(isSubmitting ? "Saving..." : "Save Vendor").font(.system(size: 14, weight: .bold))
                        if !isSubmitting {
                            Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                        }
                    }.foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(name.isEmpty || isSubmitting ? Color.gold.opacity(0.4) : Color.gold).cornerRadius(8)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(name.isEmpty || isSubmitting)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(GroupedListStyle())
        .dismissKeyboardOnTap()
        .alert(isPresented: $showValidationAlert) {
            Alert(title: Text("Missing Fields"), message: Text(validationMessage), dismissButton: .default(Text("OK")))
        }
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

    private func createVendor() {
        guard !isSubmitting else { return }
        let errors = validate()
        if !errors.isEmpty {
            showErrors = true
            validationMessage = errors.map { "• \($0)" }.joined(separator: "\n")
            showValidationAlert = true
            return
        }
        isSubmitting = true
        let body: [String: Any] = [
            "name": name, "contact_person": contact, "email": email,
            "phone": ["country_code": phoneCode, "number": phone],
            "address": ["line1": addr1, "line2": addr2, "city": city, "state": state, "postal_code": postal, "country": country],
            "vat_number": vat, "department_id": departmentId
        ]
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
