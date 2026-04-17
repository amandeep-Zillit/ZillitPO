import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Pending Coding Page (grouped by cardholder)
// ═══════════════════════════════════════════════════════════════════

struct PendingCodingPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var expandedHolders: Set<String> = []

    private var items: [PendingCodingItem] { appState.pendingCodingItems }

    private var groupedByHolder: [(userId: String, userName: String, department: String, items: [PendingCodingItem])] {
        let groups = Dictionary(grouping: items, by: { $0.userId ?? "" })
        return groups.map { (userId, items) in
            let first = items.first
            return (
                userId: userId,
                userName: first?.userName ?? userId,
                department: first?.userDepartment ?? "",
                items: items.sorted { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }
            )
        }.sorted { $0.userName < $1.userName }
    }

    var body: some View {
        Group {
            if appState.isLoadingPendingCoding && items.isEmpty {
                VStack { Spacer(); LoaderView(); Spacer() }
                    .background(Color.bgBase)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if items.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("Nothing awaiting coding").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
                        } else {
                            ForEach(groupedByHolder, id: \.userId) { group in
                                holderSection(group)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
                }
                .background(Color.bgBase)
            }
        }
        .navigationBarTitle(Text("Pending Coding"), displayMode: .inline)
        .onAppear {
            appState.loadPendingCoding()
            if expandedHolders.isEmpty, let first = groupedByHolder.first {
                expandedHolders.insert(first.userId)
            }
        }
    }

    @ViewBuilder
    private func holderSection(_ group: (userId: String, userName: String, department: String, items: [PendingCodingItem])) -> some View {
        let isExpanded = expandedHolders.contains(group.userId)
        let total = group.items.reduce(0) { $0 + ($1.amount ?? 0) }
        let initials = group.userName.split(separator: " ").compactMap { $0.first.map(String.init) }.prefix(2).joined()
        VStack(spacing: 0) {
            Button(action: {
                if isExpanded { expandedHolders.remove(group.userId) } else { expandedHolders.insert(group.userId) }
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color(red: 0.91, green: 0.29, blue: 0.48)).frame(width: 28, height: 28)
                        Text(initials.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(group.userName).font(.system(size: 13, weight: .bold))
                            if !group.department.isEmpty {
                                Text("— \(group.department)").font(.system(size: 11)).foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    Text("\(group.items.count) pending")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.12)).cornerRadius(4)
                    Text(FormatUtils.formatGBP(total))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                }
                .padding(12).contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())

            if isExpanded {
                Divider()
                ForEach(group.items) { item in
                    NavigationLink(destination: PendingCodingDetailPage(item: item).environmentObject(appState)) {
                        pendingRow(item)
                    }.buttonStyle(PlainButtonStyle())
                    Divider().padding(.leading, 14)
                }
            }
        }
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func pendingRow(_ item: PendingCodingItem) -> some View {
        let dateText = (item.date ?? 0) > 0 ? FormatUtils.formatTimestamp(item.date ?? 0) : ((item.createdAt ?? 0) > 0 ? FormatUtils.formatTimestamp(item.createdAt ?? 0) : "—")
        let user = UsersData.byId[item.userId ?? ""]
        let ageDays: Int = {
            let ref = (item.createdAt ?? 0) > 0 ? (item.createdAt ?? 0) : (item.date ?? 0)
            guard ref > 0 else { return 0 }
            let secs = (Date().timeIntervalSince1970 * 1000 - Double(ref)) / 1000
            return max(0, Int(secs / 86400))
        }()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text((item.description ?? "").isEmpty ? "—" : (item.description ?? ""))
                        .font(.system(size: 13, weight: .semibold)).lineLimit(2)
                    Text(dateText).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(FormatUtils.formatGBP(item.amount ?? 0))
                        .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    pendingStatusBadge(item.status ?? "")
                }
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(user?.fullName ?? item.userName)
                        .font(.system(size: 11, weight: .semibold))
                    if let d = user?.displayDesignation, !d.isEmpty {
                        Text(d).font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if !(item.processingFlags ?? []).isEmpty {
                    Image(systemName: "flag.fill").font(.system(size: 9)).foregroundColor(.orange)
                }
                if item.isUrgent ?? false {
                    Image(systemName: "exclamationmark.circle.fill").font(.system(size: 9)).foregroundColor(.red)
                }
                Text("\(ageDays)d").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func pendingStatusBadge(_ status: String) -> some View {
        let (label, color): (String, Color) = {
            switch status.lowercased() {
            case "pending_code", "pending_coding", "pending code": return ("Needs Coding", Color(red: 0.05, green: 0.15, blue: 0.42))
            case "pending_receipt": return ("No Receipt", Color.purple)
            default:                return (status.replacingOccurrences(of: "_", with: " ").capitalized, Color.gray)
            }
        }()
        return Text(label)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12)).cornerRadius(3)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Pending Coding Detail Page
// ═══════════════════════════════════════════════════════════════════

struct PendingCodingDetailPage: View {
    let item: PendingCodingItem
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    private var live: PendingCodingItem {
        appState.pendingCodingItems.first(where: { $0.id == item.id }) ?? item
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text((live.description ?? "").isEmpty ? "—" : (live.description ?? ""))
                                .font(.system(size: 17, weight: .bold)).lineLimit(3)
                            HStack(spacing: 6) {
                                Text(live.statusDisplay)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor({
                                        let s = (live.status ?? "").lowercased()
                                        if s == "pending_receipt" { return Color.purple }
                                        if ["pending_code","pending_coding","pending code"].contains(s) { return Color(red: 0.05, green: 0.15, blue: 0.42) }
                                        return Color(red: 0.95, green: 0.55, blue: 0.15)
                                    }())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background({
                                        let s = (live.status ?? "").lowercased()
                                        if s == "pending_receipt" { return Color.purple.opacity(0.12) }
                                        if ["pending_code","pending_coding","pending code"].contains(s) { return Color(red: 0.05, green: 0.15, blue: 0.42).opacity(0.12) }
                                        return Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.12)
                                    }())
                                    .cornerRadius(4)
                                if live.isUrgent ?? false {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 10))
                                        Text("Urgent").font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.red.opacity(0.1)).cornerRadius(4)
                                }
                            }
                        }
                        Spacer()
                        Text(FormatUtils.formatGBP(live.amount ?? 0))
                            .font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                    }
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill").font(.system(size: 11)).foregroundColor(.secondary)
                        Text(live.userName).font(.system(size: 12, weight: .semibold))
                        if !live.userDepartment.isEmpty {
                            Text("· \(live.userDepartment)").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(14).background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // Processing flags
                if !(live.processingFlags ?? []).isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("PROCESSING FLAGS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                        ForEach(Array((live.processingFlags ?? []).enumerated()), id: \.offset) { idx, flag in
                            let flagColor: Color = {
                                switch flag.flag?.lowercased() {
                                case "review": return .purple
                                case "query":  return .orange
                                case "deduct": return .red
                                default:       return .gray
                                }
                            }()
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "flag.fill").font(.system(size: 12)).foregroundColor(flagColor)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(flag.title ?? "Flag").font(.system(size: 13, weight: .semibold))
                                    if let desc = flag.description, !desc.isEmpty {
                                        Text(desc).font(.system(size: 11)).foregroundColor(.secondary)
                                    }
                                    HStack(spacing: 6) {
                                        if let pt = flag.processType {
                                            Text(pt.replacingOccurrences(of: "_", with: " ").capitalized)
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(flagColor)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(flagColor.opacity(0.1)).cornerRadius(3)
                                        }
                                        if let tv = flag.thresholdValue, let tt = flag.thresholdType {
                                            let label = tt == "percentage" ? "\(Int(tv))%" : FormatUtils.formatGBP(tv)
                                            Text("Threshold: \(label)")
                                                .font(.system(size: 9)).foregroundColor(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            if idx < (live.processingFlags ?? []).count - 1 { Divider().padding(.leading, 44) }
                        }
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                }

                // Details
                VStack(spacing: 0) {
                    detailRow("Date", (live.date ?? 0) > 0 ? FormatUtils.formatTimestamp(live.date ?? 0) : "—")
                    Divider().padding(.leading, 14)
                    detailRow("Status", live.statusDisplay)
                    if let code = live.nominalCode, !code.isEmpty {
                        Divider().padding(.leading, 14)
                        detailRow("Nominal Code", code)
                    }
                    if let ep = live.episode, !ep.isEmpty {
                        Divider().padding(.leading, 14)
                        detailRow("Episode", ep)
                    }
                    if let cd = live.codeDescription, !cd.isEmpty {
                        Divider().padding(.leading, 14)
                        detailRow("Code Notes", cd)
                    }
                    if let txId = live.transactionId {
                        Divider().padding(.leading, 14)
                        detailRow("Transaction ID", txId)
                    }
                    if !(live.matchStatus ?? "").isEmpty {
                        Divider().padding(.leading, 14)
                        detailRow("Match Status", (live.matchStatus ?? "").replacingOccurrences(of: "_", with: " ").capitalized)
                    }
                    Divider().padding(.leading, 14)
                    detailRow("Submitted", (live.createdAt ?? 0) > 0 ? FormatUtils.formatTimestamp(live.createdAt ?? 0) : "—")
                }
                .background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                // Receipt attachment
                if let att = live.receiptAttachment, let name = att.name, !name.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "paperclip").font(.system(size: 14)).foregroundColor(.goldDark)
                        Text(name).font(.system(size: 13)).lineLimit(1)
                        Spacer()
                        Text("Attached").font(.system(size: 10, weight: .semibold)).foregroundColor(.green)
                    }
                    .padding(14).background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }

                // History
                if !(live.history ?? []).isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("HISTORY").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.6)
                            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
                        ForEach(Array((live.history ?? []).enumerated()), id: \.offset) { _, entry in
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(Color.goldDark).frame(width: 8, height: 8).padding(.top, 4)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.action ?? "").font(.system(size: 12, weight: .semibold))
                                    Text(entry.actionByName).font(.system(size: 10)).foregroundColor(.secondary)
                                    if let ts = entry.actionAt, ts > 0 {
                                        Text(FormatUtils.formatDateTime(ts)).font(.system(size: 9)).foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                            }.padding(.horizontal, 14).padding(.vertical, 6)
                        }
                    }
                    .background(Color.bgSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Coding Detail"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 120, alignment: .leading)
            Text(value).font(.system(size: 12, weight: .medium)).lineLimit(2)
            Spacer()
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }
}
