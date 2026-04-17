import SwiftUI

struct FloatRequestListView: View {
    @EnvironmentObject var appState: POViewModel

    private var floats: [FloatRequest] {
        appState.myFloats.sorted { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if appState.isLoadingMyFloats && appState.myFloats.isEmpty {
                    LoaderView()
                } else if floats.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "banknote").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No float requests yet").font(.system(size: 13)).foregroundColor(.secondary)
                        Text("Tap + New Float to submit your first request.").font(.system(size: 11)).foregroundColor(.gray)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: 480)
                } else {
                    ForEach(floats) { f in
                        NavigationLink(destination: FloatDetailView(float: f).environmentObject(appState)) {
                            FloatRequestRow(float: f).padding(.horizontal, 16)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }.padding(.top, 12).padding(.bottom, 100)
        }
        .background(Color.bgBase)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Claim Detail Page (Receipt Details)
// ═══════════════════════════════════════════════════════════════════

struct FloatRequestRow: View {
    let float: FloatRequest

    /// Delegates to the shared file-scope helper so the status badge colors on
    /// the list match exactly what's shown on the detail page / approval queue.
    private var statusColors: (Color, Color) {
        floatStatusColors(float.status ?? "")
    }

    private var durationLabel: String {
        let d = (float.duration ?? "").lowercased()
        if d == "run_of_show" { return "Run of Show" }
        if d.isEmpty { return "" }
        if let n = Int(d) { return "\(n) day\(n == 1 ? "" : "s")" }
        return float.duration ?? ""
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("#\(float.reqNumber ?? "")").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    let (fg, bg) = statusColors
                    Text(float.statusDisplay.uppercased())
                        .font(.system(size: 8, weight: .bold)).foregroundColor(fg)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(bg).cornerRadius(3)
                }
                Text("Submitted \(FormatUtils.formatTimestamp(float.createdAt ?? 0))")
                    .font(.system(size: 10)).foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(FormatUtils.formatGBP(float.reqAmount ?? 0))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                if !durationLabel.isEmpty {
                    Text(durationLabel).font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.gray)
        }
        .padding(14)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

struct FloatDetailsCard: View {
    let float: FloatRequest

    private var statusColors: (Color, Color) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        switch (float.status ?? "").uppercased() {
        case "AWAITING_APPROVAL":   return (.orange, Color.orange.opacity(0.15))
        case "APPROVED",
             "ACCT_OVERRIDE":       return (.green, Color.green.opacity(0.12))
        case "READY_TO_COLLECT":    return (.blue, Color.blue.opacity(0.12))
        case "COLLECTED":           return (teal, teal.opacity(0.12))
        case "ACTIVE",
             "SPENDING":            return (.goldDark, Color.gold.opacity(0.15))
        case "SPENT":               return (.purple, Color.purple.opacity(0.12))
        case "PENDING_RETURN":      return (.orange, Color.orange.opacity(0.15))
        case "CLOSED":              return (.gray, Color.gray.opacity(0.15))
        case "REJECTED",
             "CANCELLED":           return (.red, Color.red.opacity(0.12))
        default: return (.goldDark, Color.gold.opacity(0.15))
        }
    }

    private var footer: (String, Color, String) {
        let teal = Color(red: 0.0, green: 0.6, blue: 0.5)
        switch (float.status ?? "").uppercased() {
        case "AWAITING_APPROVAL":
            return ("Float request submitted — awaiting approval", .orange, "clock.fill")
        case "APPROVED":
            return ("Float approved — awaiting cash preparation", .green, "checkmark.circle.fill")
        case "ACCT_OVERRIDE":
            return ("Override approved — awaiting cash preparation", .green, "bolt.fill")
        case "READY_TO_COLLECT":
            return ("Cash ready — collect from the accountant", .blue, "banknote.fill")
        case "COLLECTED":
            return ("Cash collected — ready to spend", teal, "checkmark.seal.fill")
        case "ACTIVE":
            return ("Float active — submit receipts against this float", .goldDark, "creditcard.fill")
        case "SPENDING":
            return ("Spending in progress — submit receipts as you go", .goldDark, "cart.fill")
        case "SPENT":
            return ("All cash spent — submit final receipts to close", .purple, "doc.text.fill")
        case "PENDING_RETURN":
            return ("Awaiting physical cash return to accountant", .orange, "arrow.uturn.backward.circle.fill")
        case "CLOSED":
            return ("Float closed", .gray, "checkmark.seal.fill")
        case "CANCELLED":
            return ("Float cancelled", .red, "xmark.circle.fill")
        case "REJECTED":
            return ("Float rejected — see notes below", .red, "xmark.circle.fill")
        default:
            return (float.statusDisplay, .secondary, "info.circle.fill")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Float Details").font(.system(size: 14, weight: .bold))
                Spacer()
                let (fg, bg) = statusColors
                Text(float.statusDisplay.uppercased())
                    .font(.system(size: 9, weight: .bold)).foregroundColor(fg)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(bg).cornerRadius(4)
            }
            .padding(14)

            Divider()

            // Two-column grid of details
            VStack(spacing: 14) {
                detailRow(leftLabel: "REF.", leftValue: "#\(float.reqNumber ?? "")",
                          rightLabel: "SUBMITTED ON", rightValue: FormatUtils.formatTimestamp(float.createdAt ?? 0),
                          leftMono: true)
                detailRow(leftLabel: "USER", leftValue: UsersData.byId[float.userId ?? ""]?.fullName ?? "—",
                          rightLabel: "DEPARTMENT", rightValue: (float.department ?? "").isEmpty ? "—" : float.department!)
                detailRow(leftLabel: "REQUESTED AMOUNT", leftValue: FormatUtils.formatGBP(float.reqAmount ?? 0),
                          rightLabel: "DURATION", rightValue: (float.duration ?? "").isEmpty ? "—" : "\(float.duration!) days",
                          leftMono: true)
                detailRow(leftLabel: "COST CODE", leftValue: costCodeDisplay(float.costCode ?? ""),
                          rightLabel: "START DATE", rightValue: (float.startDate ?? 0) > 0 ? FormatUtils.formatTimestamp(float.startDate!) : "—")
                if !(float.collectionMethod ?? "").isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PREFERRED COLLECTION METHOD").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Text(collectionDisplay(float.collectionMethod ?? "")).font(.system(size: 13))
                        }
                        Spacer()
                    }
                }
                if !(float.purpose ?? "").isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PURPOSE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Text(float.purpose ?? "").font(.system(size: 13))
                        }
                        Spacer()
                    }
                }
            }
            .padding(14)

            Divider()

            // Footer status line
            let (text, color, icon) = footer
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
                Text(text).font(.system(size: 12, weight: .semibold)).foregroundColor(color)
            }.padding(14)

            // Rejection reason if present
            if let reason = float.rejectionReason, !reason.isEmpty {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundColor(.red)
                    Text(reason).font(.system(size: 11)).foregroundColor(.red)
                    Spacer()
                }.padding(14).background(Color.red.opacity(0.06))
            }
        }
        .background(Color.bgSurface).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
    }

    private func detailRow(leftLabel: String, leftValue: String, rightLabel: String, rightValue: String, leftMono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(leftLabel).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                Text(leftValue).font(leftMono ? .system(size: 14, weight: .bold, design: .monospaced) : .system(size: 13))
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(rightLabel).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                Text(rightValue).font(.system(size: 13))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func costCodeDisplay(_ code: String?) -> String {
        let code = code ?? ""
        if code.isEmpty { return "—" }
        if let match = costCodeOptions.first(where: { $0.0 == code }) { return match.1 }
        return code.uppercased()
    }

    private func collectionDisplay(_ method: String) -> String {
        if let match = collectionOptions.first(where: { $0.0 == method }) { return match.1 }
        return method.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

let claimCategories = [
    ("materials", "Materials"), ("equipment", "Props / Equipment"),
    ("stationery", "Consumables / Stationery"), ("catering", "Catering"),
    ("fuel", "Fuel"), ("parking", "Parking"), ("taxi", "Taxi / Travel"),
    ("accommodation", "Accommodation"), ("other", "Other"),
]
