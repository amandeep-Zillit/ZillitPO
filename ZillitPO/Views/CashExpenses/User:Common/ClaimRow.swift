import SwiftUI

struct ClaimRow: View {
    let claim: ClaimBatch

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: reference + status
            HStack {
                Text((claim.batchReference ?? "").isEmpty ? "—" : (claim.batchReference ?? ""))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                Spacer()
                let (fg, bg) = claimStatusColor(claim.status ?? "")
                Text(claim.statusDisplay).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
            }
            // Type badge + department
            HStack(spacing: 6) {
                Text(claim.isPettyCash ? "Petty Cash" : "Out of Pocket")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(claim.isPettyCash ? Color(red: 0.2, green: 0.7, blue: 0.45) : .purple)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background((claim.isPettyCash ? Color(red: 0.2, green: 0.7, blue: 0.45) : Color.purple).opacity(0.1)).cornerRadius(3)
                if !(claim.department ?? "").isEmpty {
                    Text(claim.department!).font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            // Submitter
            if let user = UsersData.byId[claim.userId ?? ""] {
                Text(user.fullName ?? "").font(.system(size: 13, weight: .medium))
            }
            // Amounts
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Gross").font(.system(size: 9)).foregroundColor(.secondary)
                    Text(FormatUtils.formatGBP(claim.totalGross ?? 0)).font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Net").font(.system(size: 9)).foregroundColor(.secondary)
                    Text(FormatUtils.formatGBP(claim.totalNet ?? 0)).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("VAT").font(.system(size: 9)).foregroundColor(.secondary)
                    Text(FormatUtils.formatGBP(claim.totalVat ?? 0)).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(.secondary)
                }
                Spacer()
                if (claim.claimCount ?? 0) > 0 {
                    Text("\(claim.claimCount!) item\(claim.claimCount! == 1 ? "" : "s")")
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
            }
            // Rejection
            if let reason = claim.rejectionReason, !reason.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundColor(.red)
                    Text(reason).font(.system(size: 10)).foregroundColor(.red).lineLimit(1)
                }
            }
            // Date
            if (claim.createdAt ?? 0) > 0 {
                Text(FormatUtils.formatDateTime(claim.createdAt ?? 0)).font(.system(size: 10)).foregroundColor(.gray)
            }
        }
        .padding(12).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func claimStatusColor(_ s: String) -> (Color, Color) {
        switch s.uppercased() {
        case "CODING", "CODED": return (.blue, Color.blue.opacity(0.1))
        case "IN_AUDIT": return (.purple, Color.purple.opacity(0.1))
        case "AWAITING_APPROVAL": return (.goldDark, Color.gold.opacity(0.15))
        case "APPROVED", "ACCT_OVERRIDE": return (.green, Color.green.opacity(0.1))
        case "READY_TO_POST": return (.blue, Color.blue.opacity(0.1))
        case "POSTED": return (.green, Color.green.opacity(0.1))
        case "REJECTED": return (.red, Color.red.opacity(0.1))
        case "ESCALATED": return (.orange, Color.orange.opacity(0.1))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }
}

// MARK: - Floats List View

// ═══════════════════════════════════════════════════════════════════
// MARK: - Cash Top-ups View (accountant side, Petty Cash tab)
// ═══════════════════════════════════════════════════════════════════
