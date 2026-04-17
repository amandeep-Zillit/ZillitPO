import SwiftUI

struct CodingQueueListView: View {
    let claims: [ClaimBatch]
    var isLoading: Bool = false
    @EnvironmentObject var appState: POViewModel
    @State private var activeFilter = "All"
    @State private var showFilterSheet = false
    @State private var navigateToDetail = false
    @State private var selectedClaim: ClaimBatch?

    private var filtered: [ClaimBatch] {
        switch activeFilter {
        case "Petty Cash": return claims.filter { $0.isPettyCash }
        case "Out of Pocket": return claims.filter { $0.isOutOfPocket }
        default: return claims
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                        Text(activeFilter).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8).background(Color.bgSurface).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }
                .buttonStyle(BorderlessButtonStyle())
                .selectionActionSheet(
                    title: "Filter by Type",
                    isPresented: $showFilterSheet,
                    options: ["All", "Petty Cash", "Out of Pocket"],
                    isSelected: { $0 == activeFilter },
                    label: { $0 },
                    onSelect: { activeFilter = $0 }
                )
                Spacer()
                Text("\(filtered.count) PENDING").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 10) {
                    if isLoading && claims.isEmpty {
                        LoaderView()
                    } else if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            Image(systemName: "doc.text").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                            Text("No claims in coding queue").font(.system(size: 13)).foregroundColor(.secondary)
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 480)
                    } else {
                        ForEach(filtered) { claim in
                            Button(action: { selectedClaim = claim; navigateToDetail = true }) {
                                ClaimRow(claim: claim)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
        .background(
            NavigationLink(destination: Group {
                if let c = selectedClaim { CodingDetailPage(claim: c).environmentObject(appState) }
                else { EmptyView() }
            }, isActive: $navigateToDetail) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Coding Detail Page
// ═══════════════════════════════════════════════════════════════════
