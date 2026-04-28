import SwiftUI
import UIKit

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Detail Page
// ═══════════════════════════════════════════════════════════════════

struct CardDetailPage: View {
    let card: ExpenseCard
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var liveCard: ExpenseCard? = nil
    @State private var showRejectSheet = false
    @State private var rejectReason = ""
    @State private var showCardNumber = false
    @State private var navigateToAssign = false
    @State private var navigateToEdit = false
    @State private var navigateToHistory = false
    @State private var navigateToActivate = false
    @State private var deleting = false

    enum StatusOperation { case suspending, reactivating }
    @State private var pendingOperation: StatusOperation? = nil
    /// Loader state for the Override action — flips on tap and
    /// clears in the VM completion so the button shows a spinner +
    /// "Overriding…" label for the duration of the network call.
    @State private var isOverriding = false
    /// Loader state for Approve (inline button on this page).
    @State private var isApproving = false
    /// Loader state for the reject sheet's nav-bar Reject button.
    @State private var isRejecting = false

    enum ActiveAlert: Identifiable {
        case deleteConfirm, suspendConfirm, reactivateConfirm
        var id: Int { hashValue }
    }
    @State private var activeAlert: ActiveAlert? = nil

    private var displayCard: ExpenseCard { liveCard ?? card }

    /// Keeps `liveCard` in sync with whichever card list the VM refreshes.
    /// Extracted to a helper so the `.onReceive` closures stay simple —
    /// inlining the full expression tripped SwiftUI's type-check timeout.
    private func syncLiveCard(from cards: [ExpenseCard]) {
        let cardId = card.id ?? ""
        if let updated = cards.first(where: { ($0.id ?? "") == cardId }) {
            liveCard = updated
        }
    }
    private var isAccountant: Bool { appState.currentUser?.isAccountant ?? false }
    /// True only while the card is still awaiting tier approvals.
    /// Approved / override / active / suspended / rejected cards have finished the approval workflow
    /// and should not show the "Pending Approval" section or action buttons.
    private var isPendingApproval: Bool { (displayCard.status ?? "").lowercased() == "pending" }
    private var isOwnCard: Bool { displayCard.holderId == appState.userId }
    private var canEditRequest: Bool {
        // User can edit their own card while still in requested/pending state (not yet approved/active).
        // Accountants can also edit any card while it's in requested/pending state.
        let editableStatuses: Set<String> = ["requested", "pending"]
        guard editableStatuses.contains((displayCard.status ?? "").lowercased()) else { return false }
        return isOwnCard || isAccountant
    }

    private var totalTiers: Int {
        let cfg = ApprovalHelpers.resolveConfig(appState.cardTierConfigRows, deptId: displayCard.departmentId, amount: displayCard.monthlyLimit ?? 0)
            ?? ApprovalHelpers.resolveConfig(appState.cardTierConfigRows, deptId: nil, amount: displayCard.monthlyLimit ?? 0)
            ?? ApprovalHelpers.resolveConfig(appState.cardTierConfigRows, deptId: nil)
        let fromConfig = ApprovalHelpers.getTotalTiers(cfg)
        if fromConfig > 0 { return fromConfig }
        // No config resolved — only show progress circles when the card
        // already has recorded approvals (so a partially-approved card stays
        // accurate). For a fresh pending card with zero approvals, return 0
        // so the chain is hidden entirely rather than fabricating
        // "Level 1 Awaiting, Level 2 Awaiting" from nothing.
        let maxApproved = (displayCard.approvals ?? []).map { $0.tierNumber ?? 0 }.max() ?? 0
        return maxApproved > 0 ? maxApproved + 1 : 0
    }

    /// True only when the current user can approve at this card's
    /// active tier (mirrors the web's `vis.canApprove`). Drives the
    /// inline Approve / Reject buttons in the Pending Approval panel.
    private var canApproveCard: Bool {
        guard let cfg = ApprovalHelpers.resolveConfig(
            appState.cardTierConfigRows,
            deptId: displayCard.departmentId,
            amount: displayCard.monthlyLimit ?? 0
        ) else { return false }
        var po = PurchaseOrder()
        po.id = displayCard.id
        po.userId = displayCard.holderId
        po.departmentId = displayCard.departmentId
        po.status = "PENDING"
        po.approvals = displayCard.approvals ?? []
        po.netAmount = displayCard.monthlyLimit ?? 0
        return ApprovalHelpers.getVisibility(po: po, config: cfg, userId: appState.userId).canApprove
    }

    /// True when the user has card-override privilege. Reads from
    /// the card-expenses-server's metadata (`cardExpenseMeta`) — that
    /// endpoint is the one that populates `card_override` alongside
    /// `can_override`. The cash-expenses metadata only carries
    /// `can_override`, so relying on `cashMeta` left the Override
    /// button hidden for everyone.
    private var canOverrideCard: Bool { appState.cardExpenseMeta.canOverrideCards }

    private var approverName: String {
        guard let id = displayCard.approvedBy, !id.isEmpty else { return "" }
        return UsersData.byId[id]?.fullName ?? id
    }

    private var resolvedBankAccount: ProductionBankAccount? {
        if let bankId = displayCard.bankAccount?.id, !bankId.isEmpty {
            return appState.bankAccounts.first { $0.id == bankId }
        }
        return nil
    }

    private var resolvedBankName: String {
        resolvedBankAccount?.name ?? displayCard.bankName
    }

    private var resolvedSortCode: String {
        resolvedBankAccount?.sortCode ?? ""
    }

    private var resolvedAccountNumber: String {
        let num = resolvedBankAccount?.accountNumber ?? ""
        guard !num.isEmpty else { return "—" }
        if num.count > 4 {
            let masked = String(repeating: "•", count: num.count - 4)
            return masked + num.suffix(4)
        }
        return num
    }

    private var cardStatusBadge: some View {
        let status = (displayCard.status ?? "").lowercased()
        let (label, fg, bg): (String, Color, Color) = {
            let purple = Color(red: 0.5, green: 0.1, blue: 0.8)
            switch status {
            case "active":
                return displayCard.isDigitalOnly ? ("Digital Active", Color(red: 0.0, green: 0.6, blue: 0.7), Color(red: 0.0, green: 0.6, blue: 0.7).opacity(0.15))
                                                 : ("Active", .green, Color.green.opacity(0.15))
            case "suspended":    return ("Suspended", purple, purple.opacity(0.15))
            case "requested":    return ("Requested", .orange, Color.orange.opacity(0.15))
            case "pending":      return ("Pending Approval", .orange, Color.orange.opacity(0.15))
            case "approved",
                 "override":     return ("Approved", .green, Color.green.opacity(0.15))
            case "rejected":     return ("Rejected", .red, Color.red.opacity(0.15))
            default:             return (status.capitalized, .goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(bg).cornerRadius(5)
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    @ViewBuilder private var cardDetailsGrid: some View {
        let hasHolder  = !displayCard.holderFullName.isEmpty
        let hasDept    = !(displayCard.department ?? "").isEmpty
        let hasBSCode  = !(displayCard.bsControlCode ?? "").isEmpty
        let hasIssuer  = !resolvedBankName.isEmpty
        let hasAccNum  = resolvedAccountNumber != "—"
        let hasDigital = !(displayCard.digitalCardNumber  ?? "").isEmpty
        let hasPhysical = !(displayCard.physicalCardNumber ?? "").isEmpty

        if hasHolder || hasDept || hasBSCode || hasIssuer {
            Divider()
            VStack(spacing: 0) {
                if hasHolder || hasDept {
                    HStack(alignment: .top, spacing: 16) {
                        if hasHolder {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CARD HOLDER")
                                    .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                Text(displayCard.holderFullName)
                                    .font(.system(size: 14, weight: .semibold))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if hasDept {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DEPARTMENT")
                                    .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                Text(displayCard.department ?? "").font(.system(size: 14, weight: .semibold))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
                if hasBSCode || hasIssuer {
                    if hasHolder || hasDept { Divider().padding(.horizontal, 20) }
                    HStack(alignment: .top, spacing: 16) {
                        if hasBSCode {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("BS CONTROL CODE")
                                    .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                Text(displayCard.bsControlCode ?? "").font(.system(size: 14, weight: .semibold))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if hasIssuer {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CARD ISSUER")
                                    .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                Text(resolvedBankName).font(.system(size: 14, weight: .semibold))
                                if !resolvedSortCode.isEmpty {
                                    HStack(spacing: 4) {
                                        Text("Sort:").font(.system(size: 10)).foregroundColor(.secondary)
                                        Text(resolvedSortCode).font(.system(size: 10, weight: .medium, design: .monospaced))
                                    }
                                }
                                if hasAccNum {
                                    HStack(spacing: 4) {
                                        Text("Acc:").font(.system(size: 10)).foregroundColor(.secondary)
                                        Text(resolvedAccountNumber).font(.system(size: 10, weight: .medium, design: .monospaced))
                                    }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
            }
            .padding(.vertical, 4)
        }

        if hasDigital || hasPhysical {
            Divider()
            HStack(alignment: .top, spacing: 12) {
                if hasDigital {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("DIGITAL CARD")
                            .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                        // `lineLimit(1) + minimumScaleFactor` ensures the 19-char
                        // monospaced number always renders in full on one line,
                        // shrinking slightly when the column is tight (common
                        // when both digital + physical split the row 50/50 on
                        // narrower devices). `fixedSize(vertical: true)` prevents
                        // the Text from wrapping to a second line inside the VStack.
                        Text(showCardNumber ? formatCardNum(displayCard.digitalCardNumber) : maskedCardNum(displayCard.digitalCardNumber))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .truncationMode(.middle)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                if hasPhysical {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("PHYSICAL CARD")
                            .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                        Text(showCardNumber ? formatCardNum(displayCard.physicalCardNumber) : maskedCardNum(displayCard.physicalCardNumber))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .truncationMode(.middle)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }

        if displayCard.isDigitalOnly {
            NavigationLink(
                destination: AssignPhysicalCardPage(card: displayCard).environmentObject(appState),
                isActive: $navigateToAssign
            ) { EmptyView() }
            .frame(width: 0, height: 0).hidden()

            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PHYSICAL CARD").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                    Text("No physical card assigned yet").font(.system(size: 13)).foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { navigateToAssign = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "creditcard.and.123").font(.system(size: 11, weight: .semibold))
                        Text("Assign Physical Card").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color.orange).cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                    // ── Card number + holder subtitle ──
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 10) {
                            // Prefer digital card number, fall back to physical.
                            let fullNumber = displayCard.digitalCardNumber ?? displayCard.physicalCardNumber
                            let hasFullNumber = !(fullNumber ?? "").isEmpty

                            // Effective last-4: use the stored lastFour field when
                            // available, otherwise derive it from whichever card
                            // number is stored. This prevents "——" showing in the
                            // header when the list correctly showed digits (the list
                            // API and detail API may return fields at different times).
                            let effectiveLast4: String = {
                                if let lf = displayCard.lastFour, !lf.isEmpty { return lf }
                                if hasFullNumber, let num = fullNumber {
                                    let digits = num.filter { $0.isNumber }
                                    if digits.count >= 4 { return String(digits.suffix(4)) }
                                }
                                return "——"
                            }()

                            let display: String = {
                                if showCardNumber, hasFullNumber, let num = fullNumber {
                                    return formatCardNum(num)           // "1234 5678 9012 3456"
                                }
                                return "•••• •••• •••• \(effectiveLast4)"
                            }()

                            Text(display)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.goldDark)
                                .lineLimit(1)
                                // Scale down (not truncate) when the status
                                // badge is wide. Required specifically for the
                                // "Digital Active" badge on narrower devices
                                // (iPhone SE / Mini) — card number + eye +
                                // badge otherwise exceeds the content width.
                                .minimumScaleFactor(0.75)

                            // Only show the eye toggle when the full card number is
                            // actually stored — if it's nil the button does nothing
                            // visible and is misleading.
                            if hasFullNumber {
                                Button(action: { showCardNumber.toggle() }) {
                                    Image(systemName: showCardNumber ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(showCardNumber ? .secondary : .goldDark)
                                        // Fixed-size tap target so the button itself
                                        // never resizes between eye.fill / eye.slash.fill
                                        // (the .slash glyph renders slightly wider).
                                        .frame(width: 22, height: 22)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            Spacer()
                            cardStatusBadge
                        }
                        let subtitle = [displayCard.holderFullName, displayCard.holderDesignation, resolvedBankName]
                            .filter { !$0.isEmpty }.joined(separator: " · ")
                        if !subtitle.isEmpty {
                            Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 18)

                    // ── Stats + Utilisation only when the card is active / suspended ──
                    // For pending, requested, approved, rejected states, spending data is meaningless.
                    let statusLower = (displayCard.status ?? "").lowercased()
                    let showSpending = statusLower == "active" || statusLower == "suspended"

                    if showSpending {
                        // ── Stats: Card Limit | Available | Total Spent ──
                        HStack(spacing: 0) {
                            statCol("CARD LIMIT",   FormatUtils.formatGBP(displayCard.monthlyLimit ?? 0),   .goldDark)
                            statCol("AVAILABLE",    FormatUtils.formatGBP(displayCard.currentBalance ?? 0), Color(red: 0, green: 0.6, blue: 0.5))
                            statCol("TOTAL SPENT",  FormatUtils.formatGBP(displayCard.spentAmount),    .primary)
                        }
                        .padding(.horizontal, 20).padding(.bottom, 14)

                        // ── Utilisation bar (only when a limit is set) ──
                        if (displayCard.monthlyLimit ?? 0) > 0 {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("UTILISATION").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                                    Spacer()
                                    Text("\(Int(displayCard.spendPercent * 100))%").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5)).frame(height: 6)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(displayCard.spendPercent > 0.8 ? Color.red : Color.goldDark)
                                            .frame(width: max(geo.size.width * CGFloat(min(displayCard.spendPercent, 1.0)), 0), height: 6)
                                    }
                                }.frame(height: 6)
                                HStack {
                                    Text("Spent: \(FormatUtils.formatGBP(displayCard.spentAmount))").font(.system(size: 10)).foregroundColor(.secondary)
                                    Spacer()
                                    Text("Limit: \(FormatUtils.formatGBP(displayCard.monthlyLimit ?? 0))").font(.system(size: 10)).foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 20).padding(.bottom, 20)
                        }
                    } else if (displayCard.monthlyLimit ?? 0) > 0 {
                        // For non-active states, just show the proposed limit compactly
                        HStack {
                            Text("PROPOSED LIMIT").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                            Spacer()
                            Text(FormatUtils.formatGBP(displayCard.monthlyLimit ?? 0))
                                .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        }
                        .padding(.horizontal, 20).padding(.bottom, 20)
                    }

                    // ── Detail grid (only visible rows) ──
                    cardDetailsGrid

                    // ── Justification ──
                    if !(displayCard.justification ?? "").isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 5) {
                            Text("JUSTIFICATION").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                            Text(displayCard.justification ?? "").font(.system(size: 14))
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                    // ── Pending approval chain + action buttons ──
                    //
                    // Gate: pending card AND the current user has at
                    // least one action available (can approve at the
                    // current tier OR has card-override privilege).
                    // Previously this was gated on `isAccountant`,
                    // which hid the Approve/Reject buttons from
                    // non-accountant approvers AND the Override
                    // button from everyone who didn't have the
                    // accountant role flag — including users with
                    // `can_override` privilege. The web uses the
                    // per-action handlers to decide visibility, so
                    // iOS now mirrors that with
                    // `(canApproveCard || canOverrideCard)`.
                    if isPendingApproval && (canApproveCard || canOverrideCard) {
                        Divider()
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Pending Approval")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.orange)

                            if totalTiers > 0 {
                                HStack(spacing: 0) {
                                    ForEach(1...totalTiers, id: \.self) { tier in
                                        let isApproved = (displayCard.approvals ?? []).contains { ($0.tierNumber ?? 0) == tier }
                                        let isCurrent  = !isApproved && (tier == 1 || (displayCard.approvals ?? []).contains { ($0.tierNumber ?? 0) == tier - 1 })
                                        if tier > 1 {
                                            Rectangle()
                                                .fill((displayCard.approvals ?? []).contains { ($0.tierNumber ?? 0) == tier - 1 } ? Color.green.opacity(0.4) : Color.gray.opacity(0.3))
                                                .frame(width: 20, height: 2)
                                        }
                                        VStack(spacing: 4) {
                                            ZStack {
                                                Circle()
                                                    .fill(isApproved ? Color.green : isCurrent ? Color.gold : Color.gray.opacity(0.25))
                                                    .frame(width: 28, height: 28)
                                                if isApproved {
                                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                                } else if isCurrent {
                                                    Circle().fill(Color.white).frame(width: 10, height: 10)
                                                }
                                            }
                                            Text("Level \(tier)").font(.system(size: 9, weight: .semibold))
                                                .foregroundColor(isApproved ? .green : isCurrent ? .goldDark : .gray)
                                            if isApproved {
                                                let u = (displayCard.approvals ?? []).first(where: { ($0.tierNumber ?? 0) == tier }).flatMap { UsersData.byId[$0.userId ?? ""] }
                                                if let user = u {
                                                    Text(user.fullName ?? "").font(.system(size: 8, weight: .medium)).foregroundColor(.green).lineLimit(1)
                                                    if !user.displayDesignation.isEmpty {
                                                        Text(user.displayDesignation).font(.system(size: 7)).foregroundColor(.green.opacity(0.8)).lineLimit(1)
                                                    }
                                                }
                                            } else {
                                                Text("Awaiting").font(.system(size: 8)).foregroundColor(isCurrent ? .goldDark : .gray)
                                            }
                                        }.frame(minWidth: 60)
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            // Action buttons — mutually exclusive, matches
                            // the web (CardItem.jsx):
                            //   • Override: only when user has override
                            //     privilege AND is NOT an approver at
                            //     the current tier (`!canApprove`).
                            //   • Approve / Reject: only when
                            //     `canApprove`.
                            // Accountants who happen to be in the tier
                            // chain see Approve/Reject; everyone else
                            // with override privilege sees Override.
                            let showOverrideHere = canOverrideCard && !canApproveCard
                            if canApproveCard || showOverrideHere {
                                HStack(spacing: 10) {
                                    Spacer()
                                    if showOverrideHere {
                                        Button(action: {
                                            guard !isOverriding else { return }
                                            isOverriding = true
                                            appState.overrideCard(displayCard) { success, _ in
                                                isOverriding = false
                                                // Only dismiss on success so
                                                // users who hit a server
                                                // error stay on the card
                                                // detail and can try again.
                                                if success {
                                                    presentationMode.wrappedValue.dismiss()
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                if isOverriding {
                                                    ActivityIndicator(isAnimating: true).frame(width: 12, height: 12)
                                                } else {
                                                    Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold))
                                                }
                                                Text(isOverriding ? "Overriding…" : "Override")
                                                    .font(.system(size: 13, weight: .bold))
                                            }
                                            .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(isOverriding ? Color.orange.opacity(0.55) : Color.orange)
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                        .disabled(isOverriding)
                                    }
                                    if canApproveCard {
                                        // Reject opens the sheet — the
                                        // actual network call fires
                                        // from there (with its own loader).
                                        Button(action: { showRejectSheet = true }) {
                                            Text("Reject").font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 10)
                                                .background(Color.red).cornerRadius(8)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                        .disabled(isApproving)
                                        // Approve fires immediately from
                                        // this button — show a spinner
                                        // + "Approving…" while the call
                                        // is in flight, and only dismiss
                                        // the page on success.
                                        Button(action: {
                                            guard !isApproving else { return }
                                            isApproving = true
                                            appState.approveCard(displayCard) { success, _ in
                                                isApproving = false
                                                if success { presentationMode.wrappedValue.dismiss() }
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                if isApproving {
                                                    ActivityIndicator(isAnimating: true).frame(width: 12, height: 12)
                                                }
                                                Text(isApproving ? "Approving…" : "Approve")
                                                    .font(.system(size: 13, weight: .bold))
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(isApproving ? Color.green.opacity(0.55) : Color.green)
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                        .disabled(isApproving)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                    // Edit (+ Delete for users) buttons — shown while card is in requested/pending state.
                    // Users see Delete + Edit (they can cancel their own request).
                    // Accountants see just Edit (they can modify details on behalf of requester).
                    if canEditRequest {
                        Divider()
                        HStack(spacing: 10) {
                            if !isAccountant {
                                Button(action: { activeAlert = .deleteConfirm }) {
                                    HStack(spacing: 6) {
                                        if deleting {
                                            ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: "trash").font(.system(size: 12, weight: .bold))
                                        }
                                        Text(deleting ? "Deleting…" : "Delete").font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red).cornerRadius(8)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .disabled(deleting)
                            }

                            Button(action: { navigateToEdit = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil").font(.system(size: 12, weight: .bold))
                                    Text("Edit Request").font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.gold).cornerRadius(8)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                    if !approverName.isEmpty {
                        Text("Approved by \(approverName)")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                    }

                    // Activate Card — accountant only, when status is approved/override (not yet active)
                    if isAccountant && ((displayCard.status ?? "").lowercased() == "approved" || (displayCard.status ?? "").lowercased() == "override") {
                        Divider()
                        Button(action: { navigateToActivate = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "creditcard.and.123").font(.system(size: 12, weight: .bold))
                                let hasNum = !(displayCard.physicalCardNumber ?? "").isEmpty || !(displayCard.digitalCardNumber ?? "").isEmpty
                                Text(hasNum ? "Activate Card" : "Activate & Assign Card Number")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange).cornerRadius(10)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                    // Suspend / Reactivate — accountant only, when card is active or suspended.
                    // While an operation is in flight, pin the button to the operation being
                    // performed so labels don't flip mid-request (optimistic status update
                    // would otherwise swap Suspend ↔ Re-activate while the spinner is showing).
                    if isAccountant && ((displayCard.status ?? "").lowercased() == "active" || (displayCard.status ?? "").lowercased() == "suspended" || pendingOperation != nil) {
                        Divider()
                        Group {
                            let showingSuspend: Bool = {
                                if let op = pendingOperation { return op == .suspending }
                                return (displayCard.status ?? "").lowercased() == "active"
                            }()

                            if showingSuspend {
                                Button(action: { activeAlert = .suspendConfirm }) {
                                    HStack(spacing: 6) {
                                        if pendingOperation == .suspending {
                                            ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: "pause.circle.fill").font(.system(size: 12, weight: .semibold))
                                        }
                                        Text(pendingOperation == .suspending ? "Suspending…" : "Suspend Card").font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.orange).cornerRadius(10)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .disabled(pendingOperation != nil)
                            } else {
                                Button(action: { activeAlert = .reactivateConfirm }) {
                                    HStack(spacing: 6) {
                                        if pendingOperation == .reactivating {
                                            ActivityIndicator(isAnimating: true).frame(width: 14, height: 14)
                                        } else {
                                            Image(systemName: "play.circle.fill").font(.system(size: 12, weight: .semibold))
                                        }
                                        Text(pendingOperation == .reactivating ? "Reactivating…" : "Re-activate Card").font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.green).cornerRadius(10)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .disabled(pendingOperation != nil)
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16)
                    }

                Spacer(minLength: 20)
            }
        }
        .background(Color.bgSurface)
        .overlay(
            // Full-page dim + spinner while a suspend / reactivate request is in flight.
            // Ensures the user sees clear progress and can't double-tap buttons.
            Group {
                if let op = pendingOperation {
                    ZStack {
                        Color.black.opacity(0.35).edgesIgnoringSafeArea(.all)
                        VStack(spacing: 12) {
                            ActivityIndicator(isAnimating: true).frame(width: 28, height: 28)
                            Text(op == .suspending ? "Suspending card…" : "Re-activating card…")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(22)
                        .background(Color.bgSurface)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
                    }
                }
            }
        )
        .allowsHitTesting(pendingOperation == nil)
        .navigationBarTitle(Text("Card Details"), displayMode: .inline)
        .navigationBarItems(trailing:
            Button(action: { navigateToHistory = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 14, weight: .semibold))
                    Text("History").font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.goldDark)
            }
        )
        .background(
            NavigationLink(destination: EditCardRequestPage(card: displayCard).environmentObject(appState),
                           isActive: $navigateToEdit) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            NavigationLink(destination: CardHistoryPage(cardId: displayCard.id ?? "", cardLabel: displayCard.holderFullName).environmentObject(appState),
                           isActive: $navigateToHistory) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            NavigationLink(destination: ActivateCardPage(card: displayCard).environmentObject(appState),
                           isActive: $navigateToActivate) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .deleteConfirm:
                return Alert(
                    title: Text("Delete Card Request?"),
                    message: Text("This will permanently delete your card request. This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleting = true
                        appState.deleteCardRequest(id: displayCard.id ?? "") { success in
                            deleting = false
                            if success { presentationMode.wrappedValue.dismiss() }
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .suspendConfirm:
                return Alert(
                    title: Text("Suspend Card?"),
                    message: Text("The card will be temporarily disabled. You can re-activate it anytime."),
                    primaryButton: .destructive(Text("Suspend")) {
                        performStatusChange(op: .suspending)
                    },
                    secondaryButton: .cancel()
                )
            case .reactivateConfirm:
                return Alert(
                    title: Text("Re-activate Card?"),
                    message: Text("The card will be re-enabled for spending."),
                    primaryButton: .default(Text("Re-activate")) {
                        performStatusChange(op: .reactivating)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            appState.loadCard(card.id ?? "") { fetched in liveCard = fetched }
            if appState.bankAccounts.isEmpty { appState.loadBankAccounts() }
        }
        .onReceive(appState.$userCards) { cards in syncLiveCard(from: cards) }
        .onReceive(appState.$allCards)  { cards in syncLiveCard(from: cards) }
        .sheet(isPresented: $showRejectSheet) {
            NavigationView {
                ZStack {
                    Color.bgBase.edgesIgnoringSafeArea(.all)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reject card request from \(displayCard.holderName ?? "")")
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
                .navigationBarTitle(Text("Reject Card"), displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showRejectSheet = false
                        rejectReason = ""
                    }
                    .foregroundColor(.goldDark)
                    .disabled(isRejecting),
                    trailing: Button(action: {
                        guard !isRejecting,
                              !rejectReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        isRejecting = true
                        appState.rejectCard(displayCard, reason: rejectReason.trimmingCharacters(in: .whitespaces)) { success, _ in
                            isRejecting = false
                            if success {
                                showRejectSheet = false
                                rejectReason = ""
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isRejecting { ActivityIndicator(isAnimating: true).frame(width: 14, height: 14) }
                            Text(isRejecting ? "Rejecting…" : "Reject")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundColor(isRejecting ? .red.opacity(0.55) : .red)
                    .disabled(isRejecting)
                )
            }
        }
    }

    /// Runs a suspend or re-activate request. While the request is in flight
    /// the full-page loader overlay is visible (driven by `pendingOperation`).
    /// On success, refresh the card list so the caller shows fresh data, then
    /// pop back to it. On failure, clear the loader and stay on the page.
    private func performStatusChange(op: StatusOperation) {
        pendingOperation = op
        let cardId = displayCard.id ?? ""
        let done: (Bool) -> Void = { success in
            if success {
                // Refresh the list the user is going back to so it reflects the new status.
                appState.loadUserCards()
                pendingOperation = nil
                presentationMode.wrappedValue.dismiss()
            } else {
                pendingOperation = nil
            }
        }
        switch op {
        case .suspending:    appState.suspendCard(id: cardId, completion: done)
        case .reactivating:  appState.reactivateCard(id: cardId, completion: done)
        }
    }

    private func statCol(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailGrid(_ l1: String, _ v1: String, _ l2: String, _ v2: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l1).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                Text(v1.isEmpty ? "—" : v1).font(.system(size: 14, weight: .semibold))
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !l2.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l2).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).tracking(0.5)
                    Text(v2.isEmpty ? "—" : v2).font(.system(size: 14, weight: .semibold))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private func formatCardNum(_ raw: String?) -> String {
        guard let s = raw, !s.isEmpty else { return "—" }
        let digits = s.filter { $0.isNumber }
        guard !digits.isEmpty else { return s }
        return stride(from: 0, to: digits.count, by: 4).map { i -> String in
            let start = digits.index(digits.startIndex, offsetBy: i)
            let end   = digits.index(start, offsetBy: min(4, digits.count - i))
            return String(digits[start..<end])
        }.joined(separator: " ")
    }

    private func maskedCardNum(_ raw: String?) -> String {
        guard let s = raw, !s.isEmpty else { return "—" }
        let digits = s.filter { $0.isNumber }
        guard digits.count >= 4 else { return "••••" }
        let last4 = String(digits.suffix(4))
        let groupCount = Int(ceil(Double(digits.count) / 4.0))
        let masked = Array(repeating: "••••", count: groupCount - 1).joined(separator: " ")
        return masked + " " + last4
    }
}

struct CardHistoryPage: View {
    @EnvironmentObject var appState: POViewModel
    let cardId: String
    let cardLabel: String

    @State private var entries: [CardHistoryEntry] = []
    @State private var isLoading = true

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            if isLoading {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                    Text("No history yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                    Text("Actions on this card will appear here.")
                        .font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !cardLabel.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "creditcard.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                                Text(cardLabel)
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                                Spacer()
                                Text("\(entries.count) event\(entries.count == 1 ? "" : "s")")
                                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                            }
                            .padding(12).background(Color.bgSurface).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
                        }
                        ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                            historyRow(entry, isLast: idx == entries.count - 1)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarTitle(Text("Card History"), displayMode: .inline)
        .onAppear {
            appState.loadCardHistoryById(cardId) { fetched in
                entries = fetched.sorted { ($0.timestamp ?? 0) > ($1.timestamp ?? 0) }
                isLoading = false
            }
        }
    }

    private func actionColor(_ action: String) -> Color {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return .green }
        if a.contains("reject") { return .red }
        if a.contains("override") { return .orange }
        if a.contains("submit") || a.contains("request") || a.contains("upload") { return .goldDark }
        if a.contains("escalat") { return .red }
        if a.contains("post") { return Color(red: 0.1, green: 0.6, blue: 0.3) }
        if a.contains("delete") || a.contains("remov") { return .red }
        return .goldDark
    }

    private func actionIcon(_ action: String) -> String {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return "checkmark.circle.fill" }
        if a.contains("reject") { return "xmark.circle.fill" }
        if a.contains("override") { return "bolt.fill" }
        if a.contains("submit") || a.contains("request") { return "paperplane.fill" }
        if a.contains("upload") { return "arrow.up.circle.fill" }
        if a.contains("escalat") { return "exclamationmark.triangle.fill" }
        if a.contains("post") { return "tray.and.arrow.down.fill" }
        if a.contains("delete") || a.contains("remov") { return "trash.fill" }
        if a.contains("update") || a.contains("edit") || a.contains("amend") { return "pencil.circle.fill" }
        return "circle.fill"
    }

    private func historyRow(_ entry: CardHistoryEntry, isLast: Bool) -> some View {
        let color = actionColor(entry.action ?? "")
        return HStack(alignment: .top, spacing: 12) {
            // Timeline: icon + vertical line
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: actionIcon(entry.action ?? ""))
                        .font(.system(size: 11, weight: .bold)).foregroundColor(color)
                }
                if !isLast {
                    Rectangle().fill(Color.borderColor).frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 2)
                }
            }
            .frame(width: 28)

            // Card content
            VStack(alignment: .leading, spacing: 6) {
                // Header: action + tier badge
                HStack(spacing: 6) {
                    Text((entry.action ?? "").isEmpty ? "—" : entry.action ?? "")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    if let tier = entry.tierNumber, tier > 0 {
                        Text("Tier \(tier)")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(color.opacity(0.12)).cornerRadius(4)
                    }
                    Spacer()
                }

                // Actor
                if !(entry.actionByName ?? "").isEmpty || !(entry.actionBy ?? "").isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill").font(.system(size: 9)).foregroundColor(.secondary)
                        Text("by \((entry.actionByName ?? "").isEmpty ? (entry.actionBy ?? "") : (entry.actionByName ?? ""))")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }

                // Details
                if !(entry.details ?? "").isEmpty {
                    Text(entry.details ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Field change (old → new)
                if !(entry.oldValue ?? "").isEmpty || !(entry.newValue ?? "").isEmpty {
                    HStack(spacing: 6) {
                        if !(entry.field ?? "").isEmpty {
                            Text((entry.field ?? "").uppercased())
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                        }
                        if !(entry.oldValue ?? "").isEmpty {
                            Text(entry.oldValue ?? "").font(.system(size: 11, design: .monospaced)).foregroundColor(.red)
                                .strikethrough()
                        }
                        if !(entry.oldValue ?? "").isEmpty && !(entry.newValue ?? "").isEmpty {
                            Image(systemName: "arrow.right").font(.system(size: 9)).foregroundColor(.gray)
                        }
                        if !(entry.newValue ?? "").isEmpty {
                            Text(entry.newValue ?? "").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.green)
                        }
                    }
                }

                // Reason
                if !(entry.reason ?? "").isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "quote.bubble").font(.system(size: 9)).foregroundColor(.secondary)
                        Text("Reason: \(entry.reason ?? "")")
                            .font(.system(size: 11)).foregroundColor(.secondary).italic()
                    }
                }

                // Timestamp (date + time)
                if (entry.timestamp ?? 0) > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.gray)
                        Text(FormatUtils.formatDateTime(entry.timestamp ?? 0))
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
