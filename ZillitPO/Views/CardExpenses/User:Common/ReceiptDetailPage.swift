import SwiftUI

struct ReceiptDetailPage: View {
    let receipt: Receipt
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var activeSheet: ReceiptDetailSheet?
    @State private var navigateToHistory = false

    // Prefer freshly fetched detail; fall back to the receipt passed in
    private var live: Receipt {
        appState.currentReceiptDetail?.id == receipt.id
            ? appState.currentReceiptDetail!
            : receipt
    }

    private var receiptDocumentURL: URL? {
        guard !(live.filePath ?? "").isEmpty else { return nil }
        return URL(string: "\(CardExpenseRequest.baseURL)\(live.filePath ?? "")")
    }

    // MARK: - Derived helpers

    private var currentStep: Int {
        switch (live.workflowStatus ?? "").lowercased() {
        case "pending_receipt":             return 0
        case "pending_code","pending_coding": return 1
        case "awaiting_approval":           return 2
        case "approved":                    return 3
        case "posted":                      return 4
        default:                            return 0
        }
    }

    private var expenseDate: String {
        let ts = (live.transactionDate ?? 0) > 0 ? (live.transactionDate ?? 0) : (live.createdAt ?? 0)
        return ts > 0 ? FormatUtils.formatTimestamp(ts) : "—"
    }

    private var hasLinkedTxn: Bool { !(live.linkedMerchant ?? "").isEmpty || live.linkedAmount != nil }
    private var uploaderUser: AppUser? { UsersData.byId[live.uploaderId ?? ""] }

    // MARK: - Status badge

    private func statusBadge() -> some View {
        let teal   = Color(red: 0.0,  green: 0.6,  blue: 0.5)
        let navy   = Color(red: 0.05, green: 0.15, blue: 0.42)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        let s = (live.workflowStatus ?? "").isEmpty ? (live.matchStatus ?? "") : (live.workflowStatus ?? "")
        let (label, fg, bg): (String, Color, Color) = {
            switch s.lowercased() {
            case "pending_coding", "pending_code", "pending code": return ("Pending Code", navy, navy.opacity(0.12))
            case "posted":               return ("Posted",            Color(red: 0.1, green: 0.6, blue: 0.3), Color.green.opacity(0.1))
            case "approved":             return ("Approved",          teal,   teal.opacity(0.12))
            case "awaiting_approval":    return ("Awaiting Approval", orange, orange.opacity(0.12))
            case "matched","suggested_match": return ("Matched",      teal,   teal.opacity(0.12))
            case "unmatched":            return ("No Match",          orange, orange.opacity(0.12))
            case "pending_receipt":      return ("Pending Receipt",   orange, orange.opacity(0.12))
            default:                     return ("Pending",           orange, orange.opacity(0.12))
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(bg).cornerRadius(5)
    }

    // MARK: - Step dot

    private func stepDot(index: Int, label: String) -> some View {
        let isDone   = index < currentStep
        let isActive = index == currentStep
        let dotColor: Color = isDone ? Color(red: 0.1, green: 0.6, blue: 0.3) : isActive ? .goldDark : Color.gray.opacity(0.3)
        let textColor: Color = isDone ? Color(red: 0.1, green: 0.6, blue: 0.3) : isActive ? .goldDark : Color.gray.opacity(0.5)
        return VStack(spacing: 5) {
            ZStack {
                Circle().fill(isDone ? Color(red: 0.1, green: 0.6, blue: 0.3) : isActive ? Color.goldDark : Color.gray.opacity(0.15))
                    .frame(width: 22, height: 22)
                if isDone {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                } else {
                    Circle().fill(isActive ? Color.white : dotColor).frame(width: 7, height: 7)
                }
            }
            Text(label)
                .font(.system(size: 9, weight: isActive ? .bold : .medium))
                .foregroundColor(textColor)
                .lineLimit(2).multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Detail row

    private func dRow(_ icon: String, _ label: String, _ value: String, valueColor: Color = .primary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 18)
            Text(label).font(.system(size: 13)).foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(valueColor).lineLimit(1)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: - Body

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        let showActionBar = (live.workflowStatus ?? "").lowercased() == "pending_receipt" && appState.currentUser?.isAccountant == true

        return ZStack(alignment: .bottom) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            // Centered loader while fetching fresh detail
            if appState.isLoadingReceiptDetail {
                VStack {
                    Spacer()
                    LoaderView()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.bgBase.edgesIgnoringSafeArea(.all))
                .zIndex(1)
            }

            ScrollView {
                VStack(spacing: 12) {

                    // ── Hero card ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        // Top: merchant + urgent + status
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(live.displayMerchant.isEmpty ? "Receipt" : live.displayMerchant)
                                        .font(.system(size: 18, weight: .bold)).lineLimit(2)
                                    if live.isUrgent ?? false {
                                        Text("URGENT")
                                            .font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                                            .padding(.horizontal, 5).padding(.vertical, 3)
                                            .background(Color.red).cornerRadius(4)
                                    }
                                }
                                Text(expenseDate)
                                    .font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            Spacer(minLength: 8)
                            statusBadge()
                        }
                        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

                        // Amount
                        if live.displayAmount > 0 {
                            Text(FormatUtils.formatGBP(live.displayAmount))
                                .font(.system(size: 26, weight: .bold, design: .monospaced))
                                .foregroundColor(.goldDark)
                                .padding(.horizontal, 14).padding(.bottom, 10)
                        }

                        Divider().padding(.horizontal, 14)

                        // Uploader
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Color.gold.opacity(0.18)).frame(width: 32, height: 32)
                                Text((uploaderUser?.initials ?? String((live.uploaderName ?? "").prefix(2))).uppercased())
                                    .font(.system(size: 12, weight: .bold)).foregroundColor(.goldDark)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(uploaderUser?.fullName ?? ((live.uploaderName ?? "").isEmpty ? "—" : (live.uploaderName ?? "")))
                                    .font(.system(size: 13, weight: .semibold))
                                if !(live.uploaderDepartment ?? "").isEmpty {
                                    Text(live.uploaderDepartment ?? "")
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            // Nominal code pill
                            if let code = live.nominalCode, !code.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill").font(.system(size: 9)).foregroundColor(.goldDark)
                                    Text(code.uppercased().replacingOccurrences(of: "_", with: "-"))
                                        .font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.gold.opacity(0.12)).cornerRadius(5)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)

                        Divider().padding(.horizontal, 14)

                        // Action buttons
                        HStack(spacing: 10) {
                            Button(action: { activeSheet = .document }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "doc.text.viewfinder").font(.system(size: 11))
                                    Text("View Receipt").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.goldDark)
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(Color.gold.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                            }.buttonStyle(BorderlessButtonStyle())

                            Button(action: { activeSheet = .edit }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "pencil").font(.system(size: 11))
                                    Text("Edit Details").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background(Color.goldDark)
                                .cornerRadius(8)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                    }
                    .background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                    // ── Workflow progress ─────────────────────────
                    VStack(spacing: 0) {
                        Text("WORKFLOW").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 14)
                        HStack(alignment: .top, spacing: 0) {
                            stepDot(index: 0, label: "Submitted")
                            stepConnector(isDone: currentStep > 0)
                            stepDot(index: 1, label: "Coding")
                            stepConnector(isDone: currentStep > 1)
                            stepDot(index: 2, label: "Approval")
                            stepConnector(isDone: currentStep > 2)
                            stepDot(index: 3, label: "Approved")
                            stepConnector(isDone: currentStep > 3)
                            stepDot(index: 4, label: "Posted")
                        }
                        .padding(.horizontal, 10).padding(.bottom, 14)
                    }
                    .background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                    // ── Key details ───────────────────────────────
                    VStack(spacing: 0) {
                        Text("DETAILS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)

                        if live.displayAmount > 0 {
                            dRow("sterlingsign.circle", "Amount", FormatUtils.formatGBP(live.displayAmount), valueColor: .goldDark)
                            Divider().padding(.leading, 42)
                        }
                        dRow("calendar", "Date", expenseDate)
                        if let code = live.nominalCode, !code.isEmpty {
                            Divider().padding(.leading, 42)
                            dRow("tag", "Nominal Code", code.uppercased().replacingOccurrences(of: "_", with: "-"), valueColor: .goldDark)
                        }
                        Divider().padding(.leading, 42)
                        dRow("arrow.triangle.2.circlepath", "Match Status", (live.matchStatus ?? "").replacingOccurrences(of: "_", with: " ").capitalized)
                        if !(live.workflowStatus ?? "").isEmpty {
                            Divider().padding(.leading, 42)
                            dRow("checkmark.seal", "Workflow", (live.workflowStatus ?? "").replacingOccurrences(of: "_", with: " ").capitalized)
                        }
                        Divider().padding(.leading, 42)
                        dRow("person.fill", "Uploaded by", (uploaderUser?.fullName ?? (live.uploaderName ?? "")).isEmpty ? "—" : (uploaderUser?.fullName ?? (live.uploaderName ?? "")))
                        Divider().padding(.leading, 42)
                        dRow("clock", "Created", (live.createdAt ?? 0) > 0 ? FormatUtils.formatTimestamp(live.createdAt ?? 0) : "—")
                        if !(live.originalName ?? "").isEmpty {
                            Divider().padding(.leading, 42)
                            dRow("doc.fill", "File", live.originalName ?? "")
                        }
                    }
                    .background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

                    // ── Linked transaction ────────────────────────
                    if hasLinkedTxn {
                        VStack(spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "link.circle.fill").font(.system(size: 13)).foregroundColor(.goldDark)
                                Text("LINKED TRANSACTION").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.8)
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                if !(live.linkedMerchant ?? "").isEmpty {
                                    Text(live.linkedMerchant ?? "")
                                        .font(.system(size: 14, weight: .semibold)).lineLimit(2)
                                }
                                HStack(spacing: 10) {
                                    if let amt = live.linkedAmount {
                                        Text(FormatUtils.formatGBP(amt))
                                            .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                                    }
                                    if !(live.linkedCardLast4 ?? "").isEmpty {
                                        HStack(spacing: 3) {
                                            Text("····").font(.system(size: 11)).foregroundColor(.secondary)
                                            Text(live.linkedCardLast4 ?? "").font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        }
                                    }
                                    if let ld = live.linkedDate, ld > 0 {
                                        Text(FormatUtils.formatTimestamp(ld))
                                            .font(.system(size: 11)).foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                        }
                        .background(Color.bgSurface).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
                    }

                    // ── Line items ────────────────────────────────
                    if !(live.lineItems ?? []).isEmpty {
                        VStack(spacing: 0) {
                            Text("LINE ITEMS (\((live.lineItems ?? []).count))")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                            Divider()
                            ForEach(Array((live.lineItems ?? []).enumerated()), id: \.offset) { idx, li in
                                HStack(spacing: 8) {
                                    if let c = li.code, !c.isEmpty {
                                        Text(c.uppercased()).font(.system(size: 9, weight: .bold)).foregroundColor(.goldDark)
                                            .padding(.horizontal, 5).padding(.vertical, 2)
                                            .background(Color.gold.opacity(0.1)).cornerRadius(4)
                                    }
                                    Text(li.description ?? "—").font(.system(size: 12)).foregroundColor(.primary).lineLimit(1)
                                    Spacer()
                                    Text(FormatUtils.formatGBP(li.amountValue))
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                if idx < (live.lineItems ?? []).count - 1 { Divider().padding(.leading, 14) }
                            }
                            Divider()
                            HStack {
                                Text("Total").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(FormatUtils.formatGBP((live.lineItems ?? []).reduce(0) { $0 + $1.amountValue }))
                                    .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                        }
                        .background(Color.bgSurface).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
                    }

                }
                .padding(.horizontal, 16).padding(.top, 14)
                .padding(.bottom, showActionBar ? 80 : 28)
                .opacity(appState.isLoadingReceiptDetail ? 0 : 1)
            }

            if showActionBar {
                HStack(spacing: 10) {
                    Button(action: { appState.flagReceiptPersonal(live); presentationMode.wrappedValue.dismiss() }) {
                        Text("Flag Personal").font(.system(size: 13, weight: .bold)).foregroundColor(.purple)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple, lineWidth: 1))
                    }.buttonStyle(BorderlessButtonStyle())
                    Spacer()
                    Button(action: { appState.confirmReceipt(live); presentationMode.wrappedValue.dismiss() }) {
                        Text("Confirm").font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                            .padding(.horizontal, 20).padding(.vertical, 10).background(Color.gold).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.bgSurface)
                .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
            }
        }
        .background(
            NavigationLink(destination: ReceiptHistoryPage(history: live.history ?? []).environmentObject(appState),
                           isActive: $navigateToHistory) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .navigationBarTitle(Text("Receipt Detail"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)); Text("Back").font(.system(size: 16)) }.foregroundColor(.goldDark)
            },
            trailing: Button(action: { navigateToHistory = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 13))
                    Text("History").font(.system(size: 14))
                }.foregroundColor(.goldDark)
            }
        )
        .sheet(item: $activeSheet) { sheet in
            if sheet == .edit {
                EditReceiptDetailsSheet(receipt: live).environmentObject(appState)
            } else if let docURL = receiptDocumentURL {
                ReceiptDocumentViewerSheet(url: docURL, fileName: live.originalName ?? "Receipt")
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill").font(.system(size: 36)).foregroundColor(.gray)
                    Text("No document available").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
                    Text("This receipt does not have an uploaded file.").font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.center)
                    Button("Close") { activeSheet = nil }
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.goldDark).padding(.top, 8)
                }.padding(32)
            }
        }
        .onAppear { appState.loadReceiptDetail(id: receipt.id ?? "") }
    }

    private func stepConnector(isDone: Bool) -> some View {
        Rectangle()
            .fill(isDone ? Color(red: 0.1, green: 0.6, blue: 0.3) : Color.gray.opacity(0.2))
            .frame(height: 2)
            .padding(.bottom, 18)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt History Page
// ═══════════════════════════════════════════════════════════════════

enum ReceiptDetailSheet: String, Identifiable {
    case edit, document
    var id: String { rawValue }
}

struct EditReceiptDetailsSheet: View {
    let receipt: Receipt
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var merchant: String = ""
    @State private var amount: String = ""
    @State private var date: String = ""
    @State private var nominalCode: String = ""

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Receipt Details")) {
                    HStack {
                        Text("Merchant").foregroundColor(.secondary)
                        Spacer()
                        TextField("Merchant", text: $merchant).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Amount (£)").foregroundColor(.secondary)
                        Spacer()
                        TextField("0.00", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Date").foregroundColor(.secondary)
                        Spacer()
                        TextField("DD MMM YYYY", text: $date).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Nominal Code").foregroundColor(.secondary)
                        Spacer()
                        TextField("Code", text: $nominalCode).multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationBarTitle(Text("Edit Details"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Save") {
                    appState.updateReceiptDetails(
                        id: receipt.id ?? "",
                        merchant: merchant,
                        amount: amount,
                        date: date,
                        nominalCode: nominalCode
                    )
                    presentationMode.wrappedValue.dismiss()
                }.font(.system(size: 16, weight: .bold))
            )
            .onAppear {
                merchant = receipt.merchantDetected ?? ""
                amount = receipt.amountDetected ?? ""
                date = receipt.dateDetected ?? ""
                nominalCode = receipt.nominalCode ?? ""
            }
        }
    }
}

struct ReceiptHistoryPage: View {
    let history: [ReceiptHistoryEntry]
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ScrollView {
            if history.isEmpty {
                VStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                    Text("No history available").font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, minHeight: 480)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(history.enumerated()), id: \.offset) { idx, entry in
                        HStack(alignment: .top, spacing: 12) {
                            // Timeline dot + line
                            VStack(spacing: 0) {
                                Circle().fill(Color.goldDark).frame(width: 10, height: 10).padding(.top, 3)
                                if idx < history.count - 1 {
                                    Rectangle().fill(Color.goldDark.opacity(0.2)).frame(width: 1).frame(maxHeight: .infinity)
                                }
                            }.frame(width: 10)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.action ?? "Action").font(.system(size: 13, weight: .semibold))
                                if let d = entry.details, !d.isEmpty {
                                    Text(d).font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                if let ts = entry.timestamp, ts > 0 {
                                    Text(FormatUtils.formatDateTime(ts))
                                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, idx == 0 ? 16 : 12)
                        .padding(.bottom, idx == history.count - 1 ? 16 : 0)
                    }
                }
                .background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
            }
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("History"), displayMode: .inline)
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
}
