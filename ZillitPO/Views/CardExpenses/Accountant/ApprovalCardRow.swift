import SwiftUI

struct ApprovalCardRow: View {
    let card: ExpenseCard
    let tierConfigs: [ApprovalTierConfig]
    /// Whether the current user can approve at this card's active tier
    /// (mirrors the web's `vis.canApprove`). Defaults to `false` so the
    /// Approve / Reject buttons stay hidden until the caller opts in
    /// explicitly with the right per-card visibility check.
    var canApprove: Bool = false
    /// Whether the current user has card-override privilege. When true,
    /// an Override button is shown alongside Approve / Reject.
    var canOverride: Bool = false
    let onApprove: () -> Void
    let onReject: () -> Void
    /// Optional override handler — only invoked when `canOverride` is
    /// true and the caller wires it up.
    var onOverride: (() -> Void)? = nil
    /// Parent-driven flag: `true` while a network action (approve /
    /// reject / override) initiated from this row is in flight. The
    /// row swaps the Approve/Reject/Override button content for a
    /// spinner + "…" label and disables all action taps for the
    /// duration. The parent typically keeps a `processingCardId`
    /// and passes `isProcessing: processingCardId == card.id`.
    var isProcessing: Bool = false

    private var totalTiers: Int {
        let cfg = ApprovalHelpers.resolveConfig(tierConfigs, deptId: card.departmentId, amount: card.monthlyLimit ?? 0)
            ?? ApprovalHelpers.resolveConfig(tierConfigs, deptId: nil, amount: card.monthlyLimit ?? 0)
            ?? ApprovalHelpers.resolveConfig(tierConfigs, deptId: nil)
        return ApprovalHelpers.getTotalTiers(cfg)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top: card icon + Pending (0/2) badge
            HStack {
                Image(systemName: "creditcard.fill").font(.system(size: 18)).foregroundColor(.goldDark)
                Spacer()
                Text("Pending (\((card.approvals ?? []).count)/\(totalTiers))")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.orange)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1)).cornerRadius(4)
            }

            // Status label
            Text("Pending Approval").font(.system(size: 13, design: .monospaced)).foregroundColor(.orange)

            // Holder name + designation + bank
            Text(card.holderFullName).font(.system(size: 15, weight: .bold))
            HStack(spacing: 4) {
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                }
                if !card.bankName.isEmpty {
                    Text("· \(card.bankName)").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }

            // BS Control
            if !(card.bsControlCode ?? "").isEmpty {
                HStack {
                    Text("BS Control").font(.system(size: 11)).foregroundColor(.secondary)
                    Spacer()
                    Text(card.bsControlCode ?? "").font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.bgRaised).cornerRadius(8)
            }

            // Proposed Limit
            if (card.monthlyLimit ?? 0) > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                    Text("\(FormatUtils.formatGBP(card.monthlyLimit ?? 0))/mo")
                        .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                }
            }

            // Approval Chain circles (Level 1, Level 2, etc.)
            if totalTiers > 0 {
                HStack(spacing: 0) {
                    ForEach(1...totalTiers, id: \.self) { tier in
                        let isApproved = (card.approvals ?? []).contains { $0.tierNumber == tier }
                        let isCurrent = !isApproved && (tier == 1 || (card.approvals ?? []).contains { $0.tierNumber == tier - 1 })

                        if tier > 1 {
                            Rectangle()
                                .fill((card.approvals ?? []).contains { $0.tierNumber == tier - 1 } ? Color.green.opacity(0.4) : Color.gray.opacity(0.3))
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
                            Text("Level \(tier)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(isApproved ? .green : isCurrent ? .goldDark : .gray)
                            if isApproved {
                                let approverUser = (card.approvals ?? []).first(where: { $0.tierNumber == tier }).flatMap { UsersData.byId[$0.userId ?? ""] }
                                if let user = approverUser {
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

            // Action buttons — mutually-exclusive with the web's
            // CardItem.jsx logic:
            //   • Override: shown when the user CAN'T approve but HAS
            //     the override privilege (`canOverride && !canApprove`).
            //     Override is explicitly the escape-hatch for users
            //     who aren't in the approval chain but have admin
            //     rights to force a card through.
            //   • Approve / Reject: shown only when `canApprove`.
            // Never both — if you can approve, there's nothing to
            // override. This matches the web:
            //   `{onOverride && !vis.canApprove && <Override />}`
            //   `{onReject && vis.canApprove && <Reject />}`
            //   `{onApprove && vis.canApprove && <Approve />}`
            let showOverride = canOverride && !canApprove && onOverride != nil
            if canApprove || showOverride {
                HStack(spacing: 10) {
                    Spacer()
                    if showOverride, let ov = onOverride {
                        Button(action: { if !isProcessing { ov() } }) {
                            HStack(spacing: 4) {
                                if isProcessing {
                                    ActivityIndicator(isAnimating: true).frame(width: 10, height: 10)
                                } else {
                                    Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold))
                                }
                                Text(isProcessing ? "Overriding…" : "Override")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(isProcessing ? Color.orange.opacity(0.55) : Color.orange)
                            .cornerRadius(8)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .disabled(isProcessing)
                    }
                    if canApprove {
                        Button(action: { if !isProcessing { onReject() } }) {
                            HStack(spacing: 4) {
                                if isProcessing { ActivityIndicator(isAnimating: true).frame(width: 10, height: 10) }
                                Text(isProcessing ? "Rejecting…" : "Reject")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(isProcessing ? Color.red.opacity(0.55) : Color.red)
                            .cornerRadius(8)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .disabled(isProcessing)
                        Button(action: { if !isProcessing { onApprove() } }) {
                            HStack(spacing: 4) {
                                if isProcessing { ActivityIndicator(isAnimating: true).frame(width: 10, height: 10) }
                                Text(isProcessing ? "Approving…" : "Approve")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(isProcessing ? Color.green.opacity(0.55) : Color.green)
                            .cornerRadius(8)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .disabled(isProcessing)
                    }
                }
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }
}
