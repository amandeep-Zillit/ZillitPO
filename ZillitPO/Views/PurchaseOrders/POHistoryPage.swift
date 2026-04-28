import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - PO History Page
// Mirrors `InvoiceHistoryPage` — a vertical timeline of audit events
// for a single purchase order. Icons + colours are derived from the
// action string so the list reads at a glance.
// ═══════════════════════════════════════════════════════════════════

struct POHistoryPage: View {
    @EnvironmentObject var appState: POViewModel
    let poId: String
    let poLabel: String

    private var entries: [InvoiceHistoryEntry] { appState.poHistory[poId] ?? [] }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            if appState.poHistoryLoading && entries.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
            } else if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                    Text("No history yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                    Text("Actions on this purchase order will appear here.")
                        .font(.system(size: 12)).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Summary header
                        if !poLabel.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "cart.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                                Text(poLabel)
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
        .navigationBarTitle(Text("PO History"), displayMode: .inline)
        .onAppear { appState.loadPOHistory(poId) }
    }

    // MARK: - Styling helpers (kept identical to InvoiceHistoryPage so
    // icon + colour mappings stay in sync across modules)

    private func actionColor(_ action: String) -> Color {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return .green }
        if a.contains("reject") { return .red }
        if a.contains("override") { return .orange }
        if a.contains("submit") || a.contains("raise") { return .goldDark }
        if a.contains("escalat") { return .red }
        if a.contains("post") || a.contains("paid") { return Color(red: 0.1, green: 0.6, blue: 0.3) }
        return .goldDark
    }

    private func actionIcon(_ action: String) -> String {
        let a = action.lowercased()
        if a.contains("approv") && !a.contains("override") { return "checkmark.circle.fill" }
        if a.contains("reject") { return "xmark.circle.fill" }
        if a.contains("override") { return "bolt.fill" }
        if a.contains("submit") || a.contains("raise") { return "paperplane.fill" }
        if a.contains("escalat") { return "exclamationmark.triangle.fill" }
        if a.contains("post") || a.contains("paid") { return "tray.and.arrow.down.fill" }
        if a.contains("update") || a.contains("edit") { return "pencil.circle.fill" }
        if a.contains("creat") { return "plus.circle.fill" }
        if a.contains("close") || a.contains("cancel") { return "xmark.octagon.fill" }
        return "circle.fill"
    }

    /// Turn a raw backend action string into a past-tense Title Case label.
    /// "po_approved" → "Po approved", "created" → "Created".
    private func actionTitle(_ raw: String) -> String {
        if raw.isEmpty { return "—" }
        let replaced = raw.replacingOccurrences(of: "_", with: " ")
        return replaced.prefix(1).uppercased() + replaced.dropFirst()
    }

    /// Resolve the actor for a history entry — returns both the display
    /// name and (optionally) a designation like "Production Accountant".
    private func resolvedUser(for entry: InvoiceHistoryEntry) -> (name: String, role: String?) {
        if let uid = entry.effectiveUserId, !uid.isEmpty, let u = UsersData.byId[uid] {
            let role = u.displayDesignation.isEmpty ? nil : u.displayDesignation
            return (u.fullName ?? "", role)
        }
        if let name = entry.userName, !name.isEmpty { return (name, nil) }
        if let uid = entry.effectiveUserId, !uid.isEmpty { return (uid, nil) }
        return ("Unknown", nil)
    }

    private func historyRow(_ entry: InvoiceHistoryEntry, isLast: Bool) -> some View {
        let actionStr = entry.action ?? ""
        let title = actionTitle(actionStr)
        let color = actionColor(actionStr)
        let who = resolvedUser(for: entry)
        return HStack(alignment: .top, spacing: 12) {
            // Timeline icon + connecting line
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: actionIcon(actionStr))
                        .font(.system(size: 11, weight: .bold)).foregroundColor(color)
                }
                if !isLast {
                    Rectangle().fill(Color.borderColor).frame(width: 2)
                        .frame(maxHeight: .infinity).padding(.top, 2)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.primary)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                        .padding(.trailing, 4)
                    (
                        Text("by ").foregroundColor(.secondary)
                        + Text(who.name).fontWeight(.semibold).foregroundColor(.primary)
                        + Text({
                            if let r = who.role { return " (\(r))" }
                            return ""
                        }()).foregroundColor(.secondary)
                    )
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }

                if let d = entry.details, !d.isEmpty {
                    Text(d).font(.system(size: 12)).foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let ts = entry.effectiveTimestamp, ts > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.gray)
                        Text(FormatUtils.formatHistoryDateTime(ts))
                            .font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
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
