import SwiftUI

struct PaymentRoutingView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var bacsGenerated = false
    @State private var activeSection = "bacs"   // "bacs" | "payroll"

    private var routing: PaymentRoutingResponse { appState.paymentRouting }
    private var bacsBatches: [PaymentRoutingBatch]    { routing.bacsBatches ?? [] }
    private var payrollBatches: [PaymentRoutingBatch] { routing.payrollBatches ?? [] }
    private var bacsTotal: Double    { routing.stats?.bacsReady ?? 0 }
    private var payrollTotal: Double { routing.stats?.payrollTotal ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header banner
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.down.circle.fill").font(.system(size: 14)).foregroundColor(.goldDark)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payment Routing").font(.system(size: 13, weight: .bold))
                    Text("Approved BACS claims batched for export. Payroll claims auto-add to the payroll run on approval.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12).background(Color.gold.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.25), lineWidth: 1))
            .cornerRadius(8).padding(.horizontal, 16).padding(.top, 12)

            // Tappable section cards — mirrors the Approval Queue pattern
            HStack(spacing: 10) {
                Button(action: { activeSection = "bacs" }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "building.columns.fill").font(.system(size: 14)).foregroundColor(.goldDark)
                            Text("BACS Payments").font(.system(size: 13, weight: .bold)).lineLimit(1)
                        }
                        Text("\(bacsBatches.count) claims · \(FormatUtils.formatGBP(bacsTotal))")
                            .font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(12)
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(activeSection == "bacs" ? Color.goldDark : Color.borderColor, lineWidth: activeSection == "bacs" ? 2 : 1))
                }.buttonStyle(PlainButtonStyle())

                Button(action: { activeSection = "payroll" }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.plus").font(.system(size: 14)).foregroundColor(.goldDark)
                            Text("Payroll Additions").font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Text("\(payrollBatches.count) additions · \(FormatUtils.formatGBP(payrollTotal))")
                            .font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(12)
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(activeSection == "payroll" ? Color.goldDark : Color.borderColor, lineWidth: activeSection == "payroll" ? 2 : 1))
                }.buttonStyle(PlainButtonStyle())
            }
            .frame(height: 64)
            .padding(.horizontal, 16).padding(.top, 12)

            // Active section content
            if appState.isLoadingPaymentRouting && bacsBatches.isEmpty && payrollBatches.isEmpty {
                // Full-area loader on cold-open — the header banner and tab
                // buttons above stay visible so the layout doesn't jump.
                VStack { Spacer(); LoaderView(); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if activeSection == "bacs" {
                        sectionCard(
                            icon: "building.columns.fill",
                            title: "BACS Payments",
                            subtitle: "\(bacsBatches.count) claim\(bacsBatches.count == 1 ? "" : "s") · \(FormatUtils.formatGBP(bacsTotal))",
                            badge: bacsGenerated ? "Generated" : "Ready",
                            badgeColor: .green,
                            emptyText: "No BACS claims to process.",
                            batches: bacsBatches,
                            kind: .bacs,
                            footerValue: FormatUtils.formatGBP(bacsTotal),
                            footerSub: "\(bacsBatches.count) payee\(bacsBatches.count == 1 ? "" : "s")",
                            action: bacsFooterAction
                        )
                    } else {
                        sectionCard(
                            icon: "calendar.badge.plus",
                            title: "Payroll Additions",
                            subtitle: "Auto-added to payroll run on approval",
                            badge: "Auto-routed",
                            badgeColor: .gray,
                            emptyText: "No payroll claims.",
                            batches: payrollBatches,
                            kind: .payroll,
                            footerValue: FormatUtils.formatGBP(payrollTotal),
                            footerSub: "\(payrollBatches.count) addition\(payrollBatches.count == 1 ? "" : "s")",
                            action: .none
                        )
                    }

                    // Blue info notice at the bottom — mirrors the React
                    // reference's footer paragraph explaining what happens
                    // once the BACS file is uploaded.
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 13)).foregroundColor(.blue)
                            .padding(.top, 1)
                        Text("Once BACS file is uploaded and payroll additions are confirmed, all claims will be marked Processed and crew notified automatically.")
                            .font(.system(size: 11)).foregroundColor(.blue.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.25), lineWidth: 1))
                    .cornerRadius(8)
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
            }
            } // end of else branch for loader guard
        }
        .background(Color.bgBase)
        .onAppear { appState.loadPaymentRouting() }
    }

    // MARK: - BACS footer action

    /// What the BACS card's footer button area should render. We split this
    /// out so the card renderer can draw either a single "Generate" button or
    /// a pair of "Download + Mark as uploaded" buttons after generation.
    private enum FooterAction {
        case none
        case generate(onTap: () -> Void)
        case generated(onDownload: () -> Void, onMarkUploaded: () -> Void)
    }

    private var bacsFooterAction: FooterAction {
        if bacsGenerated {
            return .generated(
                onDownload: { /* hook up real download when backend endpoint exists */ },
                onMarkUploaded: { bacsGenerated = false /* or transition to next state */ }
            )
        }
        // Always clickable — matches the React reference. The `generateBACS`
        // call itself handles empty-state by just flipping the flag (the
        // BACS card body already shows an "empty" message when there are
        // no batches, so tapping Generate in that state is a no-op UX-wise).
        return .generate(onTap: generateBACS)
    }

    // MARK: - Batch row

    private enum RoutingKind { case bacs, payroll }

    /// Row layout mirrors the React reference: round initials avatar on the
    /// left, resolved holder name + batch ref/claim-count under it, and an
    /// amount + (for BACS) bank last-4 / (for payroll) "payroll addition"
    /// label on the right.
    private func routingBatchRow(_ b: PaymentRoutingBatch, kind: RoutingKind) -> some View {
        let ring: (stroke: Color, bg: Color, fg: Color) = {
            switch kind {
            case .bacs:    return (.purple, Color.purple.opacity(0.1), .purple)
            case .payroll: return (.blue,   Color.blue.opacity(0.1),   .blue)
            }
        }()
        return HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle().fill(ring.bg)
                Circle().stroke(ring.stroke.opacity(0.5), lineWidth: 1.5)
                Text(b.holderInitials)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ring.fg)
            }
            .frame(width: 32, height: 32)

            // Name + ref/claim count
            VStack(alignment: .leading, spacing: 2) {
                Text(b.holderName.isEmpty ? "—" : b.holderName)
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let ref = b.batchReference, !ref.isEmpty {
                        Text(ref).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                        Text("·").font(.system(size: 10)).foregroundColor(.gray)
                    }
                    Text("\(b.claimCount ?? 0) receipt\((b.claimCount ?? 0) == 1 ? "" : "s")")
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
            }

            Spacer(minLength: 8)

            // Amount + right-hand subtext
            VStack(alignment: .trailing, spacing: 2) {
                Text(FormatUtils.formatGBP(b.displayAmount))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                Group {
                    switch kind {
                    case .bacs where !b.bankLast4Display.isEmpty:
                        Text("to \(b.bankLast4Display)")
                    case .bacs:
                        EmptyView()
                    case .payroll:
                        Text("payroll addition")
                    }
                }
                .font(.system(size: 9)).foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func generateBACS() {
        // No empty-batches guard — the React reference always allows the
        // flip (the green success banner and post-generated UI are still
        // relevant metadata for the user even if no batches loaded yet).
        bacsGenerated = true
    }

    // MARK: - Section card
    // Header (icon + title + badge) → body (batch rows or empty) →
    // footer (total + contextual action) → optional green "BACS file
    // generated" banner when the BACS card is post-generation.

    private func sectionCard(icon: String, title: String, subtitle: String,
                             badge: String, badgeColor: Color,
                             emptyText: String,
                             batches: [PaymentRoutingBatch],
                             kind: RoutingKind,
                             footerValue: String, footerSub: String,
                             action: FooterAction) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(.goldDark)
                    .frame(width: 28, height: 28).background(Color.gold.opacity(0.12)).cornerRadius(6)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .bold))
                    Text(subtitle).font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
                Text(badge).font(.system(size: 9, weight: .bold)).foregroundColor(badgeColor)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(badgeColor.opacity(0.12)).cornerRadius(4)
            }.padding(12)

            Divider()

            // Body — either a list of batch rows or the empty state
            if batches.isEmpty {
                Text(emptyText).font(.system(size: 11)).foregroundColor(.gray)
                    .frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(batches.enumerated()), id: \.element.id) { idx, b in
                        routingBatchRow(b, kind: kind)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                        if idx < batches.count - 1 { Divider().padding(.leading, 12) }
                    }
                }
            }

            Divider()

            // Footer — total on the left, contextual action on the right
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(footerValue).font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text(footerSub).font(.system(size: 9)).foregroundColor(.gray)
                }
                Spacer(minLength: 8)
                footerActionView(action)
            }.padding(12)

            // Green success banner inline under the BACS card once the
            // BACS file has been generated — replaces the old modal alert.
            if case .generated = action {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("BACS file generated")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                    Text("Upload to your bank portal to process payment.")
                        .font(.system(size: 10))
                        .foregroundColor(.green.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.green.opacity(0.08))
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    @ViewBuilder
    private func footerActionView(_ action: FooterAction) -> some View {
        switch action {
        case .none:
            EmptyView()
        case .generate(let onTap):
            Button(action: onTap) {
                Text("Generate BACS File")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.goldDark)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        case .generated(let onDownload, let onMarkUploaded):
            HStack(spacing: 6) {
                Button(action: onDownload) {
                    Text("Download")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color.bgSurface)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                        .cornerRadius(6)
                }.buttonStyle(PlainButtonStyle())

                Button(action: onMarkUploaded) {
                    Text("Mark as uploaded")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color.green)
                        .cornerRadius(6)
                }.buttonStyle(PlainButtonStyle())
            }
        }
    }
}
