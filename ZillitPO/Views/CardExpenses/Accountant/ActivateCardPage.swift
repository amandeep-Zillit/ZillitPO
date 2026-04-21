import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Activate Card Page
// ═══════════════════════════════════════════════════════════════════

struct ActivateCardPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    let card: ExpenseCard

    @State private var selectedType: POViewModel.CardType? = .digital
    @State private var cardNumber: String = ""
    @State private var submitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String? = nil

    // Bank account picker — shown when the card has no issuer set yet
    // (mirrors React: `activateTarget && !activateTarget.card_issuer`).
    @State private var selectedBankId: String = ""
    @State private var showBankSheet = false

    /// True when the card has no bank account / card issuer set yet.
    /// In this case the accountant must choose one before activating.
    private var needsBank: Bool {
        let hasBankId  = !(card.bankAccount?.id ?? "").isEmpty
        let hasIssuer  = !(card.cardIssuer ?? "").isEmpty
        return !hasBankId && !hasIssuer
    }

    private var selectedBankName: String {
        appState.bankAccounts.first { $0.id == selectedBankId }?.name ?? ""
    }

    private var rawDigits: String { cardNumber.filter { $0.isNumber } }
    private var isValid: Bool { rawDigits.count == 16 }
    private var canSubmit: Bool {
        guard selectedType != nil, isValid, !submitting else { return false }
        return !needsBank || !selectedBankId.isEmpty
    }

    private var submitLabel: String {
        switch selectedType {
        case .physical: return submitting ? "Activating…" : "Activate Physical Card"
        case .digital:  return submitting ? "Activating…" : "Activate Digital Card"
        case .none:     return "Activate Card"
        }
    }

    private var holderName: String {
        if !card.holderFullName.isEmpty { return card.holderFullName }
        if let u = UsersData.byId[card.holderId ?? ""] { return u.fullName ?? "—" }
        return "—"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Intro
                    (Text("Assign a card type, card number and activate the card for ")
                        .font(.system(size: 14)).foregroundColor(.primary)
                     + Text(holderName)
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                     + Text(".").font(.system(size: 14)).foregroundColor(.primary))
                        .fixedSize(horizontal: false, vertical: true)

                    // ── Bank account picker (only when card has no issuer set) ──
                    // Mirrors the React activate modal: when !activateTarget.card_issuer
                    // the user must pick a bank before the activate button is enabled.
                    if needsBank {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Text("CARD ISSUER (BANK ACCOUNT)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(0.5)
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
                                .padding(10)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            // Bottom sheet picker — same pattern as
                            // AssignPhysicalCardPage and the cost-code
                            // pickers elsewhere in the app.
                            .sheet(isPresented: $showBankSheet) {
                                PickerSheetView(
                                    selection: $selectedBankId,
                                    options: appState.bankAccounts.map {
                                        DropdownOption($0.id, $0.name ?? $0.id)
                                    },
                                    isPresented: $showBankSheet
                                )
                            }
                            // Warn if bank was not yet selected while trying to submit
                            if needsBank && selectedBankId.isEmpty, let err = errorMessage, err.contains("bank") {
                                Text(err)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    // Card type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CARD TYPE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                        HStack(spacing: 10) {
                            cardTypeOption(type: .digital, label: "Digital Card")
                            cardTypeOption(type: .physical, label: "Physical Card")
                        }
                    }

                    // Card number (shown once a type is picked)
                    if let type = selectedType {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(type == .physical ? "CARD NUMBER (16 DIGITS)" : "VIRTUAL CARD NUMBER (16 DIGITS)")
                                .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            TextField("0000  0000  0000  0000", text: Binding(
                                get: { cardNumber },
                                set: { newValue in
                                    let digits = newValue.filter { $0.isNumber }
                                    let trimmed = String(digits.prefix(16))
                                    cardNumber = formatCardNumber(trimmed)
                                }
                            ))
                                .font(.system(size: 15, design: .monospaced))
                                .keyboardType(.numberPad)
                                .padding(12)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            Text("\(rawDigits.count)/16 digits")
                                .font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }

                    // Error message (non-bank errors)
                    if let err = errorMessage, !err.contains("bank") {
                        Text(err)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(10)
                            .background(Color.red.opacity(0.07))
                            .cornerRadius(8)
                    }
                }
                .padding(20).padding(.bottom, 100)
            }

            // Footer — full-width submit
            Button(action: submit) {
                HStack(spacing: 6) {
                    if submitting { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                    Text(submitLabel).font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmit ? Color.orange : Color.gray.opacity(0.4))
                .cornerRadius(10)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(!canSubmit)
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Activate Card"), displayMode: .inline)
        .alert(isPresented: $showSuccess) {
            Alert(
                title: Text("Card Activated"),
                message: Text("\(holderName)'s card is now active."),
                dismissButton: .default(Text("Done")) { presentationMode.wrappedValue.dismiss() }
            )
        }
        .onAppear {
            if appState.bankAccounts.isEmpty { appState.loadBankAccounts() }
        }
    }

    @ViewBuilder
    private func cardTypeOption(type: POViewModel.CardType, label: String) -> some View {
        let isSelected = selectedType == type
        Button(action: { selectedType = type }) {
            VStack(spacing: 6) {
                Image(systemName: "creditcard")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(isSelected ? .goldDark : .secondary)
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .goldDark : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? Color.gold.opacity(0.08) : Color.bgRaised)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.goldDark : Color.borderColor, lineWidth: isSelected ? 1.5 : 1))
        }.buttonStyle(BorderlessButtonStyle())
    }

    private func formatCardNumber(_ digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        let groups = stride(from: 0, to: digits.count, by: 4).map { i -> String in
            let start = digits.index(digits.startIndex, offsetBy: i)
            let end = digits.index(start, offsetBy: min(4, digits.count - i))
            return String(digits[start..<end])
        }
        return groups.joined(separator: "  ")
    }

    private func submit() {
        guard let type = selectedType, isValid else { return }
        if needsBank && selectedBankId.isEmpty {
            errorMessage = "Please select a bank account"
            return
        }
        errorMessage = nil
        submitting = true
        appState.activateCard(id: card.id, cardNumber: rawDigits, cardType: type, bankAccountId: selectedBankId) { success, error in
            submitting = false
            if success {
                showSuccess = true
            } else {
                errorMessage = error ?? "Failed to activate card. Please try again."
            }
        }
    }
}
