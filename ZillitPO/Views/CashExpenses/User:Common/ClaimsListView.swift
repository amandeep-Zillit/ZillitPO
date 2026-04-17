import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Claims List View (reusable)
// ═══════════════════════════════════════════════════════════════════

enum ClaimFilterMode { case status, expenseType, myClaims }

struct ClaimsListView: View {
    let claims: [ClaimBatch]
    var title: String = ""
    var isLoading: Bool = false
    @EnvironmentObject var appState: POViewModel
    @State private var searchText = ""
    @State private var showFilterSheet = false
    @State private var activeFilter = "All"

    var filterMode: ClaimFilterMode = .status
    var hideFilterSearch: Bool = false

    private var filters: [String] {
        switch filterMode {
        case .expenseType:
            return ["All", "Petty Cash", "Out of Pocket"]
        case .myClaims:
            return ["All", "With Coordinator", "In Audit", "Awaiting Approval", "Ready to Post", "Rejected", "Under Review", "Escalated", "Queried", "Posted"]
        case .status:
            var unique = Set<String>()
            for c in claims { unique.insert(c.statusDisplay) }
            var list = ["All"]
            let order = ["Coding", "Coded", "In Audit", "Awaiting Approval", "Escalated", "Approved", "Override", "Ready to Post", "Posted", "Rejected"]
            for s in order { if unique.contains(s) { list.append(s) } }
            for s in unique.sorted() { if !list.contains(s) { list.append(s) } }
            return list
        }
    }

    private var filtered: [ClaimBatch] {
        var list = claims
        if activeFilter != "All" {
            switch filterMode {
            case .expenseType:
                if activeFilter == "Petty Cash" { list = list.filter { $0.isPettyCash } }
                else if activeFilter == "Out of Pocket" { list = list.filter { $0.isOutOfPocket } }
            case .myClaims:
                let mapped: String = {
                    switch activeFilter {
                    case "With Coordinator": return "CODING"
                    case "In Audit": return "IN_AUDIT"
                    case "Awaiting Approval": return "AWAITING_APPROVAL"
                    case "Ready to Post": return "READY_TO_POST"
                    case "Rejected": return "REJECTED"
                    case "Under Review": return "UNDER_REVIEW"
                    case "Escalated": return "ESCALATED"
                    case "Queried": return "QUERIED"
                    case "Posted": return "POSTED"
                    default: return activeFilter.uppercased()
                    }
                }()
                list = list.filter { ($0.status ?? "").uppercased() == mapped || (($0.status ?? "").uppercased() == "CODED" && mapped == "CODING") }
            case .status:
                list = list.filter { $0.statusDisplay == activeFilter }
            }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter { ($0.batchReference ?? "").lowercased().contains(q) || ($0.notes ?? "").lowercased().contains(q) || ($0.department ?? "").lowercased().contains(q) }
        }
        return list.sorted { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !hideFilterSearch {
                // Search + Filter in one line
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                        TextField("Search claims…", text: $searchText).font(.system(size: 14))
                    }
                    .padding(10).background(Color.bgSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                    Button(action: { showFilterSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                            Text(activeFilter).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                            Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 10).background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .selectionActionSheet(
                        title: filterMode == .expenseType ? "Filter by Type" : "Filter by Status",
                        isPresented: $showFilterSheet,
                        options: filters,
                        isSelected: { $0 == activeFilter },
                        label: { $0 },
                        onSelect: { activeFilter = $0 }
                    )
                }.padding(.horizontal, 16).padding(.top, 12)
            }

            ScrollView {
                VStack(spacing: 10) {
                    if isLoading && claims.isEmpty {
                        LoaderView()
                    } else if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("No claims found").font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 480)
                    } else {
                        ForEach(filtered) { claim in
                            if filterMode == .myClaims {
                                NavigationLink(destination: ClaimDetailPage(claim: claim)) {
                                    ClaimRow(claim: claim)
                                }.buttonStyle(PlainButtonStyle())
                            } else {
                                ClaimRow(claim: claim)
                            }
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 20)
            }
        }
        .onAppear {
            // Reset search on re-appear (e.g. after returning from a tapped claim)
            searchText = ""
        }
    }
}

// MARK: - Claim Row
