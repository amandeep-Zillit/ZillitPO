//
//  DMApprovalQueuePage.swift
//  ZillitPO
//
//  Port of `DMApprovalQueuePage.jsx`. Shows 3 buckets — Pending /
//  Approved / Rejected — and lets approvers take action on the pending
//  ones (approve / reject). Reject sheet UI ports from
//  `RejectDealMemoModal.jsx` and is presented as a `.sheet` below.
//

import SwiftUI

struct DMApprovalQueuePage: View {
    @EnvironmentObject var dm: DealMemoViewModel
    @State private var bucket: Bucket = .pending

    enum Bucket: String, CaseIterable, Identifiable {
        case pending, approved, rejected
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bucketSwitcher
            if dm.isLoadingApprovalQueue {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            } else if rows.isEmpty {
                emptyState
            } else {
                ForEach(rows) { deal in
                    DMApprovalRow(deal: deal)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .sheet(isPresented: $dm.showRejectSheet) {
            RejectDealMemoSheet()
                .environmentObject(dm)
        }
        .onAppear {
            if dm.approvalQueue == nil && !dm.isLoadingApprovalQueue { dm.loadApprovalQueue() }
        }
    }

    private var bucketSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(Bucket.allCases) { b in
                Button(action: { bucket = b }) {
                    HStack(spacing: 6) {
                        Text(b.label)
                            .font(.system(size: 12, weight: bucket == b ? .semibold : .regular))
                        Text("\(count(for: b))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.bgRaised)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(bucket == b ? Color.gold.opacity(0.15) : Color.bgSurface)
                    .foregroundColor(bucket == b ? .goldDark : .secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(bucket == b ? Color.goldDark.opacity(0.4) : Color.borderColor, lineWidth: 1)
                    )
                    .cornerRadius(10)
                }.buttonStyle(BorderlessButtonStyle())
            }
            Spacer()
        }
    }

    private func count(for b: Bucket) -> Int {
        switch b {
        case .pending:  return dm.approvalTotals?.pending ?? (dm.approvalQueue?.pending?.count ?? 0)
        case .approved: return dm.approvalTotals?.approved ?? (dm.approvalQueue?.approved?.count ?? 0)
        case .rejected: return dm.approvalTotals?.rejected ?? (dm.approvalQueue?.rejected?.count ?? 0)
        }
    }

    private var rows: [DealMemo] {
        switch bucket {
        case .pending:  return dm.approvalQueue?.pending ?? []
        case .approved: return dm.approvalQueue?.approved ?? []
        case .rejected: return dm.approvalQueue?.rejected ?? []
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal").font(.system(size: 28)).foregroundColor(.secondary.opacity(0.5))
            Text("Nothing in this bucket.").font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Row

private struct DMApprovalRow: View {
    @EnvironmentObject var dm: DealMemoViewModel
    let deal: DealMemo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(deal.dealReference ?? "—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                StatusBadge(deal.poStatus.label, color: statusColor(deal.poStatus))
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dm.crewName(for: deal)).font(.system(size: 13, weight: .semibold))
                    Text(dm.position(for: deal)).font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
                Text(dm.formattedDailyRate(deal))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }

            if deal.poStatus == .awaitingApproval {
                HStack(spacing: 8) {
                    Button(action: approve) {
                        Text("Approve")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Color(red: 0.21, green: 0.64, blue: 0.37))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())
                    Button(action: openRejectSheet) {
                        Text("Reject")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Color.red.opacity(0.12))
                            .foregroundColor(.red)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.4), lineWidth: 1))
                            .cornerRadius(8)
                    }.buttonStyle(BorderlessButtonStyle())
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func approve() {
        guard let id = deal._id else { return }
        dm.approveDeal(id, signature: nil, comment: nil) { _ in }
    }
    private func openRejectSheet() {
        dm.rejectTarget = deal
        dm.rejectReason = ""
        dm.showRejectSheet = true
    }
    private func statusColor(_ s: DealMemoStatus) -> Color {
        switch s.tokenColor {
        case "amber": return Color(red: 0.96, green: 0.62, blue: 0.20)
        case "green": return Color(red: 0.21, green: 0.64, blue: 0.37)
        case "red":   return .red
        case "blue":  return Color(red: 0.20, green: 0.50, blue: 0.86)
        default:      return .gray
        }
    }
}

// MARK: - Reject sheet (RejectDealMemoModal port)

private struct RejectDealMemoSheet: View {
    @EnvironmentObject var dm: DealMemoViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Reason for rejection")
                    .font(.system(size: 13, weight: .semibold))
                TextEditor(text: $dm.rejectReason)
                    .frame(minHeight: 120)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                Text("This will be sent to the deal raiser and recorded on the deal's audit trail.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                HStack {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    Spacer()
                    Button(action: submit) {
                        Text("Reject deal")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.red.opacity(dm.rejectReason.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(dm.rejectReason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(16)
            .navigationBarTitle(Text("Reject Deal Memo"), displayMode: .inline)
        }
    }

    private func submit() {
        guard let id = dm.rejectTarget?._id else { return }
        let reason = dm.rejectReason
        dm.rejectDeal(id, reason: reason) { _ in }
        presentationMode.wrappedValue.dismiss()
    }
}
