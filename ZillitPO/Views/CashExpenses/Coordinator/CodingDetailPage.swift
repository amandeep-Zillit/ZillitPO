import SwiftUI

struct CodingDetailPage: View {
    let claim: ClaimBatch
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var nominalCode = ""
    @State private var vatTreatment = "standard_20"
    @State private var codingNotes = ""
    @State private var saving = false
    @State private var forwarding = false
    @State private var showError: String?

    private var user: AppUser? { UsersData.byId[claim.userId ?? ""] }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("#\(claim.batchReference ?? "")").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                            Spacer()
                            Text(claim.statusDisplay).font(.system(size: 10, weight: .bold)).foregroundColor(.purple)
                                .padding(.horizontal, 8).padding(.vertical, 3).background(Color.purple.opacity(0.1)).cornerRadius(4)
                        }
                        if let u = user {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle().fill(Color.gold.opacity(0.2)).frame(width: 32, height: 32)
                                    Text(u.initials).font(.system(size: 11, weight: .bold)).foregroundColor(.goldDark)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(u.fullName ?? "").font(.system(size: 14, weight: .semibold))
                                    Text("\(u.displayDesignation) · \(claim.department ?? "")").font(.system(size: 11)).foregroundColor(.secondary)
                                }
                            }
                        }
                        HStack(spacing: 6) {
                            Text(claim.isPettyCash ? "Petty Cash" : "Out of Pocket")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(claim.isPettyCash ? Color(red: 0.2, green: 0.7, blue: 0.45) : .purple)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background((claim.isPettyCash ? Color(red: 0.2, green: 0.7, blue: 0.45) : Color.purple).opacity(0.1)).cornerRadius(3)
                            Text("Submitted \(FormatUtils.formatDateTime(claim.createdAt ?? 0))").font(.system(size: 10)).foregroundColor(.gray)
                        }
                    }
                    .padding(14).background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Amounts
                    VStack(spacing: 0) {
                        codingAmtRow("Gross Total", FormatUtils.formatGBP(claim.totalGross ?? 0), .primary)
                        Divider().padding(.leading, 14)
                        codingAmtRow("Net", FormatUtils.formatGBP(claim.totalNet ?? 0), .secondary)
                        Divider().padding(.leading, 14)
                        codingAmtRow("VAT", FormatUtils.formatGBP(claim.totalVat ?? 0), .secondary)
                        Divider().padding(.leading, 14)
                        codingAmtRow("Items", "\(claim.claimCount ?? 0) receipt\((claim.claimCount ?? 0) == 1 ? "" : "s")", .secondary)
                        if !(claim.settlementType ?? "").isEmpty {
                            Divider().padding(.leading, 14)
                            codingAmtRow("Settlement", claim.settlementType!.replacingOccurrences(of: "_", with: " ").capitalized, .secondary)
                        }
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Budget Coding
                    VStack(alignment: .leading, spacing: 12) {
                        Text("BUDGET CODING").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOMINAL / COST CODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            TextField("e.g. ART-4100", text: $nominalCode)
                                .font(.system(size: 14, design: .monospaced)).padding(10)
                                .background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VAT TREATMENT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Text(VATHelpers.vatLabel(vatTreatment)).font(.system(size: 14))
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CODING NOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            TextField("Notes for accounts team…", text: $codingNotes)
                                .font(.system(size: 13)).padding(10)
                                .background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        }
                    }
                    .padding(14).background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    if !(claim.notes ?? "").isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SUBMITTER NOTES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                            Text(claim.notes!).font(.system(size: 13))
                        }
                        .padding(14).background(Color.bgSurface).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    if let err = showError {
                        Text(err).font(.system(size: 11)).foregroundColor(.red)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.06)).cornerRadius(8)
                    }
                }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 90)
            }

            // Bottom bar
            HStack(spacing: 12) {
                Button(action: saveDraft) {
                    HStack(spacing: 4) {
                        if saving { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                        Text(saving ? "Saving..." : "Save Draft")
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }.buttonStyle(BorderlessButtonStyle()).disabled(saving || forwarding)

                Button(action: forwardToAccounts) {
                    HStack(spacing: 4) {
                        if forwarding { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                        Text(forwarding ? "Sending..." : "Forward to Accounts")
                    }
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.gold).cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle()).disabled(saving || forwarding)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
        .navigationBarTitle(Text("#\(claim.batchReference ?? "")"), displayMode: .inline)
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

    private func codingAmtRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(color)
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func saveDraft() {
        saving = true; showError = nil
        let body: [String: Any] = ["nominal_code": nominalCode, "vat_treatment": vatTreatment, "notes": codingNotes]
        CashExpenseCodableTask.saveClaims(claim.id, body) { result in
            DispatchQueue.main.async {
                saving = false
                if case .success = result { appState.loadCodingQueue(); presentationMode.wrappedValue.dismiss() }
                else if case .failure(let e) = result { showError = e.localizedDescription }
            }
        }.urlDataTask?.resume()
    }

    private func forwardToAccounts() {
        forwarding = true; showError = nil
        let body: [String: Any] = ["nominal_code": nominalCode, "vat_treatment": vatTreatment, "notes": codingNotes]
        CashExpenseCodableTask.saveAndSubmit(claim.id, body) { result in
            DispatchQueue.main.async {
                forwarding = false
                if case .success = result { appState.loadCodingQueue(); presentationMode.wrappedValue.dismiss() }
                else if case .failure(let e) = result { showError = e.localizedDescription }
            }
        }.urlDataTask?.resume()
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Cost Code Picker Button (opens compact action sheet)
// ═══════════════════════════════════════════════════════════════════
