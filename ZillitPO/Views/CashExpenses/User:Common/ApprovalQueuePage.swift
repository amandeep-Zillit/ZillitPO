import SwiftUI

struct ApprovalQueuePage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var activeSection = "floats" // "floats" or "batches"
    @State private var batchFilter = "All"
    @State private var showBatchFilterSheet = false

    private var pendingFloats: [FloatRequest] { appState.approvalQueueFloats }
    private var pendingClaims: [ClaimBatch] { appState.approvalQueueClaims }
    private var filteredClaims: [ClaimBatch] {
        switch batchFilter {
        case "Petty Cash": return pendingClaims.filter { $0.isPettyCash }
        case "Out of Pocket": return pendingClaims.filter { $0.isOutOfPocket }
        default: return pendingClaims
        }
    }

    /// How many approval tiers this float needs, for the "Pending X/Y" badge.
    /// Falls back to the number of approvals + 1 when the tier config hasn't
    /// loaded yet, with a minimum of 2 so we never show "0/0".
    fileprivate func totalTiers(for f: FloatRequest) -> Int {
        // Most projects use 2-tier approval on floats. If your model already
        // carries a `totalTiers` field per float, prefer that.
        max(2, (f.approvals ?? []).count + 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header banner
            HStack(spacing: 8) {
                Image(systemName: "person.badge.shield.checkmark.fill").font(.system(size: 14)).foregroundColor(.goldDark)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Approval Queue — \(appState.currentUser?.fullName ?? "")")
                        .font(.system(size: 13, weight: .bold))
                    Text("Review and approve or reject float requests and receipt batches.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12).background(Color.gold.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.2), lineWidth: 1))
            .cornerRadius(8).padding(.horizontal, 16).padding(.top, 12)

            // Tappable section cards
            HStack(spacing: 10) {
                Button(action: { activeSection = "floats" }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath").font(.system(size: 14)).foregroundColor(.goldDark)
                            Text("Float Requests").font(.system(size: 13, weight: .bold)).lineLimit(1)
                        }
                        Text("\(pendingFloats.count) pending approval").font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(12)
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(activeSection == "floats" ? Color.goldDark : Color.borderColor, lineWidth: activeSection == "floats" ? 2 : 1))
                }.buttonStyle(PlainButtonStyle())

                Button(action: { activeSection = "batches" }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc").font(.system(size: 14)).foregroundColor(.goldDark)
                            Text("Receipt Batches & OOP").font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Text("\(pendingClaims.count) items").font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(12)
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(activeSection == "batches" ? Color.goldDark : Color.borderColor, lineWidth: activeSection == "batches" ? 2 : 1))
                }.buttonStyle(PlainButtonStyle())
            }
            .frame(height: 64)
            .padding(.horizontal, 16).padding(.top, 12)

            // Section content
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if activeSection == "floats" {
                        HStack {
                            Text("Float Requests").font(.system(size: 14, weight: .bold))
                            Spacer()
                            Text("\(pendingFloats.count) PENDING").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
                        }

                        if appState.isLoadingApprovalFloats && pendingFloats.isEmpty {
                            // Cold-open loader — matches the batches-tab pattern
                            // below and prevents the empty-state flash that
                            // otherwise appears while the initial fetch runs.
                            LoaderView()
                                .frame(maxWidth: .infinity, minHeight: 480)
                        } else if pendingFloats.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "banknote").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No float requests awaiting your approval.").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
                        } else {
                            ForEach(pendingFloats) { f in
                                NavigationLink(destination: FloatApprovalDetailPage(float: f).environmentObject(appState)) {
                                    ApprovalFloatRow(float: f, totalTiers: totalTiers(for: f))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Button(action: { showBatchFilterSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                                    Text(batchFilter).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8).background(Color.bgSurface).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .selectionActionSheet(
                                title: "Filter by Type",
                                isPresented: $showBatchFilterSheet,
                                options: ["All", "Petty Cash", "Out of Pocket"],
                                isSelected: { $0 == batchFilter },
                                label: { $0 },
                                onSelect: { batchFilter = $0 }
                            )
                            Spacer()
                            Text("\(filteredClaims.count) PENDING").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
                        }

                        if appState.isLoadingApprovalClaims && appState.approvalQueueClaims.isEmpty {
                            LoaderView()
                        } else if filteredClaims.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No batches awaiting approval.").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
                        } else {
                            ForEach(filteredClaims) { claim in
                                NavigationLink(destination: ClaimApprovalDetailPage(claim: claim).environmentObject(appState)) {
                                    ApprovalClaimRow(claim: claim)
                                }.buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
            }
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Approval Queue"), displayMode: .inline)
        .onAppear {
            appState.loadApprovalQueueFloats()
            appState.loadApprovalQueueClaims()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Approval Queue — compact float row
// Matches the web screenshot: avatar + name + role + ref/date on the left;
// pending badge + amount on the right. No ISSUED/SPENT/BALANCE (the float
// hasn't been issued yet when it's in the approval queue).
// ═══════════════════════════════════════════════════════════════════

struct ApprovalFloatRow: View {
    let float: FloatRequest
    let totalTiers: Int

    private var user: AppUser? { UsersData.byId[float.userId ?? ""] }

    private var roleLine: String {
        let role = user?.displayDesignation ?? ""
        let dept = (float.department ?? "").isEmpty ? (user?.displayDepartment ?? "") : (float.department ?? "")
        switch (role.isEmpty, dept.isEmpty) {
        case (false, false): return "\(role) · \(dept)"
        case (false, true):  return role
        case (true, false):  return dept
        default:             return ""
        }
    }

    private var submittedLine: String {
        let ref = "#\(float.reqNumber ?? "")"
        let stamp = FormatUtils.formatDateTime(float.createdAt ?? 0)
        return "\(ref) · \(stamp)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Avatar initials — fixed 36×36, never squeezed by a long name.
            ZStack {
                Circle().fill(Color.gold.opacity(0.18)).frame(width: 36, height: 36)
                Text(user?.initials ?? "—")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.goldDark)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user?.fullName ?? "Unknown")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !roleLine.isEmpty {
                    Text(roleLine)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(submittedLine)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Pending badge + Amount.
            // `fixedSize(horizontal: true)` so the right column reserves the
            // width it needs (amount + "Pending x/y" badge) and long names
            // on the left can't starve it. `lineLimit(1)` on each child
            // defends against any wrap that would break vertical alignment.
            VStack(alignment: .trailing, spacing: 4) {
                Text("Pending \((float.approvals ?? []).count)/\(totalTiers)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.goldDark)
                    .lineLimit(1)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.gold.opacity(0.15))
                    .cornerRadius(4)
                Text(FormatUtils.formatGBP(float.reqAmount ?? 0))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.goldDark)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(12)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Approval Queue — compact claim batch row
// Mirrors the web design: avatar + name + role + ref/date on the left;
// "Awaiting Approval" badge + amount + "N receipts" on the right.
// ═══════════════════════════════════════════════════════════════════

struct ApprovalClaimRow: View {
    let claim: ClaimBatch

    private var user: AppUser? { UsersData.byId[claim.userId ?? ""] }

    private var roleLine: String {
        let role = user?.displayDesignation ?? ""
        let dept = (claim.department ?? "").isEmpty ? (user?.displayDepartment ?? "") : (claim.department ?? "")
        switch (role.isEmpty, dept.isEmpty) {
        case (false, false): return "\(role) · \(dept)"
        case (false, true):  return role
        case (true, false):  return dept
        default:             return ""
        }
    }

    private var submittedLine: String {
        let ref = (claim.batchReference ?? "").isEmpty ? "—" : "#\(claim.batchReference!)"
        let stamp = FormatUtils.formatDateTime(claim.createdAt ?? 0)
        return "\(ref) · \(stamp)"
    }

    private var statusBadge: (label: String, fg: Color, bg: Color) {
        switch (claim.status ?? "").uppercased() {
        case "CODING", "CODED":           return ("Awaiting Coding",    .blue,     Color.blue.opacity(0.1))
        case "IN_AUDIT":                  return ("Awaiting Audit",     .purple,   Color.purple.opacity(0.1))
        case "AWAITING_APPROVAL":         return ("Awaiting Approval",  .goldDark, Color.gold.opacity(0.15))
        case "ACCT_OVERRIDE":             return ("Override",           .green,    Color.green.opacity(0.1))
        case "READY_TO_POST":             return ("Ready to Post",      .blue,     Color.blue.opacity(0.1))
        case "POSTED":                    return ("Posted",             .green,    Color.green.opacity(0.1))
        case "REJECTED":                  return ("Rejected",           .red,      Color.red.opacity(0.1))
        case "ESCALATED":                 return ("Escalated",          .orange,   Color.orange.opacity(0.1))
        default:                          return (claim.statusDisplay,  .goldDark, Color.gold.opacity(0.15))
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Avatar initials — pink/rose tint to match the screenshot.
            // Fixed width so it's never squeezed by a long name.
            ZStack {
                Circle()
                    .fill(Color(red: 0.98, green: 0.83, blue: 0.80))
                    .frame(width: 36, height: 36)
                Text(user?.initials ?? "—")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.78, green: 0.30, blue: 0.33))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user?.fullName ?? "Unknown")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !roleLine.isEmpty {
                    Text(roleLine)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(submittedLine)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: status badge + amount + receipts count.
            // `fixedSize(horizontal: true)` guarantees the column claims the
            // width it needs — otherwise long names on the left starve the
            // badge/amount and they wrap or clip. `lineLimit(1)` on each
            // child defends against overlong labels (e.g. "Awaiting Approval")
            // wrapping to a second line and breaking alignment.
            VStack(alignment: .trailing, spacing: 4) {
                let s = statusBadge
                Text(s.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(s.fg)
                    .lineLimit(1)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(s.bg)
                    .cornerRadius(4)
                Text(FormatUtils.formatGBP(claim.totalGross ?? 0))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.goldDark)
                    .lineLimit(1)
                if (claim.claimCount ?? 0) > 0 {
                    Text("\(claim.claimCount!) receipt\(claim.claimCount! == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(12)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Claim Approval Detail Page
// Full-page detail for a receipt batch in the approval queue — mirrors
// the FloatApprovalDetailPage layout: header (name + role + date +
// status), 2-column grid of details, notes panel, approval progress,
// and a role-aware action footer (Override for accountants, Approve/
// Reject for approvers).
// ═══════════════════════════════════════════════════════════════════
