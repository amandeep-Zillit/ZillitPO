import SwiftUI
import UIKit

// ═══════════════════════════════════════════════════════════════════
// MARK: - Smart Alerts Page
// ═══════════════════════════════════════════════════════════════════

struct SmartAlertsPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var activeFilter: AlertFilter = .all
    @State private var showFilterSheet = false
    @State private var resolveTarget: SmartAlert? = nil
    @State private var navigateToAlertId: String? = nil

    private let pink   = Color(red: 0.91, green: 0.29, blue: 0.48)
    private let teal   = Color(red: 0.0,  green: 0.6,  blue: 0.5)
    private let amber  = Color(red: 0.96, green: 0.62, blue: 0.04)
    private let purple = Color(red: 0.66, green: 0.33, blue: 0.97)

    // MARK: - Filter definitions
    enum AlertFilter: String, CaseIterable, Identifiable {
        case all, anomaly, dup, velocity, merchant, resolved
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all:      return "All"
            case .anomaly:  return "Anomaly"
            case .dup:      return "Duplicate Risk"
            case .velocity: return "Velocity"
            case .merchant: return "Merchant"
            case .resolved: return "Resolved"
            }
        }
        /// Backend `type` values this filter should match (lowercased, substring match).
        var matchTypes: [String] {
            switch self {
            case .anomaly:  return ["amount anomaly", "anomaly"]
            case .dup:      return ["cross-card duplicate", "duplicate risk", "duplicate_risk", "duplicate"]
            case .velocity: return ["spending limit", "velocity"]
            case .merchant: return ["overdue coding", "missing amount", "merchant"]
            case .all, .resolved: return []
            }
        }
    }

    // MARK: - Derived data
    private var alerts: [SmartAlert] { appState.smartAlerts }
    private var resolvedAlerts: [SmartAlert] {
        alerts.filter { ($0.status ?? "").lowercased() == "resolved" }
    }
    private var resolvedCount: Int { resolvedAlerts.count }

    private var visible: [SmartAlert] {
        switch activeFilter {
        case .all:      return alerts
        case .resolved: return resolvedAlerts
        default:
            let types = activeFilter.matchTypes
            return alerts.filter { a in
                let t = (a.type ?? "").lowercased()
                return types.contains(where: { t.contains($0) })
            }
        }
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:tag:selection:label:)")
    var body: some View {
        Group {
            if appState.isLoadingSmartAlerts && alerts.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
                    .background(Color.bgBase)
            } else {
                ScrollView {
                    VStack(spacing: 14) {

                        // ── Filter dropdown ──
                        filterBar

                        // ── Alert list ──
                        if visible.isEmpty {
                            VStack(spacing: 10) {
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 32)).foregroundColor(.gray.opacity(0.25))
                                Text(activeFilter == .all ? "All clear — no active alerts." : "No alerts match the current filter.")
                                    .font(.system(size: 12)).foregroundColor(.gray)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 280)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(visible) { alert in
                                    alertCard(alert)
                                }
                            }
                        }

                        // ── Recently Resolved summary (only on All filter) ──
                        if activeFilter == .all && !resolvedAlerts.isEmpty {
                            recentlyResolvedCard
                        }

                        // Footer caption
                        Text("Alerts detect cross-card duplicates, spending velocity, merchant mismatches, and amount anomalies. All actions are logged.")
                            .font(.system(size: 10)).foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 16).padding(.top, 14)
                }
                .background(Color.bgBase)
            }
        }
        .navigationBarTitle(Text("Smart Alerts"), displayMode: .inline)
        .onAppear { appState.loadSmartAlerts() }
        .sheet(item: $resolveTarget) { alert in
            ResolveAlertSheet(alert: alert) { note in
                appState.resolveSmartAlert(alert.id ?? "", note: note)
            }
            .environmentObject(appState)
        }
    }

    // MARK: - Filter bar (matches AllTransactionsPage / ClaimsListView dropdown pattern)
    private var filterBar: some View {
        HStack(spacing: 8) {
            Button(action: { showFilterSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                    Text(activeFilter.label)
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.bgSurface).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }
            .buttonStyle(BorderlessButtonStyle())
            .selectionActionSheet(
                title: "Filter Alerts",
                isPresented: $showFilterSheet,
                options: AlertFilter.allCases,
                isSelected: { $0 == activeFilter },
                label: { $0.label },
                onSelect: { activeFilter = $0 }
            )
            Spacer()
        }
    }

    // MARK: - Recently Resolved card
    private var recentlyResolvedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundColor(teal)
                Text("Recently Resolved (\(resolvedCount))")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.primary)
                Spacer()
            }.padding(14)
            Divider()
            ForEach(Array(resolvedAlerts.prefix(5).enumerated()), id: \.element.id) { idx, a in
                HStack(spacing: 8) {
                    statusBadge("resolved")
                    Text((a.title ?? "").isEmpty ? "Alert" : (a.title ?? ""))
                        .font(.system(size: 11)).foregroundColor(.primary).lineLimit(1)
                    Spacer()
                    if (a.detectedAt ?? 0) > 0 {
                        Text(FormatUtils.formatDateTime(a.detectedAt ?? 0))
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .opacity(0.75)
                if idx < min(resolvedAlerts.count, 5) - 1 { Divider() }
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - User-id replacement
    /// Replaces any known user IDs in free-text with "Full Name (Designation)".
    private func replaceUserIds(in text: String) -> String {
        guard !text.isEmpty else { return text }
        var out = text
        for (id, user) in UsersData.byId {
            guard !id.isEmpty, out.contains(id) else { continue }
            let desg = FormatUtils.formatLabel(user.designationName ?? "").trimmingCharacters(in: .whitespaces)
            let name = user.fullName ?? ""
            let label = desg.isEmpty ? name : "\(name) (\(desg))"
            out = out.replacingOccurrences(of: id, with: label)
        }
        return out
    }

    // MARK: - Alert card
    private func isTopUpAlert(_ alert: SmartAlert) -> Bool {
        let s = (alert.status ?? "").lowercased()
        let t = (alert.type ?? "").lowercased()
        return s.contains("top_up") || s.contains("topup") || s.contains("top-up")
            || t.contains("top_up") || t.contains("topup") || t.contains("top-up")
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:tag:selection:label:)")
    private func alertCard(_ alert: SmartAlert) -> some View {
        let lowerStatus = (alert.status ?? "").lowercased()
        let isActive = lowerStatus == "active" || lowerStatus == "under_investigation" || lowerStatus == "investigating"
        let isInvestigating = lowerStatus == "under_investigation" || lowerStatus == "investigating"
        let isPendingTopUp = isTopUpAlert(alert)
        let severityColor: Color = {
            if isPendingTopUp { return purple }
            switch (alert.priority ?? "").lowercased() {
            case "high":   return pink
            case "medium": return amber
            case "low":    return purple
            default:       return Color(red: 0.4, green: 0.5, blue: 0.9)
            }
        }()
        let titleColor: Color = {
            if isPendingTopUp { return purple }
            switch (alert.priority ?? "").lowercased() {
            case "high":   return pink
            case "medium": return amber
            case "low":    return purple
            default:       return pink
            }
        }()
        let iconName: String = {
            if isPendingTopUp { return "arrow.up.circle.fill" }
            switch (alert.priority ?? "").lowercased() {
            case "high":   return "exclamationmark.circle.fill"
            case "medium": return "exclamationmark.triangle.fill"
            default:       return "info.circle.fill"
            }
        }()

        return VStack(alignment: .leading, spacing: 0) {

                // ── Header ──
                VStack(alignment: .leading, spacing: 6) {
                    // Title row — colour driven by severity
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: iconName)
                            .font(.system(size: 13)).foregroundColor(titleColor)
                        Text((alert.title ?? "").isEmpty ? "Alert" : (alert.title ?? ""))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(titleColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Badges + savings + detected time on same row
                    HStack(spacing: 6) {
                        priorityBadge(alert.priority ?? "")
                        statusBadge(alert.status ?? "")
                        if (alert.savings ?? 0) > 0 {
                            Text("\(FormatUtils.formatGBP(alert.savings ?? 0)) savings")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(teal)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(teal.opacity(0.12)).cornerRadius(4)
                        }
                        Spacer()
                        if (alert.detectedAt ?? 0) > 0 {
                            Text(FormatUtils.formatDateTime(alert.detectedAt ?? 0))
                                .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                        }
                    }
                }
                .padding(.leading, 16).padding(.trailing, 12).padding(.top, 12).padding(.bottom, 8)

                Divider()

                // ── Description ──
                if !(alert.alertDescription ?? "").isEmpty {
                    Text(replaceUserIds(in: alert.alertDescription ?? ""))
                        .font(.system(size: 12)).foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 16).padding(.trailing, 12).padding(.top, 8).padding(.bottom, 6)
                }

                // ── Resolution note (for resolved alerts) ──
                if lowerStatus == "resolved" && !(alert.resolution ?? "").isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RESOLUTION")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(teal).tracking(0.5)
                        Text(alert.resolution ?? "")
                            .font(.system(size: 11)).foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(teal.opacity(0.08))
                    .overlay(Rectangle().fill(teal).frame(width: 2), alignment: .leading)
                    .cornerRadius(4)
                    .padding(.leading, 16).padding(.trailing, 12).padding(.bottom, 8)
                }

                // ── Details strip (type · cardholder · department) ──
                HStack(spacing: 0) {
                    if !alert.typeDisplay.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 9)).foregroundColor(.goldDark)
                            Text(alert.typeDisplay)
                                .font(.system(size: 10, weight: .semibold)).foregroundColor(.goldDark)
                        }
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.gold.opacity(0.12)).cornerRadius(4)
                    }
                    if !(alert.holderName ?? "").isEmpty {
                        Text("  ·  ").font(.system(size: 10)).foregroundColor(.secondary)
                        Image(systemName: "person.fill")
                            .font(.system(size: 9)).foregroundColor(.secondary)
                        Text(" \(alert.holderName ?? "")")
                            .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                    }
                    if !(alert.department ?? "").isEmpty {
                        Text("  ·  ").font(.system(size: 10)).foregroundColor(.secondary)
                        Text(alert.department ?? "")
                            .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 16).padding(.trailing, 12).padding(.bottom, 8)

                // ── Transaction preview card ──
                if alert.hasTransactionData {
                    VStack(alignment: .leading, spacing: 4) {
                        // Label line
                        if !alert.transactionLabel.isEmpty {
                            Text(alert.transactionLabel)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        // Meta line: ••••7733 · Sophie Turner (Catering Manager) · £285.70
                        HStack(spacing: 4) {
                            Text(alert.holderDisplay)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            if alert.effectiveAmount > 0 {
                                Text("·")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(FormatUtils.formatGBP(alert.effectiveAmount))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(severityColor)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(6)
                    .padding(.leading, 16).padding(.trailing, 12).padding(.bottom, 10)
                }

                // ── Action buttons ──
                if isActive {
                    HStack(spacing: 0) {
                        NavigationLink(
                            destination: SmartAlertDetailPage(alert: alert).environmentObject(appState),
                            tag: alert.id ?? "",
                            selection: $navigateToAlertId
                        ) { EmptyView() }.frame(width: 0, height: 0).hidden()

                        if isInvestigating {
                            // Under Investigation — tap to revert back to active
                            Button(action: { appState.revertSmartAlert(alert.id ?? "") }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye.fill").font(.system(size: 11, weight: .medium))
                                    Text("Under Investigation").font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.orange).cornerRadius(6)
                            }.buttonStyle(BorderlessButtonStyle())
                        } else {
                            // Active state — show Investigate, Resolve, Dismiss
                            Button(action: { appState.investigateSmartAlert(alert.id ?? "") }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .medium))
                                    Text("Investigate").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.bgSurface)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }.buttonStyle(BorderlessButtonStyle())

                            Spacer().frame(width: 8)

                            Button(action: { resolveTarget = alert }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 11, weight: .medium))
                                    Text("Resolve").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(teal).cornerRadius(6)
                            }.buttonStyle(BorderlessButtonStyle())

                            Spacer().frame(width: 12)

                            Button(action: { appState.dismissSmartAlert(alert.id ?? "") }) {
                                Text("Dismiss")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }.buttonStyle(BorderlessButtonStyle())
                        }

                        Spacer()
                    }
                    .padding(.leading, 16).padding(.trailing, 12).padding(.bottom, 12)
                } else {
                    Spacer().frame(height: 4)
                }
        }
        .background(
            HStack(spacing: 0) {
                Rectangle().fill(severityColor).frame(width: 4)
                Spacer()
            }
        )
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(severityColor.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Badges
    private func priorityBadge(_ p: String) -> some View {
        let (fg, bg): (Color, Color) = {
            switch p.lowercased() {
            case "high":   return (pink, pink.opacity(0.12))
            case "medium": return (amber, amber.opacity(0.12))
            case "low":    return (purple, purple.opacity(0.12))
            default:       return (.goldDark, Color.gold.opacity(0.15))
            }
        }()
        // React reference labels: "High Priority" / "Medium" / "Info"
        let label: String = {
            switch p.lowercased() {
            case "high":   return "High Priority"
            case "medium": return "Medium"
            case "low":    return "Info"
            default:       return p.isEmpty ? "Info" : p.capitalized
            }
        }()
        return Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 3).background(bg).cornerRadius(4)
    }

    private func statusBadge(_ s: String) -> some View {
        let lower = s.lowercased()
        let isTopUp = lower.contains("top_up") || lower.contains("topup") || lower.contains("top-up")
        let (label, fg, bg): (String, Color, Color) = {
            if isTopUp { return ("Pending Top-Up", purple, purple.opacity(0.12)) }
            switch lower {
            case "active":
                return ("Active", pink, pink.opacity(0.12))
            case "investigating", "under_investigation":
                return ("Investigating", amber, amber.opacity(0.12))
            case "resolved":
                return ("Resolved", teal, teal.opacity(0.12))
            case "dismissed":
                return ("Dismissed", .gray, Color.gray.opacity(0.15))
            case "auto_closed", "auto-closed", "autoclosed":
                return ("Auto-closed", .gray, Color.gray.opacity(0.15))
            default:
                return (s.isEmpty ? "Unknown" : s.capitalized, .goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 6).padding(.vertical, 3).background(bg).cornerRadius(4)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Resolve Alert Sheet (modal with note textarea)
// ═══════════════════════════════════════════════════════════════════

private struct ResolveAlertSheet: View {
    let alert: SmartAlert
    let onConfirm: (String) -> Void

    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var note: String = ""

    private let teal = Color(red: 0.0, green: 0.6, blue: 0.5)

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Context card
                VStack(alignment: .leading, spacing: 6) {
                    Text((alert.title ?? "").isEmpty ? "Alert" : (alert.title ?? ""))
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                    if !(alert.alertDescription ?? "").isEmpty {
                        Text(alert.alertDescription ?? "")
                            .font(.system(size: 11)).foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)

                // Note textarea
                VStack(alignment: .leading, spacing: 6) {
                    Text("RESOLUTION NOTE")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.gray).tracking(0.5)

                    if #available(iOS 14.0, *) {
                        TextEditor(text: $note)
                            .font(.system(size: 13))
                            .frame(minHeight: 120)
                            .padding(6)
                            .background(Color.bgSurface).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    } else {
                        // iOS 13 fallback
                        TextField("Describe how this alert was resolved…", text: $note)
                            .font(.system(size: 13))
                            .padding(10)
                            .background(Color.bgSurface).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }
                }

                Spacer()

                // Confirm button
                Button(action: {
                    onConfirm(note)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                        Text("Confirm Resolution").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(teal).cornerRadius(8)
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(16)
            .background(Color.bgBase.edgesIgnoringSafeArea(.all))
            .navigationBarTitle(Text("Resolve Alert"), displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark)
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Smart Alert Detail Page
// ═══════════════════════════════════════════════════════════════════

struct SmartAlertDetailPage: View {
    let alert: SmartAlert
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    private var live: SmartAlert {
        appState.smartAlerts.first(where: { $0.id == alert.id }) ?? alert
    }

    private var isResolved: Bool { (live.status ?? "").lowercased() == "resolved" }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Summary card
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Alert Details").font(.system(size: 15, weight: .bold))
                        Spacer()
                        priorityBadge(live.priority ?? "")
                        statusBadge(live.status ?? "")
                    }
                    .padding(14)

                    Divider()

                    // Title + description
                    VStack(alignment: .leading, spacing: 8) {
                        let s = (live.status ?? "").lowercased(); let t = (live.type ?? "").lowercased()
                        let isPendingTopUp = s.contains("top_up") || s.contains("topup") || s.contains("top-up")
                            || t.contains("top_up") || t.contains("topup") || t.contains("top-up")
                        let detailHeaderColor: Color = isPendingTopUp ? .purple : Color(red: 0.91, green: 0.29, blue: 0.48)
                        let detailIconName = isPendingTopUp ? "arrow.up.circle.fill" : "exclamationmark.circle.fill"
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: detailIconName).font(.system(size: 16))
                                .foregroundColor(detailHeaderColor)
                            Text((live.title ?? "").isEmpty ? "Alert" : (live.title ?? ""))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(detailHeaderColor)
                        }
                        if !(live.alertDescription ?? "").isEmpty {
                            Text(live.alertDescription ?? "")
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)

                    Divider()

                    // Details grid
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "TYPE", value: live.typeDisplay)
                            infoCell(label: "AMOUNT",
                                     value: (live.amount ?? 0) > 0 ? FormatUtils.formatGBP(live.amount ?? 0) : "—",
                                     valueColor: .goldDark, mono: true)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "CARD",
                                     value: (live.cardLastFour ?? "").isEmpty ? "—" : "•••• \(live.cardLastFour ?? "")",
                                     mono: true)
                            infoCell(label: "BS CONTROL CODE",
                                     value: (live.bsControlCode ?? "").isEmpty ? "—" : (live.bsControlCode ?? ""),
                                     mono: true)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            infoCell(label: "CARDHOLDER",
                                     value: (live.holderName ?? "").isEmpty ? "—" : (live.holderName ?? ""))
                            infoCell(label: "DEPARTMENT",
                                     value: (live.department ?? "").isEmpty ? "—" : (live.department ?? ""))
                        }
                        if (live.detectedAt ?? 0) > 0 || (live.resolvedAt ?? 0) > 0 {
                            HStack(alignment: .top, spacing: 12) {
                                infoCell(label: "DETECTED",
                                         value: (live.detectedAt ?? 0) > 0 ? FormatUtils.formatTimestamp(live.detectedAt ?? 0) : "—")
                                infoCell(label: "RESOLVED",
                                         value: (live.resolvedAt ?? 0) > 0 ? FormatUtils.formatTimestamp(live.resolvedAt ?? 0) : "—")
                            }
                        }
                        if (live.savings ?? 0) > 0 {
                            HStack(alignment: .top, spacing: 12) {
                                infoCell(label: "SAVINGS",
                                         value: FormatUtils.formatGBP(live.savings ?? 0),
                                         valueColor: Color(red: 0.0, green: 0.6, blue: 0.5), mono: true)
                                Spacer()
                            }
                        }
                    }
                    .padding(14)
                }
                .background(Color.bgSurface).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.91, green: 0.29, blue: 0.48).opacity(0.3), lineWidth: 1.5))

                // Actions
                if !isResolved {
                    HStack(spacing: 10) {
                        Button(action: {
                            appState.resolveSmartAlert(live.id ?? "")
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 12))
                                Text("Resolve").font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.0, green: 0.6, blue: 0.5)).cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                        Button(action: {
                            appState.dismissSmartAlert(live.id ?? "")
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Dismiss").font(.system(size: 13, weight: .bold)).foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                                .cornerRadius(8)
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Alert Details"), displayMode: .inline)
    }

    private func infoCell(label: String, value: String, valueColor: Color = .primary, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
            Text(value)
                .font(mono ? .system(size: 14, weight: .bold, design: .monospaced) : .system(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func priorityBadge(_ p: String) -> some View {
        let pink = Color(red: 0.91, green: 0.29, blue: 0.48)
        let (fg, bg): (Color, Color) = {
            switch p.lowercased() {
            case "high":   return (pink, pink.opacity(0.12))
            case "medium": return (Color(red: 0.95, green: 0.55, blue: 0.15), Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.12))
            case "low":    return (.gray, Color.gray.opacity(0.15))
            default:       return (.goldDark, Color.gold.opacity(0.15))
            }
        }()
        let label: String = {
            switch p.lowercased() {
            case "high":   return "High"
            case "medium": return "Medium"
            case "low":    return "Low"
            default:       return p.capitalized
            }
        }()
        return Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
    }

    private func statusBadge(_ s: String) -> some View {
        let pink = Color(red: 0.91, green: 0.29, blue: 0.48)
        let lower = s.lowercased()
        let isTopUp = lower.contains("top_up") || lower.contains("topup") || lower.contains("top-up")
        let (label, fg, bg): (String, Color, Color) = {
            if isTopUp { return ("Pending Top-Up", Color.purple, Color.purple.opacity(0.12)) }
            switch lower {
            case "active":
                return ("Active", pink, pink.opacity(0.12))
            case "investigating":
                return ("Under Investigation", .orange, Color.orange.opacity(0.12))
            case "resolved":
                return ("Resolved", Color(red: 0.0, green: 0.6, blue: 0.5), Color(red: 0.0, green: 0.6, blue: 0.5).opacity(0.12))
            case "dismissed":
                return ("Dismissed", Color.gray, Color.gray.opacity(0.15))
            default:
                return (s.capitalized, .goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(fg)
            .padding(.horizontal, 8).padding(.vertical, 3).background(bg).cornerRadius(4)
    }
}
