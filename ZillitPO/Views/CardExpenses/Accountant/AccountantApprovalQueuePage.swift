import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Accountant Approval Queue Page
// ═══════════════════════════════════════════════════════════════════

struct AccountantApprovalQueuePage: View {
    @EnvironmentObject var appState: POViewModel

    @State private var overrideTarget: CardTransaction? = nil
    @State private var overrideReason: String = ""
    @State private var isOverriding: Bool = false
    @State private var showOverrideSheet: Bool = false

    private var items: [CardTransaction] { appState.cardApprovalQueueItems }

    private var groupedByStatus: [(status: String, label: String, color: Color, items: [CardTransaction])] {
        let order: [(String, String, Color)] = [
            ("awaiting_approval", "Awaiting Approval", .goldDark),
            ("escalated",         "Escalated",         .red),
            ("under_review",      "Under Review",      .purple),
        ]
        return order.compactMap { (status, label, color) in
            let group = items.filter { ($0.status ?? "").lowercased() == status }
            guard !group.isEmpty else { return nil }
            return (status: status, label: label, color: color, items: group.sorted { ($0.transactionDate ?? 0) > ($1.transactionDate ?? 0) })
        }
    }

    var body: some View {
        Group {
            if appState.isLoadingCardApprovals && items.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
                    .background(Color.bgBase)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if items.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark.shield").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No items awaiting approval").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
                        } else {
                            ForEach(groupedByStatus, id: \.status) { group in
                                approvalSection(group)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
                }
                .background(Color.bgBase)
            }
        }
        .navigationBarTitle(Text("Approval Queue"), displayMode: .inline)
        .onAppear { appState.loadCardApprovalQueue() }
        .sheet(isPresented: $showOverrideSheet) {
            overrideSheet
        }
    }

    @ViewBuilder
    private func approvalSection(_ group: (status: String, label: String, color: Color, items: [CardTransaction])) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(group.color).frame(width: 8, height: 8)
                Text(group.label.uppercased())
                    .font(.system(size: 10, weight: .bold)).tracking(0.5)
                Text("\(group.items.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(group.color).cornerRadius(8)
                Spacer()
                Text(FormatUtils.formatGBP(group.items.reduce(0) { $0 + ($1.amount ?? 0) }))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(group.color)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(group.color.opacity(0.06))

            Divider()
            ForEach(group.items) { tx in
                HStack(spacing: 0) {
                    NavigationLink(destination: CardTransactionDetailPage(transaction: tx).environmentObject(appState)) {
                        approvalRow(tx, color: group.color)
                    }.buttonStyle(PlainButtonStyle())

                    // Override button
                    Button(action: {
                        overrideTarget = tx
                        overrideReason = ""
                        showOverrideSheet = true
                    }) {
                        VStack(spacing: 3) {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.system(size: 13))
                            Text("Override")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 64)
                        .frame(maxHeight: .infinity)
                        .background(Color(red: 0.95, green: 0.55, blue: 0.15))
                    }.buttonStyle(BorderlessButtonStyle())
                }
                .frame(minHeight: 64)
                if tx.id != group.items.last?.id { Divider().padding(.leading, 14) }
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(group.color.opacity(0.25), lineWidth: 1))
        .clipped()
    }

    private func approvalRow(_ tx: CardTransaction, color: Color) -> some View {
        let dateText = (tx.transactionDate ?? 0) > 0 ? FormatUtils.formatTimestamp(tx.transactionDate ?? 0)
                     : (tx.createdAt ?? 0) > 0 ? FormatUtils.formatTimestamp(tx.createdAt ?? 0) : "—"
        let user = UsersData.byId[tx.holderId ?? ""]
        let ageDays: Int = {
            let ref = (tx.createdAt ?? 0) > 0 ? (tx.createdAt ?? 0) : (tx.transactionDate ?? 0)
            guard ref > 0 else { return 0 }
            let secs = (Date().timeIntervalSince1970 * 1000 - Double(ref)) / 1000
            return max(0, Int(secs / 86400))
        }()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text((tx.merchant ?? "").isEmpty ? ((tx.description ?? "").isEmpty ? "—" : (tx.description ?? "")) : (tx.merchant ?? ""))
                            .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        if tx.isUrgent ?? false {
                            Text("Urgent")
                                .font(.system(size: 8, weight: .bold)).foregroundColor(.red)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.red.opacity(0.1)).cornerRadius(3)
                        }
                    }
                    Text(dateText).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(FormatUtils.formatGBP(tx.amount ?? 0))
                        .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(color)
                    if !(tx.nominalCode ?? "").isEmpty {
                        Text(tx.nominalCode ?? "")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.08)).cornerRadius(3)
                    }
                }
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(user?.fullName ?? ((tx.holderName ?? "").isEmpty ? "—" : (tx.holderName ?? "")))
                        .font(.system(size: 11, weight: .semibold))
                    if !(tx.department ?? "").isEmpty {
                        Text(tx.department ?? "").font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if tx.hasReceipt {
                    Image(systemName: "paperclip").font(.system(size: 10)).foregroundColor(.green)
                }
                Text("\(ageDays)d").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var overrideSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                if let tx = overrideTarget {
                    // Item summary
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ITEM").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text((tx.merchant ?? "").isEmpty ? (tx.description ?? "") : (tx.merchant ?? ""))
                                    .font(.system(size: 14, weight: .semibold))
                                Text((tx.holderName ?? "").isEmpty ? "—" : (tx.holderName ?? ""))
                                    .font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(FormatUtils.formatGBP(tx.amount ?? 0))
                                .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        }
                        .padding(14).background(Color(.systemGray6)).cornerRadius(10)
                    }

                    // Reason field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REASON FOR OVERRIDE").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                        TextField("e.g. Approver unavailable, deadline critical…", text: $overrideReason)
                            .font(.system(size: 13))
                            .padding(12)
                            .background(Color.bgSurface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    Spacer()

                    // Confirm button
                    Button(action: submitOverride) {
                        HStack(spacing: 6) {
                            if isOverriding {
                                ActivityIndicator(isAnimating: true)
                            }
                            Text(isOverriding ? "Overriding…" : "Confirm Override")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding
                                    ? Color.gray.opacity(0.3) : Color(red: 0.95, green: 0.55, blue: 0.15))
                        .foregroundColor(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding
                                         ? .gray : .white)
                        .cornerRadius(12)
                    }
                    .disabled(overrideReason.trimmingCharacters(in: .whitespaces).isEmpty || isOverriding)
                }
            }
            .padding(20)
            .background(Color.bgBase.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Override Approval", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                showOverrideSheet = false
            }.foregroundColor(.goldDark))
        }
    }

    private func submitOverride() {
        guard let tx = overrideTarget, !overrideReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isOverriding = true
        appState.overrideApprovalItem(tx.id ?? "", reason: overrideReason) { success in
            isOverriding = false
            if success { showOverrideSheet = false }
        }
    }
}
