import SwiftUI

struct FloatApprovalDetailPage: View {
    let float: FloatRequest
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var details: FloatDetailsResponse? = nil
    @State private var liveFloat: FloatRequest? = nil
    @State private var isLoading = true
    @State private var showRejectSheet = false
    @State private var rejectReason = ""
    @State private var actioning = false
    @State private var showHistory = false

    private var displayFloat: FloatRequest { liveFloat ?? float }
    private var totals: FloatTotals { details?.totals ?? FloatTotals() }
    private var isAccountant: Bool { appState.currentUser?.isAccountant == true }
    private var isApprover: Bool { appState.cashMeta?.isApprover == true }
    private var canAct: Bool {
        // Approvers and accountants can approve / reject AWAITING_APPROVAL floats
        (displayFloat.status ?? "").uppercased() == "AWAITING_APPROVAL" && (isApprover || isAccountant)
    }

    /// 2 if no tier config is carried on the model — matches the web.
    private var totalApprovalTiers: Int { max(2, (displayFloat.approvals ?? []).count + 1) }

    private var isAwaitingApproval: Bool {
        (displayFloat.status ?? "").uppercased() == "AWAITING_APPROVAL"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgSurface.edgesIgnoringSafeArea(.all)
            if isLoading {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header — name, role, date, pending badge
                        pendingHeader
                            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

                        Divider()

                        // 2-column grid of details (screenshot 2 layout)
                        detailsGrid
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                        Divider()

                        // Purpose panel (light grey box)
                        purposePanel
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                        Divider()

                        // Approval progress
                        approvalProgressPanel
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)

                        // Rejection reason (if set)
                        if let reason = displayFloat.rejectionReason, !reason.isEmpty {
                            Divider()
                            rejectionCard(reason: reason)
                                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 14)
                        }

                        // Activity sections only make sense AFTER issuance;
                        // suppressed while the float is still AWAITING_APPROVAL.
                        if !isAwaitingApproval {
                            if !((details?.batches ?? []).isEmpty)  {
                                Divider()
                                batchesSection.padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            if !((details?.topups ?? []).isEmpty)   {
                                Divider()
                                topupsSection.padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            if !((details?.returns ?? []).isEmpty)  {
                                Divider()
                                returnsSection.padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, canAct ? 100 : 24)
                }
            }
            if canAct { actionFooter }
        }
        .navigationBarTitle(Text("\(displayFloat.reqNumber ?? "") — Float Request"), displayMode: .inline)
        .navigationBarItems(trailing:
            Button(action: openHistory) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 14, weight: .semibold))
                    Text("History").font(.system(size: 14, weight: .semibold))
                }.foregroundColor(.goldDark)
            }
        )
        .background(
            NavigationLink(
                destination: FloatHistoryPage(
                    floatId: displayFloat.id,
                    floatLabel: "#\(displayFloat.reqNumber ?? "")"
                ).environmentObject(appState),
                isActive: $showHistory
            ) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .onAppear { reload() }
        .sheet(isPresented: $showRejectSheet) { rejectSheet }
    }

    private func openHistory() {
        showHistory = true
    }

    // MARK: - New header / grid / purpose / approval panels

    /// Top section — user name (bold), role · department, submitted date/time,
    /// and a "PENDING X/Y" badge on the right.
    private var pendingHeader: some View {
        let user = UsersData.byId[displayFloat.userId ?? ""]
        let name = user?.fullName ?? "—"
        let roleLine: String = {
            let role = user?.displayDesignation ?? ""
            let dept = (displayFloat.department ?? "").isEmpty ? (user?.displayDepartment ?? "") : (displayFloat.department ?? "")
            switch (role.isEmpty, dept.isEmpty) {
            case (false, false): return "\(role) · \(dept)"
            case (false, true):  return role
            case (true, false):  return dept
            default:             return ""
            }
        }()
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.system(size: 16, weight: .bold))
                if !roleLine.isEmpty {
                    Text(roleLine).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Text(FormatUtils.formatDateTime(displayFloat.createdAt ?? 0))
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
            }
            Spacer(minLength: 8)
            Text("PENDING \((displayFloat.approvals ?? []).count)/\(totalApprovalTiers)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.goldDark)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.gold.opacity(0.15)).cornerRadius(6)
        }
    }

    /// Two-column grid of six fields — REQUESTED AMOUNT / HOW LONG,
    /// COLLECTION METHOD / DEPARTMENT, START DATE / COLLECT DATE/TIME.
    private var detailsGrid: some View {
        let duration: String = {
            let d = (displayFloat.duration ?? "").lowercased()
            if d == "run_of_show" { return "Run of Show" }
            if d.isEmpty { return "—" }
            if let n = Int(d) { return "\(n) day\(n == 1 ? "" : "s")" }
            return displayFloat.duration ?? ""
        }()
        let collection: String = {
            let key = displayFloat.collectionMethod ?? ""
            if let label = collectionOptions.first(where: { $0.0 == key })?.1 { return label }
            if key.isEmpty { return "—" }
            return key.replacingOccurrences(of: "_", with: " ").capitalized
        }()
        let startDate: String = {
            guard let s = displayFloat.startDate, s > 0 else { return "—" }
            return FormatUtils.formatTimestamp(s)
        }()
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                gridCell("REQUESTED AMOUNT", FormatUtils.formatGBP(displayFloat.reqAmount ?? 0), valueColor: .goldDark, mono: true)
                gridCell("HOW LONG", duration)
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("COLLECTION METHOD", collection)
                gridCell("DEPARTMENT", (displayFloat.department ?? "").isEmpty ? "—" : (displayFloat.department ?? ""))
            }
            HStack(alignment: .top, spacing: 16) {
                gridCell("START DATE", startDate)
                gridCell("COLLECT DATE/TIME", "—")
            }
        }
    }

    private func gridCell(_ label: String, _ value: String,
                          valueColor: Color = .primary, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            Text(value)
                .font(mono
                      ? .system(size: 15, weight: .bold, design: .monospaced)
                      : .system(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "PURPOSE / JUSTIFICATION" with the body in a subtle grey-filled box.
    private var purposePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PURPOSE / JUSTIFICATION")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            Text((displayFloat.purpose ?? "").isEmpty ? "—" : (displayFloat.purpose ?? ""))
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.bgRaised)
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// APPROVAL PROGRESS (N/T) — lists existing approvals, or "No approvals yet".
    private var approvalProgressPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("APPROVAL PROGRESS (\((displayFloat.approvals ?? []).count)/\(totalApprovalTiers))")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            if (displayFloat.approvals ?? []).isEmpty {
                Text("No approvals yet")
                    .font(.system(size: 13)).foregroundColor(.secondary)
            } else {
                ForEach(displayFloat.approvals ?? [], id: \.tierNumber) { a in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12)).foregroundColor(.green)
                        Text(UsersData.byId[a.userId ?? ""]?.fullName ?? (a.userId ?? "—"))
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("Tier \(a.tierNumber ?? 0)")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                        Text(FormatUtils.formatDateTime(a.approvedAt ?? 0))
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    private var headerCard: some View {
        let (fg, bg) = floatStatusColors(displayFloat.status ?? "")
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(UsersData.byId[displayFloat.userId ?? ""]?.fullName ?? "—")
                        .font(.system(size: 16, weight: .bold))
                    if !(displayFloat.department ?? "").isEmpty {
                        Text(displayFloat.department ?? "").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Text("#\(displayFloat.reqNumber ?? "")")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.goldDark)
                }
                Spacer()
                Text(displayFloat.statusDisplay.uppercased())
                    .font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(bg).cornerRadius(4)
            }
            if !displayFloat.statusSubtitle.isEmpty {
                Text(displayFloat.statusSubtitle).font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack(spacing: 12) {
                metaCol("Submitted", FormatUtils.formatTimestamp(displayFloat.createdAt ?? 0))
                metaCol("Duration", (displayFloat.duration ?? "").isEmpty ? "—" : (displayFloat.duration == "run_of_show" ? "Run of Show" : "\(displayFloat.duration ?? "") days"))
                metaCol("Cost Code", (displayFloat.costCode ?? "").isEmpty ? "—" : (displayFloat.costCode ?? "").uppercased())
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func metaCol(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(.system(size: 11, weight: .semibold))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var purposeCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PURPOSE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(displayFloat.purpose ?? "").font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Amounts breakdown

    private var amountsBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Amounts").font(.system(size: 14, weight: .bold))
            VStack(spacing: 6) {
                amountRow("Requested",   FormatUtils.formatGBP((totals.requested ?? 0) > 0 ? (totals.requested ?? 0) : (displayFloat.reqAmount ?? 0)))
                amountRow("Issued",      FormatUtils.formatGBP(totals.issued ?? 0))
                if (totals.toppedUp ?? 0) > 0   { amountRow("Topped Up",  FormatUtils.formatGBP(totals.toppedUp ?? 0), color: .blue) }
                amountRow("Spent",       FormatUtils.formatGBP(totals.spent ?? 0), color: .orange)
                if (totals.returned ?? 0) > 0   { amountRow("Returned",   FormatUtils.formatGBP(totals.returned ?? 0), color: .gray) }
                Divider()
                amountRow("Balance",     FormatUtils.formatGBP((totals.finalBalance ?? 0) > 0 ? (totals.finalBalance ?? 0) : displayFloat.remaining), color: .goldDark, bold: true)
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func amountRow(_ label: String, _ value: String, color: Color = .primary, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: bold ? .bold : .regular)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: bold ? .bold : .semibold, design: .monospaced)).foregroundColor(color)
        }
    }

    // MARK: - Posted batches

    private var batchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Posted Batches").font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\((details?.batches ?? []).count)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
            }
            ForEach(details?.batches ?? [], id: \.id) { raw in
                let batch = raw.toClaimBatch()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("#\(batch.batchReference ?? "")").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                        Text(batch.statusDisplay).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(FormatUtils.formatGBP(batch.totalGross ?? 0))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .padding(10).background(Color.bgRaised).cornerRadius(8)
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Top-ups

    private var topupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Top-ups").font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\((details?.topups ?? []).count)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
            }
            ForEach(details?.topups ?? [], id: \.id) { t in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text((t.status ?? "").capitalized).font(.system(size: 11, weight: .semibold))
                        if (t.createdAt ?? 0) > 0 {
                            Text(FormatUtils.formatTimestamp(t.createdAt ?? 0)).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text(FormatUtils.formatGBP((t.issuedAmount ?? 0) > 0 ? (t.issuedAmount ?? 0) : (t.amount ?? 0)))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.blue)
                }
                .padding(10).background(Color.bgRaised).cornerRadius(8)
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Returns

    private var returnsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cash Returns").font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\((details?.returns ?? []).count)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
            }
            ForEach(details?.returns ?? [], id: \.id) { r in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text((r.returnReason ?? "").replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text(FormatUtils.formatGBP(r.returnAmount ?? 0))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.gray)
                    }
                    if !(r.reasonNotes ?? "").isEmpty {
                        Text(r.reasonNotes!).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    if (r.recordedAt ?? 0) > 0 {
                        Text(FormatUtils.formatDateTime(r.recordedAt ?? 0)).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bgRaised).cornerRadius(8)
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Approvals

    private var approvalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Approvals").font(.system(size: 14, weight: .bold))
            ForEach((displayFloat.approvals ?? []).sorted(by: { ($0.tierNumber ?? 0) < ($1.tierNumber ?? 0) }), id: \.userId) { a in
                HStack {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tier \(a.tierNumber ?? 0) — \(UsersData.byId[a.userId ?? ""]?.fullName ?? (a.userId ?? "—"))")
                            .font(.system(size: 12, weight: .semibold))
                        if (a.approvedAt ?? 0) > 0 {
                            Text(FormatUtils.formatDateTime(a.approvedAt ?? 0)).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func rejectionCard(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundColor(.red)
                Text("Rejection Reason").font(.system(size: 12, weight: .bold)).foregroundColor(.red)
            }
            Text(reason).font(.system(size: 11)).foregroundColor(.primary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.06)).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Action footer (role-aware)
    //
    // Accountants get a single "Override" button (bypasses the tier chain;
    // matches the web flow that stamps the float as ACCT_OVERRIDE).
    // Approvers see the normal "Reject" + "Approve" pair.

    @ViewBuilder
    private var actionFooter: some View {
        Group {
            if isAccountant {
                // Accountant: single gold "Override" button, right-aligned.
                // Accountants have override privilege over the approval chain,
                // so this takes precedence even if they also happen to be an
                // approver on this float.
                HStack {
                    Spacer()
                    Button(action: overrideFloat) {
                        HStack(spacing: 6) {
                            if actioning {
                                ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                            }
                            Text(actioning ? "Overriding…" : "Override")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 28).padding(.vertical, 12)
                        .background(Color.gold).cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
                }
            } else {
                // Approver (and approver+accountant): Reject + Approve pair
                HStack(spacing: 10) {
                    Button(action: { showRejectSheet = true }) {
                        Text("Reject").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.red).cornerRadius(10)
                    }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
                    Button(action: approve) {
                        HStack(spacing: 6) {
                            if actioning { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                            Text(actioning ? "Approving…" : "Approve").font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.green).cornerRadius(10)
                    }.buttonStyle(BorderlessButtonStyle()).disabled(actioning)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.bgSurface)
        .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
    }

    private var rejectSheet: some View {
        NavigationView {
            ZStack {
                Color.bgBase.edgesIgnoringSafeArea(.all)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reject float request from \(UsersData.byId[displayFloat.userId ?? ""]?.fullName ?? "—")")
                        .font(.system(size: 15, weight: .semibold))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reason").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                        TextField("Enter reason…", text: $rejectReason)
                            .font(.system(size: 14)).padding(10)
                            .background(Color.bgSurface).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }
                    Spacer()
                }.padding()
            }
            .navigationBarTitle(Text("Reject Float"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { showRejectSheet = false; rejectReason = "" }.foregroundColor(.goldDark),
                trailing: Button("Reject") {
                    let r = rejectReason.trimmingCharacters(in: .whitespaces)
                    guard !r.isEmpty else { return }
                    showRejectSheet = false
                    reject(reason: r)
                }.foregroundColor(.red).font(.system(size: 16, weight: .bold))
            )
        }
    }

    // MARK: - Actions

    private func reload() {
        appState.loadFloatDetails(displayFloat.id) { d in
            details = d
            if let raw = d?.float { liveFloat = raw.toFloatRequest() }
            isLoading = false
        }
    }

    private func approve() {
        actioning = true
        // Backend is keyed on tier_number. Approver supplies their own tier; for now use next tier.
        let nextTier = ((displayFloat.approvals ?? []).map { $0.tierNumber ?? 0 }.max() ?? 0) + 1
        let totalTiers = max(nextTier, 1)
        appState.approveFloatRequest(id: displayFloat.id, tierNumber: nextTier, totalTiers: totalTiers) { success in
            actioning = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }

    private func reject(reason: String) {
        actioning = true
        appState.rejectFloatRequest(id: displayFloat.id, reason: reason) { success in
            actioning = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }

    /// Accountant one-click override — posts `override: true` alongside the
    /// standard approve payload. Backend stamps the float as ACCT_OVERRIDE.
    private func overrideFloat() {
        actioning = true
        appState.overrideFloatRequest(id: displayFloat.id) { success in
            actioning = false
            if success { presentationMode.wrappedValue.dismiss() }
        }
    }
}
