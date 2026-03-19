import SwiftUI

struct PODetailModalView: View {
    let po: PurchaseOrder
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode

    private var vat: VATResult { VATHelpers.calcVat(po.netAmount, treatment: po.vatTreatment) }
    private var vis: ApprovalVisibility {
        guard let c = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId, amount: po.totalAmount)
        else { return ApprovalVisibility(visible: true, canApprove: false, nextTier: nil, totalTiers: 0, approvedCount: 0, isCreator: false) }
        return ApprovalHelpers.getVisibility(po: po, config: c, userId: appState.userId)
    }
    private var isCreator: Bool { po.userId == appState.userId }
    private var canEdit: Bool { isCreator && ![.approved, .posted, .acctEntered].contains(po.poStatus) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(po.poNumber).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                        Text((po.description ?? "").isEmpty ? "No description" : po.description ?? "").font(.system(size: 17, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        DetailRow(label: "Vendor", value: po.vendor.isEmpty ? "—" : po.vendor)
                        DetailRow(label: "Department", value: po.department.isEmpty ? "—" : po.department)
                        DetailRow(label: "Amount (Gross)", value: FormatUtils.formatGBP(vat.gross))
                        DetailRow(label: "Currency", value: po.currency)
                        DetailRow(label: "Eff. Date", value: FormatUtils.formatTimestamp(po.effectiveDate))
                        DetailRow(label: "VAT", value: VATHelpers.vatLabel(po.vatTreatment))
                        DetailRow(label: "Created By", value: UsersData.byId[po.userId]?.fullName ?? po.userId)
                        DetailRow(label: "Status", value: po.poStatus.displayName)
                    }

                    if !(po.notes ?? "").isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NOTES").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                            Text(po.notes ?? "").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }

                    if po.poStatus == .rejected, let reason = po.rejectionReason, !reason.isEmpty {
                        Text(reason).font(.system(size: 12)).foregroundColor(.red)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.05)).cornerRadius(8)
                    }

                    if !po.lineItems.isEmpty {
                        Text("LINE ITEMS").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        ForEach(po.lineItems, id: \.id) { li in
                            HStack {
                                Text(li.description).font(.system(size: 12)).lineLimit(1)
                                Spacer()
                                Text("×\(Int(li.quantity))").font(.system(size: 11)).foregroundColor(.secondary)
                                Text(FormatUtils.formatGBP(li.total)).font(.system(size: 12, weight: .medium, design: .monospaced))
                            }.padding(.vertical, 4)
                            Divider()
                        }
                        HStack {
                            Spacer()
                            Text("Gross: ").font(.system(size: 14, weight: .semibold))
                            Text(FormatUtils.formatGBP(vat.gross)).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                        }
                    }

                    // Actions
                    if canEdit || vis.canApprove {
                        Divider()
                        HStack(spacing: 12) {
                            if canEdit {
                                Button(action: { presentationMode.wrappedValue.dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { appState.editingPO = po } }) {
                                    HStack { Image(systemName: "pencil"); Text("Edit") }.font(.system(size: 13, weight: .semibold)).foregroundColor(.goldDark)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldDark, lineWidth: 1))
                                }
                                Button(action: { presentationMode.wrappedValue.dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { appState.deleteTarget = po } }) {
                                    HStack { Image(systemName: "trash"); Text("Delete") }.font(.system(size: 13, weight: .semibold)).foregroundColor(.red)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                                }
                            }
                            Spacer()
                            if vis.canApprove {
                                Button(action: { presentationMode.wrappedValue.dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { appState.rejectTarget = po; appState.showRejectSheet = true } }) {
                                    Text("Reject").font(.system(size: 13, weight: .bold)).foregroundColor(.red)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                                }
                                Button(action: { appState.approvePO(po); presentationMode.wrappedValue.dismiss() }) {
                                    Text("Approve").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 8).background(Color.green).cornerRadius(8)
                                }
                            }
                        }
                    }
                }.padding()
            }
            .navigationBarTitle(Text(po.poNumber), displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() })
        }
    }
}

struct DetailRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
            Text(value).font(.system(size: 13))
            Spacer()
        }
    }
}
