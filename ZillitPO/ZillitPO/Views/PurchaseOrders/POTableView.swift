import SwiftUI

struct POTableView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPO: PurchaseOrder?
    @State private var navigateToDetail = false

    var body: some View {
        ZStack {
            if appState.filteredPOs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                    Text("No purchase orders found").font(.system(size: 13)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.white).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.filteredPOs, id: \.id) { po in
                        Button(action: { selectedPO = po; navigateToDetail = true }) {
                            PORow(po: po)
                        }.buttonStyle(BorderlessButtonStyle())
                        Divider().padding(.horizontal, 12)
                    }
                }.background(Color.white).cornerRadius(10)
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
    }
}

struct PORow: View {
    let po: PurchaseOrder
    @EnvironmentObject var appState: AppState
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(po.poNumber).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(.goldDark)
                Text(po.vendor.isEmpty ? "—" : po.vendor).font(.system(size: 13, weight: .medium)).foregroundColor(.black).lineLimit(1)
                if !(po.description ?? "").isEmpty { Text(po.description ?? "").font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(FormatUtils.formatCurrency(VATHelpers.calcVat(po.totalAmount, treatment: po.vatTreatment).gross, code: po.currency))
                    .font(.system(size: 13, design: .monospaced))
                statusBadge
            }
        }.padding(12)
        .contentShape(Rectangle())
    }

    private var statusBadge: some View {
        let cfg = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId, amount: po.totalAmount)
        let total = ApprovalHelpers.getTotalTiers(cfg)
        let label: String = {
            switch po.poStatus {
            case .rejected: return "Rejected"; case .posted: return "Posted"; case .closed: return "Closed"
            case .acctEntered: return "Acct Entered"; case .approved: return "Approved"; case .draft: return "Draft"
            case .pending: return total > 0 ? "Pending (\(po.approvals.count)/\(total))" : "Pending"
            }
        }()
        let colors: (Color, Color) = {
            switch po.poStatus {
            case .rejected: return (.red, Color.red.opacity(0.1))
            case .posted: return (.blue, Color.blue.opacity(0.1))
            case .closed: return (.gray, Color.gray.opacity(0.1))
            case .approved: return (.green, Color.green.opacity(0.1))
            case .pending, .acctEntered: return (.goldDark, Color.gold.opacity(0.15))
            case .draft: return (.orange, Color.orange.opacity(0.1))
            }
        }()
        return Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(colors.0)
            .padding(.horizontal, 8).padding(.vertical, 3).background(colors.1).cornerRadius(4)
    }
}
