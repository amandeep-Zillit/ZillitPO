import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Coding Queue Page (coordinator)
// ═══════════════════════════════════════════════════════════════════

struct CardCodingQueuePage: View {
    @EnvironmentObject var appState: POViewModel

    private var items: [PendingCodingItem] {
        let all = appState.pendingCodingItems
        let allowedDeptIds: Set<String> = Set(appState.cardExpenseMeta.coordinatorDeptIds ?? [])
        guard !allowedDeptIds.isEmpty else { return all }
        return all.filter { item in
            if let deptId = item.departmentId, allowedDeptIds.contains(deptId) { return true }
            if let user = UsersData.byId[item.userId ?? ""], allowedDeptIds.contains(user.departmentId ?? "") { return true }
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if appState.isLoadingPendingCoding && appState.pendingCodingItems.isEmpty {
                    LoaderView()
                } else if items.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "doc.text.magnifyingglass").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("Nothing in the coding queue").font(.system(size: 13)).foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: 480)
                } else {
                    ForEach(items) { item in
                        NavigationLink(destination: PendingCodingDetailPage(item: item).environmentObject(appState)) {
                            codingRow(item)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .onAppear { appState.loadPendingCoding() }   // GET /card-expenses/receipts/pending-coding
    }

    private func codingRow(_ item: PendingCodingItem) -> some View {
        let dateText = (item.date ?? 0) > 0
            ? FormatUtils.formatTimestamp(item.date ?? 0)
            : ((item.createdAt ?? 0) > 0 ? FormatUtils.formatTimestamp(item.createdAt ?? 0) : "—")
        let user = UsersData.byId[item.userId ?? ""]
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text((item.description ?? "").isEmpty ? "—" : (item.description ?? ""))
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary).lineLimit(2)
                HStack(spacing: 6) {
                    Text(user?.fullName ?? item.userName)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    if !item.userDepartment.isEmpty {
                        Text("· \(item.userDepartment)")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                Text(dateText).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(FormatUtils.formatGBP(item.amount ?? 0))
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                Text(item.statusDisplay)
                    .font(.system(size: 9, weight: .semibold)).foregroundColor(.orange)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12)).cornerRadius(4)
                if item.isUrgent ?? false {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10)).foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}
