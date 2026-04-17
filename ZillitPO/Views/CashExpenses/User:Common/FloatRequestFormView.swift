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

                    // User + Department (read-only)
                    HStack(alignment: .top, spacing: 10) {
                        formReadOnly("USER *", appState.currentUser?.fullName ?? "—")
                            .frame(maxWidth: .infinity)
                        formReadOnly("DEPARTMENT *", appState.currentUser?.displayDepartment ?? "—")
                            .frame(maxWidth: .infinity)
                    }
                    Text("Pre-filled from your Zillit profile").font(.system(size: 10)).foregroundColor(.gray)

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
                            .selectionActionSheet(
                                title: "How Long",
                                isPresented: $showHowLongSheet,
                                options: howLongOptions.map { $0.0 },
                                isSelected: { $0 == howLongMode },
                                label: { key in howLongOptions.first { $0.0 == key }?.1 ?? key },
                                onSelect: { howLongMode = $0 }
                            )

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
                        .selectionActionSheet(
                            title: "Collection Method",
                            isPresented: $showCollectionSheet,
                            options: collectionOptions.map { $0.0 },
                            isSelected: { $0 == collectionMethod },
                            label: { key in collectionOptions.first { $0.0 == key }?.1 ?? key },
                            onSelect: { collectionMethod = $0 }
                        )
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

    private func submitFloat() {
        guard let user = appState.currentUser else { return }
        guard let amount = Double(reqAmount), amount > 0 else { submitError = "Enter a valid amount"; return }
        guard !purpose.trimmingCharacters(in: .whitespaces).isEmpty else { submitError = "Purpose is required"; return }
        submitting = true; submitError = nil

        var body: [String: Any] = [
            "department_id": user.departmentId ?? "",
            "req_amount": amount,
            "collection_method": collectionMethod,
            "purpose": purpose
        ]

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

        appState.submitFloatRequest(body) { success, error in
            submitting = false
            if success {
                submitted = true
                // Give the user a brief "Submitted" confirmation then pop back
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            else { submitError = error ?? "Failed to submit" }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Calendar Picker Sheet
// ═══════════════════════════════════════════════════════════════════
