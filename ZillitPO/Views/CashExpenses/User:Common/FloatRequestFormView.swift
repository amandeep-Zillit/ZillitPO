import SwiftUI

struct FloatRequestFormView: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var reqAmount = ""
    @State private var startDate: Date?
    @State private var howLongMode: String = ""       // "" | "run_of_show" | "days"
    @State private var durationDays: String = ""
    @State private var collectionMethod = "production_office"
    @State private var collectDate: Date?
    @State private var collectTime: Date?
    @State private var purpose = ""
    @State private var submitting = false
    @State private var submitted = false
    @State private var submitError: String?
    @State private var showHowLongSheet = false
    @State private var showCollectionSheet = false
    /// Values for any admin-added custom fields (non-system-default)
    /// in the float form template. Keyed by the field's `label`.
    /// Emitted on submit as a PO-style array of sections — see the
    /// `custom_fields` block in `submitFloat()`.
    @State private var customFieldValues: [String: String] = [:]
    /// Per-field validation errors surfaced inline on the Additional
    /// Fields rows (mirrors the web's `customFieldErrors` map).
    @State private var customFieldErrors: [String: String] = [:]
    // MARK: - Accountant "create on behalf" state
    //
    // Accountants can raise a float for another crew member by
    // picking their user — the picked user's department is used for
    // validation + the server's `target_user_id` field flips the
    // float's owner while `created_by` stays the signed-in
    // accountant. Mirrors commit `91ceec4f` on the web side.
    @State private var targetUserId: String = ""
    @State private var showUserPicker = false
    /// Post-submit toast for accountants — they stay on the form
    /// instead of dismissing, so we need a visible confirmation.
    @State private var accountantSubmittedAt: Date?

    /// `true` when the signed-in user has accountant privileges.
    /// Gates the user picker + keep-on-form behaviour.
    private var isAccountant: Bool { appState.currentUser?.isAccountant == true }

    /// The user the float is being raised for — the picked target
    /// when the accountant is acting on behalf, otherwise the
    /// signed-in user themselves.
    private var effectiveUser: AppUser? {
        if !targetUserId.isEmpty, let u = UsersData.byId[targetUserId] { return u }
        return appState.currentUser
    }

    /// The department the float is raised against — always driven by
    /// `effectiveUser` so accountants see the target's department
    /// after they pick a user.
    private var effectiveDepartmentId: String {
        effectiveUser?.departmentId ?? ""
    }

    private var effectiveDepartmentLabel: String {
        if let u = effectiveUser, !u.displayDepartment.isEmpty {
            return u.displayDepartment
        }
        // Fall back to resolving by id so an unusual user record
        // without a pre-computed `displayDepartment` still shows a
        // readable name.
        if let d = DepartmentsData.all.first(where: {
            $0.id == effectiveDepartmentId || $0.identifier == effectiveDepartmentId
        }) {
            return d.displayName
        }
        return "—"
    }

    /// Full user list for the picker — all crew members with a
    /// displayable name. Matches the web's USER_OPTIONS.
    private var userPickerOptions: [DropdownOption] {
        UsersData.allUsers.compactMap { u -> DropdownOption? in
            guard let id = u.id else { return nil }
            let desig = u.displayDesignation.isEmpty ? "" : " (\(u.displayDesignation))"
            return DropdownOption(id, "\(u.fullName ?? id)\(desig)")
        }
    }

    /// System field labels we already render with dedicated UI — any
    /// template field whose `label` is NOT in this set AND is not a
    /// system default is treated as a custom field and rendered in
    /// the "Additional Fields" section.
    private let knownFieldLabels: Set<String> = [
        "user_id", "department_id",
        "requested_amount", "req_amount",
        "duration_type", "duration",
        "start_date", "collect_date", "collect_time",
        "collection_method", "purpose", "episode"
    ]

    /// Custom fields discovered in the current float form template —
    /// anything the admin added beyond the system-default schema.
    private var customFields: [FormField] {
        guard let sections = appState.floatFormTemplate?.template else { return [] }
        return sections
            .flatMap { $0.visibleFields }
            .filter { !$0.isSystemDefault && !knownFieldLabels.contains($0.label ?? "") }
    }

    private let howLongOptions: [(String, String)] = [
        ("run_of_show", "Run of Show"),
        ("days", "Days")
    ]

    private var howLongDisplay: String {
        if howLongMode.isEmpty { return "— Select —" }
        return howLongOptions.first { $0.0 == howLongMode }?.1 ?? "— Select —"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header banner
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle").font(.system(size: 14)).foregroundColor(.goldDark)
                    Text("Crew Portal — \(appState.currentUser?.fullName ?? "") (\(appState.currentUser?.displayDepartment ?? ""))")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.goldDark)
                    Text("· Requesting a new petty cash float.").font(.system(size: 11)).foregroundColor(.secondary)
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gold.opacity(0.06)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.2), lineWidth: 1))

                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Request a Petty Cash Float").font(.system(size: 18, weight: .bold))
                    Text("Float requests are reviewed by the production accountant. You'll receive a notification once approved and cash is ready to collect.")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }

                // Float Details form
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Float Details").font(.system(size: 15, weight: .bold))
                        Spacer()
                        Text("NEW REQUEST").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
                    }

                    // User + Department
                    //
                    // Crew users: both fields are pre-filled + read-only.
                    // Accountants: USER becomes a searchable picker so
                    // they can raise a float on behalf of any crew
                    // member. DEPARTMENT then mirrors the target user's
                    // department instead of the accountant's own.
                    HStack(alignment: .top, spacing: 10) {
                        if isAccountant {
                            accountantUserPicker
                                .frame(maxWidth: .infinity)
                        } else {
                            formReadOnly("USER *", appState.currentUser?.fullName ?? "—")
                                .frame(maxWidth: .infinity)
                        }
                        formReadOnly("DEPARTMENT *", effectiveDepartmentLabel)
                            .frame(maxWidth: .infinity)
                    }
                    Text(isAccountant
                        ? "Select the crew member this float is for. Department auto-fills from their profile."
                        : "Pre-filled from your Zillit profile")
                        .font(.system(size: 10)).foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)

                    // Requested Amount + Start Date
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            labelRequired("REQUESTED AMOUNT")
                            TextField("£0.00", text: $reqAmount)
                                .font(.system(size: 14, design: .monospaced)).keyboardType(.decimalPad)
                                .padding(.horizontal, 10)
                                .frame(height: 40)
                                .background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            Text("Max single float: £500 · your dept limit: £400")
                                .font(.system(size: 9)).foregroundColor(.gray)
                                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("START DATE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            datePickerCell(date: $startDate)
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // How Long (Run of Show / Days)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HOW LONG").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        HStack(spacing: 10) {
                            Button(action: { showHowLongSheet = true }) {
                                HStack {
                                    Text(howLongDisplay)
                                        .font(.system(size: 14))
                                        .foregroundColor(howLongMode.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                                }
                                .padding(10).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .frame(maxWidth: .infinity)
                            // How Long → bottom sheet picker
                            .sheet(isPresented: $showHowLongSheet) {
                                PickerSheetView(
                                    selection: $howLongMode,
                                    options: howLongOptions.map { DropdownOption($0.0, $0.1) },
                                    isPresented: $showHowLongSheet
                                )
                            }

                            if howLongMode == "days" {
                                TextField("e.g. 7", text: $durationDays)
                                    .font(.system(size: 14, design: .monospaced)).keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .padding(10).background(Color.bgRaised).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                                    .frame(width: 90)
                            }
                        }
                        Text("Run of Show = open until production wraps")
                            .font(.system(size: 9)).foregroundColor(.gray)
                    }

                    // Preferred Collection Method
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PREFERRED COLLECTION METHOD").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        Button(action: { showCollectionSheet = true }) {
                            HStack {
                                Text(collectionOptions.first { $0.0 == collectionMethod }?.1 ?? "Select")
                                    .font(.system(size: 14)).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                            }
                            .padding(10).background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .frame(maxWidth: .infinity)
                        // Collection Method → bottom sheet picker
                        .sheet(isPresented: $showCollectionSheet) {
                            PickerSheetView(
                                selection: $collectionMethod,
                                options: collectionOptions.map { DropdownOption($0.0, $0.1) },
                                isPresented: $showCollectionSheet
                            )
                        }
                    }

                    // Collect Date + Collect Time
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COLLECT DATE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            datePickerCell(date: $collectDate)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("COLLECT TIME").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            timePickerCell(time: $collectTime)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Purpose / Reason
                    VStack(alignment: .leading, spacing: 4) {
                        labelRequired("PURPOSE/REASON")
                        MultilineTextView(text: $purpose, placeholder: "Please be specific. Vague descriptions may delay approval.")
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(Color.bgRaised)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        Text("Please be specific. Vague descriptions may delay approval.")
                            .font(.system(size: 9)).foregroundColor(.gray)
                    }
                }
                .padding(14).background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // ── Additional Fields (form-template driven) ──
                // Renders any admin-defined custom fields from the
                // loaded float form template (e.g. "New Field Custom").
                // Values are written back via `custom_fields` on submit
                // — matches the web's PCFloatRequestPage behaviour.
                if !customFields.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Additional Fields")
                            .font(.system(size: 15, weight: .bold))
                        ForEach(customFields) { field in
                            customFieldRow(field)
                        }
                    }
                    .padding(14)
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }

                // Info
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                    Text("You must retain all original receipts. Submit via the Zillit portal within 48 hours of each purchase. Unreceipted items cannot be reimbursed and will be deducted from your float.")
                        .font(.system(size: 11)).foregroundColor(.goldDark)
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gold.opacity(0.06)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.2), lineWidth: 1))

                // Error
                if let err = submitError {
                    Text(err).font(.system(size: 11)).foregroundColor(.red)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.06)).cornerRadius(8)
                }

                // Accountant "just submitted" confirmation — shown for
                // ~4 seconds after a successful on-behalf submission.
                // The form resets underneath so they can immediately
                // raise another float without navigating away.
                if isAccountant, accountantSubmittedAt != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14)).foregroundColor(.green)
                        Text("Float submitted. Form reset — raise another or tap back.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.3), lineWidth: 1))
                }

                // Submit button (full-width)
                Button(action: submitFloat) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(submitted ? "Submitted" : submitting ? "Submitting..." : "Submit Float Request")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(submitted ? Color.green : Color.orange).cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(submitting || submitted)

            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 20)
        }
        .onAppear {
            // Fetch the float request form template so dynamic fields reflect the
            // latest server configuration (GET /form-templates?module=float_requests).
            appState.loadFloatFormTemplate()
            // Accountant default — seed the USER picker with the
            // signed-in accountant's own id so the form lands with
            // both USER and DEPARTMENT pre-selected. Swapping the
            // picker to another crew member reactively updates
            // DEPARTMENT via `effectiveUser` / `effectiveDepartmentLabel`.
            if isAccountant && targetUserId.isEmpty,
               let uid = appState.currentUser?.id, !uid.isEmpty {
                targetUserId = uid
            }
        }
    }

    /// Searchable user picker shown to accountants in place of the
    /// read-only USER field. Matches the web's `SearchableSelect`
    /// over `USER_OPTIONS`, and writes the picked user's id into
    /// `targetUserId` — the payload builder ships this as
    /// `target_user_id` when non-empty.
    ///
    /// Placeholder shows "Select crew member…" when nothing has been
    /// picked, then displays "Full Name (Designation)" once the
    /// accountant chooses someone. Department updates reactively via
    /// `effectiveUser` → `effectiveDepartmentLabel`.
    private var accountantUserPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text("USER").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                Text("*").font(.system(size: 9, weight: .bold)).foregroundColor(.red)
            }
            PickerField(
                selection: $targetUserId,
                placeholder: "Select crew member…",
                options: userPickerOptions
            )
        }
    }

    private func formReadOnly(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(.system(size: 14)).padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    /// Label with a small red asterisk to indicate a required field.
    @ViewBuilder
    private func labelRequired(_ text: String) -> some View {
        HStack(spacing: 2) {
            Text(text).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text("*").font(.system(size: 9, weight: .bold)).foregroundColor(.red)
        }
    }

    /// Inline date picker cell — delegates to the shared `DateField`
    /// component so empty-tap opens the calendar (no auto-today) and
    /// selected dates render as `dd/MM/yyyy` with an X clear button,
    /// matching every other date field in the app.
    @ViewBuilder
    private func datePickerCell(date: Binding<Date?>) -> some View {
        DateField(date: date, placeholder: "Select date")
    }

    /// Inline time picker cell — placeholder "--:-- --" when unset.
    @ViewBuilder
    private func timePickerCell(time: Binding<Date?>) -> some View {
        if time.wrappedValue != nil {
            HStack(spacing: 6) {
                DatePicker("", selection: Binding(
                    get: { time.wrappedValue ?? Date() },
                    set: { time.wrappedValue = $0 }
                ), displayedComponents: .hourAndMinute).labelsHidden()
                Spacer(minLength: 0)
                Button(action: { time.wrappedValue = nil }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.gray)
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(Color.bgRaised).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        } else {
            Button(action: { time.wrappedValue = Date() }) {
                HStack {
                    Text("--:-- --").font(.system(size: 14)).foregroundColor(.gray)
                    Spacer()
                    Image(systemName: "clock").font(.system(size: 12)).foregroundColor(.goldDark)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }.buttonStyle(BorderlessButtonStyle())
        }
    }

    private func formatDate(_ d: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"; return df.string(from: d)
    }

    /// One custom-field row. Mirrors the web's `renderCustomField(...)`
    /// in `PCFloatRequestPage.jsx`:
    ///
    ///   • `select` branches on `selection_type` — vendor, department,
    ///     user, account_code, vat, currency, country, exp_type, tags.
    ///   • `textarea` → multi-line TextEditor (iOS 14+ — plain
    ///     TextField on iOS 13 since TextEditor is unavailable).
    ///   • `date` → shared `DateField` component (same one PO / invoice
    ///     flows use).
    ///   • `number` → decimal-pad keyboard.
    ///   • `email` / `phone` / `url` → appropriate keyboard types.
    ///   • default → plain text.
    ///
    /// Required fields show an amber asterisk; everything else shows
    /// a muted "(optional)" tag. Per-field validation errors render
    /// below the input.
    @ViewBuilder
    private func customFieldRow(_ field: FormField) -> some View {
        let key = field.label ?? field.name ?? ""
        VStack(alignment: .leading, spacing: 4) {
            // Label row — bold uppercase name + required/optional marker.
            HStack(spacing: 4) {
                Text((field.name ?? key).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.4)
                if field.isRequired {
                    Text("*")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.goldDark)
                } else {
                    Text("(optional)")
                        .font(.system(size: 9))
                        .italic()
                        .foregroundColor(.gray)
                }
            }
            customFieldInput(field, key: key)
            if let err = customFieldErrors[key] {
                Text(err).font(.system(size: 10)).foregroundColor(.red)
            }
        }
    }

    /// Input component for a single custom field — routes by
    /// `type` + `selection_type` so the user gets the same control
    /// the web shows.
    @ViewBuilder
    private func customFieldInput(_ field: FormField, key: String) -> some View {
        let textBinding = Binding<String>(
            get: { customFieldValues[key] ?? "" },
            set: { customFieldValues[key] = $0; customFieldErrors[key] = nil }
        )

        switch (field.type ?? "text").lowercased() {
        case "select":
            customSelectInput(field: field, binding: textBinding)

        case "textarea":
            // iOS 13 has no TextEditor — fall back to a plain TextField
            // (single-line) since multi-line entry isn't critical.
            if #available(iOS 14.0, *) {
                TextEditor(text: textBinding)
                    .font(.system(size: 14))
                    .frame(minHeight: 80, alignment: .topLeading)
                    .padding(6)
                    .background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            } else {
                TextField(field.name ?? "Enter value", text: textBinding)
                    .font(.system(size: 14))
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }

        case "date":
            // Store dates as ISO `yyyy-MM-dd` strings (same shape the
            // web emits) so the payload round-trips with the existing
            // server validator. `DateField` is the same component
            // used everywhere else in the app.
            DateField(date: Binding<Date?>(
                get: { parseISODate(customFieldValues[key]) },
                set: { d in
                    customFieldValues[key] = d.map(formatISODate) ?? ""
                    customFieldErrors[key] = nil
                }
            ))

        case "number":
            TextField("0", text: textBinding)
                .font(.system(size: 14, design: .monospaced))
                .keyboardType(.decimalPad)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))

        default:
            TextField(field.name ?? "Enter value", text: textBinding)
                .font(.system(size: 14))
                .keyboardType(keyboardType(for: field.type))
                .autocapitalization((field.type ?? "").lowercased() == "email" ? .none : .sentences)
                .disableAutocorrection((field.type ?? "").lowercased() == "email" || (field.type ?? "").lowercased() == "url")
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    /// `select`-type custom field — branches on `selection_type`.
    /// Mirrors the web's per-`ST` branch list exactly so the picker
    /// uses the same option source.
    @ViewBuilder
    private func customSelectInput(field: FormField, binding: Binding<String>) -> some View {
        let st = (field.selectionType ?? "").lowercased()
        switch st {
        case "vendor":
            // Same search-as-you-type vendor picker used by Create PO
            // (`VendorSearchField` in Views/PurchaseOrders/). Shows
            // name + contact + email, filters live, and closes once
            // a vendor is tapped. Uses the shared `appState.vendors`
            // list so the results match the PO / Invoice vendor
            // pickers everywhere in the app.
            VendorSearchField(vendorId: binding, vendors: appState.vendors)
        case "department":
            PickerField(
                selection: binding,
                placeholder: "Select department…",
                options: DepartmentsData.sorted.map {
                    DropdownOption($0.identifier ?? "", $0.displayName)
                }
            )
        case "user":
            PickerField(
                selection: binding,
                placeholder: "Select user…",
                options: UsersData.allUsers.compactMap { u -> DropdownOption? in
                    guard let id = u.id else { return nil }
                    let desig = u.displayDesignation.isEmpty ? "" : " (\(u.displayDesignation))"
                    return DropdownOption(id, "\(u.fullName ?? id)\(desig)")
                }
            )
        case "account_code":
            PickerField(
                selection: binding,
                placeholder: "Select account code…",
                options: NominalCodes.all.map {
                    DropdownOption($0.code, "\($0.code) — \($0.label)")
                }
            )
        case "vat":
            PickerField(
                selection: binding,
                placeholder: "Select VAT…",
                options: VATHelpers.options.map { DropdownOption($0.value, $0.label) }
            )
        case "currency":
            PickerField(
                selection: binding,
                placeholder: "Select currency…",
                options: [
                    DropdownOption("GBP", "GBP — British Pound"),
                    DropdownOption("USD", "USD — US Dollar"),
                    DropdownOption("EUR", "EUR — Euro")
                ]
            )
        case "country":
            // `CountryNamePickerSheet` is sheet-presented elsewhere,
            // but for this inline context we expose a PickerField
            // over the shared country list for parity with other
            // select types.
            PickerField(
                selection: binding,
                placeholder: "Select country…",
                options: countryCodes.map { DropdownOption($0.name, "\($0.flag) \($0.name)") }
            )
        case "exp_type":
            PickerField(
                selection: binding,
                placeholder: "Select expenditure type…",
                options: [
                    DropdownOption("Purchase", "Purchase"),
                    DropdownOption("Consumption", "Consumption"),
                    DropdownOption("Rent", "Rent")
                ]
            )
        case "tags":
            // Web stores tags as a comma-separated string entered by
            // the user — treat iOS the same way so the payload matches.
            TextField("e.g. urgent, travel, kit", text: binding)
                .font(.system(size: 14))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        default:
            // Unknown selection type — fall through to plain text so
            // the user isn't stuck with an empty picker.
            TextField(field.name ?? "Enter value", text: binding)
                .font(.system(size: 14))
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    /// Map a FormField type hint → keyboard preset. Falls back to
    /// `.default` for anything unknown (matches the web's generic
    /// text input for custom fields).
    private func keyboardType(for type: String?) -> UIKeyboardType {
        switch (type ?? "").lowercased() {
        case "number", "numeric", "decimal":
            return .decimalPad
        case "email":
            return .emailAddress
        case "phone", "tel":
            return .phonePad
        case "url":
            return .URL
        default:
            return .default
        }
    }

    // MARK: - ISO date helpers (custom-field date round-trip)

    private static let isoDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df
    }()

    private func parseISODate(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        return Self.isoDateFormatter.date(from: s)
    }

    private func formatISODate(_ d: Date) -> String {
        Self.isoDateFormatter.string(from: d)
    }

    // MARK: - Custom field validation + payload shaping

    /// Per-type validation matching the web's submit handler.
    /// Returns a non-empty error string when the value fails the
    /// field's rules; `nil` when it passes.
    private func validateCustomField(_ field: FormField, rawValue: String) -> String? {
        let val = rawValue.trimmingCharacters(in: .whitespaces)
        // Required check — runs against trimmed input so whitespace-only
        // doesn't satisfy the gate.
        if field.isRequired && val.isEmpty {
            return "\(field.name ?? "This field") is required"
        }
        guard !val.isEmpty else { return nil }
        switch (field.type ?? "").lowercased() {
        case "email":
            let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
            if val.range(of: pattern, options: .regularExpression) == nil {
                return "\(field.name ?? "Email") must be a valid email address"
            }
        case "url":
            // Web uses a loose `.+\..+` pattern — mirror it rather
            // than attempting strict URL parsing.
            if val.range(of: #"^.+\..+$"#, options: .regularExpression) == nil {
                return "\(field.name ?? "URL") must be a valid URL"
            }
        case "number":
            if Double(val) == nil {
                return "\(field.name ?? "Value") must be a number"
            }
        case "phone":
            // Allow digits, spaces, `+`, `-`, `(`, `)` with min 6 chars
            // (same as the web's `/^[\d\s\+\-\(\)]{6,}$/`).
            if val.range(of: #"^[\d\s\+\-\(\)]{6,}$"#, options: .regularExpression) == nil {
                return "\(field.name ?? "Phone") must be a valid phone number"
            }
        default:
            break
        }
        return nil
    }

    /// Build the PO-style `custom_fields` array for the submit body.
    /// Groups every non-empty custom value by its template section,
    /// preserving full field metadata so the server can re-render the
    /// values with correct type/selection handling on the web.
    ///
    /// Shape:
    /// ```
    /// [{
    ///   "section": "Float Request",
    ///   "fields": [
    ///     { "name": "Budget Code", "label": "budget_code",
    ///       "type": "select", "selection_type": "account_code",
    ///       "value": "1234" }
    ///   ]
    /// }]
    /// ```
    private func buildCustomFieldsPayload() -> [[String: Any]] {
        guard let sections = appState.floatFormTemplate?.template else { return [] }
        var out: [[String: Any]] = []
        for section in sections {
            let fields = (section.fields ?? []).filter { f in
                guard !f.isSystemDefault, !f.isHidden else { return false }
                let label = f.label ?? f.name ?? ""
                let val = (customFieldValues[label] ?? "").trimmingCharacters(in: .whitespaces)
                return !val.isEmpty
            }
            if fields.isEmpty { continue }
            let fieldPayloads: [[String: Any]] = fields.map { f in
                let label = f.label ?? f.name ?? ""
                var entry: [String: Any] = [
                    "name":  f.name ?? label,
                    "label": label,
                    "type":  f.type ?? "text",
                    "value": customFieldValues[label] ?? ""
                ]
                if let st = f.selectionType, !st.isEmpty {
                    entry["selection_type"] = st
                }
                return entry
            }
            out.append([
                "section": section.label ?? section.key ?? "Float Request",
                "fields":  fieldPayloads
            ])
        }
        return out
    }

    private func submitFloat() {
        guard appState.currentUser != nil else { return }
        guard let amount = Double(reqAmount), amount > 0 else { submitError = "Enter a valid amount"; return }
        guard !purpose.trimmingCharacters(in: .whitespaces).isEmpty else { submitError = "Purpose is required"; return }
        // Accountants on-behalf: must pick the crew member before
        // submitting; the server requires a target user id.
        if isAccountant && targetUserId.isEmpty {
            submitError = "Select the crew member to raise the float for."
            return
        }
        submitting = true; submitError = nil

        var body: [String: Any] = [
            // `effectiveDepartmentId` is the target user's dept when
            // an accountant is acting on behalf, otherwise the
            // signed-in user's own dept.
            "department_id": effectiveDepartmentId,
            "req_amount": amount,
            "collection_method": collectionMethod,
            "purpose": purpose
        ]

        // Accountant → flag the float's true owner. The server keeps
        // `created_by = authenticatedUser` and sets `user_id` to the
        // target so the float lands under the right crew member's
        // queue. Omitted when the user is raising for themselves.
        if isAccountant && !targetUserId.isEmpty {
            body["target_user_id"] = targetUserId
        }

        // How long: either "run_of_show" (open-ended) or explicit day count
        if howLongMode == "run_of_show" {
            body["duration"] = "run_of_show"
        } else if howLongMode == "days", let days = Int(durationDays), days > 0 {
            body["duration"] = String(days)
        }

        if let d = startDate {
            body["start_date"] = Int64(d.timeIntervalSince1970 * 1000)
        }
        if let d = collectDate {
            body["collect_date"] = Int64(d.timeIntervalSince1970 * 1000)
        }
        if let t = collectTime {
            let df = DateFormatter(); df.dateFormat = "HH:mm"
            body["collect_time"] = df.string(from: t)
        }

        // Validate every custom field first — required + per-type
        // rules (email / url / number / phone). Any failures are
        // surfaced inline under each field and the submit is aborted.
        var newErrors: [String: String] = [:]
        for f in customFields {
            let label = f.label ?? f.name ?? ""
            let raw = customFieldValues[label] ?? ""
            if let err = validateCustomField(f, rawValue: raw) {
                newErrors[label] = err
            }
        }
        customFieldErrors = newErrors
        if !newErrors.isEmpty {
            submitting = false
            submitError = "Please fix the highlighted fields."
            return
        }

        // Custom fields ship as a PO-style array of sections, matching
        // the web payload exactly. Each entry carries the field's
        // display name, internal label, type, optional selection_type
        // and the current value so the server can round-trip the
        // data with full metadata.
        let customFieldsPayload = buildCustomFieldsPayload()
        if !customFieldsPayload.isEmpty {
            body["custom_fields"] = customFieldsPayload
        }

        appState.submitFloatRequest(body) { success, error in
            submitting = false
            if success {
                submitted = true
                if isAccountant {
                    // Accountant raised on behalf of someone — reset
                    // the form state and stay on the page so they
                    // can raise another without navigating back.
                    // Mirrors the web's behaviour in commit 91ceec4f.
                    resetFormForAccountant()
                } else {
                    // Crew path — brief "Submitted" confirmation,
                    // then pop back to the list so they can see the
                    // active float sitting at the top.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            else { submitError = error ?? "Failed to submit" }
        }
    }

    /// Clears form state after an accountant submits so they can
    /// immediately raise another float. Keeps the confirmation
    /// banner visible via `accountantSubmittedAt`. Re-seeds the
    /// USER picker to the signed-in accountant so the form lands
    /// back on its default state (matches the initial `.onAppear`
    /// seed) — they can pick a different crew member if the next
    /// float is on behalf of someone else.
    private func resetFormForAccountant() {
        targetUserId = appState.currentUser?.id ?? ""
        reqAmount = ""
        startDate = nil
        howLongMode = ""
        durationDays = ""
        collectionMethod = "production_office"
        collectDate = nil
        collectTime = nil
        purpose = ""
        customFieldValues = [:]
        customFieldErrors = [:]
        submitError = nil
        submitted = false
        accountantSubmittedAt = Date()
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Calendar Picker Sheet
// ═══════════════════════════════════════════════════════════════════
