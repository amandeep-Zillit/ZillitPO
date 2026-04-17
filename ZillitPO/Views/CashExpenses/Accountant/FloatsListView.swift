import SwiftUI
import UIKit

struct FloatsListView: View {
    let floats: [FloatRequest]
    @EnvironmentObject var appState: POViewModel

    @State private var searchText: String = ""
    @State private var showRecordReturn: Bool = false

    private var totalOutstanding: Double { floats.reduce(0) { $0 + $1.remaining } }

    /// Filters by crew member name, department, float ref number or purpose.
    private var filteredFloats: [FloatRequest] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return floats }
        return floats.filter { f in
            let name = (UsersData.byId[f.userId ?? ""]?.fullName ?? "").lowercased()
            return (f.reqNumber ?? "").lowercased().contains(q)
                || name.contains(q)
                || (f.department ?? "").lowercased().contains(q)
                || (f.purpose ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        Group {
            if appState.isLoadingActiveFloats && floats.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bgBase)
            } else {
                // Fixed header + search bar at the top; only the float list
                // below scrolls.
                VStack(alignment: .leading, spacing: 0) {
                    // ── Register header + Record Cash Return action ──
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active Floats Register").font(.system(size: 15, weight: .bold))
                            Text("\(floats.count) active float\(floats.count == 1 ? "" : "s") · \(FormatUtils.formatGBP(totalOutstanding)) outstanding")
                                .font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        Spacer()
                        if !floats.isEmpty {
                            NavigationLink(
                                destination: RecordCashReturnPage(floats: floats).environmentObject(appState),
                                isActive: $showRecordReturn
                            ) { EmptyView() }.frame(width: 0, height: 0).hidden()
                            Button(action: { showRecordReturn = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .font(.system(size: 11))
                                    Text("Record Cash Return").font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Color.goldDark).cornerRadius(6)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)

                    // ── Search bar (fixed) ───────────────────────────
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12)).foregroundColor(.gray)
                        TextField("Search by crew, department, ref…", text: $searchText)
                            .font(.system(size: 13))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12)).foregroundColor(.gray)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.bgSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    .padding(.horizontal, 16).padding(.bottom, 10)

                    // ── Scrollable list below ─────────────────────────
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if floats.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer(minLength: 0)
                                    Image(systemName: "banknote").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                    Text("No active floats").font(.system(size: 13)).foregroundColor(.secondary)
                                    Spacer(minLength: 0)
                                }.frame(maxWidth: .infinity, minHeight: 480)
                            } else if filteredFloats.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer(minLength: 0)
                                    Image(systemName: "magnifyingglass").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                    Text("No floats match \"\(searchText)\"").font(.system(size: 13)).foregroundColor(.secondary)
                                    Spacer(minLength: 0)
                                }.frame(maxWidth: .infinity, minHeight: 320)
                            } else {
                                ForEach(filteredFloats) { f in
                                    NavigationLink(destination: FloatDetailView(float: f).environmentObject(appState)) {
                                        FloatCard(
                                            float: f,
                                            batches: appState.allClaims.filter { $0.floatRequestId == f.id },
                                            disableInternalTap: true
                                        )
                                        .padding(.horizontal, 16)
                                    }.buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.top, 2).padding(.bottom, 20)
                    }
                }
            }
        }
        .onAppear {
            // Reset search on re-appear (e.g. after returning from a tapped float)
            searchText = ""
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Record Manual Cash Return page (navigation-pushed)
// Select a float → enter amount + date + reason + optional notes →
// POST /record-return. Rendered as a pushed detail page (not a
// modal sheet) so it sits natively in the nav stack.
// ═══════════════════════════════════════════════════════════════════

struct FloatCard: View {
    let float: FloatRequest
    var batches: [ClaimBatch] = []
    var disableInternalTap: Bool = false
    var forceExpanded: Bool = false
    var onTap: (() -> Void)? = nil
    @State private var expandedState = false
    @State private var selectedBatchId: String?

    private var expanded: Bool { forceExpanded || expandedState }

    // MARK: - Stats (match web PCFloatsPage calculations)
    //
    // The web derives every stat from `req_amount` (the float limit),
    // `balance` (server's live remaining), and `issued_float`:
    //
    //   floatLimit = req_amount
    //   balance    = balance ?? floatLimit              // fallback
    //   spent      = max(0, floatLimit - balance)       // simple derivation
    //   issued     = issued_float > 0 ? issued_float : floatLimit
    //
    // We mirror that here so iOS numbers exactly match the desktop.

    private var floatLimit: Double { float.reqAmount ?? 0 }
    private var liveBalance: Double { float.balance ?? floatLimit }
    private var spentDerived: Double { max(0, floatLimit - liveBalance) }
    private var issuedDisplay: Double {
        (float.issuedFloat ?? 0) > 0 ? (float.issuedFloat ?? 0) : floatLimit
    }
    private var spendPct: Double {
        guard floatLimit > 0 else { return 0 }
        return min(max(spentDerived / floatLimit, 0), 1)
    }

    /// Branch the stat strip exactly like the web (`PCFloatsPage.jsx`):
    ///   • CLOSED / CANCELLED      → Limit / Closed
    ///   • in-use (COLLECTED…PENDING_RETURN) → Balance / Spent / Issued + bar
    ///   • otherwise (pre-collection: AWAITING_APPROVAL, APPROVED,
    ///     ACCT_OVERRIDE, READY_TO_COLLECT, REJECTED) → Requested only
    private enum StatsVariant { case terminal, inUse, preCollection }
    private var statsVariant: StatsVariant {
        switch (float.status ?? "").uppercased() {
        case "CLOSED", "CANCELLED":
            return .terminal
        case "COLLECTED", "ACTIVE", "SPENDING", "SPENT", "PENDING_RETURN":
            return .inUse
        default:
            return .preCollection
        }
    }
    private var isClosedLike: Bool { statsVariant == .terminal }

    /// Value shown under the CLOSED / CANCELLED column. Prefer the
    /// returned amount (what actually came back); fall back to the
    /// original limit so the column is never £0 on legacy data.
    private var closedStatValue: Double {
        if (float.returnAmount ?? 0) > 0 { return float.returnAmount! }
        return floatLimit
    }

    /// Days since submission — web uses the same `daysAgo(created_at)`.
    private var daysActive: Int {
        guard (float.createdAt ?? 0) > 0 else { return 0 }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let diff = max(0, nowMs - (float.createdAt ?? 0))
        return Int(diff / 86_400_000)
    }

    /// Duration text — "Run of Show" when run_of_show, else "N days duration".
    private var durationText: String {
        let d = (float.duration ?? "").lowercased()
        if d == "run_of_show" { return "Run of Show" }
        if d.isEmpty { return "" }
        if let n = Int(d) { return "\(n) day\(n == 1 ? "" : "s") duration" }
        return "\(float.duration ?? "") duration"
    }

    /// Shared header + stat strip layout. A tiny status branch inside
    /// the stat strip swaps SPENT/BALANCE → CLOSED/CANCELLED when the
    /// float is terminal; everything else stays identical across states.
    @ViewBuilder private var headerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: avatar + name + float number + status
            HStack(spacing: 8) {
                if !disableInternalTap && onTap == nil {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(.gray)
                }
                if let user = UsersData.byId[float.userId ?? ""] {
                    ZStack {
                        Circle().fill(Color.gold.opacity(0.2)).frame(width: 32, height: 32)
                        Text(user.initials).font(.system(size: 11, weight: .bold)).foregroundColor(.goldDark)
                    }
                    Text(user.fullName ?? "").font(.system(size: 14, weight: .bold)).lineLimit(1)
                }
                Text("· \(float.reqNumber ?? "")").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                Spacer()
                let (fg, bg) = floatStatusColor(float.status ?? "")
                Text(float.statusDisplay.uppercased()).font(.system(size: 8, weight: .bold)).foregroundColor(fg)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(bg).cornerRadius(4)
            }

            // Row 2: submitted date + N days active + duration
            // Matches the web: "Submitted DD MMM · N days active · <duration>".
            HStack(spacing: 6) {
                Text("Submitted \(FormatUtils.formatTimestamp(float.createdAt ?? 0))").font(.system(size: 10)).foregroundColor(.gray)
                Text("· \(daysActive) day\(daysActive == 1 ? "" : "s") active")
                    .font(.system(size: 10)).foregroundColor(.gray)
                if !durationText.isEmpty {
                    Text("· \(durationText)").font(.system(size: 10)).foregroundColor(.gray)
                }
            }

            // Row 3: stats — three branches mirroring PCFloatsPage.jsx.
            switch statsVariant {
            case .terminal:
                // CLOSED / CANCELLED → Limit + Closed (greyed)
                let isCancelled = (float.status ?? "").uppercased() == "CANCELLED"
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("LIMIT").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                        Text(FormatUtils.formatGBP(floatLimit))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity)
                    VStack(spacing: 2) {
                        Text(isCancelled ? "CANCELLED" : "CLOSED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary).tracking(0.3)
                        Text(FormatUtils.formatGBP(closedStatValue))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity)
                }
                .padding(.vertical, 6).background(Color.bgRaised).cornerRadius(8)
                .opacity(0.75)

            case .inUse:
                // COLLECTED / ACTIVE / SPENDING / SPENT / PENDING_RETURN →
                // Balance + Spent + Issued + progress bar underneath.
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text("BALANCE").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                            Text(FormatUtils.formatGBP(liveBalance))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: 2) {
                            // The derivation (limit - balance) covers both
                            // posted receipts AND cash returned — so the
                            // label reflects both, matching the web.
                            Text("SPENT/RETURN").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                            Text(FormatUtils.formatGBP(spentDerived))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(spentDerived > 0 ? .blue : .gray)
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: 2) {
                            Text("ISSUED").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                            Text(FormatUtils.formatGBP(issuedDisplay))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }.frame(maxWidth: .infinity)
                    }
                    // Spend progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5).fill(Color(.systemGray5)).frame(height: 3)
                            RoundedRectangle(cornerRadius: 1.5).fill(Color.goldDark)
                                .frame(width: max(geo.size.width * CGFloat(spendPct), 0), height: 3)
                        }
                    }.frame(height: 3)
                    Text("Spent/Returned \(FormatUtils.formatGBP(spentDerived)) of \(FormatUtils.formatGBP(floatLimit))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8).padding(.horizontal, 8)
                .background(Color.bgRaised).cornerRadius(8)

            case .preCollection:
                // AWAITING_APPROVAL / APPROVED / ACCT_OVERRIDE /
                // READY_TO_COLLECT / REJECTED → only the Requested amount.
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("REQUESTED").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).tracking(0.3)
                        Text(FormatUtils.formatGBP(floatLimit))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12).contentShape(Rectangle())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onTap = onTap {
                Button(action: onTap) { headerContent }.buttonStyle(PlainButtonStyle())
            } else if disableInternalTap {
                headerContent
            } else {
                Button(action: { expandedState.toggle() }) { headerContent }.buttonStyle(PlainButtonStyle())
            }

            // ── Expanded: details + batches ──
            if expanded {
                Divider()
                // Details
                VStack(spacing: 0) {
                    if !(float.costCode ?? "").isEmpty { detailRow("Cost Code", (float.costCode ?? "").uppercased()) }
                    if !(float.purpose ?? "").isEmpty { detailRow("Purpose", float.purpose ?? "") }
                    if !(float.duration ?? "").isEmpty { detailRow("Duration", "\(float.duration ?? "") days") }
                    if !(float.collectionMethod ?? "").isEmpty { detailRow("Collection", (float.collectionMethod ?? "").replacingOccurrences(of: "_", with: " ").capitalized) }
                    if let start = float.startDate, start > 0 { detailRow("Start Date", FormatUtils.formatTimestamp(start)) }
                    if !(float.department ?? "").isEmpty { detailRow("Department", float.department ?? "") }
                }

                // Approvals
                if !(float.approvals ?? []).isEmpty {
                    Divider().padding(.horizontal, 14)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("APPROVALS (\((float.approvals ?? []).count))").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                        ForEach(float.approvals ?? [], id: \.tierNumber) { a in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundColor(.green)
                                Text(UsersData.byId[a.userId ?? ""]?.fullName ?? (a.userId ?? "—")).font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text("Tier \(a.tierNumber ?? 0)").font(.system(size: 10)).foregroundColor(.secondary)
                                Text(FormatUtils.formatTimestamp(a.approvedAt ?? 0)).font(.system(size: 9)).foregroundColor(.gray)
                            }
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 8)
                }

                // Batches
                if !batches.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(batches.count) BATCHES").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 6)

                        ForEach(batches) { batch in
                            let isSelected = selectedBatchId == batch.id
                            VStack(spacing: 0) {
                                Button(action: { selectedBatchId = isSelected ? nil : batch.id }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text").font(.system(size: 11))
                                            .foregroundColor(isSelected ? .goldDark : .gray)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("#\(batch.batchReference ?? "")").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                                            Text("\(batch.claimCount ?? 0) receipt\(batch.claimCount == 1 ? "" : "s") · \(FormatUtils.formatTimestamp(batch.createdAt ?? 0))").font(.system(size: 10)).foregroundColor(.gray)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(FormatUtils.formatGBP(batch.totalGross ?? 0)).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.primary)
                                            let (bfg, bbg) = batchStatusColor(batch.status ?? "")
                                            Text(batch.statusDisplay).font(.system(size: 8, weight: .bold)).foregroundColor(bfg)
                                                .padding(.horizontal, 6).padding(.vertical, 2).background(bbg).cornerRadius(3)
                                        }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(isSelected ? Color.gold.opacity(0.04) : Color.clear)
                                    .overlay(isSelected ? RoundedRectangle(cornerRadius: 6).stroke(Color.gold.opacity(0.3), lineWidth: 1).padding(.horizontal, 8) : nil)
                                }.buttonStyle(PlainButtonStyle())

                                // Inline status flow when selected
                                if isSelected {
                                    batchStatusFlow(batch)
                                }

                                Divider().padding(.horizontal, 14)
                            }
                        }
                    }
                }

                // Rejection
                if let reason = float.rejectionReason, !reason.isEmpty {
                    Divider().padding(.horizontal, 14)
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundColor(.red)
                        Text(reason).font(.system(size: 10)).foregroundColor(.red).lineLimit(2)
                    }.padding(.horizontal, 14).padding(.vertical, 8)
                }
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

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
            let s = (batch.status ?? "").uppercased()
            switch s {
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

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("#\(batch.batchReference ?? "")")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .padding(.horizontal, 14).padding(.top, 10)
            Text("\(FormatUtils.formatGBP(batch.totalGross ?? 0)) · \(batch.claimCount ?? 0) receipt\(batch.claimCount == 1 ? "" : "s") · \(FormatUtils.formatDateTime(batch.createdAt ?? 0))")
                .font(.system(size: 11)).foregroundColor(.secondary)
                .padding(.horizontal, 14).padding(.bottom, 8)

            Text("STATUS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                .padding(.horizontal, 14).padding(.bottom, 6)

            // Timeline
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(idx < current ? Color.green :
                                  idx == current ? Color.goldDark :
                                  Color.gray.opacity(0.25))
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

            // Rejected
            if (batch.status ?? "").uppercased() == "REJECTED" {
                HStack(spacing: 8) {
                    Circle().fill(Color.red).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rejected").font(.system(size: 12, weight: .bold)).foregroundColor(.red)
                        Text("Resubmit required").font(.system(size: 10)).foregroundColor(.red.opacity(0.7))
                    }
                }.padding(.horizontal, 14).padding(.top, 4)
            }

        }.padding(.bottom, 10).background(Color.bgRaised.opacity(0.5))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium))
        }.padding(.horizontal, 14).padding(.vertical, 6)
    }

    private func floatStatusColor(_ s: String) -> (Color, Color) {
        floatStatusColors(s)
    }

    private func batchStatusColor(_ s: String) -> (Color, Color) {
        switch s.uppercased() {
        case "CODING", "CODED": return (.purple, Color.purple.opacity(0.1))
        case "POSTED": return (.green, Color.green.opacity(0.1))
        case "REJECTED": return (.red, Color.red.opacity(0.1))
        case "ESCALATED": return (.orange, Color.orange.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Submit Receipts Form
// ═══════════════════════════════════════════════════════════════════
