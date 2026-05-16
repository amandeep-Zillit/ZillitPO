//
//  TCApprovalQueuePage.swift
//  ZillitPO
//
//  Scaffold for `ApproveTimeCardsPage.jsx` (1,353 LOC). Lists timecards
//  pending approval with batch-select + approve / reject (single + batch).
//

import SwiftUI

struct TCApprovalQueuePage: View {
    @EnvironmentObject var tc: TimecardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !tc.selectedForBatch.isEmpty { batchBar }
                if tc.isLoadingApprovalQueue {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if tc.approvalQueue.isEmpty {
                    emptyState
                } else {
                    ForEach(tc.approvalQueue) { card in
                        approvalRow(card)
                    }
                }
            }
            .padding(16)
        }
        .navigationBarTitle("Approval Queue", displayMode: .inline)
        .background(Color.bgBase.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $tc.showRejectSheet) {
            TimecardRejectSheet().environmentObject(tc)
        }
        .onAppear { if tc.approvalQueue.isEmpty { tc.loadApprovalQueue() } }
    }

    private var batchBar: some View {
        HStack {
            Text("\(tc.selectedForBatch.count) selected")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button(action: batchApprove) {
                Text("Approve")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color(red: 0.21, green: 0.64, blue: 0.37))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }.buttonStyle(BorderlessButtonStyle())
            Button(action: openBatchReject) {
                Text("Reject")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.red.opacity(0.12))
                    .foregroundColor(.red)
                    .cornerRadius(8)
            }.buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.gold.opacity(0.1))
        .cornerRadius(10)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Nothing pending").font(.system(size: 13)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func approvalRow(_ card: Timecard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: { toggleSelect(card) }) {
                    Image(systemName: isSelected(card) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected(card) ? .goldDark : .secondary)
                        .font(.system(size: 18))
                }.buttonStyle(BorderlessButtonStyle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(crewName(card)).font(.system(size: 13, weight: .semibold))
                    Text("\(TimecardViewModel.weekOfLabel(card.weekStarting)) · \(card.timecardNumber ?? "—")")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(TimecardViewModel.grossLabel(card.grossPay, currency: card.currency))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            HStack(spacing: 8) {
                Button(action: { singleApprove(card) }) {
                    Text("Approve")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Color(red: 0.21, green: 0.64, blue: 0.37))
                        .foregroundColor(.white).cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle())
                Button(action: { openSingleReject(card) }) {
                    Text("Reject")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.4), lineWidth: 1))
                        .cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle())
                Spacer()
            }
        }
        .padding(12)
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func crewName(_ c: Timecard) -> String {
        if let uid = c.userId, let u = UsersData.byId[uid] { return u.fullName ?? "—" }
        return "—"
    }

    private func isSelected(_ c: Timecard) -> Bool {
        c._id.map { tc.selectedForBatch.contains($0) } ?? false
    }

    private func toggleSelect(_ c: Timecard) {
        guard let id = c._id else { return }
        if tc.selectedForBatch.contains(id) { tc.selectedForBatch.remove(id) }
        else { tc.selectedForBatch.insert(id) }
    }

    private func singleApprove(_ c: Timecard) {
        guard let id = c._id else { return }
        tc.approveTimecard(id) { _ in }
    }
    private func batchApprove() {
        tc.approveBatch(Array(tc.selectedForBatch)) { _ in }
    }
    private func openSingleReject(_ c: Timecard) {
        tc.rejectTarget = c
        tc.rejectReason = ""
        tc.showRejectSheet = true
    }
    private func openBatchReject() {
        tc.rejectTarget = nil  // signals "batch mode"
        tc.rejectReason = ""
        tc.showRejectSheet = true
    }
}

// MARK: - Reject sheet (single + batch)

private struct TimecardRejectSheet: View {
    @EnvironmentObject var tc: TimecardViewModel
    @Environment(\.presentationMode) var presentationMode

    private var isBatch: Bool { tc.rejectTarget == nil }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 14) {
                Text(isBatch
                     ? "Rejecting \(tc.selectedForBatch.count) timecards"
                     : "Reason for rejection")
                    .font(.system(size: 13, weight: .semibold))
                TextEditor(text: $tc.rejectReason)
                    .frame(minHeight: 120)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                Text("This will be sent to the crew member and recorded on the timecard's audit trail.")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                HStack {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    Spacer()
                    Button(action: submit) {
                        Text(isBatch ? "Reject all" : "Reject timecard")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.red.opacity(tc.rejectReason.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(tc.rejectReason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(16)
            .navigationBarTitle(Text(isBatch ? "Reject Timecards" : "Reject Timecard"), displayMode: .inline)
        }
    }

    private func submit() {
        let reason = tc.rejectReason
        if isBatch {
            tc.rejectBatch(Array(tc.selectedForBatch), reason: reason) { _ in }
        } else if let id = tc.rejectTarget?._id {
            tc.rejectTimecard(id, reason: reason) { _ in }
        }
        presentationMode.wrappedValue.dismiss()
    }
}
