import SwiftUI
import UIKit

struct RequestCardPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    private var isAccountant: Bool { appState.currentUser?.isAccountant == true }

    // Card holder (accountant picks any user; non-accountant locked to self)
    @State private var selectedUserId: String = ""
    @State private var userSearch: String = ""
    @State private var showUserDropdown = false

    // Bank account
    @State private var selectedBankId: String = ""
    @State private var bankSearch: String = ""
    @State private var showBankDropdown = false

    // Other fields
    @State private var proposedLimit: String = ""
    @State private var bsControlCode: String = ""
    @State private var justification: String = ""
    @State private var submitting = false
    /// Server error surfaced in an alert if the request fails.
    /// Keeps the form open + the loader cleared so the user can retry.
    @State private var submitError: String?

    private var effectiveUser: AppUser? {
        if isAccountant { return UsersData.byId[selectedUserId] }
        return appState.currentUser
    }
    private var departmentDisplay: String { effectiveUser?.displayDepartment ?? "" }

    private var filteredUsers: [AppUser] {
        let all = UsersData.allUsers.filter { !$0.isAccountant }
        let q = userSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter {
            ($0.fullName ?? "").lowercased().contains(q) ||
            $0.displayDepartment.lowercased().contains(q) ||
            $0.displayDesignation.lowercased().contains(q)
        }
    }
    private var filteredBanks: [ProductionBankAccount] {
        let q = bankSearch.lowercased()
        guard !q.isEmpty else { return appState.bankAccounts }
        return appState.bankAccounts.filter { ($0.name ?? "").lowercased().contains(q) || ($0.accountNumber ?? "").lowercased().contains(q) }
    }

    private var isValid: Bool {
        let hasHolder = isAccountant ? !selectedUserId.isEmpty : true
        return hasHolder && (Double(proposedLimit) ?? 0) > 0
    }

    var body: some View {
        if isAccountant {
            accountantForm
        } else {
            userForm
        }
    }

    // ── Non-accountant: original simple form ─────────────────────────
    private var userForm: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Icon header
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard.fill").font(.system(size: 40)).foregroundColor(.gold)
                        Text("Request New Card").font(.system(size: 18, weight: .bold))
                        Text("Your request will be sent to the accounts team for review and approval.")
                            .font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                    .background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                    // Read-only info + limit input
                    VStack(spacing: 0) {
                        simpleRow(label: "Card Holder",  value: appState.currentUser?.fullName ?? "—")
                        Divider().padding(.leading, 14)
                        simpleRow(label: "Department",   value: appState.currentUser?.displayDepartment ?? "—")
                        Divider().padding(.leading, 14)
                        simpleRow(label: "Designation",  value: appState.currentUser?.displayDesignation ?? "—")
                        Divider().padding(.leading, 14)
                        HStack {
                            Text("Proposed Limit").font(.system(size: 12)).foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 2) {
                                Text("£").font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark)
                                TextField("e.g. 1500", text: $proposedLimit)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.goldDark)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                            .padding(6).background(Color.bgRaised).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill").font(.system(size: 14)).foregroundColor(.blue)
                        Text("Your card request will be sent to the accounts team for review. They will assign the card issuer and other details.")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.04)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.15), lineWidth: 1))
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 80)
            }

            HStack(spacing: 12) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Cancel").font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle())

                Button(action: submit) {
                    HStack(spacing: 6) {
                        if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(submitting ? "Submitting..." : "Submit Request")
                    }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background((Double(proposedLimit) ?? 0) > 0 && !submitting ? Color.gold : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled((Double(proposedLimit) ?? 0) <= 0 || submitting)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Request New Card"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
    }

    // ── Accountant: full form (user picker, bank, BS code, justification) ──
    private var accountantForm: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 0) {
                    // CARD HOLDER
                    fieldLabel("CARD HOLDER")
                    VStack(alignment: .leading, spacing: 0) {
                        // ── Search / selected-user row ──
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11)).foregroundColor(.gray)
                            if showUserDropdown || selectedUserId.isEmpty {
                                TextField("Search by name or department...", text: $userSearch,
                                          onEditingChanged: { editing in
                                              showUserDropdown = editing
                                              if editing { showBankDropdown = false }
                                          })
                                .font(.system(size: 13))
                            } else {
                                if let u = effectiveUser {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(u.fullName ?? "")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.primary).lineLimit(1)
                                        Text("\(u.displayDepartment)\(u.displayDesignation.isEmpty ? "" : " · \(u.displayDesignation)")")
                                            .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Button(action: {
                                    selectedUserId = ""; userSearch = ""
                                    showUserDropdown = true
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 13)).foregroundColor(.gray.opacity(0.5))
                                }.buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .background(Color.bgSurface)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                            showUserDropdown ? Color.goldDark : Color.borderColor,
                            lineWidth: showUserDropdown ? 1.5 : 1
                        ))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !showUserDropdown && !selectedUserId.isEmpty {
                                selectedUserId = ""; userSearch = ""; showUserDropdown = true
                            }
                        }

                        // ── Inline user list ──
                        if showUserDropdown {
                            Group {
                                if filteredUsers.isEmpty {
                                    Text("No users found")
                                        .font(.system(size: 12)).foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(14)
                                        .background(Color.bgSurface)
                                } else {
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 0) {
                                            ForEach(filteredUsers) { u in
                                                Button(action: {
                                                    selectedUserId = u.id ?? ""
                                                    userSearch = ""
                                                    showUserDropdown = false
                                                    #if canImport(UIKit)
                                                    UIApplication.shared.sendAction(
                                                        #selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                                                    #endif
                                                }) {
                                                    HStack(spacing: 10) {
                                                        ZStack {
                                                            Circle().fill(Color.gold.opacity(0.18))
                                                                .frame(width: 30, height: 30)
                                                            Text(u.initials)
                                                                .font(.system(size: 10, weight: .bold))
                                                                .foregroundColor(.goldDark)
                                                        }
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(u.fullName ?? "")
                                                                .font(.system(size: 13, weight: .medium))
                                                                .foregroundColor(.primary).lineLimit(1)
                                                            HStack(spacing: 4) {
                                                                Text(u.displayDepartment)
                                                                    .font(.system(size: 10))
                                                                    .foregroundColor(.secondary).lineLimit(1)
                                                                if !u.displayDesignation.isEmpty {
                                                                    Text("·").font(.system(size: 10)).foregroundColor(.secondary)
                                                                    Text(u.displayDesignation)
                                                                        .font(.system(size: 10))
                                                                        .foregroundColor(.secondary).lineLimit(1)
                                                                }
                                                            }
                                                        }
                                                        Spacer()
                                                        if selectedUserId == (u.id ?? "") {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 11, weight: .bold))
                                                                .foregroundColor(.goldDark)
                                                        }
                                                    }
                                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(selectedUserId == u.id
                                                                ? Color.gold.opacity(0.06) : Color.bgSurface)
                                                    .contentShape(Rectangle())
                                                }
                                                .buttonStyle(BorderlessButtonStyle())
                                                if u.id != filteredUsers.last?.id {
                                                    Divider().padding(.horizontal, 8)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 220)
                                }
                            }
                            .background(Color.bgSurface)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            .padding(.top, 4)
                        }
                    }

                    Spacer().frame(height: 14)

                    // DEPARTMENT
                    fieldLabel("DEPARTMENT")
                    HStack {
                        Text(departmentDisplay.isEmpty ? "Auto-filled from user" : departmentDisplay)
                            .font(.system(size: 14))
                            .foregroundColor(departmentDisplay.isEmpty ? .secondary : .primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                    Spacer().frame(height: 14)

                    // CARD ISSUER
                    fieldLabel("CARD ISSUER (BANK ACCOUNT)")
                    VStack(spacing: 0) {
                        Button(action: {
                            showUserDropdown = false
                            withAnimation { showBankDropdown.toggle() }
                        }) {
                            HStack {
                                if let bank = appState.bankAccounts.first(where: { $0.id == selectedBankId }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bank.name ?? "").font(.system(size: 14, weight: .semibold))
                                        if !(bank.accountNumber ?? "").isEmpty {
                                            Text("Account: \(bank.accountNumber ?? "")").font(.system(size: 11)).foregroundColor(.secondary)
                                        }
                                    }
                                } else {
                                    Text("Search bank account...").font(.system(size: 14)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: showBankDropdown ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(Color.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .buttonStyle(BorderlessButtonStyle())

                        if showBankDropdown {
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(.secondary)
                                    TextField("Search...", text: $bankSearch).font(.system(size: 13))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(Color(UIColor.secondarySystemBackground))
                                Divider()
                                if appState.bankAccounts.isEmpty {
                                    Text("No bank accounts found").font(.system(size: 12)).foregroundColor(.secondary).padding(14)
                                } else {
                                    ForEach(filteredBanks.prefix(6)) { bank in
                                        Button(action: {
                                            selectedBankId = bank.id ?? ""; bankSearch = ""
                                            withAnimation { showBankDropdown = false }
                                        }) {
                                            HStack(spacing: 10) {
                                                Image(systemName: "building.columns.fill")
                                                    .font(.system(size: 13)).foregroundColor(.goldDark).frame(width: 28)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(bank.name ?? "").font(.system(size: 13, weight: .semibold))
                                                    if !(bank.accountNumber ?? "").isEmpty {
                                                        Text(bank.accountNumber ?? "").font(.system(size: 11)).foregroundColor(.secondary)
                                                    }
                                                }
                                                Spacer()
                                                if selectedBankId == (bank.id ?? "") {
                                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.goldDark)
                                                }
                                            }
                                            .padding(.horizontal, 14).padding(.vertical, 9)
                                            .background(selectedBankId == bank.id ? Color.gold.opacity(0.06) : Color.bgSurface)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                        Divider().padding(.leading, 52)
                                    }
                                }
                            }
                            .background(Color.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                            .cornerRadius(8)
                        }
                    }

                    Spacer().frame(height: 14)

                    // PROPOSED LIMIT + BS CONTROL CODE
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("PROPOSED LIMIT")
                            HStack(spacing: 4) {
                                Text("£").font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark)
                                TextField("1,500", text: $proposedLimit)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .keyboardType(.decimalPad)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 12)
                            .background(Color.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("BS CONTROL CODE")
                            TextField("e.g. 1145", text: $bsControlCode)
                                .font(.system(size: 14))
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 12).padding(.vertical, 12)
                                .background(Color.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Spacer().frame(height: 14)

                    // JUSTIFICATION
                    fieldLabel("JUSTIFICATION")
                    MultilineTextView(text: $justification, placeholder: "Reason for card request...")
                        .frame(minHeight: 90)
                        .background(Color.bgSurface)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 90)
            }
            .onTapGesture { showUserDropdown = false; showBankDropdown = false }

            Button(action: submit) {
                HStack(spacing: 6) {
                    if submitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                    Text(submitting ? "Submitting..." : "Submit Request").font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(isValid && !submitting ? .black : .white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(isValid && !submitting ? Color.gold : Color.gray.opacity(0.35))
                .cornerRadius(10)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(!isValid || submitting)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("Request New Card"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .onAppear { appState.loadBankAccounts() }
        .alert(isPresented: .init(
            get: { submitError != nil },
            set: { if !$0 { submitError = nil } }
        )) {
            Alert(
                title: Text("Request Failed"),
                message: Text(submitError ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func submit() {
        guard isValid, !submitting else { return }
        submitting = true
        submitError = nil
        let uid = isAccountant ? selectedUserId : (appState.currentUser?.id ?? "")
        let user = UsersData.byId[uid] ?? appState.currentUser
        // The VM method now fires a completion on the main queue.
        // Only dismiss the page on success; on failure clear the
        // loader, surface the server error in an alert, and let the
        // user retry without losing their form data.
        appState.requestNewCard(
            userId: uid,
            holderName: user?.fullName ?? "",
            departmentName: user?.displayDepartment ?? "",
            bankAccountId: selectedBankId,
            proposedLimit: Double(proposedLimit) ?? 0,
            bsControlCode: bsControlCode,
            justification: justification
        ) { success, error in
            submitting = false
            if success {
                presentationMode.wrappedValue.dismiss()
            } else {
                submitError = error ?? "Failed to submit card request."
            }
        }
    }

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.bottom, 4)
    }

    private func simpleRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
