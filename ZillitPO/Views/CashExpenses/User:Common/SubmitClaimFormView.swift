import SwiftUI
import UIKit

struct SubmitClaimFormView: View {
    var expenseType: String = "pc" // "pc" or "oop"
    @EnvironmentObject var appState: POViewModel

    @State private var receipts: [ClaimReceiptItem] = [ClaimReceiptItem()]
    // Primary settlement is auto-derived ("reimb" or "reduce") — never user-overridable.
    // followUp is an OPTIONAL extra action (independent of the primary):
    //   nil      → no extra action
    //   "top_up" → reimburse this batch back into the float
    //   "close"  → close the float after this batch
    @State private var settlementType: String = ""  // legacy — only used for old reimbursement panel
    @State private var followUp: String? = nil

    // Pending (not-yet-posted) batches against the active float — fetched on appear.
    // Used to compute the *effective* float balance (live balance − pending submissions)
    // so the primary derivation accounts for receipts already in the pipeline.
    @State private var pendingBatches: [ClaimBatch] = []
    private var pendingBatchesTotal: Double {
        pendingBatches.reduce(0) { $0 + ($1.totalGross ?? 0) }
    }
    @State private var reimbMethod: String = "bacs"
    @State private var accountName: String = ""
    @State private var sortCode: String = ""
    @State private var accountNumber: String = ""
    @State private var reimbAmount: String = ""
    @State private var extraFields: [(label: String, value: String)] = []
    @State private var topUpAmount: String = ""
    @State private var notes: String = ""
    @State private var submitting = false
    @State private var submitted = false
    @State private var submitError: String?
    @State private var categorySheetForId: UUID?
    @State private var uploadReceiptId: UUID?
    @State private var navigateToUpload = false
    @State private var receiptDates: [UUID: Date] = [:]
    @State private var receiptDatePickerId: UUID?
    @State private var budgetCodingOpenId: UUID?

    private var batchTotal: Double {
        receipts.reduce(0) { $0 + (Double($1.amount) ?? 0) }
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Step 1: Receipts ──
                stepHeader(number: "1", title: "Add Your Receipts", subtitle: "Upload receipts for your purchases")

                ForEach(receipts) { item in
                    receiptCard(item)
                }

                Button(action: { receipts.append(ClaimReceiptItem()) }) {
                    HStack {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        Text("Add Another Receipt").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.goldDark).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())

                Divider()

                // ── Step 2: Settlement / Reimbursement ──
                if expenseType == "pc" {
                    stepHeader(number: "2", title: "Choose Your Settlement", subtitle: "This will be sent to the accountant with your receipts")

                    settlementStatsBanner
                    primarySettlementCard

                    // When this batch overdraws the float, the primary becomes "Reimburse"
                    // and the user needs to provide reimbursement bank details.
                    // Also show when the user picked "Reimburse to Float" follow-up — the
                    // reimbursement amount goes back to the float, but the form is the same.
                    if autoPrimarySettlement == "reimb" {
                        reimbursementSection
                    }

                    optionalSettlementPills
                    optionalSettlementDetail
                } else {
                    // OOP: always reimbursement
                    stepHeader(number: "2", title: "Reimbursement Method", subtitle: "How would you like to be paid back?")
                    reimbursementSection
                }

                // ── Notes ──
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADDITIONAL NOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                    MultilineTextView(text: $notes, placeholder: "Any additional context for the accountant…")
                        .frame(maxWidth: .infinity, minHeight: 70)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }

                // ── Error ──
                if let err = submitError {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        Text(err).font(.system(size: 11)).foregroundColor(.red)
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.06)).cornerRadius(8)
                }

                // ── Submit (full-width) ──
                Button(action: submitClaim) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(submitted ? "Submitted" : submitting ? "Submitting..." : "Submit Claim for Coding & Approval")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(submitted ? Color.green : Color.orange).cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(submitting || submitted)

                claimInfoBanner

            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 30)
        }
        .background(
            NavigationLink(destination: ClaimFilePickerPage(onFilePicked: { name, data in
                if let id = uploadReceiptId, let idx = receipts.firstIndex(where: { $0.id == id }) {
                    receipts[idx].fileName = name; receipts[idx].fileData = data
                }
                uploadReceiptId = nil
            }), isActive: $navigateToUpload) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .onAppear {
            // Float + batch data is ONLY needed for Petty Cash. OOP claims
            // are pure reimbursement — they don't touch `myFloats` or
            // `myBatches`, so skipping these loads avoids firing
            // `my-batches?float_request_id=<id>` on an OOP submission
            // where the id would be unrelated to the claim.
            guard expenseType == "pc" else { return }
        }
        .onReceive(appState.$myBatches) { batches in
            // OOP doesn't render pendingBatches — bail out so we don't
            // churn state when an unrelated batches fetch lands.
            guard expenseType == "pc" else { return }
            recomputePendingBatches(from: batches)
        }
        .onReceive(appState.$myFloats) { _ in
            // PC-only. In OOP mode there's no active float concept — any
            // stale float in `myFloats` (e.g. an old PC float Marco Rossi
            // no longer uses, or a cached value from a prior session)
            // would otherwise trigger `my-batches?float_request_id=<id>`
            // with a wrong id while the user is filing an OOP claim.
            guard expenseType == "pc" else { return }
            if let id = activeFloat?.id {
                appState.loadMyBatches(floatRequestId: id)
            } else {
                pendingBatches = []
            }
        }
    }

    /// Filter myBatches to those against the current active float that are still
    /// in the pipeline (not POSTED / REJECTED / CLOSED). These reduce the
    /// effective balance used to derive the primary settlement.
    private func recomputePendingBatches(from batches: [ClaimBatch]) {
        guard let floatId = activeFloat?.id else {
            pendingBatches = []
            return
        }
        let terminal: Set<String> = ["POSTED", "REJECTED", "CLOSED"]
        pendingBatches = batches.filter { b in
            b.floatRequestId == floatId && !terminal.contains((b.status ?? "").uppercased())
        }
    }

    // MARK: - Receipt Card

    private func receiptCard(_ item: ClaimReceiptItem) -> some View {
        let itemId = item.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECEIPT \(receiptIndex(item) + 1)").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                Spacer()
                if receipts.count > 1 {
                    Button(action: { receipts.removeAll { $0.id == itemId } }) {
                        Text("Remove").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(Color.red).cornerRadius(4)
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }

            // File upload
            if item.fileName.isEmpty {
                Button(action: { uploadReceiptId = itemId; navigateToUpload = true }) {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.up.doc").font(.system(size: 22)).foregroundColor(.gray.opacity(0.4))
                        Text("Upload receipt image or PDF").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        Text("Tap to browse · JPG, PNG, PDF").font(.system(size: 10)).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.bgRaised).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundColor(Color.borderColor))
                }.buttonStyle(PlainButtonStyle())
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip").font(.system(size: 11)).foregroundColor(.green)
                    Text(item.fileName).font(.system(size: 12)).foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3)).lineLimit(1)
                    Spacer()
                    Button(action: {
                        if let idx = receipts.firstIndex(where: { $0.id == itemId }) {
                            receipts[idx].fileName = ""; receipts[idx].fileData = nil
                        }
                    }) {
                        Text("Remove").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3).background(Color.red).cornerRadius(4)
                    }.buttonStyle(BorderlessButtonStyle())
                }
                .padding(8).background(Color.green.opacity(0.06)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))
            }

            // Date + Amount
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date of Purchase *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    // Custom binding mirrors the picked Date into both
                    // the `receiptDates` dict (used by the component for
                    // presentation) and the `receipts[idx].date` string
                    // column the rest of the form reads from.
                    DateField(
                        date: Binding<Date?>(
                            get: { receiptDates[itemId] },
                            set: { newDate in
                                receiptDates[itemId] = newDate
                                let df = DateFormatter(); df.dateFormat = "dd/MM/yyyy"
                                if let idx = receipts.firstIndex(where: { $0.id == itemId }) {
                                    receipts[idx].date = newDate.map { df.string(from: $0) } ?? ""
                                }
                            }
                        ),
                        placeholder: "Select date",
                        // Receipts can't be dated in the future.
                        maxDate: Date(),
                        navigationTitle: "Date of Purchase"
                    )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    TextField("£0.00", text: receiptBinding(itemId, \.amount))
                        .font(.system(size: 13, design: .monospaced)).keyboardType(.decimalPad)
                        .padding(8).background(Color.bgRaised).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }
            }

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Description *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                TextField("What did you purchase?", text: receiptBinding(itemId, \.description))
                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }

            // Category dropdown
            VStack(alignment: .leading, spacing: 4) {
                Text("Category").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                Button(action: { categorySheetForId = itemId }) {
                    HStack {
                        Text(claimCategories.first { $0.0 == item.category }?.1 ?? "Materials")
                            .font(.system(size: 13)).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                    }
                    .padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                // Category picker (per-receipt) → searchable bottom
                // sheet. Matches the cost-code + category pickers
                // throughout Card/Cash Expenses.
                .sheet(isPresented: Binding(
                    get: { categorySheetForId == itemId },
                    set: { if !$0 { categorySheetForId = nil } }
                )) {
                    PickerSheetView(
                        selection: Binding<String>(
                            get: {
                                receipts.first { $0.id == itemId }?.category ?? ""
                            },
                            set: { newValue in
                                if let idx = receipts.firstIndex(where: { $0.id == itemId }) {
                                    receipts[idx].category = newValue
                                }
                            }
                        ),
                        options: claimCategories.map { DropdownOption($0.0, $0.1) },
                        isPresented: Binding(
                            get: { categorySheetForId == itemId },
                            set: { if !$0 { categorySheetForId = nil } }
                        )
                    )
                }
            }

            // Budget Coding (collapsible)
            VStack(spacing: 0) {
                Button(action: { budgetCodingOpenId = budgetCodingOpenId == itemId ? nil : itemId }) {
                    HStack(spacing: 6) {
                        Image(systemName: budgetCodingOpenId == itemId ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8)).foregroundColor(.gray)
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                        Text("Budget Coding").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.secondary)
                        Text("Optional — leave blank if unsure").font(.system(size: 10)).foregroundColor(.gray)
                        Spacer()
                        if !item.costCode.isEmpty {
                            Text(item.costCode).font(.system(size: 10, design: .monospaced)).foregroundColor(.green)
                        }
                    }
                    .padding(10).background(Color.bgRaised).contentShape(Rectangle())
                }.buttonStyle(PlainButtonStyle())

                if budgetCodingOpenId == itemId {
                    VStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COST CODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            CostCodePickerButton(selectedCode: receiptBinding(itemId, \.costCode))
                        }
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("EPISODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                                TextField("e.g. Ep.3", text: receiptBinding(itemId, \.episode))
                                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DESCRIPTION").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                                TextField("Coding description (optional)", text: receiptBinding(itemId, \.codedDescription))
                                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                        }
                    }.padding(10)
                    .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
                }
            }
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
        }
        .padding(12).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Helpers

    private func receiptIndex(_ item: ClaimReceiptItem) -> Int {
        receipts.firstIndex(where: { $0.id == item.id }) ?? 0
    }

    private func receiptBinding(_ id: UUID, _ kp: WritableKeyPath<ClaimReceiptItem, String>) -> Binding<String> {
        Binding(
            get: { receipts.first(where: { $0.id == id })?[keyPath: kp] ?? "" },
            set: { val in if let idx = receipts.firstIndex(where: { $0.id == id }) { receipts[idx][keyPath: kp] = val } }
        )
    }

    private var reimbursementSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                reimbOption("Bank Transfer (BACS)", value: "bacs", icon: "building.columns.fill")
                reimbOption("Add to Payroll", value: "payroll", icon: "doc.text.fill")
            }
            if reimbMethod == "bacs" {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        formField("Account Name", text: $accountName)
                        formField("Sort Code", text: $sortCode)
                    }
                    HStack(spacing: 10) {
                        formField("Account Number", text: $accountNumber)
                        formField("Amount", text: $reimbAmount, keyboardType: .decimalPad, placeholder: "£0.00")
                    }

                    // Extra fields
                    ForEach(Array(extraFields.enumerated()), id: \.offset) { idx, _ in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Field name (e.g. IBAN)", text: Binding(
                                    get: { extraFields[idx].label },
                                    set: { extraFields[idx].label = $0 }
                                )).font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Value", text: Binding(
                                    get: { extraFields[idx].value },
                                    set: { extraFields[idx].value = $0 }
                                )).font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            Button(action: { extraFields.remove(at: idx) }) {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundColor(.red.opacity(0.6))
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }

                    // Add additional detail button
                    Button(action: { extraFields.append((label: "", value: "")) }) {
                        Text("+ Add additional detail (IBAN, BIC, routing number, etc.)")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(.goldDark)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundColor(Color.goldDark.opacity(0.4)))
                    }.buttonStyle(BorderlessButtonStyle())
                }
                .padding(12).background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            }
        }
    }

    // ── Info banner ──────────────────────────────────────────────────
    private var claimInfoBanner: some View {
        let info: Text = {
            let plain  = Font.system(size: 11)
            let bold   = Font.system(size: 11, weight: .bold)
            var t = Text("Your claim goes to your ").font(plain)
            t = t + Text("Department Coordinator").font(bold)
            t = t + Text(" for budget coding, then ").font(plain)
            t = t + Text("Accountants").font(bold)
            t = t + Text(" for auditing purposes. You'll be notified at each stage.").font(plain)
            return t
        }()
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill").font(.system(size: 12)).foregroundColor(.blue)
            info.foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2), lineWidth: 1))
    }

    // ── Current user's active float (for balance display) ────────────
    /// Match the web's allow-list of statuses (any spendable / pre-spendable state).
    private var activeFloat: FloatRequest? {
        let allowed: Set<String> = [
            "READY_TO_COLLECT", "COLLECTED", "ACTIVE", "SPENDING",
            "APPROVED", "ACCT_OVERRIDE", "AWAITING_APPROVAL",
            "SPENT", "PENDING_RETURN"
        ]
        return appState.myFloats.first { allowed.contains(($0.status ?? "").uppercased()) }
    }

    /// Live float balance from the server — the running cash remaining on the float.
    /// Mirrors the web's `parseFloat(activeFloat?.balance || 0)`.
    private var floatBalance: Double {
        // FloatRequest exposes `remaining` as a derived property; the server's
        // authoritative `balance` field is set during issue/return/topup, so use
        // remaining as a stand-in (issuedFloat − receiptsAmount − returnAmount).
        activeFloat?.remaining ?? 0
    }

    /// Effective balance = live balance − pending batches not yet posted.
    /// This is what determines whether THIS new batch overdraws the float.
    private var effectiveBalance: Double {
        max(0, floatBalance - pendingBatchesTotal)
    }

    /// Auto-derive the primary settlement: reimburse only if this batch would
    /// overdraw the *effective* balance (live balance − pending batches).
    /// Mirrors web logic `newBatchTotal > effectiveBalance ? "reimburse" : "reduce"`.
    private var autoPrimarySettlement: String {
        batchTotal > effectiveBalance ? "reimb" : "reduce"
    }

    /// Overdraft amount (only meaningful when primary == "reimb").
    private var overdraftAmount: Double {
        max(0, batchTotal - floatBalance)
    }

    // Primary card always reflects the auto-derived settlement — it does NOT
    // change when the user taps an "optional also do one of" pill.
    // Copy mirrors the web's PCSettlementSection.
    private var primaryTitle: String {
        autoPrimarySettlement == "reimb" ? "Reimburse Me" : "Reduce My Float"
    }

    private var primaryDescription: String {
        autoPrimarySettlement == "reimb"
            ? "This batch overdraws your float. The overdraft will be reimbursed to you."
            : "Batch is within float balance — this will reduce your remaining float."
    }

    private var primaryIcon: String {
        autoPrimarySettlement == "reimb"
            ? "arrow.uturn.backward.circle.fill"
            : "chart.line.downtrend.xyaxis"
    }

    // ── Settlement stats banner ──────────────────────────────────────
    private var settlementStatsBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Batch total:").font(.system(size: 10)).foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Text(FormatUtils.formatGBP(batchTotal))
                        .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.primary)
                    Text("· \(receipts.count) receipt\(receipts.count == 1 ? "" : "s")")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            Divider().frame(height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Float balance:").font(.system(size: 10)).foregroundColor(.secondary)
                Text(FormatUtils.formatGBP(floatBalance))
                    .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.primary)
            }
            Spacer()
            Text("PENDING SUBMISSION")
                .font(.system(size: 8, weight: .bold)).tracking(0.5).foregroundColor(.orange)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.orange.opacity(0.12)).cornerRadius(4)
        }
        .padding(12).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // ── Primary settlement card (auto-selected, highlighted) ─────────
    private var primarySettlementCard: some View {
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: primaryIcon).font(.system(size: 18)).foregroundColor(orange)
                    .frame(width: 32, height: 32)
                    .background(orange.opacity(0.12)).cornerRadius(6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryTitle).font(.system(size: 14, weight: .bold))
                    Text(primaryDescription).font(.system(size: 11)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundColor(orange)
            }

            // Cream-colored impact banner — shows overdraft breakdown for reimburse,
            // or the simple "£X will reduce the float" message for reduce.
            HStack {
                Text(primaryImpactText)
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.05))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(orange.opacity(0.08)).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(orange.opacity(0.2), lineWidth: 1))
        }
        .padding(14)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(orange, lineWidth: 1.5))
    }

    /// Impact strip text shown inside the primary card's cream banner.
    /// - reimburse → "Overdraft £X reimbursed · £Y float consumed"
    /// - reduce    → "£X will reduce the float"
    private var primaryImpactText: String {
        if autoPrimarySettlement == "reimb" {
            return "Overdraft \(FormatUtils.formatGBP(overdraftAmount)) reimbursed · "
                + "\(FormatUtils.formatGBP(floatBalance)) float consumed"
        }
        return "\(FormatUtils.formatGBP(batchTotal)) will reduce the float"
    }

    // ── Optional follow-up pills ─────────────────────────────────────
    /// Pills are additive to the primary — tapping toggles selection on/off.
    /// followUp values map to web's: "top_up" (reimburse to float) | "close" (close the float).
    private var optionalSettlementPills: some View {
        let pills: [(String, String)] = [
            ("top_up", "Reimburse to Float"),
            ("close",  "Close the Float"),
        ]
        return VStack(alignment: .leading, spacing: 6) {
            Text("OPTIONAL — ALSO DO ONE OF:")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            HStack(spacing: 8) {
                ForEach(pills, id: \.0) { opt in
                    pillButton(id: opt.0, label: opt.1)
                }
                Spacer()
            }
        }
    }

    private func pillButton(id: String, label: String) -> some View {
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        let active = followUp == id
        return Button(action: {
            // Toggle: tapping the active pill deselects it
            followUp = active ? nil : id
        }) {
            Text(label)
                .font(.system(size: 12, weight: active ? .semibold : .medium))
                .foregroundColor(active ? orange : .primary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(active ? orange.opacity(0.05) : Color.bgSurface)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(active ? orange : Color.borderColor, lineWidth: 1))
        }.buttonStyle(BorderlessButtonStyle())
    }

    // ── Optional detail card (shown below pills when a pill is active) ──
    @ViewBuilder
    private var optionalSettlementDetail: some View {
        if followUp == "top_up" {
            reimburseToFloatBanner
        } else if followUp == "close" {
            closeFloatBreakdown
        }
    }

    private var reimburseToFloatBanner: some View {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundColor(teal)
            (Text(FormatUtils.formatGBP(batchTotal)).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.primary)
             + Text(" will be reimbursed back to your float balance after this batch is posted.")
                .font(.system(size: 12)).foregroundColor(.primary))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(teal.opacity(0.06)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(teal.opacity(0.3), lineWidth: 1))
    }

    private var closeFloatBreakdown: some View {
        // Mirrors web logic exactly:
        //   returnAmount = balance − batchTotal − pendingBatchesTotal
        //   > 0.005     → amber: "Return £X cash to the accountant"
        //   ≈ 0         → green: "No cash to return — this batch will zero out the float"
        //   < -0.005    → red warning: pending batches exceed balance, may be overdrawn
        let amber = Color(red: 0.85, green: 0.5, blue: 0.05)
        let green = Color(red: 0.0, green: 0.55, blue: 0.3)
        let returnAmount = floatBalance - batchTotal - pendingBatchesTotal
        let needsReturn = returnAmount > 0.005
        let isOverdrawn = returnAmount < -0.005
        let bannerColor = needsReturn ? amber : (isOverdrawn ? .red : green)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Close Float").font(.system(size: 14, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                // Status line
                HStack(spacing: 6) {
                    Image(systemName: needsReturn ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.system(size: 11)).foregroundColor(bannerColor)
                    Text(needsReturn
                         ? "Return \(FormatUtils.formatGBP(returnAmount)) cash to the accountant"
                         : "No cash to return — this batch will zero out the float")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(bannerColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Breakdown rows (mirrors web's exact lines)
                VStack(spacing: 4) {
                    breakdownRow(label: "Current float balance", value: FormatUtils.formatGBP(floatBalance), sign: "")
                    breakdownRow(label: "This batch total", value: "−\(FormatUtils.formatGBP(batchTotal))", sign: "−")
                    if pendingBatches.count > 0 {
                        let pluralS = pendingBatches.count == 1 ? "" : "es"
                        breakdownRow(
                            label: "\(pendingBatches.count) pending batch\(pluralS) not yet posted",
                            value: "−\(FormatUtils.formatGBP(pendingBatchesTotal))",
                            sign: "−"
                        )
                    }
                    Divider()
                    breakdownRow(
                        label: "Cash to return",
                        value: FormatUtils.formatGBP(max(0, returnAmount)),
                        sign: "=",
                        bold: true
                    )
                }

                if isOverdrawn {
                    Text("Warning: pending batches exceed the current balance by \(FormatUtils.formatGBP(abs(returnAmount))). You may be overdrawn.")
                        .font(.system(size: 11)).foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .padding(12)
            .background(bannerColor.opacity(0.08)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(bannerColor.opacity(0.3), lineWidth: 1))
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func breakdownRow(label: String, value: String, sign: String, bold: Bool = false) -> some View {
        HStack(spacing: 6) {
            if !sign.isEmpty {
                Text(sign).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.secondary)
                    .frame(width: 10, alignment: .leading)
            }
            Text(label)
                .font(.system(size: 11, weight: bold ? .bold : .regular, design: .monospaced))
                .foregroundColor(bold ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: bold ? .bold : .regular, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    private func settlementOption(id: String, icon: String, title: String, desc: String, color: Color) -> some View {
        let active = settlementType == id
        return Button(action: { settlementType = id }) {
            HStack(spacing: 12) {
                Image(systemName: active ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18)).foregroundColor(active ? color : .gray)
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(active ? color : .gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(active ? color : .primary)
                    Text(desc).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer()
            }
            .padding(12).background(Color.bgSurface).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? color : Color.borderColor, lineWidth: active ? 2 : 1))
        }.buttonStyle(PlainButtonStyle())
    }

    private func formField(_ label: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, placeholder: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            TextField(placeholder ?? label, text: text).font(.system(size: 13)).keyboardType(keyboardType).padding(8)
                .background(Color.bgRaised).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    private func stepHeader(number: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.gold).frame(width: 24, height: 24)
                Text(number).font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
    }

    private func reimbOption(_ label: String, value: String, icon: String) -> some View {
        let active = reimbMethod == value
        let subtitle = value == "bacs" ? "Direct to your bank · 1–3 working days" : "Included in next payroll run"
        return Button(action: { reimbMethod = value }) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(active ? .goldDark : .gray)
                Text(label).font(.system(size: 12, weight: .bold)).foregroundColor(active ? .goldDark : .primary)
                Text(subtitle).font(.system(size: 9)).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color.bgSurface).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(active ? Color.gold : Color.borderColor, lineWidth: active ? 2 : 1))
        }.buttonStyle(PlainButtonStyle())
    }

    // MARK: - Submit

    private func submitClaim() {
        guard let user = appState.currentUser else { return }
        let validReceipts = receipts.filter { !$0.description.isEmpty && !$0.amount.isEmpty }
        guard !validReceipts.isEmpty else { submitError = "Add at least one receipt with description and amount"; return }
        submitting = true; submitError = nil

        let receiptItems: [[String: Any]] = validReceipts.map { r in
            var item: [String: Any] = ["description": r.description, "amount": Double(r.amount) ?? 0, "category": r.category]
            if !r.date.isEmpty { item["date"] = r.date }
            if !r.costCode.isEmpty { item["cost_code"] = r.costCode }
            if !r.episode.isEmpty { item["episode"] = r.episode }
            if !r.codedDescription.isEmpty { item["coded_description"] = r.codedDescription }
            return item
        }

        // settlement_type is ALWAYS the auto-derived primary (REIMBURSE or REDUCE_FLOAT for PC).
        // The optional follow-up pill is sent separately as `settlement_details.follow_up`.
        // Mirrors web payload exactly.
        let settleType: String = {
            if expenseType == "pc" {
                return autoPrimarySettlement == "reimb" ? "REIMBURSE" : "REDUCE_FLOAT"
            }
            // OOP: always reimburse
            return "REIMBURSE"
        }()

        var settlementDetails: [String: Any] = [:]
        let isPrimaryReimburse = (settleType == "REIMBURSE")

        if isPrimaryReimburse {
            settlementDetails["payment_method"] = reimbMethod == "bacs" ? "BACS" : "PAYROLL"
            if reimbMethod == "bacs" {
                var bd: [String: Any] = ["account_name": accountName, "sort_code": sortCode, "account_number": accountNumber]
                let extras = extraFields.filter { !$0.label.isEmpty && !$0.value.isEmpty }.map { ["label": $0.label, "value": $0.value] }
                if !extras.isEmpty { bd["additional_details"] = extras }
                settlementDetails["bank_details"] = bd
            }
        }

        // Optional follow-up action (independent of primary)
        if let fu = followUp {
            settlementDetails["follow_up"] = fu
            if fu == "top_up" {
                // Reimburse the batch back into the float
                settlementDetails["top_up_amount"] = (batchTotal * 100).rounded() / 100
            }
        } else {
            settlementDetails["follow_up"] = NSNull()
        }

        // Promote first receipt's coding info to batch level so the detail view can display it
        let first = validReceipts.first
        let body: [String: Any] = [
            "expense_type": expenseType,
            "department_id": user.departmentId ?? "",
            "float_request_id": activeFloat?.id ?? NSNull(),
            "settlement_type": settleType,
            "settlement_details": settlementDetails,
            "notes": notes,
            "category": first?.category ?? "",
            "cost_code": first?.costCode ?? "",
            "coding_description": first?.codedDescription ?? "",
            "claims": receiptItems,
        ]

        CashExpenseCodableTask.createClaimBatch(body) { [self] result in
            DispatchQueue.main.async {
                submitting = false
                switch result {
                case .success:
                    submitted = true
                    // Only refresh the filtered my-batches endpoint for PC
                    // submissions — OOP doesn't read `myBatches`. For OOP
                    // the page transitions to the "Submitted" success state
                    // immediately; the Receipts History tab fetches its own
                    // `myClaims` on appear, so no refresh is needed here.
                    if expenseType == "pc", let id = activeFloat?.id {
                        appState.loadMyBatches(floatRequestId: id)
                    }
                case .failure(let error):
                    submitError = error.localizedDescription
                }
            }
        }.urlDataTask?.resume()
    }
}

// MARK: - Claim File Picker Page (navigation, with camera/photo/file options)

struct ClaimReceiptItem: Identifiable {
    let id = UUID()
    var date: String = ""
    var amount: String = ""
    var description: String = ""
    var category: String = "materials"
    var costCode: String = ""
    var episode: String = ""
    var codedDescription: String = ""
    var fileName: String = ""
    var fileData: Data?
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Float Detail View (navigation page)
// ═══════════════════════════════════════════════════════════════════

struct CostCodePickerButton: View {
    @Binding var selectedCode: String
    @State private var showSheet = false

    private var displayText: String {
        if selectedCode.isEmpty { return "Select cost code" }
        return costCodeOptions.first { $0.0 == selectedCode }?.1 ?? selectedCode
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        Button(action: { showSheet = true }) {
            HStack {
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundColor(selectedCode.isEmpty ? .gray : .primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
            }
            .padding(10).background(Color.bgRaised).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
        .buttonStyle(BorderlessButtonStyle())
        // Bottom sheet (searchable list) instead of the previous action
        // sheet — the cost-code catalogue is long enough that the
        // action-sheet layout clipped on smaller phones. The sheet
        // reuses `PickerSheetView`, which is the same component the
        // PO-side pickers use, so all cost-code selection UIs converge.
        .sheet(isPresented: $showSheet) {
            PickerSheetView(
                selection: $selectedCode,
                options: costCodeOptions.map { DropdownOption($0.0, $0.1) },
                isPresented: $showSheet
            )
        }
    }
}

