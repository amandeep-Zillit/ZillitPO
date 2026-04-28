import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Assign Physical Card Page
// ═══════════════════════════════════════════════════════════════════

struct AssignPhysicalCardPage: View {
    let card: ExpenseCard
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var rawDigits: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String? = nil

    // Bank account picker state — surfaced when the card has no
    // `card_issuer` / `bank_account` set yet (typical override path —
    // the card was force-approved without a bank). Matches the web's
    // Activate modal: `needsBank = !activateTarget.card_issuer`.
    @State private var selectedBankId: String = ""
    @State private var showBankSheet = false

    /// `true` when the card record doesn't carry a bank/issuer yet.
    /// The accountant has to pick one here before the physical card
    /// can be assigned — without it the server rejects activation.
    private var needsBank: Bool {
        let hasBankId = !(card.bankAccount?.id ?? "").isEmpty
        let hasIssuer = !(card.cardIssuer ?? "").isEmpty
        return !hasBankId && !hasIssuer
    }

    private var selectedBankName: String {
        appState.bankAccounts.first { $0.id == selectedBankId }?.name ?? ""
    }

    private static let teal = Color(red: 0, green: 0.6, blue: 0.5)

    // Format raw digits into grouped "XXXX XXXX XXXX XXXX"
    private var formatted: String {
        stride(from: 0, to: rawDigits.count, by: 4).map { i -> String in
            let start = rawDigits.index(rawDigits.startIndex, offsetBy: i)
            let end   = rawDigits.index(start, offsetBy: min(4, rawDigits.count - i))
            return String(rawDigits[start..<end])
        }.joined(separator: " ")
    }

    private var canSubmit: Bool {
        guard rawDigits.count == 16, !isSubmitting else { return false }
        // When the card has no issuer, a bank must be chosen first —
        // mirrors the web's activate-modal guard exactly:
        //   `disabled = !cardType || digits!=16 || (needsBank && !bankId)`
        return !needsBank || !selectedBankId.isEmpty
    }

    private var maskedDigital: String {
        guard let num = card.digitalCardNumber, !num.isEmpty else { return "No digital card" }
        let digits = num.filter { $0.isNumber }
        guard digits.count >= 4 else { return num }
        let last4 = String(digits.suffix(4))
        let groups = Int(ceil(Double(digits.count) / 4.0))
        let masked = Array(repeating: "••••", count: groups - 1).joined(separator: " ")
        return masked + " " + last4
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Card Holder / Department ──
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CARD HOLDER")
                            .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                        Text(card.holderFullName.isEmpty ? "—" : card.holderFullName)
                            .font(.system(size: 15, weight: .bold))
                        if !card.holderDesignation.isEmpty {
                            Text(card.holderDesignation)
                                .font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("DEPARTMENT")
                            .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                        Text((card.department ?? "").isEmpty ? "—" : (card.department ?? ""))
                            .font(.system(size: 15, weight: .bold))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(Color.bgSurface).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                // ── Current Digital Card preview ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRENT DIGITAL CARD")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AssignPhysicalCardPage.teal).tracking(0.5)
                    Text(maskedDigital)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AssignPhysicalCardPage.teal.opacity(0.05))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(AssignPhysicalCardPage.teal, lineWidth: 1.5))

                // ── Card Issuer (Bank Account) ──
                // Only shown when the card has no bank yet — typically
                // after an Override where the card was force-approved
                // without going through the tier flow. Without a bank
                // the server rejects activation, so this gate is
                // mandatory in that path.
                if needsBank {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("CARD ISSUER (BANK ACCOUNT)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary).tracking(0.3)
                            Text("*")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.goldDark)
                        }
                        Button(action: { showBankSheet = true }) {
                            HStack {
                                Text(selectedBankName.isEmpty ? "Select bank account…" : selectedBankName)
                                    .font(.system(size: 13))
                                    .foregroundColor(selectedBankName.isEmpty ? .gray : .primary)
                                Spacer()
                                if !selectedBankId.isEmpty {
                                    Button(action: { selectedBankId = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.gray.opacity(0.6))
                                    }.buttonStyle(BorderlessButtonStyle())
                                } else {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10)).foregroundColor(.gray)
                                }
                            }
                            .padding(12)
                            .background(Color.bgSurface).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.borderColor, lineWidth: 1))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        // Bottom sheet picker — matches the rest of the
                        // app's sheet-based pickers (cost code, category,
                        // etc.).
                        .sheet(isPresented: $showBankSheet) {
                            PickerSheetView(
                                selection: $selectedBankId,
                                options: appState.bankAccounts.map {
                                    DropdownOption($0.id ?? "", $0.name ?? ($0.id ?? ""))
                                },
                                isPresented: $showBankSheet
                            )
                        }
                    }
                }

                // ── Physical Card Number input ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("PHYSICAL CARD NUMBER (16 DIGITS)")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.3)

                    ZStack(alignment: .leading) {
                        if rawDigits.isEmpty {
                            Text("0000  0000  0000  0000")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundColor(Color(.systemGray3))
                                .padding(.horizontal, 14).padding(.vertical, 14)
                        }
                        TextField("", text: Binding(
                            get: { formatted },
                            set: { new in
                                rawDigits = String(new.filter { $0.isNumber }.prefix(16))
                                // Clear any previous server error when
                                // the user edits the input so the
                                // banner only reflects the latest attempt.
                                if errorMessage != nil { errorMessage = nil }
                            }
                        ))
                        .keyboardType(.numberPad)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .padding(14)
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // "N digits remaining" helper — matches web UX.
                    let entered = rawDigits.count
                    if entered > 0 && entered < 16 {
                        Text("\(16 - entered) digit\(16 - entered == 1 ? "" : "s") remaining")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.85, green: 0.33, blue: 0.45))
                    }
                }

                // ── Warning banner ──
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14)).foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Assigning a physical card will replace the digital card. The digital card should be ")
                            .font(.system(size: 12))
                        + Text("dismissed or deactivated")
                            .font(.system(size: 12, weight: .bold))
                        + Text(" through the card issuer portal.")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(red: 0.55, green: 0.30, blue: 0))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.35), lineWidth: 1))

                // Error banner — shown when the API rejects the assign
                // (duplicate card number, network issue, etc.). Matches
                // the web reference's red error box under the input.
                if let error = errorMessage, !error.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.system(size: 13)).foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
                }

                Spacer(minLength: 24)

                // ── Assign button ──
                Button(action: assignCard) {
                    HStack(spacing: 8) {
                        if isSubmitting { ActivityIndicator(isAnimating: true) }
                        Text(isSubmitting ? "Assigning…" : "Assign Physical Card")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSubmit ? Color.gold : Color(.systemGray4))
                    .foregroundColor(canSubmit ? .black : Color(.systemGray2))
                    .cornerRadius(12)
                }
                .disabled(!canSubmit)
            }
            .padding(20)
        }
        .background(Color.bgBase)
        .navigationBarTitle("Assign Physical Card", displayMode: .inline)
        .alert(isPresented: $showSuccess) {
            Alert(
                title: Text("Card Assigned"),
                message: Text("Physical card has been assigned successfully."),
                dismissButton: .default(Text("Done")) { presentationMode.wrappedValue.dismiss() }
            )
        }
        .onAppear {
            // Prefetch bank accounts so the Card Issuer picker has
            // options ready the moment the view shows (only matters
            // for the override path — but it's cheap when not needed).
            if needsBank && appState.bankAccounts.isEmpty {
                appState.loadBankAccounts()
            }
        }
    }

    private func assignCard() {
        guard canSubmit else { return }
        errorMessage = nil
        isSubmitting = true
        // Call activateCard — assigns the physical card number AND
        // flips status to active. When the card had no issuer
        // (override path), the selected bank is sent as `card_issuer`
        // alongside the card number. On failure the ViewModel rolls
        // back its optimistic status/number patch and returns the
        // server error, which we show in the red banner above.
        appState.activateCard(
            id: card.id ?? "",
            cardNumber: rawDigits,
            cardType: .physical,
            bankAccountId: selectedBankId
        ) { success, error in
            isSubmitting = false
            if success {
                showSuccess = true
            } else {
                errorMessage = error ?? "Failed to assign physical card. Please try again."
            }
        }
    }
}
