import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Edit Card Request Page (user edits their own pending request)
// ═══════════════════════════════════════════════════════════════════

struct EditCardRequestPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    let card: ExpenseCard

    @State private var proposedLimit: String = ""
    @State private var bsControlCode: String = ""
    @State private var justification: String = ""
    @State private var selectedBankId: String = ""
    @State private var showBankSheet = false
    @State private var submitting = false

    private var isAccountant: Bool { appState.currentUser?.isAccountant ?? false }

    private var canSave: Bool {
        (Double(proposedLimit) ?? 0) > 0 && !submitting
    }

    private var holderName: String {
        if !card.holderFullName.isEmpty { return card.holderFullName }
        if let u = UsersData.byId[card.holderId ?? ""], !(u.fullName ?? "").isEmpty { return u.fullName ?? "—" }
        return appState.currentUser?.fullName ?? "—"
    }

    private var departmentName: String {
        if !(card.department ?? "").isEmpty { return card.department ?? "" }
        if let u = UsersData.byId[card.holderId ?? ""], !u.displayDepartment.isEmpty { return u.displayDepartment }
        return appState.currentUser?.displayDepartment ?? "—"
    }

    private var selectedBankName: String {
        if let b = appState.bankAccounts.first(where: { $0.id == selectedBankId }) { return b.name ?? "" }
        return card.bankAccount?.name ?? ""
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        // Card Holder (read-only)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CARD HOLDER").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            Text(holderName)
                                .font(.system(size: 14)).foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10).background(Color.bgRaised).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        // Department (read-only)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DEPARTMENT").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            Text(departmentName)
                                .font(.system(size: 14)).foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10).background(Color.bgRaised).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                    }

                    // Accountant extras: Card Issuer (Bank), BS Control, Justification
                    if isAccountant {
                        // Bank Account picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CARD ISSUER (BANK ACCOUNT)").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            Button(action: { showBankSheet = true }) {
                                HStack {
                                    Text(selectedBankName.isEmpty ? "Select bank" : selectedBankName)
                                        .font(.system(size: 13))
                                        .foregroundColor(selectedBankName.isEmpty ? .gray : .primary)
                                    Spacer()
                                    if !selectedBankId.isEmpty {
                                        Button(action: { selectedBankId = "" }) {
                                            Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundColor(.gray.opacity(0.6))
                                        }.buttonStyle(BorderlessButtonStyle())
                                    } else {
                                        Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                                    }
                                }
                                .padding(10).background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .selectionActionSheet(
                                title: "Select Bank Account",
                                isPresented: $showBankSheet,
                                options: appState.bankAccounts.compactMap { $0.id },
                                isSelected: { id in
                                    appState.bankAccounts.first { $0.id == id }?.name == selectedBankName
                                },
                                label: { id in
                                    appState.bankAccounts.first { $0.id == id }?.name ?? id
                                },
                                onSelect: { selectedBankId = $0 }
                            )
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        // Proposed Limit (editable)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PROPOSED LIMIT").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            TextField("0", text: $proposedLimit)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .keyboardType(.decimalPad)
                                .padding(10).background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)

                        // BS Control Code (accountant only — show next to limit)
                        if isAccountant {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("BS CONTROL CODE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                                TextField("e.g. 1145", text: $bsControlCode)
                                    .font(.system(size: 14))
                                    .padding(10).background(Color.bgSurface).cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Justification (accountant only — multi-line)
                    if isAccountant {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("JUSTIFICATION").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                            MultilineTextView(text: $justification, placeholder: "Reason for card request...")
                                .frame(minHeight: 90)
                                .background(Color.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(20).padding(.bottom, 90)
            }

            // Footer — Submit button (label differs by role)
            HStack {
                Spacer()
                Button(action: save) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                        Text(submitting ? "Submitting…" : (isAccountant ? "Submit for Approval" : "Re-submit"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(canSave ? Color.orange : Color.orange.opacity(0.4))
                    .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(!canSave)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Edit Card Details"), displayMode: .inline)
        .onAppear {
            proposedLimit  = (card.monthlyLimit ?? 0) > 0 ? String(format: "%.0f", card.monthlyLimit ?? 0) : ""
            bsControlCode  = card.bsControlCode ?? ""
            justification  = card.justification ?? ""
            selectedBankId = card.bankAccount?.id ?? ""
            if appState.bankAccounts.isEmpty { appState.loadBankAccounts() }
        }
    }

    private func save() {
        guard let amt = Double(proposedLimit), amt > 0 else { return }
        submitting = true
        appState.updateCardRequest(
            id: card.id ?? "",
            holderId: card.holderId ?? "",
            proposedLimit: amt,
            bsControlCode: isAccountant ? bsControlCode : (card.bsControlCode ?? ""),
            justification: isAccountant ? justification : (card.justification ?? ""),
            bankAccountId: isAccountant ? selectedBankId : (card.bankAccount?.id ?? "")
        ) { _ in
            submitting = false
            // Always dismiss — optimistic update has already applied the new values
            presentationMode.wrappedValue.dismiss()
        }
    }
}
