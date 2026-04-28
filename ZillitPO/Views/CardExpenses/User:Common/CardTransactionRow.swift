import SwiftUI
import UIKit

struct CardTransactionRow: View {
    let transaction: CardTransaction
    var onTap: (() -> Void)? = nil
    var onUploadTap: (() -> Void)? = nil

    private var statusLabel: String { transaction.statusDisplay }

    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        let navy  = Color(red: 0.05, green: 0.15, blue: 0.42)
        switch (transaction.status ?? "").lowercased() {
        case "approved", "matched", "coded": return (teal, teal.opacity(0.12))
        case "posted": return (teal, teal.opacity(0.12))
        case "pending", "pending_receipt": return (orange, orange.opacity(0.12))
        case "pending_coding", "pending_code", "pending code": return (navy, navy.opacity(0.12))
        case "awaiting_approval": return (.goldDark, Color.gold.opacity(0.15))
        case "queried": return (.purple, Color.purple.opacity(0.12))
        case "under_review": return (.blue, Color.blue.opacity(0.12))
        case "escalated": return (.red, Color.red.opacity(0.12))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private var subStatusText: String {
        switch (transaction.status ?? "").lowercased() {
        case "approved", "matched", "coded": return "Approved — awaiting processing"
        case "posted": return "Posted to ledger"
        case "pending", "pending_receipt": return "Upload your receipt for this transaction"
        case "pending_coding", "pending_code": return "Pending budget coding"
        case "awaiting_approval": return "Awaiting approval"
        case "queried": return "Queried — please respond"
        case "under_review": return "Under review"
        case "escalated": return "Escalated for review"
        default: return transaction.statusDisplay
        }
    }

    private var showUploadButton: Bool {
        let s = (transaction.status ?? "").lowercased()
        return (s == "pending" || s == "pending_receipt") && !transaction.hasReceipt
    }

    private var titleText: String {
        let m = (transaction.merchant ?? "").trimmingCharacters(in: .whitespaces)
        if !m.isEmpty { return m.uppercased() }
        if !(transaction.description ?? "").isEmpty { return (transaction.description ?? "").uppercased() }
        return "TRANSACTION"
    }

    private var dateText: String {
        let ts = (transaction.transactionDate ?? 0) > 0 ? (transaction.transactionDate ?? 0) : (transaction.createdAt ?? 0)
        return ts > 0 ? FormatUtils.formatTimestamp(ts) : ""
    }

    @ViewBuilder
    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(titleText)
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.primary).lineLimit(2)
                    Spacer(minLength: 8)
                    let (fg, bg) = statusColors
                    Text(statusLabel).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(bg).cornerRadius(4)
                }

                HStack(spacing: 8) {
                    Text(FormatUtils.formatGBP(transaction.amount ?? 0))
                        .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    if !dateText.isEmpty {
                        Text(dateText).font(.system(size: 11)).foregroundColor(.gray)
                    }
                    Spacer()
                }

                Text(subStatusText).font(.system(size: 11)).foregroundColor(.secondary)

                if showUploadButton {
                    HStack {
                        Spacer()
                        Button(action: { (onUploadTap ?? onTap)?() }) {
                            Text("Upload Receipt")
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.gold).cornerRadius(6)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgSurface).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
    }

    var body: some View {
        if let onTap = onTap {
            Button(action: onTap) { rowContent }.buttonStyle(PlainButtonStyle())
        } else {
            rowContent
        }
    }
}

// Disables the interactive swipe-back gesture on the parent UINavigationController
