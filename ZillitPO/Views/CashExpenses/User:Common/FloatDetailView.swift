import SwiftUI
import UIKit

struct FloatDetailView: View {
    let float: FloatRequest
    @EnvironmentObject var appState: POViewModel
    @State private var selectedBatchId: String?
    /// Rich details from GET /float-requests/{id}/details (batches, top-ups,
    /// returns, totals). Fetched on appear so batches always populate even
    /// if the Active Floats tab hasn't loaded `allClaims` yet.
    @State private var details: FloatDetailsResponse? = nil
    /// True on first entry and during any subsequent re-fetch. Drives the
    /// full-screen loader so the user sees a spinner instead of the raw
    /// `float` prop data while `/details` is in-flight.
    @State private var isLoading: Bool = true
    /// Drives the nav-bar History button → FloatHistoryPage push.
    @State private var navigateToHistory = false
    /// Drives the pink "Record Cash Return" action → RecordCashReturnPage.
    @State private var navigateToRecordReturn = false
    /// Collapsible state for the CASH RETURNS section — collapsed by
    /// default so the page stays short when there are many returns.
    @State private var cashReturnsExpanded: Bool = false

    /// Batches belonging to this float. Prefer the authoritative
    /// `/details` response; fall back to the client-side filter on
    /// `allClaims` so the UI still works if the detail call hasn't
    /// completed yet and the claims list happens to be populated.
    private var batches: [ClaimBatch] {
        if let d = details, !(d.batches ?? []).isEmpty {
            return d.batches ?? []
        }
        return appState.allClaims.filter { $0.floatRequestId == float.id }
    }
    private var balance: Double { float.remaining }

    /// Delegates to the shared file-scope helper so float status colors are
    /// consistent everywhere (FloatCard, FloatDetailView, approval queue, etc.)
    /// Uses the full backend state machine:
    /// AWAITING_APPROVAL → APPROVED / ACCT_OVERRIDE → READY_TO_COLLECT →
    /// COLLECTED → ACTIVE / SPENDING / SPENT / PENDING_RETURN →
    /// CLOSED / CANCELLED / REJECTED.
    private func statusColor(_ s: String) -> (Color, Color) {
        floatStatusColors(s)
    }

    private func batchColor(_ s: String) -> (Color, Color) {
        switch s.uppercased() {
        case "CODING", "CODED": return (.purple, Color.purple.opacity(0.1))
        case "POSTED": return (.green, Color.green.opacity(0.1))
        case "REJECTED": return (.red, Color.red.opacity(0.1))
        case "ESCALATED": return (.orange, Color.orange.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium))
        }.padding(.horizontal, 14).padding(.vertical, 6)
    }

    @ViewBuilder
    private func batchStatusFlow(_ batch: ClaimBatch) -> some View {
        let steps: [(key: String, label: String, sub: String)] = [
            ("CODING", "Submitted", "Batch #\(batch.batchReference ?? "")"),
            ("CODED", "Coordinator Coding", "Budget coding done"),
            ("IN_AUDIT", "Accounts Audit", "Audited & verified"),
            ("AWAITING_APPROVAL", "Approval", "Approved"),
            ("READY_TO_POST", "Post & Ledger", "Ready to post"),
            ("POSTED", "Settlement", (batch.settlementType ?? "").isEmpty ? "Complete" : (batch.settlementType ?? "").replacingOccurrences(of: "_", with: " ").capitalized),
        ]
        let current: Int = {
            switch (batch.status ?? "").uppercased() {
            case "CODING": return 0
            case "CODED": return 1
            case "IN_AUDIT": return 2
            case "AWAITING_APPROVAL", "ACCT_OVERRIDE": return 3
            case "READY_TO_POST", "ESCALATED": return 4
            case "POSTED": return 5
            case "REJECTED": return -1
            default: return 0
            }
        }()
        VStack(alignment: .leading, spacing: 0) {
            Text("STATUS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 6)
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(idx < current ? Color.green : idx == current ? Color.goldDark : Color.gray.opacity(0.25))
                            .frame(width: 12, height: 12)
                        if idx < steps.count - 1 {
                            Rectangle()
                                .fill(idx < current ? Color.green.opacity(0.4) : Color.gray.opacity(0.2))
                                .frame(width: 2, height: 24)
                        }
                    }.frame(width: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.label)
                            .font(.system(size: 12, weight: idx == current ? .bold : .medium))
                            .foregroundColor(idx < current ? .green : idx == current ? .goldDark : .secondary)
                        Text(step.sub).font(.system(size: 10)).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
            }
            if (batch.status ?? "").uppercased() == "REJECTED" {
                HStack(spacing: 8) {
                    Circle().fill(Color.red).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rejected").font(.system(size: 12, weight: .bold)).foregroundColor(.red)
                        Text("Resubmit required").font(.system(size: 10)).foregroundColor(.red.opacity(0.7))
                    }
                }.padding(.horizontal, 14).padding(.top, 4)
            }
        }
        .padding(.bottom, 10).background(Color.bgRaised.opacity(0.5))
    }

    // MARK: - Layout helpers

    private var spendPercent: Double {
        let issued = float.issuedFloat ?? 0
        guard issued > 0 else { return 0 }
        return min(max((float.receiptsAmount ?? 0) / issued, 0), 1)
    }

    private var statusFooter: (String, Color, String) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        switch (float.status ?? "").uppercased() {
        case "AWAITING_APPROVAL":   return ("Float request submitted — awaiting approval", .orange, "clock.fill")
        case "APPROVED":            return ("Float approved — awaiting cash preparation", .green, "checkmark.circle.fill")
        case "ACCT_OVERRIDE":       return ("Override approved — awaiting cash preparation", .green, "bolt.fill")
        case "READY_TO_COLLECT":    return ("Cash ready — collect from the accountant", .blue, "banknote.fill")
        case "COLLECTED":           return ("Cash collected — ready to spend", teal, "checkmark.seal.fill")
        case "ACTIVE":              return ("Float active — submit receipts against this float", .goldDark, "creditcard.fill")
        case "SPENDING":            return ("Spending in progress — submit receipts as you go", .goldDark, "cart.fill")
        case "SPENT":               return ("All cash spent — submit final receipts to close", .purple, "doc.text.fill")
        case "PENDING_RETURN":      return ("Awaiting physical cash return to accountant", Color(red: 0.91, green: 0.29, blue: 0.48), "arrow.uturn.backward.circle.fill")
        case "CLOSED":              return ("Float closed", .gray, "checkmark.seal.fill")
        case "CANCELLED":           return ("Float cancelled", .red, "xmark.circle.fill")
        case "REJECTED":            return ("Float rejected — see notes below", .red, "xmark.circle.fill")
        default:                    return (float.statusDisplay, .secondary as Color, "info.circle.fill")
        }
    }

    /// Two-line detail cell (label on top, value below) used in the 3-column grid.
    private func gridCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 13, weight: value.isEmpty ? .regular : .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Three stat columns (Float Issued / Spent / Remaining Balance) — styled
    /// like the web screenshot with subtle cream background and colored values.
    private func statColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.4)
            Text(value).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Body

    // Totals — prefer backend-computed values from /details; fall back
    // to the values baked into the float object when the API is slow.
    private var issuedTotal: Double   { details?.totals?.issued       ?? (float.issuedFloat ?? 0) }
    private var spentTotal: Double    { details?.totals?.spent        ?? float.spentTotal }
    private var toppedUpTotal: Double { details?.totals?.toppedUp     ?? 0 }
    private var finalBalance: Double  { details?.totals?.finalBalance ?? float.remaining }
    private var returnedTotal: Double { details?.totals?.returned     ?? (float.returnAmount ?? 0) }

    /// Action bar visibility — only PENDING_RETURN currently triggers a
    /// pinned footer action ("Record Cash Return"). More button states
    /// (Ready to Collect / Mark Collected / Mark Close) can be slotted
    /// into `actionFooter` alongside this one.
    private var hasFooterAction: Bool {
        (float.status ?? "").uppercased() == "PENDING_RETURN"
    }

    /// Pinned footer action bar. Shown for statuses where a primary
    /// action makes sense — currently PENDING_RETURN surfaces the pink
    /// "Record Cash Return" button matching the web.
    @ViewBuilder
    private var actionFooter: some View {
        if (float.status ?? "").uppercased() == "PENDING_RETURN" {
            HStack {
                Spacer()
                Button(action: { navigateToRecordReturn = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 13))
                        Text("Record Cash Return")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color(red: 0.91, green: 0.29, blue: 0.48)) // pink-500
                    .cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.bgSurface)
            .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
        }
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgSurface.edgesIgnoringSafeArea(.all)
            if isLoading {
                // Full-screen spinner while /details is in-flight. Users
                // see this before any content shows, so there's no flash
                // of stale list-level values.
                VStack { Spacer(); LoaderView(); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header row ─────────────────────────────────────────
                // #PC-XXXX + status chip · REQUESTED value on the right
                // submitted/collected dates + purpose in italic below
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("#\(float.reqNumber ?? "")")
                                .font(.system(size: 17, weight: .bold, design: .monospaced))
                            let (fg, bg) = statusColor(float.status ?? "")
                            Text(float.statusDisplay)
                                .font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(bg).cornerRadius(4)
                        }
                        Text(submittedCollectedLine)
                            .font(.system(size: 11)).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !(float.purpose ?? "").isEmpty {
                            Text("\u{201C}\(float.purpose ?? "")\u{201D}")
                                .font(.system(size: 12, weight: .regular))
                                .italic()
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("REQUESTED")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        Text(FormatUtils.formatGBP(float.reqAmount ?? 0))
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                    }
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

                Divider()

                // ── SUMMARY: 2-col grid (2×2 + 1 spill row for RETURNED)
                VStack(alignment: .leading, spacing: 0) {
                    Text("SUMMARY")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        .padding(.bottom, 10)
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            summaryCell("ISSUED",    FormatUtils.formatGBP(issuedTotal),   color: .goldDark)
                            summaryCell("SPENT",     FormatUtils.formatGBP(spentTotal),    color: .blue)
                        }
                        HStack(spacing: 12) {
                            summaryCell("TOPPED UP", FormatUtils.formatGBP(toppedUpTotal),
                                        color: Color(red: 0.95, green: 0.55, blue: 0.15))
                            summaryCell("FINAL BALANCE", FormatUtils.formatGBP(finalBalance),
                                        color: Color(red: 0.0, green: 0.55, blue: 0.25))
                        }
                        // Lone RETURNED cell spans the full screen width.
                        summaryCell("RETURNED", FormatUtils.formatGBP(returnedTotal),
                                    color: Color(red: 0.91, green: 0.29, blue: 0.48))
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 16)

                Divider()

                // ── POSTED BATCHES ──────────────────────────────────────
                // Mirrors the web: each batch row expands inline to reveal
                // SETTLEMENT + FOLLOW-UP metadata, then a table of receipts.
                Text("POSTED BATCHES · \(batches.count)")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
                if batches.isEmpty {
                    emptySection(text: "No posted batches against this float.")
                        .padding(.horizontal, 16).padding(.bottom, 14)
                } else {
                    VStack(spacing: 10) {
                        ForEach(batches) { batch in
                            postedBatchCard(batch)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 14)
                }

                Divider()

                // ── TOP-UPS ─────────────────────────────────────────────
                let topups = details?.topups ?? []
                Text("TOP-UPS · \(topups.count)")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
                if topups.isEmpty {
                    emptySection(text: "No top-ups were requested against this float.")
                        .padding(.horizontal, 16).padding(.bottom, 14)
                } else {
                    ForEach(topups, id: \.id) { t in
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.up.circle").font(.system(size: 12))
                                .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
                            VStack(alignment: .leading, spacing: 1) {
                                let tStatus = (t.status ?? "").capitalized
                                Text(tStatus.isEmpty ? "Top-Up" : tStatus)
                                    .font(.system(size: 12, weight: .semibold))
                                if (t.createdAt ?? 0) > 0 {
                                    Text(FormatUtils.formatDateTime(t.createdAt ?? 0))
                                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Text(FormatUtils.formatGBP((t.issuedAmount ?? 0) > 0 ? (t.issuedAmount ?? 0) : (t.amount ?? 0)))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        Divider()
                    }
                    Spacer().frame(height: 8)
                }

                Divider()

                // ── CASH RETURNS (collapsible) ─────────────────────────
                // Collapsed by default so the detail page stays compact
                // even when a float has accumulated many partial returns.
                let returns = details?.returns ?? []
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        cashReturnsExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("CASH RETURNS · \(returns.count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary).tracking(0.6)
                        Spacer()
                        Image(systemName: cashReturnsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

                if cashReturnsExpanded {
                    if returns.isEmpty {
                        emptySection(text: "No cash returns recorded against this float.")
                            .padding(.horizontal, 16).padding(.bottom, 14)
                    } else {
                        ForEach(returns, id: \.id) { r in
                            cashReturnRow(r)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                            Divider()
                        }
                        Spacer().frame(height: 8)
                    }
                }

                // ── Rejection banner (only when applicable) ─────────────
                if let reason = float.rejectionReason, !reason.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REJECTION REASON")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.red).tracking(0.6)
                        Text(reason).font(.system(size: 12)).foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.red.opacity(0.06))
                }

                // Bottom spacer so the pinned action bar doesn't cover the
                // last section (rejection banner / cash returns / etc).
                if hasFooterAction {
                    Spacer().frame(height: 80)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
            } // end if isLoading { … } else { ScrollView … }

            // ── Pinned action footer ─────────────────────────────────
            if hasFooterAction && !isLoading { actionFooter }
        }
        .navigationBarTitle(Text("Float \(float.reqNumber ?? "")"), displayMode: .inline)
        // History button — visible on every status. Even pre-collection
        // floats have a "Submitted" entry worth showing, and users may
        // want to see rejection notes etc.
        .navigationBarItems(trailing:
            Button(action: { navigateToHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.goldDark)
            }
            .accessibility(label: Text("History"))
        )
        .background(
            ZStack {
                NavigationLink(
                    destination: FloatHistoryPage(floatId: float.id ?? "", floatLabel: "#\(float.reqNumber ?? "")")
                        .environmentObject(appState),
                    isActive: $navigateToHistory
                ) { EmptyView() }.frame(width: 0, height: 0).hidden()
                // Preselects this float on the record-return form so the
                // user lands straight on amount/date/reason — the detail
                // page already made the selection explicit.
                NavigationLink(
                    destination: RecordCashReturnPage(floats: [float], preselectedFloatId: float.id)
                        .environmentObject(appState),
                    isActive: $navigateToRecordReturn
                ) { EmptyView() }.frame(width: 0, height: 0).hidden()
            }
        )
        .onAppear {
            // Show the loader, then re-hit /details so Issued/Spent/
            // Balance reflect the latest backend state (after a return
            // was recorded or a batch posted via another screen).
            isLoading = true
            appState.loadFloatDetails(float.id ?? "") { d in
                if let d = d { self.details = d }
                // Whether the call succeeded or returned empty, we're
                // done loading — the existing `float` prop + any new
                // `details` are enough to render a sensible page.
                self.isLoading = false
            }
            if appState.allClaims.isEmpty { appState.loadAllClaims() }
        }
    }

    // MARK: - Header helpers

    /// "Submitted 10 Apr 2026 · Collected 10 Apr 2026" — matches the web.
    /// `startDate` acts as the collected date when set (that's when the
    /// crew physically took the cash).
    private var submittedCollectedLine: String {
        var parts: [String] = []
        if (float.createdAt ?? 0) > 0 {
            parts.append("Submitted \(FormatUtils.formatTimestamp(float.createdAt ?? 0))")
        }
        if let s = float.startDate, s > 0 {
            parts.append("Collected \(FormatUtils.formatTimestamp(s))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Summary cell (used by the 2×2 SUMMARY grid)

    private func summaryCell(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.bgRaised.opacity(0.4))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
    }

    private func emptySection(text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 18)
            .background(Color.bgRaised.opacity(0.3))
            .cornerRadius(8)
    }

    // MARK: - Posted batch card (inline expandable)
    //
    // Collapsed: #RB-XXXX + status chip, "Posted … · N receipt · Settlement
    // Type", amount on right, chevron.
    // Expanded: SETTLEMENT + FOLLOW-UP chips, then a receipt table.

    private func settlementLabel(_ type: String) -> String {
        let t = type.lowercased()
        switch t {
        case "":                          return "—"
        case "reduce", "reduce_float":    return "Reduce Float"
        case "reimb", "reimburse":        return "Reimburse"
        case "reimburse_bacs", "bacs":    return "Reimburse BACS"
        case "payroll":                   return "Payroll"
        case "float":                     return "Float"
        default:                          return t.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func followUpLabel(_ key: String) -> String {
        let k = key.lowercased()
        switch k {
        case "":        return "—"
        case "close":   return "Close the Float"
        case "top_up":  return "Reimburse to Float"
        default:        return k.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Short status chip label ("Close" when the batch has `close` follow-up,
    /// else the normal statusDisplay) — mirrors the web's compact chip.
    private func batchChipLabel(_ batch: ClaimBatch) -> String {
        if (batch.followUp ?? "").lowercased() == "close" { return "Close" }
        return batch.statusDisplay
    }

    @ViewBuilder
    private func postedBatchCard(_ batch: ClaimBatch) -> some View {
        let isSelected = selectedBatchId == batch.id
        let (bfg, bbg) = batchColor(batch.status ?? "")
        VStack(spacing: 0) {
            // ── Header row (tap toggles expansion) ─────────────────
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedBatchId = isSelected ? nil : batch.id
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 12)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("#\(batch.batchReference ?? "")")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                            Text(batchChipLabel(batch))
                                .font(.system(size: 9, weight: .bold)).foregroundColor(bfg)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(bbg).cornerRadius(3)
                        }
                        Text(batchSubtitle(batch))
                            .font(.system(size: 10)).foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(FormatUtils.formatGBP(batch.totalGross ?? 0))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.0, green: 0.55, blue: 0.25))
                }
                .padding(12)
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            // ── Expanded body: settlement + follow-up + table ──────
            if isSelected {
                Divider()
                // Settlement · Follow-up meta row
                HStack(alignment: .top, spacing: 16) {
                    metaPair("SETTLEMENT", settlementLabel(batch.settlementType ?? ""))
                    metaPair("FOLLOW-UP", followUpLabel(batch.followUp ?? ""))
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.bgRaised.opacity(0.35))

                Divider()

                // Receipt table (single aggregate row if we don't have
                // individual receipts decoded yet — batch totals stand in).
                batchReceiptTable(batch)
            }
        }
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(isSelected ? Color.goldDark : Color.borderColor,
                    lineWidth: isSelected ? 2 : 1))
    }

    private func batchSubtitle(_ batch: ClaimBatch) -> String {
        var parts: [String] = []
        let stamp = batch.postedAt ?? (batch.createdAt ?? 0)
        if stamp > 0 { parts.append("Posted \(FormatUtils.formatDateTime(stamp))") }
        let count = batch.claimCount ?? 0
        parts.append("\(count) receipt\(count == 1 ? "" : "s")")
        let sType = batch.settlementType ?? ""
        if !sType.isEmpty { parts.append(settlementLabel(sType)) }
        return parts.joined(separator: " · ")
    }

    private func metaPair(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary)
        }
    }

    /// Table of receipts inside a batch. Individual receipts aren't
    /// decoded in the current `ClaimBatch`; we surface a single
    /// aggregate row (description = notes/coding, amount = totalGross).
    /// When the backend returns per-receipt data we can switch this
    /// `ForEach` to iterate the real line items.
    @ViewBuilder
    private func batchReceiptTable(_ batch: ClaimBatch) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                tableHeader("#",           width: 24,  align: .leading)
                tableHeader("DESCRIPTION", width: nil, align: .leading)
                tableHeader("AMOUNT",      width: 72,  align: .trailing)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.bgRaised.opacity(0.2))

            Divider()

            // One row — aggregate from batch data until per-receipt data
            // is available from the backend.
            HStack(alignment: .top, spacing: 8) {
                Text("1").font(.system(size: 11)).foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
                Text({
                    let codingDesc = batch.codingDescription ?? ""
                    let notes = batch.notes ?? ""
                    if !codingDesc.isEmpty { return codingDesc }
                    if !notes.isEmpty { return notes }
                    return "—"
                }())
                .font(.system(size: 11)).foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(FormatUtils.formatGBP(batch.totalGross ?? 0))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .frame(width: 72, alignment: .trailing)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            Divider()

            // Meta row: settlement/follow-up date references
            HStack(spacing: 16) {
                metaPair("SETTLEMENT", settlementLabel(batch.settlementType ?? ""))
                metaPair("FOLLOW-UP", followUpLabel(batch.followUp ?? ""))
                Spacer()
                let dateStr: String = {
                    if let p = batch.postedAt, p > 0 { return FormatUtils.formatTimestamp(p) }
                    return "—"
                }()
                metaPair("DATE", dateStr)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
    }

    private func tableHeader(_ text: String, width: CGFloat?, align: Alignment) -> some View {
        let t = Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.secondary)
            .tracking(0.5)
        return Group {
            if let w = width {
                t.frame(width: w, alignment: align)
            } else {
                t.frame(maxWidth: .infinity, alignment: align)
            }
        }
    }

    // MARK: - Cash Return row

    private func cashReturnRow(_ r: FloatReturnEntry) -> some View {
        // Mark as PARTIAL RETURN when the amount is less than the issued
        // total, else FULL RETURN. Reason notes appear below.
        let returnAmt = r.returnAmount ?? 0
        let isFull = returnAmt > 0 && abs(returnAmt - issuedTotal) < 0.005
        let chipLabel = isFull ? "FULL RETURN" : "PARTIAL RETURN"
        let chipColor = Color(red: 0.91, green: 0.29, blue: 0.48)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(FormatUtils.formatGBP(returnAmt)) returned")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text(chipLabel)
                    .font(.system(size: 9, weight: .bold)).foregroundColor(chipColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(chipColor.opacity(0.12))
                    .cornerRadius(3)
                Spacer()
            }
            HStack(spacing: 6) {
                if (r.recordedAt ?? 0) > 0 {
                    Text("Recorded \(FormatUtils.formatDateTime(r.recordedAt ?? 0))")
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                if (r.receivedDate ?? 0) > 0 {
                    if (r.recordedAt ?? 0) > 0 { Text("·").font(.system(size: 10)).foregroundColor(.gray) }
                    Text("Received \(FormatUtils.formatTimestamp(r.receivedDate ?? 0))")
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
            }
            let reasonNotes = r.reasonNotes ?? ""
            let notes = r.notes ?? ""
            if !reasonNotes.isEmpty || !notes.isEmpty {
                let body = !reasonNotes.isEmpty ? reasonNotes : notes
                Text(body).font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    private var durationLabel: String {
        let d = (float.duration ?? "").lowercased()
        if d == "run_of_show" { return "Run of Show" }
        if d.isEmpty { return "—" }
        if let n = Int(d) { return "\(n) day\(n == 1 ? "" : "s")" }
        return float.duration ?? ""
    }

    private func collectionDisplay(_ key: String) -> String {
        if let label = collectionOptions.first(where: { $0.0 == key })?.1 { return label }
        if key.isEmpty { return "—" }
        return key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Float History Page
// Timeline of float status transitions + batch transitions merged into
// a single chronological feed (matches the backend `getHistory` shape:
// [{ action, action_by, action_at, note? }]).
// ═══════════════════════════════════════════════════════════════════

struct FloatHistoryPage: View {
    let floatId: String
    let floatLabel: String
    @EnvironmentObject var appState: POViewModel

    @State private var entries: [FloatHistoryEntry] = []
    @State private var isLoading: Bool = true

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack {
            Color.bgSurface.edgesIgnoringSafeArea(.all)
            if isLoading && entries.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32)).foregroundColor(.gray.opacity(0.35))
                    Text("No history yet").font(.system(size: 13)).foregroundColor(.secondary)
                    Text("Status transitions on this float will appear here.")
                        .font(.system(size: 11)).foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Summary header chip
                        HStack(spacing: 6) {
                            Image(systemName: "banknote").font(.system(size: 12)).foregroundColor(.goldDark)
                            Text(floatLabel)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.goldDark)
                            Spacer()
                            Text("\(entries.count) event\(entries.count == 1 ? "" : "s")")
                                .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        .padding(12).background(Color.bgRaised.opacity(0.4)).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

                        ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                            historyRow(entry, isLast: idx == entries.count - 1)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitle(Text("Float History"), displayMode: .inline)
        .onAppear {
            appState.loadFloatHistory(floatId) { list in
                // Sort newest-first for display.
                self.entries = list.sorted { ($0.actionAt ?? 0) > ($1.actionAt ?? 0) }
                self.isLoading = false
            }
        }
    }

    /// Colour tied to the action string (status transitions mostly).
    /// The cash-expenses server returns history actions as uppercase snake_case
    /// codes (`CASH_RETURN`, `TOP_UP`, `TOP_UP_PARTIAL`, `BALANCE_DEDUCTED`,
    /// `REQUESTED`, etc.). Convert them to human-readable labels for display.
    private func actionLabel(_ action: String) -> String {
        let trimmed = action.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "—" }
        // Explicit overrides for the cleanest phrasing
        switch trimmed.uppercased() {
        case "REQUESTED":         return "Requested"
        case "APPROVED":          return "Approved"
        case "REJECTED":          return "Rejected"
        case "CANCELLED":         return "Cancelled"
        case "OVERRIDE":          return "Override Approved"
        case "ACCT_OVERRIDE":     return "Override Approved"
        case "READY_TO_COLLECT":  return "Ready to Collect"
        case "COLLECTED":         return "Collected"
        case "ACTIVE":            return "Active"
        case "SPENDING":          return "Spending"
        case "SPENT":             return "Spent"
        case "PENDING_RETURN":    return "Pending Return"
        case "CLOSED":            return "Closed"
        case "TOP_UP":            return "Top-Up"
        case "TOP_UP_PARTIAL":    return "Partial Top-Up"
        case "BALANCE_DEDUCTED":  return "Balance Deducted"
        case "CASH_RETURN":       return "Cash Return"
        default:
            // Generic fallback: SNAKE_CASE / snake_case → Title Case
            if trimmed.contains("_") || trimmed == trimmed.uppercased() {
                return trimmed
                    .replacingOccurrences(of: "_", with: " ")
                    .lowercased()
                    .split(separator: " ")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                    .joined(separator: " ")
            }
            return trimmed
        }
    }

    private func actionColor(_ action: String) -> Color {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return .green }
        if a.contains("reject") || a.contains("cancel") { return .red }
        if a.contains("override") { return .orange }
        if a.contains("posted") || a.contains("deduct") { return .green }
        if a.contains("top") && a.contains("up") { return .goldDark }
        if a.contains("return") { return Color(red: 0.91, green: 0.29, blue: 0.48) }
        if a.contains("collected") || a.contains("ready") { return .blue }
        if a.contains("closed") { return .gray }
        return .goldDark
    }

    private func actionIcon(_ action: String) -> String {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return "checkmark.circle.fill" }
        if a.contains("reject") { return "xmark.circle.fill" }
        if a.contains("cancel") { return "slash.circle.fill" }
        if a.contains("override") { return "bolt.fill" }
        if a.contains("deduct") { return "minus.circle.fill" }
        if a.contains("posted") { return "tray.and.arrow.down.fill" }
        if a.contains("top") && a.contains("up") { return "arrow.up.circle.fill" }
        if a.contains("return") { return "arrow.uturn.backward.circle.fill" }
        if a.contains("request") { return "paperplane.fill" }
        if a.contains("collected") { return "banknote.fill" }
        if a.contains("ready") { return "checkmark.seal.fill" }
        if a.contains("closed") { return "lock.fill" }
        return "circle.fill"
    }

    private func resolvedUser(_ entry: FloatHistoryEntry) -> (String, String?) {
        if let uid = entry.actionBy, !uid.isEmpty, let u = UsersData.byId[uid] {
            return (u.fullName ?? "", u.displayDesignation.isEmpty ? nil : u.displayDesignation)
        }
        if let uid = entry.actionBy, !uid.isEmpty { return (uid, nil) }
        return ("Unknown", nil)
    }

    @ViewBuilder
    private func historyRow(_ entry: FloatHistoryEntry, isLast: Bool) -> some View {
        let rawAction = entry.action ?? ""
        let label = actionLabel(rawAction)
        let color = actionColor(rawAction)
        let (name, role) = resolvedUser(entry)
        HStack(alignment: .top, spacing: 12) {
            // Timeline rail: dot + connecting line
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: actionIcon(rawAction))
                        .font(.system(size: 11, weight: .bold)).foregroundColor(color)
                }
                if !isLast {
                    Rectangle().fill(Color.borderColor).frame(width: 2)
                        .frame(maxHeight: .infinity).padding(.top, 2)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                // "by Name (Role)"
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                        .padding(.trailing, 4)
                    (
                        Text("by ").foregroundColor(.secondary)
                        + Text(name).fontWeight(.semibold).foregroundColor(.primary)
                        + Text({ if let r = role { return " (\(r))" } else { return "" } }())
                            .foregroundColor(.secondary)
                    )
                    .font(.system(size: 11))
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                if let n = entry.note, !n.isEmpty {
                    Text(n).font(.system(size: 11)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let ts = entry.actionAt, ts > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.gray)
                        Text(FormatUtils.formatHistoryDateTime(ts))
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgSurface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            .padding(.bottom, isLast ? 0 : 10)
        }
        .padding(.horizontal, 16).padding(.top, 4)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Batch Status Detail Page
// Full-page status timeline for a single claim batch. Mirrors the web
// layout: header (ref + summary), STATUS label, then a 6-step vertical
// timeline with green dots/labels for completed steps and an orange dot
// for the current step.
// ═══════════════════════════════════════════════════════════════════
