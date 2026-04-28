import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Tab 1: Receipts
// ═══════════════════════════════════════════════════════════════════

struct ReceiptsTabView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var searchText = ""
    @State private var activeFilter: ReceiptFilter = .all
    @State private var showFilterSheet = false
    @State private var navigateToDetail = false
    @State private var navigateToUpload = false
    @State private var navigateToAddCode = false
    @State private var selectedReceipt: Receipt?
    @State private var selectedTransaction: CardTransaction?
    @State private var navigateToTxDetail = false
    @State private var navigateToTxEdit = false
    @State private var codingReceipt: Receipt?
    @State private var deleteTarget: Receipt?
    @State private var showDeleteAlert = false

    private func statusMatches(_ t: CardTransaction, _ filter: ReceiptFilter) -> Bool {
        let s = (t.status ?? "").lowercased()
        switch filter {
        case .all: return true
        case .pendingReceipt: return s == "pending" || s == "pending_receipt"
        case .pendingCode: return s == "pending_coding" || s == "pending_code"
        case .awaitingApproval: return s == "awaiting_approval"
        case .approved: return s == "approved" || s == "matched" || s == "coded"
        case .queried: return s == "queried"
        case .underReview: return s == "under_review"
        case .escalated: return s == "escalated"
        case .posted: return s == "posted"
        }
    }

    private func statusOrder(_ s: String) -> Int {
        switch s.lowercased() {
        case "pending", "pending_receipt": return 0
        case "pending_coding", "pending_code": return 1
        case "queried": return 2
        case "escalated": return 3
        case "under_review": return 4
        case "awaiting_approval": return 5
        case "approved", "matched", "coded": return 6
        case "posted": return 7
        default: return 8
        }
    }

    private var filtered: [CardTransaction] {
        var list = appState.myCardReceipts
        if activeFilter != .all { list = list.filter { statusMatches($0, activeFilter) } }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter { ($0.merchant ?? "").lowercased().contains(q) || ($0.description ?? "").lowercased().contains(q) || ($0.holderName ?? "").lowercased().contains(q) }
        }
        return list.sorted { a, b in
            let oa = statusOrder(a.status ?? "")
            let ob = statusOrder(b.status ?? "")
            if oa != ob { return oa < ob }
            let da = (a.transactionDate ?? 0) > 0 ? (a.transactionDate ?? 0) : (a.createdAt ?? 0)
            let db = (b.transactionDate ?? 0) > 0 ? (b.transactionDate ?? 0) : (b.createdAt ?? 0)
            return da > db
        }
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                // Search + Filter in one line
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                        TextField("Search receipts…", text: $searchText).font(.system(size: 14))
                    }
                    .padding(10).background(Color.bgSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                    Button(action: { showFilterSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                            Text(activeFilter.rawValue)
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 10)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .selectionActionSheet(
                        title: "Filter by Status",
                        isPresented: $showFilterSheet,
                        options: ReceiptFilter.allCases,
                        isSelected: { $0 == activeFilter },
                        label: { $0.rawValue },
                        onSelect: { activeFilter = $0 }
                    )
                }
                .padding(.horizontal, 16).padding(.top, 12)

                ScrollView {
                    VStack(spacing: 10) {
                        if appState.isLoadingReceipts && appState.myCardReceipts.isEmpty {
                            LoaderView()
                        } else if filtered.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text("No transactions found").font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
                        } else {
                            ForEach(filtered) { tx in
                                CardTransactionRow(
                                    transaction: tx,
                                    onTap: {
                                        selectedTransaction = tx
                                        navigateToTxDetail = true
                                    },
                                    onUploadTap: {
                                        selectedTransaction = tx
                                        navigateToTxEdit = true
                                    }
                                )
                            }
                        }
                    }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 80)
                }
            }

            // Floating upload button
            Button(action: { navigateToUpload = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Upload Receipt").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.gold).cornerRadius(28)
            }
            .padding(.trailing, 20).padding(.bottom, 24)
        }
        .background(
            Group {
                NavigationLink(destination: Group {
                    if let r = selectedReceipt { ReceiptDetailPage(receipt: r).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToDetail) { EmptyView() }.frame(width: 0, height: 0).hidden()

                NavigationLink(destination: Group {
                    if let tx = selectedTransaction { CardTransactionDetailPage(transaction: tx).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToTxDetail) { EmptyView() }.frame(width: 0, height: 0).hidden()

                NavigationLink(destination: Group {
                    if let tx = selectedTransaction { EditCardTransactionPage(transaction: tx).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToTxEdit) { EmptyView() }.frame(width: 0, height: 0).hidden()

                NavigationLink(destination: UploadReceiptPage().environmentObject(appState), isActive: $navigateToUpload) { EmptyView() }
                    .frame(width: 0, height: 0).hidden()

                NavigationLink(destination: Group {
                    if let r = codingReceipt { AddCodeLineItemsPage(receipt: r).environmentObject(appState) }
                    else { EmptyView() }
                }, isActive: $navigateToAddCode) { EmptyView() }.frame(width: 0, height: 0).hidden()
            }
        )
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Receipt"),
                message: Text("Are you sure you want to delete \"\(deleteTarget?.originalName ?? "this receipt")\"? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let t = deleteTarget { appState.deleteReceipt(t) }
                    deleteTarget = nil
                },
                secondaryButton: .cancel { deleteTarget = nil }
            )
        }
        .onAppear {
            // Reset search whenever this list re-appears (e.g. after returning
            // from a tapped row) so users come back to a fresh view.
            searchText = ""
            // Receipts tab loads its own data only
            appState.loadMyCardReceipts()
        }
    }
}

