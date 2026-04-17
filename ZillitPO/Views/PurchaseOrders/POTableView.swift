import SwiftUI

struct POTableView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var selectedPO: PurchaseOrder?
    @State private var navigateToDetail = false

    var body: some View {
        ZStack {
            if appState.filteredPOs.isEmpty {
                VStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                    Text("No purchase orders found").font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, minHeight: 480)
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.filteredPOs, id: \.id) { po in
                        Button(action: { selectedPO = po; navigateToDetail = true }) {
                            PORow(po: po)
                        }.buttonStyle(BorderlessButtonStyle())
                        Divider().padding(.horizontal, 12)
                    }
                }.background(Color.bgSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            }

            // Hidden NavigationLink to push PO detail page
            NavigationLink(
                destination: Group {
                    if let po = selectedPO {
                        PODetailPage(po: po).environmentObject(appState)
                    } else {
                        EmptyView()
                    }
                },
                isActive: $navigateToDetail
            ) { EmptyView() }
            .hidden()
        }
        .onReceive(appState.$popToRoot) { pop in
            if pop {
                navigateToDetail = false
                appState.popToRoot = false
            }
        }
    }
}

struct PORow: View {
    let po: PurchaseOrder
    @EnvironmentObject var appState: POViewModel
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(po.poNumber ?? "").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(.goldDark)
                Text((po.vendor ?? "").isEmpty ? "—" : po.vendor ?? "").font(.system(size: 13, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                if !(po.description ?? "").isEmpty { Text(po.description ?? "").font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(FormatUtils.formatCurrency((po.lineItems ?? []).isEmpty
                    ? VATHelpers.calcVat(po.totalAmount, treatment: po.vatTreatment ?? "pending").gross
                    : (po.lineItems ?? []).reduce(0.0) { $0 + VATHelpers.calcVat(($1.quantity ?? 0) * ($1.unitPrice ?? 0), treatment: $1.vatTreatment ?? "pending").gross },
                    code: po.currency ?? "GBP"))
                    .font(.system(size: 13, design: .monospaced))
                statusBadge
            }
        }.padding(12)
        .contentShape(Rectangle())
    }

    private var statusBadge: some View {
        // Resolve tier config: amount-based first, fallback to without amount if nil
        let resolvedConfig = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId, amount: po.totalAmount)
            ?? ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId)
        let totalTiers = ApprovalHelpers.getTotalTiers(resolvedConfig)
        let approvedCount = (po.approvals ?? []).count
        let label: String = {
            if po.poStatus == .rejected { return "Rejected" }
            if po.poStatus == .posted { return "Posted" }
            if po.poStatus == .closed { return "Closed" }
            if po.poStatus == .acctEntered { return "Acct Entered" }
            if po.poStatus == .approved { return "Approved" }
            if po.poStatus == .draft { return "Draft" }
            // pending
            if totalTiers > 0 { return "Pending (\(approvedCount)/\(totalTiers))" }
            return "Pending"
        }()
        let colors: (Color, Color) = {
            if po.poStatus == .rejected { return (.red, Color.red.opacity(0.1)) }
            if po.poStatus == .posted { return (.blue, Color.blue.opacity(0.1)) }
            if po.poStatus == .closed { return (.gray, Color.gray.opacity(0.1)) }
            if po.poStatus == .approved { return (.green, Color.green.opacity(0.1)) }
            if po.poStatus == .draft { return (.orange, Color.orange.opacity(0.1)) }
            return (.goldDark, Color.gold.opacity(0.15)) // pending, acctEntered
        }()
        return Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(colors.0)
            .padding(.horizontal, 8).padding(.vertical, 3).background(colors.1).cornerRadius(4)
    }
}
