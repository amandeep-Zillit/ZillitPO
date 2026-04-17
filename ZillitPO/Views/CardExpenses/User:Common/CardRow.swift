import SwiftUI
import UIKit

struct CardRow: View {
    let card: ExpenseCard
    var isAccountant: Bool = false
    var tierCount: Int = 0
    var resolvedBankName: String? = nil
    /// Whether the current user is in the active tier of this card's
    /// approval chain (mirrors the web's `vis.canApprove`). When false,
    /// the inline Approve / Reject buttons are hidden — matches the
    /// web behaviour where an accountant who can override but isn't a
    /// tier approver only sees the Override button.
    var canApprove: Bool = false
    var onAssignPhysical: (() -> Void)? = nil
    var onApprove: (() -> Void)? = nil
    var onReject: (() -> Void)? = nil
    var onOverride: (() -> Void)? = nil
    var onActivate: (() -> Void)? = nil

    private var displayBankName: String { resolvedBankName ?? card.bankName }
    private var totalTiers: Int { max(tierCount, (card.approvals ?? []).count + (card.status == "pending" ? 1 : 0)) }
    private var approvedCount: Int { (card.approvals ?? []).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Top row: icon + badges ──
            HStack(spacing: 6) {
                Image(systemName: "creditcard.fill").font(.system(size: 16)).foregroundColor(.goldDark)
                Spacer()
                if card.isDigitalOnly, let action = onAssignPhysical {
                    Button(action: action) {
                        HStack(spacing: 4) {
                            Image(systemName: "creditcard.and.123").font(.system(size: 9, weight: .semibold))
                            Text("Assign Physical Card").font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.orange).cornerRadius(4)
                    }.buttonStyle(BorderlessButtonStyle())
                }
                let (fg, bg) = cardStatusColor(card.status ?? "")
                let badgeLabel: String = {
                    if (card.status == "pending" || card.status == "approved") && totalTiers > 0 {
                        return "\(card.statusDisplay(isAccountant: isAccountant)) (\(approvedCount)/\(totalTiers))"
                    }
                    return card.statusDisplay(isAccountant: isAccountant)
                }()
                Text(badgeLabel).font(.system(size: 10, weight: .semibold)).foregroundColor(fg)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
            }

            if card.status == "active" || card.status == "suspended" {
                // ── Active / Suspended ──
                HStack(spacing: 4) {
                    Text("•••• •••• ••••").font(.system(size: 14, design: .monospaced)).foregroundColor(.gray)
                    Text((card.lastFour ?? "").isEmpty ? "0000" : (card.lastFour ?? ""))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !displayBankName.isEmpty {
                    Text(displayBankName).font(.system(size: 12)).foregroundColor(.secondary)
                }
                if !(card.bsControlCode ?? "").isEmpty {
                    HStack {
                        Text("BS Control").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text(card.bsControlCode ?? "").font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.bgRaised).cornerRadius(6)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Text("\(FormatUtils.formatGBP(card.monthlyLimit ?? 0))/mo")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Balance").font(.system(size: 10)).foregroundColor(.secondary)
                        Text(FormatUtils.formatGBP(card.currentBalance ?? 0))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.bgRaised).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(card.spendPercent > 0.8 ? Color(red: 0.91, green: 0.29, blue: 0.48) : Color.gold)
                            .frame(width: geo.size.width * CGFloat(min(card.spendPercent, 1.0)), height: 5)
                    }
                }.frame(height: 5)

            } else if card.status == "requested" {
                // ── Requested ──
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 12)).foregroundColor(.secondary)
                }
                if (card.monthlyLimit ?? 0) > 0 || (card.proposedLimit ?? 0) > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        // Prefer monthly_limit (the field PATCH updates). Fall back
                        // to proposed_limit only when monthly_limit is unset.
                        Text("\(FormatUtils.formatGBP((card.monthlyLimit ?? 0) > 0 ? (card.monthlyLimit ?? 0) : (card.proposedLimit ?? 0)))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }

            } else if card.status == "pending" || card.status == "approved" || card.status == "override" {
                // ── Pending / Approved ──
                let isFullyApproved = (card.status == "approved" || card.status == "override")
                Text(isFullyApproved ? "Approved" : "Pending Approval")
                    .font(.system(size: 12, weight: .medium)).italic()
                    .foregroundColor(isFullyApproved ? .green : .orange)
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                HStack(spacing: 4) {
                    if !card.holderDesignation.isEmpty {
                        Text(card.holderDesignation).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    if !displayBankName.isEmpty {
                        Text(card.holderDesignation.isEmpty ? displayBankName : "· \(displayBankName)")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                if !(card.bsControlCode ?? "").isEmpty {
                    HStack {
                        Text("BS Control").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        Text(card.bsControlCode ?? "").font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.bgRaised).cornerRadius(6)
                }
                if (card.monthlyLimit ?? 0) > 0 || (card.proposedLimit ?? 0) > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        // Prefer monthly_limit (the field PATCH updates). Fall back
                        // to proposed_limit only when monthly_limit is unset.
                        Text("\(FormatUtils.formatGBP((card.monthlyLimit ?? 0) > 0 ? (card.monthlyLimit ?? 0) : (card.proposedLimit ?? 0)))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }

                // Approval progress circles — only in detail page (when action callbacks are set)
                if totalTiers > 0 && onApprove != nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(1...totalTiers, id: \.self) { tier in
                                let isApproved = (card.approvals ?? []).contains { ($0.tierNumber ?? 0) == tier }
                                let isCurrent = !isApproved && tier == approvedCount + 1
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .stroke(isApproved ? Color.green : isCurrent ? Color.orange : Color.gray.opacity(0.3), lineWidth: 2)
                                            .frame(width: 34, height: 34)
                                        if isApproved {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold)).foregroundColor(.green)
                                        } else {
                                            Circle()
                                                .fill(isCurrent ? Color.orange.opacity(0.15) : Color.clear)
                                                .frame(width: 28, height: 28)
                                        }
                                    }
                                    Text("Level \(tier)").font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(isApproved ? .green : isCurrent ? .orange : .gray)
                                    if isApproved, let approverEntry = (card.approvals ?? []).first(where: { ($0.tierNumber ?? 0) == tier }),
                                       let user = UsersData.byId[approverEntry.userId ?? ""] {
                                        Text(user.fullName ?? "").font(.system(size: 8, weight: .medium)).foregroundColor(.green).lineLimit(1)
                                        if !user.displayDesignation.isEmpty {
                                            Text(user.displayDesignation).font(.system(size: 7)).foregroundColor(.green.opacity(0.8)).lineLimit(1)
                                        }
                                    } else {
                                        Text("Awaiting").font(.system(size: 8))
                                            .foregroundColor(isCurrent ? .orange : .gray)
                                    }
                                }
                                .frame(minWidth: 64)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Inline action buttons (mirrors the web logic):
                //   • Override → only when the caller passed an
                //     `onOverride` handler (i.e. user has card-override
                //     permission).
                //   • Approve / Reject → only when the user is in the
                //     active tier of this card's approval chain
                //     (`canApprove == true`). If a non-approver
                //     accountant has override privilege, only the
                //     Override button shows.
                let showApprove = canApprove && onApprove != nil
                let showReject  = canApprove && onReject  != nil
                let showOverride = onOverride != nil
                if showApprove || showReject || showOverride {
                    HStack(spacing: 8) {
                        Spacer()
                        if showOverride, let ov = onOverride {
                            Button(action: ov) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold))
                                    Text("Override").font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.orange).cornerRadius(7)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        if showReject, let rj = onReject {
                            Button(action: rj) {
                                Text("Reject").font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.red).cornerRadius(7)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        if showApprove, let ap = onApprove {
                            Button(action: ap) {
                                Text("Approve").font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.green).cornerRadius(7)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }

                // Activate button (full-width) — accountant side, card is approved
                if isAccountant, (card.status == "approved" || card.status == "override"), let act = onActivate {
                    Button(action: act) {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard.and.123").font(.system(size: 12, weight: .bold))
                            let hasNumber = !(card.physicalCardNumber ?? "").isEmpty
                            Text(hasNumber ? "Activate Card" : "Activate & Assign Card Number")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange).cornerRadius(10)
                    }.buttonStyle(BorderlessButtonStyle())
                }

            } else if card.status == "rejected" {
                // ── Rejected ──
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
                if !card.holderDesignation.isEmpty {
                    Text(card.holderDesignation).font(.system(size: 12)).foregroundColor(.secondary)
                }
                if (card.monthlyLimit ?? 0) > 0 || (card.proposedLimit ?? 0) > 0 {
                    HStack {
                        Text("Proposed Limit").font(.system(size: 10)).foregroundColor(.secondary)
                        Spacer()
                        // Prefer monthly_limit (the field PATCH updates). Fall back
                        // to proposed_limit only when monthly_limit is unset.
                        Text("\(FormatUtils.formatGBP((card.monthlyLimit ?? 0) > 0 ? (card.monthlyLimit ?? 0) : (card.proposedLimit ?? 0)))/mo")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                }
                if let reason = card.rejectionReason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REJECTION REASON").font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(red: 0.91, green: 0.29, blue: 0.48)).tracking(0.4)
                        Text(reason).font(.system(size: 12)).foregroundColor(.primary)
                        if let rejBy = card.rejectedBy, !rejBy.isEmpty {
                            HStack(spacing: 4) {
                                Text("By \(UsersData.byId[rejBy]?.fullName ?? rejBy)")
                                    .font(.system(size: 10)).foregroundColor(.secondary)
                                if let rejAt = card.rejectedAt, rejAt > 0 {
                                    Text("· \(FormatUtils.formatDateTime(rejAt))")
                                        .font(.system(size: 10)).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.06)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.2), lineWidth: 1))
                }

            } else {
                Text(card.holderFullName).font(.system(size: 14, weight: .bold))
            }
        }
        .padding(14).background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private func cardStatusColor(_ s: String) -> (Color, Color) {
        switch s {
        case "active":
            return card.isDigitalOnly ? (Color(red: 0.0, green: 0.6, blue: 0.7), Color(red: 0.0, green: 0.6, blue: 0.7).opacity(0.1))
                                      : (.green, Color.green.opacity(0.1))
        case "requested": return (.orange, Color.orange.opacity(0.1))
        case "pending":   return (.orange, Color.orange.opacity(0.1))
        case "approved", "override": return isAccountant ? (.green, Color.green.opacity(0.1)) : (.goldDark, Color.gold.opacity(0.15))
        case "rejected":  return (.red, Color.red.opacity(0.1))
        case "suspended": return (Color(red: 0.5, green: 0.1, blue: 0.8), Color(red: 0.5, green: 0.1, blue: 0.8).opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}
