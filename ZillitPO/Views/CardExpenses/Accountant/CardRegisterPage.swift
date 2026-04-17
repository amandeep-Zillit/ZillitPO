import SwiftUI
import UIKit

// ═══════════════════════════════════════════════════════════════════
// MARK: - Card Register Page
// ═══════════════════════════════════════════════════════════════════

struct CardRegisterPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToCardId: String? = nil
    @State private var navigateToRequestCard = false
    @State private var cardToAssign: ExpenseCard? = nil
    @State private var navigateToAssign = false
    @State private var rejectTargetCard: ExpenseCard? = nil
    @State private var rejectCardReason: String = ""
    @State private var showInlineRejectSheet = false
    @State private var cardToActivate: ExpenseCard? = nil
    @State private var navigateToActivate = false
    /// Search + status filter state — mirrors the web's CardRegisterPage.
    @State private var searchText: String = ""
    @State private var statusFilter: String = "all"
    @State private var showStatusFilterSheet: Bool = false

    /// Status filter options — keys match the web's STATUS_FILTERS.
    private let statusFilters: [(key: String, label: String)] = [
        ("all",        "All Status"),
        ("active",     "Active"),
        ("approved",   "Approved"),
        ("override",   "Override"),
        ("pending",    "Pending Approval"),
        ("requested",  "Requested"),
        ("rejected",   "Rejected"),
        ("suspended",  "Suspended"),
    ]

    private var statusFilterLabel: String {
        statusFilters.first { $0.key == statusFilter }?.label ?? "All Status"
    }

    /// Filter by status + free-text search — mirrors the web's filter logic
    /// (holder name, department, BS code, card issuer, last 4).
    private var filteredCards: [ExpenseCard] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return appState.userCards.filter { c in
            // Status filter
            if statusFilter != "all" && (c.status ?? "").lowercased() != statusFilter {
                return false
            }
            // Search
            guard !q.isEmpty else { return true }
            let holder = c.holderFullName.lowercased()
            let dept   = (c.department ?? "").lowercased()
            let bs     = (c.bsControlCode ?? "").lowercased()
            let issuer = (c.bankAccount?.name ?? c.cardIssuer ?? "").lowercased()
            let last4  = (c.lastFour ?? "").lowercased()
            return holder.contains(q)
                || dept.contains(q)
                || bs.contains(q)
                || issuer.contains(q)
                || last4.contains(q)
        }
    }

    private var tierCount: Int { appState.cardTierConfigRows.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // ── Fixed search + status filter toolbar ───────────────
                // (Stays pinned at the top while the card list scrolls.)
                HStack(spacing: 8) {
                    // Search
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray).font(.system(size: 12))
                        TextField("Search holder, dept, BS code, last 4…", text: $searchText)
                            .font(.system(size: 13))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12)).foregroundColor(.gray)
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color.bgSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                    // Status filter
                    Button(action: { showStatusFilterSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                            Text(statusFilterLabel)
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .selectionActionSheet(
                        title: "Filter by Status",
                        isPresented: $showStatusFilterSheet,
                        options: statusFilters.map { $0.key },
                        isSelected: { $0 == statusFilter },
                        label: { key in statusFilters.first { $0.key == key }?.label ?? key },
                        onSelect: { statusFilter = $0 }
                    )
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

                // ── Scrollable card list ────────────────────────────────
                ScrollView {
                    VStack(spacing: 12) {

                        // MARK: Cards Section
                        if appState.isLoadingCards && appState.userCards.isEmpty {
                            LoaderView()
                        } else if appState.userCards.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "creditcard").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                                Text("No cards yet").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                                Text("Tap Request Card to add one").font(.system(size: 12)).foregroundColor(.gray)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 480)
                        } else if filteredCards.isEmpty {
                            // Search/filter applied but no matches
                            VStack(spacing: 12) {
                                Spacer(minLength: 0)
                                Image(systemName: "magnifyingglass").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                                Text(searchText.isEmpty
                                     ? "No cards match this filter"
                                     : "No cards match \"\(searchText)\"")
                                    .font(.system(size: 13)).foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }.frame(maxWidth: .infinity, minHeight: 320)
                        } else {
                            // Hidden NavigationLink for Assign Physical Card
                            NavigationLink(
                                destination: Group {
                                    if let c = cardToAssign {
                                        AssignPhysicalCardPage(card: c).environmentObject(appState)
                                    } else { EmptyView() }
                                },
                                isActive: $navigateToAssign
                            ) { EmptyView() }
                            .frame(width: 0, height: 0).hidden()

                            ForEach(filteredCards) { card in
                                ZStack(alignment: .topLeading) {
                                    NavigationLink(
                                        destination: CardDetailPage(card: card).environmentObject(appState),
                                        tag: card.id,
                                        selection: $navigateToCardId
                                    ) { EmptyView() }
                                    .frame(width: 0, height: 0).hidden()

                                    CardRow(
                                        card: card,
                                        isAccountant: true,
                                        tierCount: tierCount,
                                        resolvedBankName: {
                                            if let bankId = card.bankAccount?.id, !bankId.isEmpty {
                                                return appState.bankAccounts.first { $0.id == bankId }?.name
                                            }
                                            return nil
                                        }(),
                                        onAssignPhysical: nil,
                                        onApprove: nil,
                                        onReject: nil,
                                        onOverride: nil,
                                        onActivate: {
                                            cardToActivate = card
                                            navigateToActivate = true
                                        }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture { navigateToCardId = card.id }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 90)
                }
            }

            Button(action: { navigateToRequestCard = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Request Card").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Color.gold).cornerRadius(28)
            }
            .padding(.trailing, 20).padding(.bottom, 24)
        }
        .background(Color.bgBase)
        .navigationBarTitle(Text("Card Register"), displayMode: .inline)
        .sheet(isPresented: $showInlineRejectSheet, onDismiss: { rejectCardReason = "" }) {
            NavigationView {
                ZStack {
                    Color.bgBase.edgesIgnoringSafeArea(.all)
                    VStack(alignment: .leading, spacing: 16) {
                        if let c = rejectTargetCard {
                            Text("Reject card request from \(c.holderFullName)")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reason").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                            TextField("Enter reason…", text: $rejectCardReason)
                                .font(.system(size: 14)).padding(10)
                                .background(Color.bgSurface).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                        }
                        Spacer()
                    }.padding()
                }
                .navigationBarTitle(Text("Reject Card"), displayMode: .inline)
                .navigationBarItems(
                    leading: Button("Cancel") { showInlineRejectSheet = false }.foregroundColor(.goldDark),
                    trailing: Button("Reject") {
                        let reason = rejectCardReason.trimmingCharacters(in: .whitespaces)
                        guard !reason.isEmpty, let c = rejectTargetCard else { return }
                        appState.rejectCard(c, reason: reason)
                        showInlineRejectSheet = false
                    }.foregroundColor(.red).font(.system(size: 16, weight: .bold))
                )
            }
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let c = cardToActivate {
                        ActivateCardPage(card: c).environmentObject(appState)
                    } else { EmptyView() }
                },
                isActive: $navigateToActivate
            ) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .background(
            NavigationLink(destination: RequestCardPage().environmentObject(appState),
                           isActive: $navigateToRequestCard) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .onAppear {
            // Reset search on re-appear (e.g. after returning from a tapped row)
            searchText = ""
            appState.loadUserCards()
            if appState.bankAccounts.isEmpty { appState.loadBankAccounts() }
        }
    }
}
