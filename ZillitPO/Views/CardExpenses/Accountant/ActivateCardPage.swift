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

    private var rawDigits: String { cardNumber.filter { $0.isNumber } }
    private var isValid: Bool { rawDigits.count == 16 }
    private var canSubmit: Bool { selectedType != nil && isValid && !submitting }

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
        // Group in 4s: "1234  5678  ..."
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
        errorMessage = nil
        submitting = true
        appState.activateCard(id: card.id, cardNumber: rawDigits, cardType: type) { success, error in
            submitting = false
            if success {
                showSuccess = true
            } else {
                errorMessage = error ?? "Failed to activate card. Please try again."
            }
        }
    }
}
