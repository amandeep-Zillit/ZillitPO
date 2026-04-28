import SwiftUI

struct RecordCashReturnPage: View {
    let floats: [FloatRequest]
    /// Optional float id to preselect on appear — used when the page is
    /// opened from a specific float's detail page so the user doesn't
    /// have to pick again. When nil, the picker starts empty.
    var preselectedFloatId: String? = nil
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedFloatId: String = ""
    @State private var amountText: String = ""
    // Optional so the field starts empty (no auto-today) — matches the
    // standard behaviour of the reusable `DateField` component. Guarded
    // on submit below.
    @State private var receivedDate: Date? = nil
    @State private var returnReason: String = "close_full_return"
    /// Sub-option when `returnReason == "other"` — maps to
    /// `close_other` / `continue_other` on submit.
    @State private var otherAction: String = "close"
    @State private var notes: String = ""
    @State private var submitting: Bool = false
    @State private var errorMessage: String?
    @State private var showFloatPicker: Bool = false
    @State private var showReasonPicker: Bool = false

    /// Reason options — keys + labels match the web `RETURN_REASONS`.
    private let reasonOptions: [(key: String, label: String)] = [
        ("close_full_return",       "Float closing — full return"),
        ("continue_partial_return", "Partial return — float continues"),
        ("overspend_settlement",    "Overspend settlement — crew paying back"),
        ("cancel_float_return",     "Float cancelled"),
        ("other",                   "Other"),
    ]

    /// Reasons that close the float — the return amount MUST equal the
    /// remaining balance (same rule the web enforces).
    private let fullReturnReasons: Set<String> = [
        "close_full_return", "cancel_float_return",
        "overspend_settlement", "close_other"
    ]

    /// Reasons that keep the float active — returning the full balance
    /// would drain it to zero, which the web rejects.
    private let continueReasons: Set<String> = [
        "continue_partial_return", "continue_other"
    ]

    private var selectedFloat: FloatRequest? {
        floats.first(where: { $0.id == selectedFloatId })
    }

    private var balance: Double { selectedFloat?.remaining ?? 0 }

    private var selectedFloatLabel: String {
        guard let f = selectedFloat else { return "— Select crew member —" }
        let name = UsersData.byId[f.userId ?? ""]?.fullName ?? "—"
        return "\(name) · #\(f.reqNumber ?? "") · Bal: \(FormatUtils.formatGBP(f.remaining))"
    }

    private var selectedReasonLabel: String {
        reasonOptions.first(where: { $0.key == returnReason })?.label ?? "— Select —"
    }

    /// Matches the web logic — splits "other" into close_other/continue_other
    /// based on the radio selection; every other reason passes through.
    private var resolvedReason: String {
        if returnReason == "other" {
            return otherAction == "close" ? "close_other" : "continue_other"
        }
        return returnReason
    }

    /// Button enabled condition — mirrors the web (`!saving && amount`).
    /// Detailed validation (full-return vs continue, amount > balance)
    /// runs inline in `submit()` so the user sees a specific error.
    private var canSubmit: Bool {
        !submitting && !amountText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // Info banner
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill").font(.system(size: 12)).foregroundColor(.blue)
                        Text("Use this to record cash physically returned to production by a crew member — reduces their float balance and updates the cash safe log.")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.06)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2), lineWidth: 1))

                    // Crew Member / Float picker
                    fieldLabel("CREW MEMBER / FLOAT", required: true)
                    Button(action: { showFloatPicker = true }) {
                        HStack {
                            Text(selectedFloatLabel)
                                .font(.system(size: 13))
                                .foregroundColor(selectedFloatId.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                        }
                        .padding(10).frame(maxWidth: .infinity)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .sheet(isPresented: $showFloatPicker) {
                        FloatPickerSheet(
                            floats: floats,
                            selectedId: selectedFloatId
                        ) { pickedId in
                            selectedFloatId = pickedId
                            showFloatPicker = false
                        } onCancel: {
                            showFloatPicker = false
                        }
                    }

                    // Amount + Date (side by side)
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("AMOUNT RETURNED", required: true)
                            TextField("£0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 14))
                                .padding(10).frame(maxWidth: .infinity)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            Text("Cash physically received").font(.system(size: 10)).foregroundColor(.gray)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("DATE RECEIVED", required: true)
                            // DateField styling now matches InputField
                            // siblings directly (padding 10h × 9v,
                            // corner radius 6) — sits side-by-side at
                            // the same height without per-call-site
                            // tuning.
                            DateField(date: $receivedDate,
                                      placeholder: "Select date",
                                      navigationTitle: "Date Received")
                        }
                    }

                    // Return reason
                    fieldLabel("RETURN REASON", required: false)
                    Button(action: { showReasonPicker = true }) {
                        HStack {
                            Text(selectedReasonLabel).font(.system(size: 13)).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                        }
                        .padding(10).frame(maxWidth: .infinity)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    // Return Reason → bottom sheet picker (matches the
                    // rest of the cash-expense form field pickers).
                    .sheet(isPresented: $showReasonPicker) {
                        PickerSheetView(
                            selection: $returnReason,
                            options: reasonOptions.map { DropdownOption($0.key, $0.label) },
                            isPresented: $showReasonPicker
                        )
                    }

                    // "Other" sub-option — close vs continue radio
                    if returnReason == "other" {
                        HStack(spacing: 16) {
                            otherOption(label: "Close the float", value: "close")
                            otherOption(label: "Continue the float", value: "continue")
                            Spacer()
                        }
                    }

                    // Notes
                    fieldLabel("NOTES", required: false)
                    TextField("e.g. Cash returned in person at production office, witnessed by Line Producer…", text: $notes)
                        .font(.system(size: 13))
                        .padding(10).frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                    if let err = errorMessage {
                        Text(err).font(.system(size: 11)).foregroundColor(.red)
                            .padding(.top, 4)
                    }

                    // Bottom spacer to avoid the pinned footer covering the notes field
                    Spacer().frame(height: 80)
                }
                .padding(16)
            }

            // ── Pinned action footer ─────────────────────────────────
            // Cancel button removed — users can back out via the nav
            // bar's Back button. Record Cash Return takes the full
            // width so the primary action is unambiguous.
            Button(action: submit) {
                HStack(spacing: 6) {
                    if submitting { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                    Text(submitting ? "Recording…" : "Record Cash Return")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(canSubmit ? Color.goldDark : Color.gray.opacity(0.4))
                .cornerRadius(10)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(!canSubmit)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Record Manual Cash Return"), displayMode: .inline)
        .onAppear {
            // Auto-select the float when the page is opened from a
            // specific float's detail screen. Only runs once on first
            // appear (leaves any user-changed selection intact).
            if selectedFloatId.isEmpty {
                if let preId = preselectedFloatId,
                   floats.contains(where: { $0.id == preId }) {
                    selectedFloatId = preId
                } else if floats.count == 1 {
                    // Convenience: if the caller passed a single-float
                    // list (e.g., from FloatDetailView), use it directly.
                    selectedFloatId = floats[0].id ?? ""
                }
            }
        }
    }

    private func fieldLabel(_ text: String, required: Bool) -> some View {
        HStack(spacing: 2) {
            Text(text).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            if required { Text("*").font(.system(size: 10, weight: .bold)).foregroundColor(.red) }
        }
    }

    /// Custom radio button for the "Other" sub-option row.
    private func otherOption(label: String, value: String) -> some View {
        Button(action: { otherAction = value }) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(otherAction == value ? Color.goldDark : Color.gray.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    if otherAction == value {
                        Circle().fill(Color.goldDark).frame(width: 7, height: 7)
                    }
                }
                Text(label).font(.system(size: 12)).foregroundColor(.primary)
            }
            .contentShape(Rectangle())
        }.buttonStyle(BorderlessButtonStyle())
    }

    /// Validates + submits — mirrors the web's detailed guards so
    /// errors surface the same way they do on the desktop form.
    private func submit() {
        errorMessage = nil
        // Float selected?
        guard !selectedFloatId.isEmpty else {
            errorMessage = "Please select a crew member / float."
            return
        }
        // Amount valid?
        let raw = amountText.trimmingCharacters(in: .whitespaces)
        guard let amt = Double(raw), amt > 0 else {
            errorMessage = "Please enter a valid return amount."
            return
        }
        // Amount not more than remaining balance
        if amt > balance + 0.005 {
            errorMessage = "Return amount \(FormatUtils.formatGBP(amt)) exceeds the remaining balance of \(FormatUtils.formatGBP(balance))."
            return
        }
        let reasonKey = resolvedReason
        // Closing/cancelling → amount MUST equal the full balance
        if fullReturnReasons.contains(reasonKey) && abs(amt - balance) > 0.005 {
            errorMessage = "This option will close the float. The return amount must be the full remaining balance of \(FormatUtils.formatGBP(balance))."
            return
        }
        // Continue options can't drain the balance to zero
        if continueReasons.contains(reasonKey) && abs(amt - balance) < 0.005 {
            errorMessage = "Returning the full balance of \(FormatUtils.formatGBP(balance)) will leave the float with zero balance. Choose a close option instead, or reduce the return amount."
            return
        }

        guard let chosenDate = receivedDate else {
            errorMessage = "Please pick the date the cash was received."
            return
        }
        submitting = true
        let dateMs = Int64(chosenDate.timeIntervalSince1970 * 1000)
        appState.recordFloatReturn(
            id: selectedFloatId,
            amount: amt,
            dateMs: dateMs,
            reason: reasonKey,
            notes: notes.trimmingCharacters(in: .whitespaces)
        ) { success, err in
            submitting = false
            if success {
                // Reset + dismiss — matches the web behaviour.
                amountText = ""
                notes = ""
                returnReason = "close_full_return"
                otherAction = "close"
                selectedFloatId = ""
                errorMessage = nil
                presentationMode.wrappedValue.dismiss()
            } else {
                errorMessage = err ?? "Failed to record cash return."
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Float Picker Sheet
// Searchable list of crew members with their float ref + balance.
// Replaces the compact action-sheet picker that could only show a
// single text label per option and ran out of vertical room quickly.
// ═══════════════════════════════════════════════════════════════════

struct FloatPickerSheet: View {
    let floats: [FloatRequest]
    let selectedId: String
    var onPick: (String) -> Void
    var onCancel: () -> Void

    @State private var searchText: String = ""

    /// Only floats that currently hold cash AND are in a status where a
    /// return makes sense:
    ///   • COLLECTED      — cash has been handed over, some may come back
    ///   • SPENT          — receipts exhausted the cash but return still possible
    ///   • PENDING_RETURN — already flagged as awaiting physical return
    /// `ACTIVE`/`SPENDING` floats are still being used and aren't typically
    /// closed out via the return flow; closed/cancelled ones have nothing
    /// left to return.
    private var eligible: [FloatRequest] {
        let allowed: Set<String> = ["COLLECTED", "SPENT", "PENDING_RETURN"]
        return floats.filter { f in
            allowed.contains((f.status ?? "").uppercased()) && f.remaining > 0.005
        }
    }

    private var filtered: [FloatRequest] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return eligible }
        return eligible.filter { f in
            let name = (UsersData.byId[f.userId ?? ""]?.fullName ?? "").lowercased()
            let role = UsersData.byId[f.userId ?? ""]?.displayDesignation.lowercased() ?? ""
            return name.contains(q)
                || role.contains(q)
                || (f.reqNumber ?? "").lowercased().contains(q)
                || (f.department ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgBase.edgesIgnoringSafeArea(.all)
                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12)).foregroundColor(.gray)
                        TextField("Search crew, department, ref…", text: $searchText)
                            .font(.system(size: 13))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12)).foregroundColor(.gray)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.bgSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

                    // List
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text(searchText.isEmpty
                                 ? "No floats with cash to return"
                                 : "No floats match \"\(searchText)\"")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(filtered) { f in
                                    Button(action: { onPick(f.id ?? "") }) {
                                        floatRow(f)
                                    }.buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8).padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationBarTitle(Text("Select Float"), displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Cancel", action: onCancel).foregroundColor(.goldDark)
            )
        }
    }

    private func floatRow(_ f: FloatRequest) -> some View {
        let user = UsersData.byId[f.userId ?? ""]
        let name = user?.fullName ?? "—"
        let role = user?.displayDesignation ?? ""
        let dept = (f.department ?? "").isEmpty ? (user?.displayDepartment ?? "") : f.department!
        let isSelected = selectedId == f.id
        return HStack(alignment: .center, spacing: 12) {
            // Avatar
            ZStack {
                Circle().fill(Color.gold.opacity(0.18)).frame(width: 36, height: 36)
                Text(user?.initials ?? "—")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.goldDark)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 14, weight: .bold)).foregroundColor(.primary).lineLimit(1)
                // Role · Department
                let subtitle: String = {
                    switch (role.isEmpty, dept.isEmpty) {
                    case (false, false): return "\(role) · \(dept)"
                    case (false, true):  return role
                    case (true, false):  return dept
                    default:             return ""
                    }
                }()
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                }
                Text("#\(f.reqNumber ?? "")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.goldDark)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("BALANCE").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).tracking(0.4)
                Text(FormatUtils.formatGBP(f.remaining))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.goldDark)
            }
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16)).foregroundColor(.green)
                    .padding(.leading, 4)
            }
        }
        .padding(12)
        .background(isSelected ? Color.gold.opacity(0.08) : Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
            isSelected ? Color.goldDark : Color.borderColor,
            lineWidth: isSelected ? 2 : 1))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Float Approval Detail Page (full breakdown for approvers)
// ═══════════════════════════════════════════════════════════════════
