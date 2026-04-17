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

    private static let teal = Color(red: 0, green: 0.6, blue: 0.5)

    // Format raw digits into grouped "XXXX XXXX XXXX XXXX"
    private var formatted: String {
        stride(from: 0, to: rawDigits.count, by: 4).map { i -> String in
            let start = rawDigits.index(rawDigits.startIndex, offsetBy: i)
            let end   = rawDigits.index(start, offsetBy: min(4, rawDigits.count - i))
            return String(rawDigits[start..<end])
        }.joined(separator: " ")
    }

    private var canSubmit: Bool { rawDigits.count == 16 && !isSubmitting }

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
                            set: { new in rawDigits = String(new.filter { $0.isNumber }.prefix(16)) }
                        ))
                        .keyboardType(.numberPad)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .padding(14)
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
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
    }

    private func assignCard() {
        guard canSubmit else { return }
        isSubmitting = true
        // Call activateCard — this assigns the physical card number AND flips status to active.
        appState.activateCard(id: card.id, cardNumber: rawDigits) { success in
            isSubmitting = false
            if success { showSuccess = true }
        }
    }
}
